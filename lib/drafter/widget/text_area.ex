defmodule Drafter.Widget.TextArea do
  @moduledoc """
  A multi-line text editor widget with cursor navigation, scrolling, and optional syntax highlighting.

  Renders inside a bordered box. An optional line-number gutter can be enabled. Syntax
  highlighting is available for `:elixir`, `:python`, `:javascript`, and `:js` via the
  `:language` option. Placeholder text is shown when the content is empty and the widget
  is not focused.

  ## Options

    * `:text` - initial text content (default: `""`)
    * `:placeholder` - hint text shown when empty and unfocused (default: `""`)
    * `:on_change` - `(String.t() -> term())` called on every edit
    * `:max_lines` - maximum number of lines permitted
    * `:width` - widget width in columns (default: `40`)
    * `:height` - widget height in rows including borders (default: `6`)
    * `:show_line_numbers` - render a line-number gutter (default: `false`)
    * `:language` - atom for syntax highlighting: `:elixir`, `:python`, `:javascript`, `:js`
    * `:style` - map of style overrides for the text content area
    * `:line_number_style` - map of style overrides for the gutter

  ## Key bindings

    * Arrow keys — move cursor by character or line
    * `Home` / `End` — move to start/end of the current line
    * `Backspace` / `Delete` — delete character; joins lines at line boundaries
    * `Enter` — insert a new line at the cursor position

  ## Usage

      text_area(placeholder: "Notes...", height: 10, show_line_numbers: true, language: :elixir)
  """

  use Drafter.Widget,
    handles: [:keyboard, :char],
    focusable: true

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  defstruct [
    :text,
    :lines,
    :cursor_line,
    :cursor_col,
    :scroll_offset,
    :focused,
    :style,
    :placeholder_style,
    :focused_style,
    :on_change,
    :max_lines,
    :width,
    :height,
    :placeholder,
    :show_line_numbers,
    :line_number_style,
    :gutter_width,
    :language
  ]

  @type t :: %__MODULE__{
          text: String.t(),
          lines: [String.t()],
          cursor_line: non_neg_integer(),
          cursor_col: non_neg_integer(),
          scroll_offset: non_neg_integer(),
          focused: boolean(),
          style: Segment.style(),
          placeholder_style: Segment.style(),
          focused_style: Segment.style(),
          on_change: (String.t() -> term()) | nil,
          max_lines: pos_integer() | nil,
          width: pos_integer(),
          height: pos_integer(),
          placeholder: String.t(),
          show_line_numbers: boolean(),
          line_number_style: Segment.style(),
          gutter_width: pos_integer(),
          language: atom() | nil
        }

  @python_keywords ~w(def class if else elif for while return import from as try except finally with raise pass break continue lambda yield async await and or not in is True False None)
  @elixir_keywords ~w(def defp defmodule do end if else cond case when fn for with import alias require use true false nil and or not in)
  @javascript_keywords ~w(function const let var if else for while return import export from class extends new this true false null undefined async await try catch finally throw typeof instanceof)

  @impl Drafter.Widget
  def mount(props) do
    text = Map.get(props, :text, "")
    lines = String.split(text, "\n")
    show_line_numbers = Map.get(props, :show_line_numbers, false)

    gutter_width =
      if show_line_numbers do
        num_lines = length(lines)
        num_digits = max(3, String.length(Integer.to_string(num_lines)))
        num_digits + 1
      else
        0
      end

    %__MODULE__{
      text: text,
      lines: lines,
      cursor_line: 0,
      cursor_col: 0,
      scroll_offset: 0,
      focused: Map.get(props, :focused, false),
      style: Map.get(props, :style, %{fg: {200, 200, 200}, bg: {40, 40, 40}}),
      placeholder_style:
        Map.get(props, :placeholder_style, %{fg: {100, 100, 100}, bg: {40, 40, 40}}),
      focused_style: Map.get(props, :focused_style, %{fg: {255, 255, 255}, bg: {50, 100, 200}}),
      on_change: Map.get(props, :on_change),
      max_lines: Map.get(props, :max_lines),
      width: Map.get(props, :width, 40),
      height: Map.get(props, :height, 6),
      placeholder: Map.get(props, :placeholder, ""),
      show_line_numbers: show_line_numbers,
      line_number_style:
        Map.get(props, :line_number_style, %{fg: {100, 150, 255}, bg: {35, 35, 35}}),
      gutter_width: gutter_width,
      language: Map.get(props, :language)
    }
  end

  @impl Drafter.Widget
  def render(state, rect) do
    normalized_state =
      if is_struct(state, __MODULE__) do
        state
      else
        mount(state)
      end

    gutter_width = normalized_state.gutter_width
    content_width = max(1, rect.width - 2 - gutter_width)
    content_height = rect.height - 2

    computed = Computed.for_widget(:text_area, normalized_state)
    effective_style = Computed.to_segment_style(computed)

    border_computed = Computed.for_part(:text_area, normalized_state, :border)
    border_style = Computed.to_segment_style(border_computed)

    gutter_computed = Computed.for_part(:text_area, normalized_state, :gutter)
    gutter_style = Computed.to_segment_style(gutter_computed)

    line_num_style = Map.merge(gutter_style, normalized_state.line_number_style)

    top_border =
      "┌" <>
        if gutter_width > 0 do
          String.duplicate("─", gutter_width) <> "┬"
        else
          ""
        end <> String.duplicate("─", content_width) <> "┐"

    bottom_border =
      "└" <>
        if gutter_width > 0 do
          String.duplicate("─", gutter_width) <> "┴"
        else
          ""
        end <> String.duplicate("─", content_width) <> "┘"

    content_lines = render_content(normalized_state, content_width, content_height)

    strips =
      [
        Strip.new([Segment.new(String.pad_trailing(top_border, rect.width), border_style)])
        | Enum.with_index(content_lines, fn line, idx ->
            line_num = normalized_state.scroll_offset + idx + 1

            line_num_text =
              if gutter_width > 0,
                do: String.pad_leading(to_string(line_num), gutter_width - 1) <> " ",
                else: ""

            gutter_segment =
              if gutter_width > 0 do
                [Segment.new("│", border_style), Segment.new(line_num_text, line_num_style)]
              else
                [Segment.new("│", border_style)]
              end

            content_segments =
              if String.length(line) > 0 do
                if normalized_state.language do
                  highlight_line(line, normalized_state.language, effective_style)
                else
                  [Segment.new(line, effective_style)]
                end
              else
                []
              end

            padding_width = rect.width - gutter_width - String.length(line) - 2

            padding_segments =
              if padding_width > 0 do
                [Segment.new(String.duplicate(" ", padding_width), effective_style)]
              else
                []
              end

            all_segments =
              gutter_segment ++
                content_segments ++ padding_segments ++ [Segment.new("│", border_style)]

            Strip.new(all_segments)
          end)
      ] ++
        [
          Strip.new([
            Segment.new(String.pad_trailing(bottom_border, rect.width), border_style)
          ])
        ]

    strips
  end

  @impl Drafter.Widget
  def handle_event(event, state) do
    case event do
      {:key, :up} when state.focused ->
        move_cursor_up(state)

      {:key, :down} when state.focused ->
        move_cursor_down(state)

      {:key, :left} when state.focused ->
        move_cursor_left(state)

      {:key, :right} when state.focused ->
        move_cursor_right(state)

      {:key, :home} when state.focused ->
        new_state = %{state | cursor_col: 0}
        {:ok, new_state}

      {:key, :end} when state.focused ->
        current_line = Enum.at(state.lines, state.cursor_line, "")
        new_state = %{state | cursor_col: String.length(current_line)}
        {:ok, new_state}

      {:key, :backspace} when state.focused ->
        handle_backspace(state)

      {:key, :delete} when state.focused ->
        handle_delete(state)

      {:key, :enter} when state.focused ->
        handle_enter(state)

      {:char, char} when state.focused and is_integer(char) ->
        char_str = <<char::utf8>>

        if printable_char?(char_str) and can_insert_char?(state) do
          insert_char(state, char_str)
        else
          {:noreply, state}
        end

      {:key, key} when state.focused and is_atom(key) ->
        char = Atom.to_string(key)

        if printable_char?(char) and can_insert_char?(state) do
          insert_char(state, char)
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

  @impl Drafter.Widget
  def update(props, state) do
    text = Map.get(props, :text, state.text)
    lines = if text != state.text, do: String.split(text, "\n"), else: state.lines
    show_line_numbers = Map.get(props, :show_line_numbers, state.show_line_numbers)

    gutter_width =
      if show_line_numbers do
        num_lines = length(lines)
        num_digits = max(3, String.length(Integer.to_string(num_lines)))
        num_digits + 1
      else
        0
      end

    %{
      state
      | text: text,
        lines: lines,
        placeholder: Map.get(props, :placeholder, state.placeholder),
        focused: Map.get(props, :focused, state.focused),
        style: Map.get(props, :style, state.style),
        placeholder_style: Map.get(props, :placeholder_style, state.placeholder_style),
        focused_style: Map.get(props, :focused_style, state.focused_style),
        on_change: Map.get(props, :on_change, state.on_change),
        max_lines: Map.get(props, :max_lines, state.max_lines),
        width: Map.get(props, :width, state.width),
        height: Map.get(props, :height, state.height),
        show_line_numbers: show_line_numbers,
        line_number_style: Map.get(props, :line_number_style, state.line_number_style),
        gutter_width: gutter_width,
        language: Map.get(props, :language, state.language)
    }
  end

  defp render_content(state, content_width, content_height) do
    lines = state.lines
    focused = state.focused
    placeholder = state.placeholder

    # Show placeholder when empty and not focused
    if Enum.all?(lines, &(&1 == "")) and not focused and placeholder != "" do
      placeholder_lines =
        String.split(placeholder, "\n")
        |> Enum.map(fn line ->
          String.pad_trailing(String.slice(line, 0, content_width), content_width)
        end)
        |> Enum.take(content_height)

      # Pad to full height
      padding_needed = max(0, content_height - length(placeholder_lines))
      placeholder_lines ++ List.duplicate(String.duplicate(" ", content_width), padding_needed)
    else
      # Show actual content
      visible_lines =
        lines
        |> Enum.slice(state.scroll_offset, content_height)
        |> Enum.with_index(state.scroll_offset)
        |> Enum.map(fn {line, line_index} ->
          line_content = String.slice(line, 0, content_width)

          # Add cursor if this is the cursor line and focused
          if focused and line_index == state.cursor_line do
            insert_cursor_in_line(line_content, state.cursor_col, content_width)
          else
            String.pad_trailing(line_content, content_width)
          end
        end)

      # Pad to full height
      padding_needed = max(0, content_height - length(visible_lines))
      visible_lines ++ List.duplicate(String.duplicate(" ", content_width), padding_needed)
    end
  end

  defp insert_cursor_in_line(line, cursor_col, max_width) do
    padded_line = String.pad_trailing(line, max_width)
    cursor_pos = min(cursor_col, max_width - 1)

    if cursor_pos >= 0 and cursor_pos < String.length(padded_line) do
      {before, after_text} = String.split_at(padded_line, cursor_pos)
      after_char = String.slice(after_text, 1..-1//1) || ""
      before <> "█" <> after_char
    else
      padded_line <> "█"
    end
  end

  defp move_cursor_up(state) do
    if state.cursor_line > 0 do
      new_line = state.cursor_line - 1
      line_length = String.length(Enum.at(state.lines, new_line, ""))
      new_col = min(state.cursor_col, line_length)

      new_state =
        %{state | cursor_line: new_line, cursor_col: new_col}
        |> adjust_scroll()

      trigger_change(new_state)
      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  defp move_cursor_down(state) do
    if state.cursor_line < length(state.lines) - 1 do
      new_line = state.cursor_line + 1
      line_length = String.length(Enum.at(state.lines, new_line, ""))
      new_col = min(state.cursor_col, line_length)

      new_state =
        %{state | cursor_line: new_line, cursor_col: new_col}
        |> adjust_scroll()

      trigger_change(new_state)
      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  defp move_cursor_left(state) do
    if state.cursor_col > 0 do
      new_state = %{state | cursor_col: state.cursor_col - 1}
      trigger_change(new_state)
      {:ok, new_state}
    else
      # Move to end of previous line
      if state.cursor_line > 0 do
        prev_line = Enum.at(state.lines, state.cursor_line - 1, "")

        new_state =
          %{state | cursor_line: state.cursor_line - 1, cursor_col: String.length(prev_line)}
          |> adjust_scroll()

        trigger_change(new_state)
        {:ok, new_state}
      else
        {:ok, state}
      end
    end
  end

  defp move_cursor_right(state) do
    current_line = Enum.at(state.lines, state.cursor_line, "")

    if state.cursor_col < String.length(current_line) do
      new_state = %{state | cursor_col: state.cursor_col + 1}
      trigger_change(new_state)
      {:ok, new_state}
    else
      # Move to beginning of next line
      if state.cursor_line < length(state.lines) - 1 do
        new_state =
          %{state | cursor_line: state.cursor_line + 1, cursor_col: 0}
          |> adjust_scroll()

        trigger_change(new_state)
        {:ok, new_state}
      else
        {:ok, state}
      end
    end
  end

  defp handle_backspace(state) do
    current_line = Enum.at(state.lines, state.cursor_line, "")

    cond do
      state.cursor_col > 0 ->
        # Delete character in current line
        {before, after_text} = String.split_at(current_line, state.cursor_col)
        new_line_content = String.slice(before, 0..-2//1) <> after_text
        new_lines = List.replace_at(state.lines, state.cursor_line, new_line_content)

        new_state = %{
          state
          | lines: new_lines,
            cursor_col: state.cursor_col - 1,
            text: Enum.join(new_lines, "\n")
        }

        trigger_change(new_state)
        {:ok, new_state}

      state.cursor_line > 0 ->
        # Join with previous line
        prev_line = Enum.at(state.lines, state.cursor_line - 1, "")
        joined_line = prev_line <> current_line

        new_lines =
          state.lines
          |> List.replace_at(state.cursor_line - 1, joined_line)
          |> List.delete_at(state.cursor_line)

        new_state =
          %{
            state
            | lines: new_lines,
              cursor_line: state.cursor_line - 1,
              cursor_col: String.length(prev_line),
              text: Enum.join(new_lines, "\n")
          }
          |> adjust_scroll()

        trigger_change(new_state)
        {:ok, new_state}

      true ->
        {:ok, state}
    end
  end

  defp handle_delete(state) do
    current_line = Enum.at(state.lines, state.cursor_line, "")

    cond do
      state.cursor_col < String.length(current_line) ->
        # Delete character in current line
        {before, after_text} = String.split_at(current_line, state.cursor_col)
        new_line_content = before <> String.slice(after_text, 1..-1//1)
        new_lines = List.replace_at(state.lines, state.cursor_line, new_line_content)

        new_state = %{state | lines: new_lines, text: Enum.join(new_lines, "\n")}

        trigger_change(new_state)
        {:ok, new_state}

      state.cursor_line < length(state.lines) - 1 ->
        # Join with next line
        next_line = Enum.at(state.lines, state.cursor_line + 1, "")
        joined_line = current_line <> next_line

        new_lines =
          state.lines
          |> List.replace_at(state.cursor_line, joined_line)
          |> List.delete_at(state.cursor_line + 1)

        new_state = %{state | lines: new_lines, text: Enum.join(new_lines, "\n")}

        trigger_change(new_state)
        {:ok, new_state}

      true ->
        {:ok, state}
    end
  end

  defp handle_enter(state) do
    current_line = Enum.at(state.lines, state.cursor_line, "")
    {before, after_text} = String.split_at(current_line, state.cursor_col)

    new_lines =
      state.lines
      |> List.replace_at(state.cursor_line, before)
      |> List.insert_at(state.cursor_line + 1, after_text)

    new_state =
      %{
        state
        | lines: new_lines,
          cursor_line: state.cursor_line + 1,
          cursor_col: 0,
          text: Enum.join(new_lines, "\n")
      }
      |> adjust_scroll()

    trigger_change(new_state)
    {:ok, new_state}
  end

  defp insert_char(state, char) do
    current_line = Enum.at(state.lines, state.cursor_line, "")
    {before, after_text} = String.split_at(current_line, state.cursor_col)
    new_line_content = before <> char <> after_text

    new_lines = List.replace_at(state.lines, state.cursor_line, new_line_content)

    new_state = %{
      state
      | lines: new_lines,
        cursor_col: state.cursor_col + 1,
        text: Enum.join(new_lines, "\n")
    }

    trigger_change(new_state)
    {:ok, new_state}
  end

  defp adjust_scroll(state) do
    # Account for borders
    content_height = state.height - 2

    cond do
      state.cursor_line < state.scroll_offset ->
        %{state | scroll_offset: state.cursor_line}

      state.cursor_line >= state.scroll_offset + content_height ->
        %{state | scroll_offset: state.cursor_line - content_height + 1}

      true ->
        state
    end
  end

  defp printable_char?(char) do
    String.length(char) == 1 and String.printable?(char) and char not in ["\t", "\r"]
  end

  defp highlight_line(line, language, base_style) do
    keywords = get_keywords(language)
    bg = base_style[:bg] || {40, 40, 40}

    keyword_color = {200, 120, 220}
    string_color = {180, 200, 100}
    comment_color = {100, 120, 100}
    number_color = {180, 150, 100}
    function_color = {100, 180, 220}

    tokens = tokenize_line(line, language)

    Enum.map(tokens, fn {type, text} ->
      color =
        case type do
          :keyword ->
            if text in keywords, do: keyword_color, else: base_style[:fg] || {200, 200, 200}

          :string ->
            string_color

          :comment ->
            comment_color

          :number ->
            number_color

          :function ->
            function_color

          _ ->
            base_style[:fg] || {200, 200, 200}
        end

      Segment.new(text, %{fg: color, bg: bg})
    end)
  end

  defp get_keywords(:python), do: @python_keywords
  defp get_keywords(:elixir), do: @elixir_keywords
  defp get_keywords(:javascript), do: @javascript_keywords
  defp get_keywords(:js), do: @javascript_keywords
  defp get_keywords(_), do: []

  defp tokenize_line(line, language) do
    comment_prefix =
      case language do
        :python -> "#"
        :elixir -> "#"
        :javascript -> "//"
        :js -> "//"
        _ -> "#"
      end

    if String.contains?(line, comment_prefix) do
      [before_comment, comment_text] = String.split(line, comment_prefix, parts: 2)
      tokenize_code(before_comment, language) ++ [{:comment, comment_prefix <> comment_text}]
    else
      tokenize_code(line, language)
    end
  end

  defp tokenize_code(code, language) do
    keywords = get_keywords(language)

    pattern = ~r/("[^"]*"|'[^']*'|\b\d+\.?\d*\b|\b\w+\b(?=\s*\()?|\b\w+\b|[^\s\w"']+|\s+)/

    Regex.scan(pattern, code)
    |> Enum.map(fn [match] ->
      cond do
        String.starts_with?(match, "\"") or String.starts_with?(match, "'") ->
          {:string, match}

        Regex.match?(~r/^\d+\.?\d*$/, match) ->
          {:number, match}

        Regex.match?(~r/^\w+$/, match) and match in keywords ->
          {:keyword, match}

        Regex.match?(~r/^\w+$/, match) ->
          {:identifier, match}

        true ->
          {:other, match}
      end
    end)
  end

  defp can_insert_char?(state) do
    case state.max_lines do
      nil -> true
      max_lines -> length(state.lines) < max_lines
    end
  end

  defp trigger_change(state) do
    if state.on_change do
      try do
        state.on_change.(state.text)
      rescue
        _error -> :ok
      end
    end
  end
end
