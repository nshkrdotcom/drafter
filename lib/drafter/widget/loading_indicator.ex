defmodule Drafter.Widget.LoadingIndicator do
  @moduledoc """
  Renders an animated spinner with an optional label.

  The spinner frame advances automatically on each render using the monotonic
  clock, producing smooth animation at approximately 10 fps (`@spinner_speed`
  of 100 ms). An optional colour gradient cycles through the provided colours
  independently from the spinner frame.

  Send `:start` or `:stop` events to control animation at runtime.

  ## Options

    * `:text` - label text shown after the spinner character (default `"Loading..."`)
    * `:spinner_type` - spinner style: `:default` (Braille, 10 frames), `:dots`, `:line`, `:arrow`, `:bounce`, `:points`
    * `:running` - whether the spinner animates: `true` (default) / `false`
    * `:gradient_colors` - list of `{r, g, b}` tuples to cycle the spinner colour through
    * `:gradient_speed` - milliseconds per gradient step (default `50`)
    * `:style` - map of style properties
    * `:classes` - list of theme class atoms

  ## Usage

      loading_indicator(text: "Fetching data...")
      loading_indicator(spinner_type: :dots, gradient_colors: [{255, 0, 100}, {0, 100, 255}])
  """

  use Drafter.Widget

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  @spinner_speed 100
  @spinner_sets %{
    default: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    dots: ["⣾", "⣽", "⣻", "⢿"],
    line: ["-", "\\", "|", "/"],
    arrow: ["←", "↑", "→", "↓"],
    bounce: ["⠁", "⠂", "⠄", "⠂"],
    points: ["•", "·", "•", "·", "•"]
  }

  defstruct [
    :text,
    :spinner_type,
    :style,
    :classes,
    :app_module,
    :running,
    :_render_timestamp,
    :gradient_colors,
    :gradient_speed
  ]

  @impl Drafter.Widget
  def mount(props) do
    spinner_type = Map.get(props, :spinner_type, :default)
    text = Map.get(props, :text, "Loading...")
    running = Map.get(props, :running, true)
    timestamp = Map.get(props, :_render_timestamp, System.monotonic_time(:millisecond))

    gradient_colors = Map.get(props, :gradient_colors)
    gradient_speed = Map.get(props, :gradient_speed, 50)

    %__MODULE__{
      text: text,
      spinner_type: spinner_type,
      style: Map.get(props, :style, %{}),
      classes: Map.get(props, :classes, []),
      app_module: Map.get(props, :app_module),
      running: running,
      _render_timestamp: timestamp,
      gradient_colors: gradient_colors,
      gradient_speed: gradient_speed
    }
  end

  @impl Drafter.Widget
  def render(state, _rect) do
    state = if is_struct(state, __MODULE__), do: state, else: mount(state)

    classes = state.classes
    computed_opts = [classes: classes, style: state.style]
    computed_opts = if state.app_module, do: Keyword.put(computed_opts, :app_module, state.app_module), else: computed_opts
    computed = Computed.for_widget(:loading_indicator, state, computed_opts)

    spinner_chars = Map.get(@spinner_sets, state.spinner_type, @spinner_sets.default)

    frame = if state.running do
      System.monotonic_time(:millisecond) |> div(@spinner_speed)
    else
      0
    end

    spinner_char = Enum.at(spinner_chars, rem(frame, length(spinner_chars)))

    fg = if state.gradient_colors do
      gradient_frame = if state.running do
        System.monotonic_time(:millisecond) |> div(state.gradient_speed)
      else
        0
      end

      interpolate_gradient(state.gradient_colors, gradient_frame)
    else
      computed[:color] || {200, 200, 200}
    end

    bg = computed[:background] || {30, 30, 30}

    label_style = %{fg: fg, bg: bg}

    label_text = if state.text do
      " #{spinner_char} #{state.text} "
    else
      " #{spinner_char} "
    end

    label_strip = Strip.new([
      Segment.new(label_text, label_style)
    ])

    [label_strip]
  end

  @impl Drafter.Widget
  def handle_event(event, state) do
    state = if is_struct(state, __MODULE__), do: state, else: mount(state)

    case event do
      :start ->
        {:ok, %{state | running: true}}

      :stop ->
        {:ok, %{state | running: false}}

      _ ->
        {:noreply, state}
    end
  end

  @impl Drafter.Widget
  def update(props, state) do
    timestamp = Map.get(props, :_render_timestamp, System.monotonic_time(:millisecond))

    %{
      state
      | text: Map.get(props, :text, state.text),
        spinner_type: Map.get(props, :spinner_type, state.spinner_type),
        style: Map.get(props, :style, state.style),
        classes: Map.get(props, :classes, state.classes),
        app_module: Map.get(props, :app_module, state.app_module),
        running: Map.get(props, :running, state.running),
        _render_timestamp: timestamp,
        gradient_colors: Map.get(props, :gradient_colors, state.gradient_colors),
        gradient_speed: Map.get(props, :gradient_speed, state.gradient_speed)
    }
  end

  def get_render_key(_state) do
    System.monotonic_time(:millisecond)
  end

  defp interpolate_gradient(colors, frame) do
    num_colors = length(colors)

    if num_colors < 2 do
      hd(colors) || {200, 200, 200}
    else
      pos = rem(frame, num_colors * 100) / 100
      idx_float = pos * (num_colors - 1)
      idx = trunc(idx_float)
      next_idx = rem(idx + 1, num_colors)
      t = idx_float - idx

      {r1, g1, b1} = Enum.at(colors, idx)
      {r2, g2, b2} = Enum.at(colors, next_idx)

      r = round(r1 + (r2 - r1) * t)
      g = round(g1 + (g2 - g1) * t)
      b = round(b1 + (b2 - b1) * t)

      {r, g, b}
    end
  end
end
