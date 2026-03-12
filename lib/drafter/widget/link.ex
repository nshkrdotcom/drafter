defmodule Drafter.Widget.Link do
  @moduledoc """
  An inline hyperlink widget that opens a URL in the system browser when activated.

  Renders as underlined text. When focused or hovered the text is wrapped in square
  brackets (`[label]`) for visibility. Activating via Enter or mouse click invokes the
  platform's default browser opener (`open` on macOS, `xdg-open` on Linux,
  `cmd /c start` on Windows).

  ## Options

    * `:text` - display text; when omitted the `:url` is used as the label
    * `:url` - URL string to open (required for the link to function)
    * `:tooltip` - reserved for future tooltip display
    * `:style` - map of style overrides
    * `:classes` - list of theme class atoms

  ## Usage

      link("Elixir website", url: "https://elixir-lang.org")
  """

  use Drafter.Widget,
    handles: [:keyboard, :click],
    focusable: true

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  defstruct [
    :text,
    :url,
    :style,
    :classes,
    :app_module,
    :focused,
    :hovered,
    :tooltip
  ]

  @impl Drafter.Widget
  def mount(props) do
    %__MODULE__{
      text: Map.get(props, :text),
      url: Map.get(props, :url),
      style: Map.get(props, :style, %{}),
      classes: Map.get(props, :classes, []),
      app_module: Map.get(props, :app_module),
      focused: false,
      hovered: false,
      tooltip: Map.get(props, :tooltip)
    }
  end

  @impl Drafter.Widget
  def render(state, _rect) do
    state = if is_struct(state, __MODULE__), do: state, else: mount(state)

    classes = state.classes ++ if state.hovered, do: [:hover], else: []
    classes = classes ++ if state.focused, do: [:focus], else: []
    computed_opts = [classes: classes, style: state.style]
    computed_opts = if state.app_module, do: Keyword.put(computed_opts, :app_module, state.app_module), else: computed_opts
    computed = Computed.for_widget(:link, state, computed_opts)

    fg = computed[:color] || {100, 150, 255}
    bg = computed[:background] || {30, 30, 30}
    underline = computed[:underline] != false
    bold = computed[:bold] || false

    base_style = %{fg: fg, bg: bg}

    link_style = base_style
    |> Map.put(:underline, underline)
    |> Map.put(:bold, bold)

    display_text = state.text || state.url

    link_text = if state.focused or state.hovered do
      "[#{display_text}]"
    else
      display_text
    end

    link_strip = Strip.new([
      Segment.new(link_text, link_style)
    ])

    [link_strip]
  end

  @impl Drafter.Widget
  def handle_event(event, state) do
    state = if is_struct(state, __MODULE__), do: state, else: mount(state)

    case event do
      {:key, :enter} ->
        open_link(state)
        {:ok, state}

      {:mouse, %{type: :click}} ->
        open_link(state)
        {:ok, state}

      {:focus} ->
        {:ok, %{state | focused: true, hovered: true}}

      {:blur} ->
        {:ok, %{state | focused: false, hovered: false}}

      :hover ->
        {:ok, %{state | hovered: true}}

      :unhover ->
        {:ok, %{state | hovered: false}}

      _ ->
        {:noreply, state}
    end
  end

  @impl Drafter.Widget
  def update(props, state) do
    %{
      state
      | text: Map.get(props, :text, state.text),
        url: Map.get(props, :url, state.url),
        style: Map.get(props, :style, state.style),
        classes: Map.get(props, :classes, state.classes),
        app_module: Map.get(props, :app_module, state.app_module),
        tooltip: Map.get(props, :tooltip, state.tooltip)
    }
  end

  defp open_link(%{url: url}) when is_binary(url) do

    command = case :os.type() do
      {:unix, :darwin} -> ["open", url]
      {:unix, _} -> ["xdg-open", url]
      {:win32, _} -> ["cmd", "/c", "start", "", url]
    end

    {output, exit_code} = System.cmd(List.first(command), Enum.drop(command, 1), stderr_to_stdout: true)

    _output = output

    if exit_code != 0 do
    end

    :ok
  end

  defp open_link(_state) do
    :ok
  end
end
