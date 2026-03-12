defmodule Drafter.Widget.Chart do
  @moduledoc """
  Renders time-series and financial data as interactive charts with multiple styles.

  Five chart types are supported: `:line`, `:area`, `:bar`, `:scatter`, and
  `:candlestick`. Braille-dot rendering (`:braille` marker) provides the highest
  resolution at two data points per column and four per row. Alternatively
  `:half_block`, `:block`, and `:dot` markers are available for all chart types.

  Scatter data points accept either `[x, y]` lists or `{x, y}` tuples.
  Candlestick candles accept `[open, high, low, close]` lists or maps with
  `:open`, `:high`, `:low`, `:close` keys.

  ## Keyboard Controls (when focused)

    * `←` / `→` — scroll the X-axis by 5 data points
    * `↑` / `↓` — pan the Y-axis up/down by 1 unit
    * `c` — re-anchor the Y-axis to the rightmost visible candle open price
    * Click and drag — pan both axes simultaneously

  ## Options

    * `:data` - list of numeric values, or candle/scatter tuples depending on `:chart_type`
    * `:chart_type` - `:line` (default), `:area`, `:bar`, `:scatter`, `:candlestick`
    * `:marker` - render density: `:braille` (default), `:half_block`, `:block`, `:dot`
    * `:min_value` - explicit Y minimum; auto-detected from data when omitted
    * `:max_value` - explicit Y maximum; auto-detected from data when omitted
    * `:color` - `{r, g, b}` primary colour
    * `:colors` - list of `{r, g, b}` tuples for multi-series data
    * `:show_axes` - draw X and Y axis lines: `true` / `false` (default)
    * `:show_labels` - draw axis tick labels: `true` / `false` (default)
    * `:title` - string displayed at the top of the chart
    * `:x_labels` - list of strings for X-axis tick labels
    * `:y_labels` - list of strings for Y-axis tick labels
    * `:animated` - animate new data points: `true` / `false` (default)
    * `:animation_speed` - milliseconds per animation frame (default `100`)
    * `:style` - map of style properties
    * `:classes` - list of theme class atoms

  ## Usage

      chart(data: [1, 4, 2, 8, 5, 9, 3], chart_type: :line)
      chart(data: candles, chart_type: :candlestick, show_axes: true)
      chart(data: points, chart_type: :scatter, marker: :dot, colors: [{0, 200, 100}])
  """

  use Drafter.Widget,
    handles: [:keyboard, :click, :drag],
    scroll: [direction: :horizontal, step: 5],
    focusable: true

  import Bitwise

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.Style.Computed

  @type chart_type :: :line | :bar | :candlestick | :area | :scatter | :braille
  @type marker :: :braille | :half_block | :block | :dot

  defstruct [
    :data,
    :chart_type,
    :marker,
    :min_value,
    :max_value,
    :width,
    :height,
    :style,
    :classes,
    :app_module,
    :color,
    :colors,
    :show_axes,
    :show_labels,
    :title,
    :x_labels,
    :y_labels,
    :animated,
    :animation_speed,
    :_render_timestamp,
    :_animation_offset,
    :_live_candle,
    :_scroll_offset,
    :_drag_last_x,
    :_drag_last_y,
    :_y_offset,
    dragging_scrollbar: false,
    focused: false
  ]

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

  @block_chars [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  @impl Drafter.Widget
  def mount(props) do
    data = Map.get(props, :data, [])

    {min_val, max_val} = calculate_data_range(data, props)

    live_candle = init_live_candle(data)

    %__MODULE__{
      data: data,
      chart_type: Map.get(props, :chart_type, :line),
      marker: Map.get(props, :marker, :braille),
      min_value: min_val,
      max_value: max_val,
      width: Map.get(props, :width),
      height: Map.get(props, :height, 1),
      color: Map.get(props, :color),
      colors: Map.get(props, :colors, []),
      show_axes: Map.get(props, :show_axes, false),
      show_labels: Map.get(props, :show_labels, false),
      title: Map.get(props, :title),
      x_labels: Map.get(props, :x_labels, []),
      y_labels: Map.get(props, :y_labels, []),
      animated: Map.get(props, :animated, false),
      animation_speed: Map.get(props, :animation_speed, 100),
      style: Map.get(props, :style, %{}),
      classes: Map.get(props, :classes, []),
      app_module: Map.get(props, :app_module),
      _render_timestamp: Map.get(props, :_render_timestamp, 0),
      _animation_offset: 0,
      _live_candle: live_candle,
      _scroll_offset: 0,
      _drag_last_x: nil,
      _drag_last_y: nil,
      _y_offset: 0,
      dragging_scrollbar: false
    }
  end

  @impl Drafter.Widget
  def handle_click(_x, _y, state) do
    {:ok, %{state | dragging_scrollbar: true, _drag_last_x: nil}}
  end

  @impl Drafter.Widget
  def handle_key(:left, state), do: scroll_left(state)
  def handle_key(:"ArrowLeft", state), do: scroll_left(state)
  def handle_key(:right, state), do: scroll_right(state)
  def handle_key(:"ArrowRight", state), do: scroll_right(state)
  def handle_key(:up, state), do: {:ok, %{state | _y_offset: (state._y_offset || 0) + 1}}
  def handle_key(:"ArrowUp", state), do: {:ok, %{state | _y_offset: (state._y_offset || 0) + 1}}
  def handle_key(:down, state), do: {:ok, %{state | _y_offset: (state._y_offset || 0) - 1}}
  def handle_key(:"ArrowDown", state), do: {:ok, %{state | _y_offset: (state._y_offset || 0) - 1}}
  def handle_key(?c, state), do: {:ok, %{state | _y_offset: 0}}
  def handle_key(_key, state), do: {:bubble, state}

  @impl Drafter.Widget
  def handle_drag(x, y, %{_drag_last_x: nil} = state) do
    {:ok, %{state | _drag_last_x: x, _drag_last_y: y}}
  end

  def handle_drag(x, y, state) do
    dx = (state._drag_last_x || x) - x
    dy = y - (state._drag_last_y || y)
    new_x_offset = max(0, (state._scroll_offset || 0) + dx)
    new_y_offset = (state._y_offset || 0) + dy
    {:ok, %{state | _scroll_offset: new_x_offset, _drag_last_x: x, _y_offset: new_y_offset, _drag_last_y: y}}
  end

  defp scroll_left(state), do: {:ok, %{state | _scroll_offset: max(0, (state._scroll_offset || 0) - 5)}}
  defp scroll_right(state), do: {:ok, %{state | _scroll_offset: (state._scroll_offset || 0) + 5}}

  defp init_live_candle(data) when is_list(data) and length(data) > 0 do
    last_candle = List.last(data)

    close =
      case last_candle do
        [_, _, _, c | _] -> c
        _ -> 1.0850
      end

    %{
      open: close,
      high: close,
      low: close,
      close: close,
      price_prints: 0,
      prints_until_complete: 5 + :rand.uniform(10)
    }
  end

  defp init_live_candle(_) do
    %{
      open: 1.0850,
      high: 1.0850,
      low: 1.0850,
      close: 1.0850,
      price_prints: 0,
      prints_until_complete: 5 + :rand.uniform(10)
    }
  end

  @impl Drafter.Widget
  def render(state, rect) do
    state = if is_struct(state, __MODULE__), do: state, else: mount(state)

    computed =
      Computed.for_widget(:chart, state,
        classes: state.classes,
        style: state.style,
        app_module: state.app_module
      )

    bg = computed[:background] || {20, 20, 30}
    fg = state.color || computed[:color] || {100, 200, 255}

    chart_height = if state.show_axes, do: max(1, rect.height - 2), else: rect.height
    chart_width = if state.show_axes, do: max(1, rect.width - 6), else: rect.width

    animation_offset =
      if state.animated do
        div(state._render_timestamp, state.animation_speed)
      else
        0
      end

    strips =
      case state.chart_type do
        :line ->
          render_line_chart(state, chart_width, chart_height, bg, fg, animation_offset)

        :bar ->
          render_bar_chart(state, chart_width, chart_height, bg, fg)

        :candlestick ->
          render_candlestick_chart(state, chart_width, chart_height, bg, fg)

        :area ->
          render_area_chart(state, chart_width, chart_height, bg, fg, animation_offset)

        :scatter ->
          render_scatter_chart(state, chart_width, chart_height, bg, fg)

        :braille ->
          render_braille_chart(state, chart_width, chart_height, bg, fg, animation_offset)

        _ ->
          render_line_chart(state, chart_width, chart_height, bg, fg, animation_offset)
      end

    strips =
      if state.show_axes do
        add_axes(strips, state, rect, bg, fg)
      else
        strips
      end

    strips =
      if state.title do
        add_title(strips, state.title, rect, bg, fg)
      else
        strips
      end

    pad_strips(strips, rect.height)
  end

  @impl Drafter.Widget
  def update(props, state) do
    new_data = Map.get(props, :data, state.data)
    {min_val, max_val} = calculate_data_range(new_data, props)

    live_candle = state._live_candle || init_live_candle(new_data)

    %{
      state
      | data: new_data,
        chart_type: Map.get(props, :chart_type, state.chart_type),
        marker: Map.get(props, :marker, state.marker),
        min_value: min_val,
        max_value: max_val,
        height: Map.get(props, :height, state.height),
        color: Map.get(props, :color, state.color),
        colors: Map.get(props, :colors, state.colors),
        show_axes: Map.get(props, :show_axes, state.show_axes),
        show_labels: Map.get(props, :show_labels, state.show_labels),
        title: Map.get(props, :title, state.title),
        x_labels: Map.get(props, :x_labels, state.x_labels),
        y_labels: Map.get(props, :y_labels, state.y_labels),
        animated: Map.get(props, :animated, state.animated),
        animation_speed: Map.get(props, :animation_speed, state.animation_speed),
        style: Map.get(props, :style, state.style),
        classes: Map.get(props, :classes, state.classes),
        _render_timestamp: Map.get(props, :_render_timestamp, state._render_timestamp),
        _live_candle: live_candle
    }
  end


  defp calculate_data_range(data, props) do
    custom_min = Map.get(props, :min_value)
    custom_max = Map.get(props, :max_value)
    live_candle = Map.get(props, :_live_candle)

    data = data || []
    data_values = extract_values(data)

    live_values =
      if live_candle do
        [live_candle.high, live_candle.low]
      else
        []
      end

    all_values = data_values ++ live_values

    {data_min, data_max} =
      if length(all_values) > 0 do
        {Enum.min(all_values), Enum.max(all_values)}
      else
        {0, 100}
      end

    min_val = if is_number(custom_min), do: custom_min, else: data_min
    max_val = if is_number(custom_max), do: custom_max, else: data_max

    if min_val == max_val do
      {min_val - 0.001, max_val + 0.001}
    else
      padding = (max_val - min_val) * 0.05
      {min_val - padding, max_val + padding}
    end
  end

  defp extract_values(data) when is_list(data) and length(data) > 0 do
    first = hd(data)

    cond do
      is_list(first) and length(first) >= 4 ->
        Enum.flat_map(data, fn [o, h, l, c | _] -> [o, h, l, c] end)

      is_list(first) ->
        Enum.flat_map(data, fn [v | _] -> [v] end)

      is_number(first) ->
        data

      true ->
        []
    end
  end

  defp extract_values(_), do: []

  defp render_line_chart(state, width, height, bg, fg, animation_offset) do
    data = state.data

    if length(data) < 2 do
      empty_strips(height, bg)
    else
      scroll_offset = state._scroll_offset || 0
      total_points = length(data)
      viewport_width = width * 2

      end_index = total_points - scroll_offset
      start_index = max(0, end_index - viewport_width)

      viewport_data = Enum.slice(data, start_index, viewport_width)

      range = state.max_value - state.min_value
      pixel_height = height * 4

      normalized = normalize_data(viewport_data, state.min_value, range, pixel_height)

      shifted =
        if animation_offset > 0 do
          shift = rem(animation_offset, length(normalized))
          Enum.drop(normalized, shift) ++ Enum.take(normalized, shift)
        else
          normalized
        end

      points = Enum.with_index(shifted) |> Enum.map(fn {y, x} -> {x, y} end)

      lines = bresenham_lines(points)

      render_braille_pixels(lines, width, height, bg, fg)
    end
  end

  defp render_bar_chart(state, width, height, bg, fg) do
    data = state.data

    if length(data) == 0 do
      empty_strips(height, bg)
    else
      range = state.max_value - state.min_value
      scroll_offset = state._scroll_offset || 0
      total_bars = length(data)

      end_index = total_bars - scroll_offset
      start_index = max(0, end_index - width)
      viewport_data = Enum.slice(data, start_index, width)

      bars =
        viewport_data
        |> Enum.map(fn value ->
          normalized = (value - state.min_value) / range
          bar_height = round(normalized * 8)
          Enum.at(@block_chars, min(8, max(0, bar_height)))
        end)

      bar_string = Enum.join(bars)
      padding = String.duplicate(" ", max(0, width - length(bars)))

      [Strip.new([Segment.new(bar_string <> padding, %{fg: fg, bg: bg})])]
    end
  end

  defp render_candlestick_chart(state, width, height, bg, _fg) do
    candles = state.data || []

    if length(candles) == 0 do
      empty_strips(height, bg)
    else
      first = hd(candles)

      is_valid_candle =
        cond do
          is_map(first) ->
            Map.has_key?(first, :open) and Map.has_key?(first, :high) and
              Map.has_key?(first, :low) and Map.has_key?(first, :close)

          is_list(first) ->
            length(first) >= 4

          true ->
            false
        end

      if not is_valid_candle do
        empty_strips(height, bg)
      else
        filtered_candles =
          Enum.filter(candles, fn c ->
            cond do
              is_map(c) ->
                Map.has_key?(c, :open) and Map.has_key?(c, :high) and
                  Map.has_key?(c, :low) and Map.has_key?(c, :close)

              is_list(c) ->
                length(c) >= 4

              true ->
                false
            end
          end)

        total_candles = length(filtered_candles)
        scroll_offset = state._scroll_offset || 0
        y_offset = state._y_offset || 0

        label_width = 11
        viewport_width = max(1, width - label_width)

        end_index = total_candles - scroll_offset
        start_index = max(0, end_index - viewport_width)

        display_candles = Enum.slice(filtered_candles, start_index, viewport_width)

        if length(display_candles) == 0 do
          empty_strips(height, bg)
        else
          rightmost = List.last(display_candles)
          {anchor_open, _, _, _} = extract_ohlc(rightmost)

          half_range = height / 2 * 0.0001
          center = anchor_open + y_offset * 0.0001
          min_val = Float.round(center - half_range, 4)
          max_val = Float.round(center + half_range, 4)

          bull_color = {52, 208, 88}
          bear_color = {234, 74, 90}
          label_color = {140, 140, 150}
          time_label_color = {120, 120, 130}

          chart_strips =
            render_candlestick_body(
              display_candles,
              height - 1,
              min_val,
              max_val,
              bull_color,
              bear_color,
              label_color,
              bg
            )

          time_strip =
            render_time_axis(
              display_candles,
              start_index,
              label_color,
              time_label_color,
              bg
            )

          chart_strips ++ [time_strip]
        end
      end
    end
  end

  defp render_candlestick_body(
         candles,
         height,
         min_val,
         max_val,
         bull_color,
         bear_color,
         label_color,
         bg
       ) do
    range = max_val - min_val
    price_per_row = range / height
    label_width = 11
    empty_seg = Segment.new(" ", %{fg: bg, bg: bg})

    precomputed =
      Enum.map(candles, fn candle ->
        {open, high, low, close} = extract_ohlc(candle)
        is_bull = close >= open
        color = if is_bull, do: bull_color, else: bear_color
        body_top = max(open, close)
        body_bottom = min(open, close)

        high_row = trunc((max_val - high) / price_per_row)
        low_row = trunc((max_val - low) / price_per_row)
        body_top_row = trunc((max_val - body_top) / price_per_row)
        body_bottom_row = trunc((max_val - body_bottom) / price_per_row)

        body_span = body_bottom_row - body_top_row
        is_doji = abs(open - close) < price_per_row * 0.5
        has_upper_wick = high_row < body_top_row
        has_lower_wick = low_row > body_bottom_row
        is_spinning_top = body_span <= 1 and has_upper_wick and has_lower_wick

        body_char =
          cond do
            is_doji -> "-"
            is_spinning_top -> "┼"
            true -> "█"
          end

        {color, high_row, low_row, body_top_row, body_bottom_row, body_char}
      end)

    for row <- 0..(height - 1) do
      row_mid_price = max_val - (row + 0.5) * price_per_row
      label_text = format_price_label(row_mid_price)
      label_seg = Segment.new(String.pad_trailing(label_text, label_width), %{fg: label_color, bg: bg})

      candle_segments =
        Enum.map(precomputed, fn {color, high_row, low_row, body_top_row, body_bottom_row, body_char} ->
          cond do
            row >= body_top_row and row <= body_bottom_row ->
              Segment.new(body_char, %{fg: color, bg: bg})

            row >= high_row and row <= low_row ->
              Segment.new("│", %{fg: color, bg: bg})

            true ->
              empty_seg
          end
        end)

      Strip.new([label_seg | candle_segments])
    end
  end

  defp render_time_axis(display_candles, start_index, label_color, time_color, bg) do
    label_width = 11
    label_seg = Segment.new(String.duplicate(" ", label_width), %{fg: label_color, bg: bg})

    num_candles = length(display_candles)
    interval = max(1, div(num_candles, 10))

    time_markers =
      for i <- 0..(num_candles - 1) do
        candle_index = start_index + i

        if rem(i, interval) == 0 do
          marker_str = Integer.to_string(candle_index)
          String.pad_leading(marker_str, String.length(marker_str))
        else
          " "
        end
      end

    time_segs =
      Enum.map(time_markers, fn char ->
        Segment.new(char, %{fg: time_color, bg: bg})
      end)

    Strip.new([label_seg | time_segs])
  end

  defp extract_ohlc(%{open: o, high: h, low: l, close: c}), do: {o, h, l, c}
  defp extract_ohlc([o, h, l, c | _]), do: {o, h, l, c}

  defp format_price_label(price) do
    cond do
      price >= 1_000_000 ->
        "#{Float.round(price / 1_000_000, 1)}M"

      price >= 100 ->
        Float.round(price, 0) |> trunc() |> Integer.to_string()

      price >= 1 ->
        Float.round(price, 4) |> to_string()

      true ->
        Float.round(price, 5) |> to_string()
    end
  end

  defp render_area_chart(state, width, height, bg, fg, animation_offset) do
    data = state.data

    if length(data) < 2 do
      empty_strips(height, bg)
    else
      range = state.max_value - state.min_value
      pixel_height = height * 4
      scroll_offset = state._scroll_offset || 0

      viewport_width = width * 2
      total_points = length(data)
      end_index = total_points - scroll_offset
      start_index = max(0, end_index - viewport_width)
      viewport_data = Enum.slice(data, start_index, viewport_width)

      normalized = normalize_data(viewport_data, state.min_value, range, pixel_height)

      shifted =
        if animation_offset > 0 do
          shift = rem(animation_offset, length(normalized))
          Enum.drop(normalized, shift) ++ Enum.take(normalized, shift)
        else
          normalized
        end

      pixels =
        for x <- 0..(length(shifted) - 1) do
          y = Enum.at(shifted, x)
          for yi <- 0..y, do: {x, yi}
        end
        |> List.flatten()

      render_braille_pixels(pixels, width, height, bg, fg)
    end
  end

  defp render_scatter_chart(state, width, height, bg, fg) do
    data = state.data

    if length(data) == 0 do
      empty_strips(height, bg)
    else
      points =
        cond do
          is_list(hd(data)) and length(hd(data)) == 2 ->
            data

          is_tuple(hd(data)) and tuple_size(hd(data)) == 2 ->
            Enum.map(data, fn {x, y} -> [x, y] end)

          true ->
            data
            |> Enum.with_index()
            |> Enum.map(fn {y, x} -> [x, y] end)
        end

      range = state.max_value - state.min_value
      pixel_height = height * 4
      scroll_offset = state._scroll_offset || 0

      viewport_width = width * 2
      max_x = Enum.map(points, fn [x, _] -> x end) |> Enum.max(fn -> 0 end)
      end_x = max_x - scroll_offset
      start_x = max(0, end_x - viewport_width)

      pixels =
        points
        |> Enum.filter(fn [x, _y] -> x >= start_x and x < end_x end)
        |> Enum.map(fn [x, y] ->
          pixel_y = round((y - state.min_value) / range * pixel_height)
          adjusted_x = x - start_x
          {adjusted_x, pixel_height - pixel_y - 1}
        end)

      render_braille_pixels(pixels, width, height, bg, fg)
    end
  end

  defp render_braille_chart(state, width, height, bg, fg, animation_offset) do
    render_line_chart(%{state | chart_type: :line}, width, height, bg, fg, animation_offset)
  end

  defp render_braille_pixels(pixels, width, height, bg, fg) do
    pixel_height = height * 4

    pixels_by_char =
      pixels
      |> Enum.filter(fn {x, y} -> x >= 0 and x < width * 2 and y >= 0 and y < pixel_height end)
      |> Enum.group_by(fn {x, y} ->
        char_x = div(x, 2)
        char_y = div(y, 4)
        {char_x, char_y}
      end)

    for row <- 0..(height - 1) do
      segments =
        for col <- 0..(width - 1) do
          char_pixels = Map.get(pixels_by_char, {col, row}, [])

          char =
            if length(char_pixels) > 0 do
              build_braille_char(char_pixels)
            else
              braille_char(0)
            end

          Segment.new(char, %{fg: fg, bg: bg})
        end

      Strip.new(segments)
    end
  end

  defp build_braille_char(pixels) do
    bits =
      pixels
      |> Enum.map(fn {x, y} ->
        local_x = rem(x, 2)
        local_y = rem(y, 4)
        Map.get(@braille_dot_offsets, {local_x, local_y}, 0)
      end)
      |> Enum.sum()

    braille_char(bits)
  end

  defp braille_char(bits) when bits >= 0 and bits <= 255 do
    <<@braille_base + bits::utf8>>
  end

  defp braille_char(_), do: " "

  defp normalize_data(data, min_val, range, pixel_height) do
    data
    |> Enum.map(fn value ->
      normalized = (value - min_val) / range

      round(normalized * pixel_height)
      |> min(pixel_height - 1)
      |> max(0)
    end)
  end

  defp bresenham_lines([]), do: []
  defp bresenham_lines([_single]), do: []

  defp bresenham_lines([{x1, y1} | rest]) do
    case rest do
      [{x2, y2} | _] -> bresenham_line(x1, y1, x2, y2) ++ bresenham_lines(rest)
      [] -> []
    end
  end

  defp bresenham_line(x1, y1, x2, y2) do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1
    err = dx - dy

    bresenham_loop(x1, y1, x2, y2, sx, sy, dx, dy, err, [])
  end

  defp bresenham_loop(x, y, x2, y2, _sx, _sy, _dx, _dy, _err, acc) when x == x2 and y == y2 do
    Enum.reverse([{x, y} | acc])
  end

  defp bresenham_loop(x, y, x2, y2, sx, sy, dx, dy, err, acc) do
    e2 = 2 * err

    {new_x, new_err} =
      if e2 > -dy do
        {x + sx, err - dy}
      else
        {x, err}
      end

    {new_y, final_err} =
      if e2 < dx do
        {y + sy, new_err + dx}
      else
        {y, new_err}
      end

    bresenham_loop(new_x, new_y, x2, y2, sx, sy, dx, dy, final_err, [{x, y} | acc])
  end

  defp empty_strips(height, bg) do
    for _ <- 1..height do
      Strip.new([Segment.new("", %{bg: bg})])
    end
  end

  defp add_axes(strips, state, rect, bg, fg) do
    y_axis_width = 5

    y_axis_segments =
      for i <- 0..(rect.height - 3) do
        y_val = state.max_value - (state.max_value - state.min_value) * i / (rect.height - 3)
        label = format_axis_value(y_val)
        Segment.new(String.pad_leading(label, y_axis_width - 1) <> "│", %{fg: fg, bg: bg})
      end

    strips_with_y =
      strips
      |> Enum.take(rect.height - 2)
      |> Enum.with_index()
      |> Enum.map(fn {strip, idx} ->
        y_seg =
          if idx < length(y_axis_segments) do
            Enum.at(y_axis_segments, idx)
          else
            Segment.new(String.duplicate(" ", y_axis_width), %{bg: bg})
          end

        Strip.new([y_seg | strip.segments])
      end)

    x_axis = " " <> String.duplicate("─", rect.width - 7) <> "┘"

    x_axis_strip =
      Strip.new([Segment.new(String.pad_trailing(x_axis, rect.width), %{fg: fg, bg: bg})])

    strips_with_y ++ [x_axis_strip]
  end

  defp add_title(strips, title, _rect, bg, fg) do
    title_seg = Segment.new(title, %{fg: fg, bg: bg, bold: true})
    title_strip = Strip.new([title_seg])
    [title_strip | strips]
  end

  defp pad_strips(strips, target_height) do
    current_height = length(strips)

    if current_height < target_height do
      padding =
        for _ <- 1..(target_height - current_height) do
          Strip.new([Segment.new("", %{})])
        end

      strips ++ padding
    else
      Enum.take(strips, target_height)
    end
  end

  defp format_axis_value(val) when is_float(val) do
    cond do
      abs(val) >= 1000 -> Float.round(val / 1000, 1) |> Kernel.<>("k")
      abs(val) >= 1 -> Float.round(val, 1) |> to_string()
      true -> Float.round(val, 3) |> to_string()
    end
  end

  defp format_axis_value(val), do: to_string(val)

  def render_tall_bar_chart(data, height, opts \\ []) do
    min_val = Keyword.get(opts, :min, 0)
    max_val = Keyword.get(opts, :max, 100)
    color = Keyword.get(opts, :color, {100, 200, 100})
    bg = Keyword.get(opts, :bg, {20, 20, 30})

    range = max_val - min_val

    bars =
      data
      |> Enum.map(fn value ->
        normalized = (value - min_val) / range
        {normalized, value}
      end)

    pixel_height = height * 2

    for row <- 0..(height - 1) do
      row_top = (height - 1 - row) * 2
      row_bottom = row_top + 1

      segments =
        bars
        |> Enum.map(fn {normalized, _value} ->
          bar_pixel = round(normalized * pixel_height)

          cond do
            bar_pixel <= row_top ->
              Segment.new(" ", %{bg: bg})

            bar_pixel >= row_bottom + 1 ->
              Segment.new("█", %{fg: color, bg: bg})

            true ->
              if bar_pixel == row_top + 1 do
                Segment.new("▄", %{fg: color, bg: bg})
              else
                Segment.new(" ", %{bg: bg})
              end
          end
        end)

      Strip.new(segments)
    end
  end

  def render_multi_series(data_series, width, height, opts \\ []) do
    bg = Keyword.get(opts, :bg, {20, 20, 30})

    colors =
      Keyword.get(opts, :colors, [
        {255, 100, 100},
        {100, 255, 100},
        {100, 100, 255},
        {255, 255, 100}
      ])

    all_values = List.flatten(data_series)
    min_val = Keyword.get(opts, :min, Enum.min(all_values))
    max_val = Keyword.get(opts, :max, Enum.max(all_values))
    range = max_val - min_val

    pixel_height = height * 4

    all_pixels =
      data_series
      |> Enum.with_index()
      |> Enum.flat_map(fn {series, series_idx} ->
        color = Enum.at(colors, series_idx, hd(colors))

        series
        |> Enum.with_index()
        |> Enum.map(fn {value, x} ->
          normalized = (value - min_val) / range
          y = round((1 - normalized) * (pixel_height - 1))
          {{div(x, 2), div(y, 4)}, {rem(x, 2), rem(y, 4)}, color}
        end)
      end)

    for row <- 0..(height - 1) do
      segments =
        for col <- 0..(width - 1) do
          char_pixels =
            all_pixels
            |> Enum.filter(fn {{cx, cy}, _, _} -> cx == col and cy == row end)

          if length(char_pixels) > 0 do
            {bits, color} =
              char_pixels
              |> Enum.reduce({0, nil}, fn {_, {lx, ly}, c}, {b, _} ->
                bit = Map.get(@braille_dot_offsets, {lx, ly}, 0)
                {b ||| bit, c}
              end)

            Segment.new(braille_char(bits), %{fg: color || hd(colors), bg: bg})
          else
            Segment.new(" ", %{bg: bg})
          end
        end

      Strip.new(segments)
    end
  end
end
