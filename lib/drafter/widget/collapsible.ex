defmodule Drafter.Widget.Collapsible do
  @moduledoc """
  Renders an expandable section with a title row and collapsible text content.

  The widget displays a `▶` arrow when collapsed and `▼` when expanded.
  Pressing `Enter`, `Space`, or clicking the title row toggles the expanded
  state. The `:on_toggle` callback is invoked with the new boolean state after
  each toggle. Content text is word-wrapped to fit the available width.

  ## Options

    * `:title` - header text shown in the toggle row (default `"Collapsible"`)
    * `:content` - body text shown when expanded (default `""`)
    * `:expanded` - initial expansion state: `true` / `false` (default)
    * `:on_toggle` - one-arity callback invoked with the new `expanded` boolean

  ## Usage

      collapsible(title: "Details", content: "Full description here...")
      collapsible(title: "Advanced", content: long_text, expanded: true, on_toggle: &handle_toggle/1)
  """

  use Drafter.Widget,
    handles: [:keyboard, :click],
    focusable: true

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed
  alias Drafter.{Text, ThemeManager}

  defstruct [
    :title,
    :content,
    :expanded,
    :focused,
    :hovered,
    :on_toggle
  ]

  def mount(props) do
    %__MODULE__{
      title: Map.get(props, :title, "Collapsible"),
      content: Map.get(props, :content, ""),
      expanded: Map.get(props, :expanded, false),
      focused: Map.get(props, :focused, false),
      hovered: Map.get(props, :hovered, false),
      on_toggle: Map.get(props, :on_toggle)
    }
  end

  def render(state, rect) do
    theme = ThemeManager.get_current_theme()
    bg_style = %{fg: theme.text_primary, bg: theme.background}

    arrow = if state.expanded, do: "▼", else: "▶"

    title_computed = Computed.for_widget(:collapsible, state)
    arrow_computed = Computed.for_part(:collapsible, state, :arrow)

    title_style = Computed.to_segment_style(title_computed)
    arrow_style = Computed.to_segment_style(arrow_computed)

    title_text = " " <> state.title
    padded_title = String.pad_trailing(title_text, rect.width - 2)

    title_strip =
      Strip.new([
        Segment.new(arrow, arrow_style),
        Segment.new(padded_title, title_style)
      ])

    if state.expanded do
      content_lines = Text.wrap(state.content, rect.width - 2, :word)

      content_strips =
        Enum.map(content_lines, fn line ->
          padded_line = "  " <> Text.pad_right(line, rect.width - 2)
          Strip.new([Segment.new(padded_line, bg_style)])
        end)

      all_strips = [title_strip | content_strips]

      current_height = length(all_strips)

      if current_height < rect.height do
        empty_line = Segment.new(String.duplicate(" ", rect.width), bg_style)
        empty_strip = Strip.new([empty_line])
        padding = List.duplicate(empty_strip, rect.height - current_height)
        all_strips ++ padding
      else
        Enum.take(all_strips, rect.height)
      end
    else
      if rect.height > 1 do
        empty_line = Segment.new(String.duplicate(" ", rect.width), bg_style)
        empty_strip = Strip.new([empty_line])
        padding = List.duplicate(empty_strip, rect.height - 1)
        [title_strip | padding]
      else
        [title_strip]
      end
    end
  end

  def update(props, state) do
    Map.merge(state, props)
  end

  def handle_event(event, state) do

    case event do
      {:key, :enter} ->
        toggle(state)

      {:key, :" "} ->
        toggle(state)

      {:mouse, %{type: :click, y: 0} = _mouse_data} ->
        toggle(state)

      {:mouse, %{type: :click} = _mouse_data} ->
        {:noreply, state}

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

  defp toggle(state) do
    new_state = %{state | expanded: not state.expanded}

    if state.on_toggle do
      try do
        state.on_toggle.(new_state.expanded)
      rescue
        _ -> :ok
      end
    end

    {:ok, new_state, [:widget_layout_needed]}
  end
end
