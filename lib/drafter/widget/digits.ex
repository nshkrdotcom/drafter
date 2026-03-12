defmodule Drafter.Widget.Digits do
  @moduledoc """
  Renders numbers and symbols as large ASCII art using box-drawing characters.

  Supports the digits `0`–`9`, punctuation (`.`, `,`, `:`), arithmetic operators
  (`+`, `-`), and currency symbols (`$`, `£`, `€`, `¥`, `%`). Characters not in
  the pattern set are rendered as blank cells.

  ## Options

    * `:text` - string of characters to render (default `""`)
    * `:style` - map of style properties applied to all characters
    * `:align` - horizontal alignment within the available width: `:left` (default), `:center`, `:right`
    * `:size` - character size: `:large` (default, 7×5 chars) or `:small` (5×3 chars)

  ## Usage

      digits("12:34", size: :large, style: %{fg: {0, 200, 100}})
      digits("99%", size: :small, align: :center)
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
    " " => ["     ", "     ", "     "]
  }

  def mount(props) do
    %{
      text: Map.get(props, :text, ""),
      style: Map.get(props, :style, %{}),
      align: Map.get(props, :align, :left),
      size: Map.get(props, :size, :large)
    }
  end

  def render(state, rect) do
    digits = String.graphemes(state.text)

    if Enum.empty?(digits) do
      []
    else
      render_digits(digits, state, rect)
    end
  end

  def update(props, state) do
    Map.merge(state, props)
  end

  def handle_event(_event, state) do
    {:noreply, state}
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
