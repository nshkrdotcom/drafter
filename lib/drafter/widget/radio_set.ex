defmodule Drafter.Widget.RadioSet do
  @moduledoc """
  A mutually exclusive radio button group where exactly one option can be selected at a time.

  Options are rendered as a vertical list of `○` (unselected) and `●` (selected) indicators
  with labels. Arrow keys move the highlighted cursor; Enter or Space confirms the selection.
  Mouse clicks select the clicked option immediately.

  ## Options

    * `:options` - list of options in any of these formats:
        * `"label"` — string used as both ID and label
        * `{"label", id}` — tuple with a display label and an identifier
        * `%{id: id, label: label}` — map with explicit fields
    * `:selected` - ID of the initially selected option
    * `:on_change` - `(id -> term())` called with the selected option's ID on change
    * `:visible_height` - number of rows allocated for the list (default: number of options)

  ## Usage

      radio_set(
        options: [{"Light", :light}, {"Dark", :dark}, {"System", :system}],
        selected: :dark,
        on_change: fn theme -> IO.inspect(theme) end
      )
  """

  use Drafter.Widget,
    handles: [:keyboard],
    focusable: true

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  defstruct [
    :options,
    :selected_index,
    :highlighted_index,
    :focused,
    :on_change,
    :visible_height
  ]

  def mount(props) do
    options = Map.get(props, :options, [])
    selected = Map.get(props, :selected)

    selected_index =
      if selected do
        Enum.find_index(options, fn opt ->
          case opt do
            %{id: id} -> id == selected
            {_label, id} -> id == selected
            label when is_binary(label) -> label == selected
          end
        end) || 0
      else
        0
      end

    %__MODULE__{
      options: normalize_options(options),
      selected_index: selected_index,
      highlighted_index: selected_index,
      focused: Map.get(props, :focused, false),
      on_change: Map.get(props, :on_change),
      visible_height: Map.get(props, :visible_height, length(options))
    }
  end

  def render(state, rect) do
    computed = Computed.for_widget(:radio_set, state)
    bg_style = Computed.to_segment_style(computed)

    visible_options = Enum.take(state.options, rect.height)

    strips =
      visible_options
      |> Enum.with_index()
      |> Enum.map(fn {option, index} ->
        render_option(state, option, index, rect.width)
      end)

    current_height = length(strips)

    if current_height < rect.height do
      empty_line = Segment.new(String.duplicate(" ", rect.width), bg_style)
      empty_strip = Strip.new([empty_line])
      padding = List.duplicate(empty_strip, rect.height - current_height)
      strips ++ padding
    else
      strips
    end
  end

  def update(props, state) do
    raw_options = Map.get(props, :options)
    new_options = if raw_options, do: normalize_options(raw_options), else: state.options

    new_selected_index =
      cond do
        Map.has_key?(props, :selected) ->
          selected = props.selected

          Enum.find_index(new_options, fn %{id: id} -> id == selected end) ||
            state.selected_index

        raw_options ->
          min(state.selected_index, length(new_options) - 1)

        true ->
          state.selected_index
      end

    new_highlighted_index =
      if new_selected_index != state.selected_index,
        do: new_selected_index,
        else: state.highlighted_index

    %{
      state
      | options: new_options,
        selected_index: new_selected_index,
        highlighted_index: new_highlighted_index,
        on_change: Map.get(props, :on_change, state.on_change),
        visible_height: Map.get(props, :visible_height, state.visible_height)
    }
  end

  def handle_event(event, state) do
    case event do
      {:key, :up} ->
        new_index = max(0, state.highlighted_index - 1)
        {:ok, %{state | highlighted_index: new_index}}

      {:key, :down} ->
        max_index = length(state.options) - 1
        new_index = min(max_index, state.highlighted_index + 1)
        {:ok, %{state | highlighted_index: new_index}}

      {:key, :enter} ->
        select_current(state)

      {:key, :" "} ->
        select_current(state)

      {:mouse, %{type: :click, y: y}} ->
        if y >= 0 and y < length(state.options) do
          new_state = %{state | selected_index: y, highlighted_index: y}
          trigger_change(new_state)
          {:ok, new_state}
        else
          {:noreply, state}
        end

      {:focus} ->
        {:ok, %{state | focused: true}}

      {:blur} ->
        {:ok, %{state | focused: false}}

      _ ->
        {:noreply, state}
    end
  end

  defp select_current(state) do
    new_state = %{state | selected_index: state.highlighted_index}
    trigger_change(new_state)
    {:ok, new_state}
  end

  defp normalize_options(options) do
    Enum.map(options, fn
      %{id: _id, label: _label} = opt -> opt
      {label, id} -> %{id: id, label: to_string(label)}
      label when is_binary(label) -> %{id: label, label: label}
    end)
  end

  defp render_option(state, option, index, width) do
    is_selected = index == state.selected_index
    is_highlighted = index == state.highlighted_index && state.focused

    radio_char = if is_selected, do: "●", else: "○"

    option_state = %{
      selected: is_selected,
      focused: is_highlighted
    }

    computed = Computed.for_part(:radio_set, option_state, :option)
    text_style = Computed.to_segment_style(computed)

    radio_computed = Computed.for_part(:radio_set, option_state, :radio)
    radio_style = Computed.to_segment_style(radio_computed)

    bg_computed = Computed.for_part(:radio_set, %{}, :option)
    bg_style = Computed.to_segment_style(bg_computed)

    text = " " <> option.label
    text_len = String.length(text) + 2
    remaining = max(0, width - text_len)

    Strip.new([
      Segment.new(" ", text_style),
      Segment.new(radio_char, radio_style),
      Segment.new(text, text_style),
      Segment.new(String.duplicate(" ", remaining), bg_style)
    ])
  end

  defp trigger_change(state) do
    if state.on_change do
      option = Enum.at(state.options, state.selected_index)

      try do
        state.on_change.(option.id)
      rescue
        _error -> :ok
      end
    end
  end
end
