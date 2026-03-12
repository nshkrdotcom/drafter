defmodule Drafter.Compositor do
  @moduledoc false

  use GenServer

  alias Drafter.{Terminal, Event}
  alias Drafter.Draw.Strip

  defstruct [
    :terminal_driver,
    :event_manager,
    screen_buffer: [],
    dirty_regions: [],
    screen_size: {80, 24},
    rendering: false
  ]

  @type screen_buffer :: [Strip.t()]
  @type dirty_region :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer()
        }

  @doc "Start the compositor"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Render strips to screen buffer"
  @spec render_strips([Strip.t()], non_neg_integer(), non_neg_integer()) :: :ok
  def render_strips(strips, x \\ 0, y \\ 0) do
    GenServer.cast(__MODULE__, {:render_strips, strips, x, y})
  end

  @doc "Clear the screen"
  @spec clear_screen() :: :ok
  def clear_screen() do
    GenServer.cast(__MODULE__, :clear_screen)
  end

  @doc "Force a complete screen refresh"
  @spec refresh() :: :ok
  def refresh() do
    GenServer.cast(__MODULE__, :refresh)
  end

  @doc "Get current screen size"
  @spec get_screen_size() :: {pos_integer(), pos_integer()}
  def get_screen_size() do
    GenServer.call(__MODULE__, :get_screen_size)
  end

  @impl GenServer
  def init(opts) do
    terminal_driver = Keyword.get(opts, :terminal_driver, Terminal.Driver)
    event_manager = Keyword.get(opts, :event_manager, Event.Manager)

    Event.Manager.subscribe(self(), &resize_event?/1)

    state = %__MODULE__{
      terminal_driver: terminal_driver,
      event_manager: event_manager,
      screen_buffer: [],
      dirty_regions: [],
      screen_size: {80, 24},
      rendering: false
    }

    {width, height} = terminal_driver.get_size()
    initial_state = %{state | screen_size: {width, height}}

    empty_buffer = create_empty_buffer(width, height)
    final_state = %{initial_state | screen_buffer: empty_buffer}

    {:ok, final_state}
  end

  @impl GenServer
  def handle_call(:get_screen_size, _from, state) do
    {:reply, state.screen_size, state}
  end

  @impl GenServer
  def handle_cast({:render_strips, strips, x, y}, state) do
    new_state = render_strips_to_buffer(state, strips, x, y)
    schedule_render(new_state)
  end

  def handle_cast(:clear_screen, state) do
    {width, height} = state.screen_size
    empty_buffer = create_empty_buffer(width, height)
    new_state = %{state | screen_buffer: empty_buffer}
    schedule_render(new_state)
  end

  def handle_cast(:refresh, state) do
    {width, height} = state.screen_size
    dirty_region = %{x: 0, y: 0, width: width, height: height}
    new_state = %{state | dirty_regions: [dirty_region]}
    schedule_render(new_state)
  end

  @impl GenServer
  def handle_info({:tui_event, {:resize, {width, height}}}, state) do
    new_buffer = create_empty_buffer(width, height)

    new_state = %{
      state
      | screen_size: {width, height},
        screen_buffer: new_buffer,
        dirty_regions: [%{x: 0, y: 0, width: width, height: height}]
    }

    schedule_render(new_state)
  end

  def handle_info(:render_frame, state) do
    if not Enum.empty?(state.dirty_regions) do
      render_to_terminal(state)
      {:noreply, %{state | dirty_regions: [], rendering: false}}
    else
      {:noreply, %{state | rendering: false}}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp resize_event?({:resize, _}), do: true
  defp resize_event?(_), do: false

  defp create_empty_buffer(width, height) do
    empty_strip = Strip.from_text(String.duplicate(" ", width))
    List.duplicate(empty_strip, height)
  end

  defp render_strips_to_buffer(state, strips, x, y) do
    {buffer_width, buffer_height} = state.screen_size

    updated_buffer = update_buffer(state.screen_buffer, strips, x, y, buffer_width, buffer_height)

    strips_height = length(strips)
    strips_width = if strips_height > 0, do: Strip.width(List.first(strips)), else: 0

    dirty_region = %{
      x: x,
      y: y,
      width: min(strips_width, buffer_width - x),
      height: min(strips_height, buffer_height - y)
    }

    %{state | screen_buffer: updated_buffer, dirty_regions: [dirty_region | state.dirty_regions]}
  end

  defp update_buffer(buffer, strips, x, y, buffer_width, buffer_height) do
    strips
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {strip, strip_index}, acc_buffer ->
      line_y = y + strip_index

      if line_y >= 0 and line_y < buffer_height do
        List.update_at(acc_buffer, line_y, fn existing_strip ->
          merge_strips(existing_strip, strip, x, buffer_width)
        end)
      else
        acc_buffer
      end
    end)
  end

  defp merge_strips(existing_strip, new_strip, x, buffer_width) do
    new_strip_width = Strip.width(new_strip)

    if x <= 0 do
      Strip.pad(new_strip, buffer_width)
    else
      {left_part, _} = Strip.divide(existing_strip, x)

      right_start = x + new_strip_width

      if right_start < buffer_width do
        {_, right_part} = Strip.divide(existing_strip, right_start)
        combined = Strip.combine(Strip.combine(left_part, new_strip), right_part)
        Strip.pad(combined, buffer_width)
      else
        combined = Strip.combine(left_part, new_strip)
        Strip.pad(combined, buffer_width)
      end
    end
  end

  defp schedule_render(state) do
    if not state.rendering do
      send(self(), :render_frame)
      {:noreply, %{state | rendering: true}}
    else
      {:noreply, state}
    end
  end

  defp render_to_terminal(state) do
    output = build_terminal_output(state.screen_buffer, state.dirty_regions)

    state.terminal_driver.write(output)
  end

  defp build_terminal_output(screen_buffer, _dirty_regions) do
    output = [
      Terminal.ANSI.cursor_to(1, 1),
      Terminal.ANSI.sync_start()
    ]

    screen_output =
      screen_buffer
      |> Enum.with_index()
      |> Enum.map(fn {strip, line_index} ->
        [
          Terminal.ANSI.cursor_to(1, line_index + 1),
          Strip.to_ansi(strip)
        ]
      end)

    output ++ screen_output ++ [Terminal.ANSI.sync_end()]
  end
end
