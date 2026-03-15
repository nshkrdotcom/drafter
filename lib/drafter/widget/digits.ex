defmodule Drafter.Widget.Digits do
  @moduledoc """
  Renders numbers and symbols as large ASCII art using box-drawing characters.

  Supports the digits `0`–`9`, punctuation (`.`, `,`, `:`, `/`), arithmetic
  operators (`+`, `-`), currency symbols (`$`, `£`, `€`, `¥`, `%`), SI-prefix
  letters (`K`, `k`, `M`, `m`, `B`, `G`, `T`), unit letters (`C`, `s`, `°`),
  and the scientific-notation letter `e`. Characters not in the pattern set are
  rendered as blank cells.

  ## Options

    * `:text` - string of characters to render (default `""`)
    * `:style` - map of style properties applied to all characters
    * `:align` - horizontal alignment within the available width: `:left` (default), `:center`, `:right`
    * `:size` - character size: `:large` (default, 7×5 chars) or `:small` (5×3 chars)
    * `:bg_data` - optional list of numbers; when set, renders an area-chart fill behind the digits using per-cell bg colors (same composite as Grafana's graphMode: area stat panel)
    * `:color` - `{r, g, b}` fill color for the area chart (default `{0, 150, 255}`); digit glyphs are rendered with an auto-contrasting fg color

  ## Usage

      digits("12:34", size: :large, style: %{fg: {0, 200, 100}})
      digits("99%", size: :small, align: :center)
      digits("42%", bg_data: history, color: {0, 180, 120}, size: :large, align: :center)
  """

  @behaviour Drafter.Widget

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  @large_patterns %{
    "0" => ["╭─────╮", "│     │", "│     │", "│     │", "╰─────╯"],
    "1" => ["   ╷   ", "   │   ", "   │   ", "   │   ", "   ╵   "],
    "2" => ["╭─────╮", "      │", "╭─────╯", "│      ", "╰─────╯"],
    "3" => ["╭─────╮", "      │", " ─────┤", "      │", "╰─────╯"],
    "4" => ["╷     ╷", "│     │", "╰─────┤", "      │", "      ╵"],
    "5" => ["╭─────╮", "│      ", "╰─────╮", "      │", "╰─────╯"],
    "6" => ["╭─────╮", "│      ", "├─────╮", "│     │", "╰─────╯"],
    "7" => ["╭─────╮", "      │", "      │", "      │", "      ╵"],
    "8" => ["╭─────╮", "│     │", "├─────┤", "│     │", "╰─────╯"],
    "9" => ["╭─────╮", "│     │", "╰─────┤", "      │", "╰─────╯"],
    ":" => ["      ", "  ●   ", "      ", "  ●   ", "      "],
    "." => ["      ", "      ", "      ", "      ", "  ●   "],
    "," => ["      ", "      ", "      ", "  ●   ", " ╱    "],
    "-" => ["       ", "       ", "╶─────╴", "       ", "       "],
    "+" => ["       ", "   │   ", "╶──┼──╴", "   │   ", "       "],
    "$" => ["   ╷╷  ", "╭──┼┼─╮", "╰──┼┼─╮", "╭──┼┼─╯", "   ╵╵  "],
    "£" => ["  ╭────", "  │    ", "╶─┼───╴", "  │    ", "╰─┴───╴"],
    "€" => [" ╭────╮", "╶┤     ", "╶┤     ", " │     ", " ╰────╯"],
    "¥" => ["╲     ╱", " ╲   ╱ ", "╶──┬──╴", "   │   ", "   ╵   "],
    "%" => ["●    ╱ ", "    ╱  ", "   ╱   ", "  ╱    ", " ╱    ●"],
    "K" => ["│    ╱ ", "│   ╱  ", "├──╱   ", "│   ╲  ", "╵    ╲ "],
    "k" => ["│      ", "│   ╱  ", "├──╱   ", "│   ╲  ", "╵    ╲ "],
    "M" => ["╭─┬─╮  ", "│ │ │  ", "│   │  ", "│   │  ", "╵   ╵  "],
    "m" => ["       ", " ╭─┬─╮ ", " │ │ │ ", " │   │ ", " ╵   ╵ "],
    "B" => ["╭───── ", "│     ╲", "├─────╱", "│     ╲", "├─────╯"],
    "G" => ["╭─────╮", "│      ", "│   ──╮", "│     │", "╰─────╯"],
    "T" => ["───┬───", "   │   ", "   │   ", "   │   ", "   ╵   "],
    "C" => ["╭─────╮", "│      ", "│      ", "│      ", "╰─────╯"],
    "s" => [" ╭────╮", " │     ", " ╰────╮", "      │", " ╰────╯"],
    "e" => ["       ", " ╭───╮ ", " ├───╯ ", " │     ", " ╰───╯ "],
    "°" => [" ╭─╮   ", " ╰─╯   ", "       ", "       ", "       "],
    "/" => ["      ╱", "     ╱ ", "    ╱  ", "   ╱   ", "  ╱    "],
    " " => ["      ", "      ", "      ", "      ", "      "]
  }

  @small_patterns %{
    "0" => ["╭───╮", "│   │", "╰───╯"],
    "1" => ["  ╷  ", "  │  ", "  ╵  "],
    "2" => ["╭───╮", "╭───╯", "╰───╴"],
    "3" => ["╭───╮", " ───┤", "╰───╯"],
    "4" => ["╷   ╷", "╰───┤", "    ╵"],
    "5" => ["╭───╴", "╰───╮", "╰───╯"],
    "6" => ["╭───╴", "├───╮", "╰───╯"],
    "7" => ["╭───╮", "    │", "    ╵"],
    "8" => ["╭───╮", "├───┤", "╰───╯"],
    "9" => ["╭───╮", "╰───┤", "╰───╯"],
    ":" => ["     ", "  ●  ", "  ●  "],
    "." => ["     ", "     ", "  ●  "],
    "," => ["     ", "  ●  ", " ╱   "],
    "-" => ["     ", "╶───╴", "     "],
    "+" => ["  │  ", "──┼──", "  │  "],
    "$" => ["╭─┼─╮", "╰─┼─╮", "╰─┼─╯"],
    "£" => [" ╭─╮ ", " ├─  ", "╰──  "],
    "€" => ["╭═══", "╞══ ", "╰═══"],
    "¥" => ["╲ ╱ ", "═══ ", " │  "],
    "%" => ["●  ╱ ", "  ╱  ", " ╱  ●"],
    "K" => ["│  ╱ ", "├─╱  ", "╵  ╲ "],
    "k" => ["│    ", "├─╱  ", "╵  ╲ "],
    "M" => ["╭─┬─╮", "│ │ │", "╵   ╵"],
    "m" => [" ╭┬╮ ", " │ │ ", " ╵ ╵ "],
    "B" => ["╭───╮", "├─╲─┤", "├───╯"],
    "G" => ["╭───╮", "│ ──┤", "╰───╯"],
    "T" => ["──┬──", "  │  ", "  ╵  "],
    "C" => ["╭───╮", "│    ", "╰───╯"],
    "s" => ["╭──╴ ", " ╰──╮", "╶──╯ "],
    "e" => [" ╭─╮ ", " ├─╯ ", " ╰─╯ "],
    "°" => ["╭─╮  ", "╰─╯  ", "     "],
    "/" => ["   ╱ ", "  ╱  ", " ╱   "],
    " " => ["     ", "     ", "     "]
  }

  def mount(props) do
    %{
      text: Map.get(props, :text, ""),
      style: Map.get(props, :style, %{}),
      align: Map.get(props, :align, :left),
      size: Map.get(props, :size, :large),
      bg_data: Map.get(props, :bg_data),
      color: Map.get(props, :color, {0, 150, 255}),
      bg_min: Map.get(props, :bg_min, 0),
      bg_max: Map.get(props, :bg_max)
    }
  end

  def render(state, rect) do
    digits = String.graphemes(state.text)

    if Enum.empty?(digits) do
      []
    else
      case state.bg_data do
        nil -> render_digits(digits, state, rect)
        data -> render_with_bg(digits, data, state, rect)
      end
    end
  end

  def update(props, state) do
    Map.merge(state, props)
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  @braille_base 0x2800
  @braille_dot_offsets %{
    {0, 0} => 0x01,
    {0, 1} => 0x02,
    {0, 2} => 0x04,
    {0, 3} => 0x40,
    {1, 0} => 0x08,
    {1, 1} => 0x10,
    {1, 2} => 0x20,
    {1, 3} => 0x80
  }

  defp render_with_bg(digits, data, state, rect) do
    {patterns, digit_height} =
      if state.size == :small, do: {@small_patterns, 3}, else: {@large_patterns, 5}

    computed = Computed.for_widget(:digits, state, style: state.style)
    effective_style = Computed.to_segment_style(computed)
    digit_fg = Map.get(effective_style, :fg)

    glyph_width =
      digits
      |> Enum.map(&(Map.get(patterns, &1, patterns[" "]) |> hd() |> String.length()))
      |> Enum.sum()

    left_offset =
      case state.align do
        :center -> max(0, div(rect.width - glyph_width, 2))
        :right -> max(0, rect.width - glyph_width)
        _ -> 0
      end

    top_offset = max(0, div(rect.height - digit_height, 2))
    glyph_map = build_glyph_map(digits, patterns, left_offset, top_offset)

    pixel_width = rect.width * 2
    pixel_height = rect.height * 4
    sampled = sample_data(data, pixel_width)
    min_val = state.bg_min || 0
    max_val = state.bg_max || Enum.max(sampled, fn -> 1 end)
    range = max(max_val - min_val, 1)

    line_pixels =
      Enum.with_index(sampled, fn v, x ->
        y_norm = (v - min_val) / range * (pixel_height - 1)
        y = y_norm |> round() |> min(pixel_height - 1) |> max(0)
        {x, pixel_height - 1 - y}
      end)

    braille_map =
      line_pixels
      |> Enum.filter(fn {x, y} -> x >= 0 and x < pixel_width and y >= 0 and y < pixel_height end)
      |> Enum.group_by(fn {x, y} -> {div(x, 2), div(y, 4)} end)
      |> Map.new(fn {{cx, cy}, pixels} ->
        bits =
          Enum.reduce(pixels, 0, fn {x, y}, acc ->
            acc + Map.get(@braille_dot_offsets, {rem(x, 2), rem(y, 4)}, 0)
          end)

        {{cx, cy}, <<@braille_base + bits::utf8>>}
      end)

    line_color = state.color

    Enum.map(0..(rect.height - 1), fn row ->
      segments =
        Enum.map(0..(rect.width - 1), fn col ->
          glyph_char = Map.get(glyph_map, {row, col})
          braille = Map.get(braille_map, {col, row})

          cond do
            glyph_char && glyph_char != " " ->
              Segment.new(glyph_char, if(digit_fg, do: %{fg: digit_fg}, else: %{}))

            braille ->
              Segment.new(braille, %{fg: line_color})

            true ->
              Segment.new(" ", %{})
          end
        end)

      Strip.new(segments)
    end)
  end


  defp build_glyph_map(digits, patterns, left_offset, top_offset) do
    digits
    |> Enum.reduce({%{}, left_offset}, fn digit, {map, col_offset} ->
      pattern = Map.get(patterns, digit, patterns[" "])
      char_width = pattern |> hd() |> String.length()

      row_map =
        pattern
        |> Enum.with_index()
        |> Enum.reduce(map, fn {row_str, row_idx}, acc ->
          row_str
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {ch, c}, inner ->
            Map.put(inner, {top_offset + row_idx, col_offset + c}, ch)
          end)
        end)

      {row_map, col_offset + char_width}
    end)
    |> elem(0)
  end


  defp sample_data(data, width) do
    len = length(data)

    cond do
      len == 0 -> List.duplicate(0, width)
      len == width -> data
      true ->
        Enum.map(0..(width - 1), fn i ->
          idx = round(i * (len - 1) / max(width - 1, 1))
          Enum.at(data, idx)
        end)
    end
  end



  defp render_digits(digits, state, rect) do
    computed = Computed.for_widget(:digits, state, style: state.style)
    effective_style = Computed.to_segment_style(computed)

    {patterns, digit_height} =
      if state.size == :small do
        {@small_patterns, 3}
      else
        {@large_patterns, 5}
      end

    digit_rows =
      0..(digit_height - 1)
      |> Enum.map(fn row ->
        line_text =
          digits
          |> Enum.map(fn digit ->
            pattern = Map.get(patterns, digit, patterns[" "])
            Enum.at(pattern, row, "     ")
          end)
          |> Enum.join("")

        segment = Segment.new(line_text, effective_style)
        strip = Strip.new([segment])

        case state.align do
          :center -> align_center(strip, rect.width, effective_style)
          :right -> align_right(strip, rect.width, effective_style)
          _ -> align_left(strip, rect.width, effective_style)
        end
      end)

    if rect.height <= digit_height do
      Enum.take(digit_rows, rect.height)
    else
      empty_strip = Strip.new([Segment.new(String.duplicate(" ", rect.width), effective_style)])
      top_pad = div(rect.height - digit_height, 2)
      bottom_pad = rect.height - digit_height - top_pad
      top_rows = List.duplicate(empty_strip, top_pad)
      bottom_rows = List.duplicate(empty_strip, bottom_pad)
      top_rows ++ digit_rows ++ bottom_rows
    end
  end

  defp align_left(strip, width, bg_style) do
    strip_width = Strip.width(strip)

    if strip_width >= width do
      Strip.crop(strip, width)
    else
      padding_width = width - strip_width
      padding = Segment.new(String.duplicate(" ", padding_width), bg_style)
      Strip.new(strip.segments ++ [padding])
    end
  end

  defp align_center(strip, width, bg_style) do
    strip_width = Strip.width(strip)

    if strip_width >= width do
      Strip.crop(strip, width)
    else
      total_padding = width - strip_width
      left_padding = div(total_padding, 2)
      right_padding = total_padding - left_padding
      left_seg = Segment.new(String.duplicate(" ", left_padding), bg_style)
      right_seg = Segment.new(String.duplicate(" ", right_padding), bg_style)
      Strip.new([left_seg] ++ strip.segments ++ [right_seg])
    end
  end

  defp align_right(strip, width, bg_style) do
    strip_width = Strip.width(strip)

    if strip_width >= width do
      Strip.crop(strip, width)
    else
      padding_width = width - strip_width
      padding = Segment.new(String.duplicate(" ", padding_width), bg_style)
      Strip.new([padding] ++ strip.segments)
    end
  end
end
