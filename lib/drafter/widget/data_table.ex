defmodule Drafter.Widget.DataTable do
  @moduledoc """
  A full-featured tabular data widget with column headers, sorting, row selection, and scrolling.

  Rows are provided as a list of maps. Each map key corresponds to a column `:key`. Data can be
  pre-sorted at mount time via `:sort_by`. Users can sort any sortable column by clicking its
  header, toggling between ascending and descending on repeated clicks. Sort direction is
  indicated by `↑` or `↓` in the header.

  An optional vertical scrollbar is rendered in the rightmost column when the number of rows
  exceeds the visible area. The scrollbar supports click-to-jump and drag-to-scroll. Zebra
  stripes alternate the background colour of odd rows when `:zebra_stripes` is enabled.

  ## Column definition format

  Each column is a map (or shorthand) with the following fields:

    * `:key` — atom matching the map key in each data row (required)
    * `:label` — header display string (required)
    * `:width` — column width in characters, or `:auto` (default: `:auto`)
    * `:align` — cell alignment: `:left` (default), `:center`, or `:right`
    * `:sortable` — whether clicking the header sorts by this column (default: `true`)

  Shorthand forms are also accepted: `{:key, "Label"}` or just `:key`.

  ## Options

    * `:columns` - list of column definitions (required)
    * `:data` - list of row maps (default: `[]`)
    * `:sort_by` - initial sort: an atom column key (ascending), or `{key, :asc | :desc}`
    * `:selection_mode` - `:none`, `:single` (default), or `:multiple`
    * `:on_select` - `([row] -> term())` called with selected rows when a row is activated
    * `:on_sort` - `(atom(), :asc | :desc -> term())` called after a column sort
    * `:show_header` - render column headers (default: `true`)
    * `:show_cursor` - highlight the current cell column in the header (default: `true`)
    * `:zebra_stripes` - alternate row background colours (default: `true`)
    * `:show_scrollbars` - render a vertical scrollbar when content overflows (default: `true`)
    * `:column_fit_mode` - `:fit` (divide available width equally, default) or `:expand`
      (compute optimal widths from content, allows horizontal overflow)
    * `:mouse_scroll_moves_selection` - when `true`, scrolling moves the cursor row rather
      than scrolling the viewport (default: `true`)
    * `:width` - widget width in columns (default: `80`)
    * `:height` - widget height in rows (default: `20`)
    * `:fixed_columns` - number of left-most columns that do not scroll horizontally (default: `0`)

  ## Key bindings

    * `↑` / `↓` — move cursor row up/down
    * `←` / `→` — move cursor column left/right
    * `Home` / `End` — jump to first/last row
    * `Page Up` / `Page Down` — jump by viewport height
    * `Enter` — select the highlighted row and call `:on_select`
    * `Space` — toggle selection in `:multiple` mode; otherwise same as Enter
    * Mouse click on header — sort by that column (toggles asc/desc)
    * Mouse click on row — select the row
    * Mouse scroll — move cursor row (or scroll viewport when `:mouse_scroll_moves_selection` is `false`)
    * Scrollbar click/drag — jump or drag the viewport position

  ## Usage

      data_table(
        columns: [
          %{key: :name, label: "Name", width: 20},
          %{key: :age, label: "Age", width: 8, align: :right},
          %{key: :city, label: "City"}
        ],
        data: [
          %{name: "Alice", age: 30, city: "Dublin"},
          %{name: "Bob", age: 25, city: "London"}
        ],
        sort_by: {:name, :asc},
        on_select: fn rows -> IO.inspect(rows) end
      )
  """

  use Drafter.Widget,
    handles: [:scroll, :keyboard, :click, :drag, :hover],
    focusable: true

  alias Drafter.Draw.{Segment, Strip}
  alias Drafter.ThemeManager

  defstruct [
    :columns,
    :data,
    :cursor_col,
    :scroll_offset_col,
    :sort_column,
    :sort_direction,
    :style,
    :header_style,
    :selected_style,
    :cursor_style,
    :on_select,
    :on_sort,
    :show_header,
    :show_cursor,
    :zebra_stripes,
    :show_scrollbars,
    :column_fit_mode,
    :width,
    :height,
    :viewport_height,
    :fixed_columns,
    :fixed_col_widths,
    # Direct scrolling fields (like OptionList)
    :highlighted_index,
    :selected_indices,
    :scroll_offset,
    :selection_mode,
    :mouse_scroll_moves_selection,
    :mouse_scroll_selects_item,
    # Drag state for scrollbar
    :dragging_scrollbar,
    # Mouse hover tracking for scrollbar effects
    :hovering_scrollbar
  ]

  @type column :: %{
          key: atom(),
          label: String.t(),
          width: pos_integer() | :auto,
          align: :left | :center | :right,
          sortable: boolean()
        }

  @type row :: map()

  @type selection_mode :: :none | :single | :multiple

  @type sort_direction :: :asc | :desc

  @type t :: %__MODULE__{
          columns: [column()],
          data: [row()],
          cursor_col: non_neg_integer(),
          scroll_offset_col: non_neg_integer(),
          highlighted_index: integer() | nil,
          selected_indices: MapSet.t(),
          scroll_offset: integer(),
          selection_mode: selection_mode(),
          sort_column: atom() | nil,
          sort_direction: sort_direction(),
          style: Segment.style(),
          header_style: Segment.style(),
          selected_style: Segment.style(),
          cursor_style: Segment.style(),
          on_select: ([row()] -> term()) | nil,
          on_sort: (atom(), sort_direction() -> term()) | nil,
          show_header: boolean(),
          show_cursor: boolean(),
          zebra_stripes: boolean(),
          show_scrollbars: boolean(),
          column_fit_mode: :fit | :expand,
          width: pos_integer(),
          height: pos_integer(),
          fixed_columns: non_neg_integer(),
          fixed_col_widths: [pos_integer()]
        }

  @impl Drafter.Widget
  def mount(props) do
    columns = Map.get(props, :columns, [])
    data = Map.get(props, :data, [])
    height = Map.get(props, :height, 20)
    selection_mode = Map.get(props, :selection_mode, :single)

    # Sort initial data if sort column is provided
    {sorted_data, sort_col, sort_dir} =
      case Map.get(props, :sort_by) do
        {column, direction} when direction in [:asc, :desc] ->
          {sort_data(data, column, direction), column, direction}

        column when is_atom(column) ->
          {sort_data(data, column, :asc), column, :asc}

        _ ->
          {data, nil, :asc}
      end

    # Calculate visible height for data (excluding header)
    _data_height = if Map.get(props, :show_header, true), do: height - 1, else: height

    # Initialize scroll fields directly (like OptionList)
    highlighted_index = if length(sorted_data) > 0, do: 0, else: nil
    selected_indices = MapSet.new()

    fixed_columns = Map.get(props, :fixed_columns, 0)

    %__MODULE__{
      columns: normalize_columns(columns),
      data: sorted_data,
      cursor_col: 0,
      scroll_offset_col: 0,
      highlighted_index: highlighted_index,
      selected_indices: selected_indices,
      scroll_offset: 0,
      selection_mode: selection_mode,
      sort_column: sort_col,
      sort_direction: sort_dir,
      style: Map.get(props, :style, %{fg: {200, 200, 200}, bg: {30, 30, 30}}),
      header_style:
        Map.get(props, :header_style, %{fg: {255, 255, 255}, bg: {60, 60, 60}, bold: true}),
      selected_style: Map.get(props, :selected_style, %{fg: {255, 255, 255}, bg: {0, 120, 215}}),
      cursor_style:
        Map.get(props, :cursor_style, %{fg: {255, 255, 255}, bg: {50, 100, 200}, bold: true}),
      on_select: Map.get(props, :on_select),
      mouse_scroll_moves_selection: Map.get(props, :mouse_scroll_moves_selection, true),
      mouse_scroll_selects_item: Map.get(props, :mouse_scroll_selects_item, false),
      dragging_scrollbar: false,
      hovering_scrollbar: false,
      on_sort: Map.get(props, :on_sort),
      show_header: Map.get(props, :show_header, true),
      show_cursor: Map.get(props, :show_cursor, true),
      zebra_stripes: Map.get(props, :zebra_stripes, true),
      show_scrollbars: Map.get(props, :show_scrollbars, true),
      column_fit_mode: Map.get(props, :column_fit_mode, :fit),
      width: Map.get(props, :width, 80),
      height: height,
      viewport_height: height,
      fixed_columns: min(fixed_columns, length(columns)),
      fixed_col_widths: []
    }
  end

  def on_rect_change(rect, state) do
    %{state | viewport_height: rect.height}
  end

  @impl Drafter.Widget
  def render(state, rect) do
    normalized_state =
      if is_struct(state, __MODULE__) do
        state
      else
        mount(state)
      end

    theme = ThemeManager.get_current_theme()
    normalized_state = apply_theme_styles(normalized_state, theme)

    content_width = min(normalized_state.width, rect.width)
    content_height = normalized_state.viewport_height || rect.height

    data_height = get_data_height(normalized_state)

    # Reserve space for vertical scrollbar if enabled and needed
    table_width =
      if normalized_state.show_scrollbars && length(normalized_state.data) > data_height do
        content_width - 1
      else
        content_width
      end

    # Calculate column widths based on fit mode
    column_widths =
      calculate_column_widths(
        normalized_state.columns,
        table_width,
        normalized_state.column_fit_mode,
        normalized_state.data
      )

    strips = []

    # Render header if enabled
    strips =
      if normalized_state.show_header do
        header_strip = render_header(normalized_state, column_widths, table_width)
        [header_strip | strips]
      else
        strips
      end

    # Get visible items directly (like OptionList)
    start_idx = normalized_state.scroll_offset
    visible_count = min(data_height, length(normalized_state.data) - start_idx)

    # Render data rows
    data_strips =
      if visible_count > 0 do
        start_idx..(start_idx + visible_count - 1)
        |> Enum.map(fn row_index ->
          row = Enum.at(normalized_state.data, row_index)
          render_row(normalized_state, row, row_index, column_widths, table_width)
        end)
      else
        []
      end

    strips = Enum.reverse(strips) ++ data_strips

    # Don't add scrollbar here - will be added after height padding

    # Pad to full height
    current_height = length(strips)

    final_strips =
      if current_height < content_height do
        empty_style = normalized_state.style
        empty_line = String.duplicate(" ", table_width)
        empty_strip = Strip.new([Segment.new(empty_line, empty_style)])
        padding = List.duplicate(empty_strip, content_height - current_height)
        strips ++ padding
      else
        Enum.take(strips, content_height)
      end

    # Add scrollbar to empty lines if needed
    if normalized_state.show_scrollbars && length(normalized_state.data) > data_height do
      add_vertical_scrollbar(final_strips, normalized_state, content_width, data_height)
    else
      final_strips
    end
  end

  @impl Drafter.Widget
  def handle_key(:left, state) do
    if focused(state) do
      move_cursor_horizontal(state, :left)
    else
      {:bubble, state}
    end
  end

  def handle_key(:right, state) do
    if focused(state) do
      move_cursor_horizontal(state, :right)
    else
      {:bubble, state}
    end
  end

  def handle_key(:up, state), do: action_cursor_up(state)
  def handle_key(:down, state), do: action_cursor_down(state)
  def handle_key(:home, state), do: action_cursor_first(state)
  def handle_key(:end, state), do: action_cursor_last(state)
  def handle_key(:page_up, state), do: action_page_up(state)
  def handle_key(:page_down, state), do: action_page_down(state)
  def handle_key(:enter, state), do: action_select_highlighted(state)
  def handle_key(:space, state), do: action_toggle_selection(state)
  def handle_key(_key, state), do: {:bubble, state}

  @impl Drafter.Widget
  def handle_scroll(direction, state) do
    if state.mouse_scroll_moves_selection do
      case direction do
        :up -> action_cursor_up(state)
        :down -> action_cursor_down(state)
      end
    else
      case direction do
        :up -> action_scroll_up(state)
        :down -> action_scroll_down(state)
      end
    end
  end

  @impl Drafter.Widget
  def handle_click(x, y, state) do
    handle_mouse_click(state, x, y)
  end

  @impl Drafter.Widget
  def handle_drag(x, y, state) do
    handle_mouse_drag(state, x, y)
  end

  @impl Drafter.Widget
  def handle_hover(x, y, state) do
    handle_mouse_move(state, x, y)
  end

  @impl Drafter.Widget
  def handle_custom_event({:mouse, %{type: :mouse_up, x: x, y: y}}, state) do
    if state.dragging_scrollbar do
      handle_mouse_release(state, x, y)
    else
      handle_mouse_click(state, x, y)
    end
  end

  def handle_custom_event(_event, state), do: {:bubble, state}

  @impl Drafter.Widget
  def update(props, state) do
    # Handle data updates while preserving navigation state
    new_data = Map.get(props, :data, state.data)

    # Re-sort if data changed and we have an active sort
    sorted_data =
      if new_data != state.data && state.sort_column do
        sort_data(new_data, state.sort_column, state.sort_direction)
      else
        new_data
      end

    # Update selection mode if changed
    new_selection_mode = Map.get(props, :selection_mode, state.selection_mode)

    # Adjust highlighted index if it's now out of bounds
    max_row = max(0, length(sorted_data) - 1)

    adjusted_highlighted_index =
      if state.highlighted_index && state.highlighted_index > max_row do
        min(max_row, state.highlighted_index)
      else
        state.highlighted_index
      end

    %{
      state
      | columns: Map.get(props, :columns, state.columns) |> normalize_columns(),
        data: sorted_data,
        highlighted_index: adjusted_highlighted_index,
        selection_mode: new_selection_mode,
        style: Map.get(props, :style, state.style),
        header_style: Map.get(props, :header_style, state.header_style),
        selected_style: Map.get(props, :selected_style, state.selected_style),
        cursor_style: Map.get(props, :cursor_style, state.cursor_style),
        on_select: Map.get(props, :on_select, state.on_select),
        on_sort: Map.get(props, :on_sort, state.on_sort),
        show_header: Map.get(props, :show_header, state.show_header),
        show_cursor: Map.get(props, :show_cursor, state.show_cursor),
        zebra_stripes: Map.get(props, :zebra_stripes, state.zebra_stripes),
        show_scrollbars: Map.get(props, :show_scrollbars, state.show_scrollbars),
        column_fit_mode: Map.get(props, :column_fit_mode, state.column_fit_mode),
        width: Map.get(props, :width, state.width),
        height: Map.get(props, :height, state.height)
    }
  end

  # Row navigation functions - Direct implementation like OptionList

  defp action_scroll_up(state) do
    if state.scroll_offset > 0 do
      new_state = %{state | scroll_offset: state.scroll_offset - 1}
      {:ok, new_state, [:render_update]}
    else
      {:ok, state, []}
    end
  end

  defp action_scroll_down(state) do
    data_height = get_data_height(state)
    max_scroll = max(0, length(state.data) - data_height)

    if state.scroll_offset < max_scroll do
      new_state = %{state | scroll_offset: state.scroll_offset + 1}
      {:ok, new_state, [:render_update]}
    else
      {:ok, state, []}
    end
  end

  defp action_cursor_up(state) do
    case find_previous_enabled(state.data, get_highlighted_index(state)) do
      nil -> {:ok, state, []}
      new_index -> change_selection(state, new_index, true)
    end
  end

  defp action_cursor_down(state) do
    case find_next_enabled(state.data, get_highlighted_index(state)) do
      nil -> {:ok, state, []}
      new_index -> change_selection(state, new_index, true)
    end
  end

  defp action_cursor_first(state) do
    case find_first_enabled(state.data) do
      nil -> {:ok, state, []}
      new_index -> change_selection(state, new_index, false)
    end
  end

  defp action_cursor_last(state) do
    new_index = find_last_enabled(state.data)
    change_selection(state, new_index, false)
  end

  defp action_page_up(state) do
    current = get_highlighted_index(state) || 0
    data_height = get_data_height(state)
    target_index = max(0, current - data_height)

    new_index =
      case find_previous_enabled_from(state.data, target_index) do
        nil -> find_next_enabled_from(state.data, target_index) || find_first_enabled(state.data)
        index -> index
      end

    if new_index do
      change_selection(state, new_index, false)
    else
      {:ok, state, []}
    end
  end

  defp action_page_down(state) do
    current = get_highlighted_index(state) || 0
    data_height = get_data_height(state)
    target_index = min(length(state.data) - 1, current + data_height)

    new_index =
      case find_next_enabled_from(state.data, target_index) do
        nil ->
          find_previous_enabled_from(state.data, target_index) || find_last_enabled(state.data)

        index ->
          index
      end

    if new_index do
      change_selection(state, new_index, false)
    else
      {:ok, state, []}
    end
  end

  defp action_select_highlighted(state) do
    if highlighted_index = get_highlighted_index(state) do
      change_selection(state, highlighted_index, true)
    else
      {:ok, state, []}
    end
  end

  defp action_toggle_selection(state) do
    if highlighted_index = get_highlighted_index(state) do
      if state.selection_mode == :multiple do
        new_selected =
          if is_selected?(state, highlighted_index) do
            MapSet.delete(state.selected_indices, highlighted_index)
          else
            MapSet.put(state.selected_indices, highlighted_index)
          end

        new_state = %{state | selected_indices: new_selected}

        # Trigger selection callback if present
        actions =
          if state.on_select do
            selected_items =
              new_selected
              |> MapSet.to_list()
              |> Enum.map(fn index -> Enum.at(state.data, index) end)
              |> Enum.filter(& &1)

            [state.on_select.(selected_items)]
          else
            []
          end

        if length(actions) > 0 do
          {:ok, new_state, actions}
        else
          {:ok, new_state}
        end
      else
        change_selection(state, highlighted_index, true)
      end
    else
      {:ok, state}
    end
  end

  # Column navigation functions
  defp move_cursor_horizontal(%{cursor_col: col} = state, :left) when col > 0 do
    new_state = %{state | cursor_col: col - 1} |> adjust_scroll_horizontal()
    {:ok, new_state, [:render_update]}
  end

  defp move_cursor_horizontal(state, :left), do: {:noreply, state}

  defp move_cursor_horizontal(%{cursor_col: col, columns: columns} = state, :right)
       when col < length(columns) - 1 do
    new_state = %{state | cursor_col: col + 1} |> adjust_scroll_horizontal()
    {:ok, new_state, [:render_update]}
  end

  defp move_cursor_horizontal(state, :right), do: {:noreply, state}

  # Mouse handling
  defp handle_mouse_click(%{show_header: true} = state, x, 0) do
    handle_header_click(state, x)
  end

  defp handle_mouse_click(state, x, y) do
    click_region = determine_click_region(state, x, y)
    handle_click_by_region(state, x, y, click_region)
  end

  defp determine_click_region(state, x, y) do
    data_start_y = get_data_start_y(state)
    data_height = get_data_height(state)
    scrollbar_x = state.width - 1

    classify_click_region(state, x, y, scrollbar_x, data_start_y, data_height)
  end

  defp classify_click_region(
         %{show_scrollbars: true} = state,
         x,
         y,
         scrollbar_x,
         data_start_y,
         data_height
       )
       when x == scrollbar_x and y >= data_start_y and length(state.data) > data_height do
    :scrollbar
  end

  defp classify_click_region(_state, _x, y, _scrollbar_x, data_start_y, _data_height)
       when y >= data_start_y, do: :data_row

  defp classify_click_region(_state, _x, _y, _scrollbar_x, _data_start_y, _data_height),
    do: :other

  defp handle_click_by_region(state, _x, y, :scrollbar) do
    data_start_y = get_data_start_y(state)
    data_height = get_data_height(state)
    handle_scrollbar_click(state, y - data_start_y, data_height)
  end

  defp handle_click_by_region(state, x, y, :data_row) do
    data_start_y = get_data_start_y(state)
    data_y = y - data_start_y
    clicked_index = state.scroll_offset + data_y

    if clicked_index >= 0 and clicked_index < length(state.data) do
      {:ok, updated_state, actions} = change_selection(state, clicked_index, true)
      final_state = update_cursor_column(updated_state, x)
      {:ok, final_state, actions}
    else
      {:noreply, state}
    end
  end

  defp handle_click_by_region(state, _x, _y, :other) do
    {:noreply, state}
  end

  defp handle_mouse_drag(state, x, y) do
    if state.dragging_scrollbar do
      # Handle scrollbar drag - continuous scrolling
      region = determine_click_region(state, x, y)

      case region do
        :scrollbar ->
          data_start_y = get_data_start_y(state)
          data_height = get_data_height(state)
          relative_y = y - data_start_y

          # Clamp relative_y to valid range
          relative_y = max(0, min(relative_y, data_height - 1))

          total_rows = length(state.data)

          if total_rows > data_height do
            max_scroll = total_rows - data_height
            scroll_range = max(1, data_height - 1)
            drag_ratio = relative_y / scroll_range
            target_scroll = round(drag_ratio * max_scroll)
            target_scroll = max(0, min(target_scroll, max_scroll))

            new_state = %{state | scroll_offset: target_scroll}
            {:ok, new_state, [:render_update]}
          else
            {:ok, state}
          end

        _ ->
          # Not dragging on scrollbar anymore, stop dragging
          {:ok, %{state | dragging_scrollbar: false}, [:render_update]}
      end
    else
      # Ignore drag events that aren't associated with scrollbar dragging
      {:noreply, state}
    end
  end

  defp handle_mouse_release(state, _x, _y) do
    # Stop dragging when mouse is released
    {:ok, %{state | dragging_scrollbar: false}, [:render_update]}
  end

  defp handle_mouse_move(state, x, y) do
    # Track hover state for scrollbar visual feedback
    region = determine_click_region(state, x, y)
    hovering_scrollbar = region == :scrollbar

    if hovering_scrollbar != state.hovering_scrollbar do
      # Hover state changed - re-render to show visual feedback
      {:ok, %{state | hovering_scrollbar: hovering_scrollbar}, [:render_update]}
    else
      {:noreply, state}
    end
  end

  defp update_cursor_column(state, x) do
    col_index = calculate_column_from_x(state, x)
    update_cursor_column_if_valid(state, col_index)
  end

  defp update_cursor_column_if_valid(state, col_index)
       when col_index >= 0 and col_index < length(state.columns) do
    %{state | cursor_col: col_index}
  end

  defp update_cursor_column_if_valid(state, _col_index), do: state

  defp get_data_start_y(%{show_header: true}), do: 1
  defp get_data_start_y(_state), do: 0

  defp get_data_height(%{show_header: true, viewport_height: vh}) when is_integer(vh) and vh > 0,
    do: vh - 1

  defp get_data_height(%{show_header: true, height: height}), do: height - 1
  defp get_data_height(%{viewport_height: vh}) when is_integer(vh) and vh > 0, do: vh
  defp get_data_height(%{height: height}), do: height

  defp handle_header_click(state, x) do
    col_index = calculate_column_from_x(state, x)

    if col_index < length(state.columns) do
      column = Enum.at(state.columns, col_index)

      if column.sortable do
        direction =
          if state.sort_column == column.key do
            if state.sort_direction == :asc, do: :desc, else: :asc
          else
            :asc
          end

        sorted_data = sort_data(state.data, column.key, direction)

        new_state = %{
          state
          | data: sorted_data,
            sort_column: column.key,
            sort_direction: direction,
            cursor_col: col_index
        }

        trigger_sort(new_state)
        {:ok, new_state}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  defp handle_scrollbar_click(state, relative_y, data_height) do
    total_rows = length(state.data)

    if total_rows > data_height do
      max_scroll = total_rows - data_height
      # Use consistent math with visual rendering: (data_height - 1)
      scroll_range = max(1, data_height - 1)
      click_ratio = relative_y / scroll_range
      target_scroll = round(click_ratio * max_scroll)
      target_scroll = max(0, min(target_scroll, max_scroll))

      new_state = %{
        state
        | scroll_offset: target_scroll,
          dragging_scrollbar: true,
          hovering_scrollbar: true
      }

      {:ok, new_state, [:render_update]}
    else
      {:noreply, state}
    end
  end

  # Rendering functions

  defp render_header(state, column_widths, total_width) do
    segments =
      state.columns
      |> Enum.zip(column_widths)
      |> Enum.with_index()
      |> Enum.map(fn {{column, width}, col_index} ->
        is_cursor_col = state.show_cursor && focused(state) && col_index == state.cursor_col
        is_sort_col = column.key == state.sort_column

        # Create header text with sort indicator
        sort_indicator =
          if is_sort_col do
            case state.sort_direction do
              :asc -> " ↑"
              :desc -> " ↓"
            end
          else
            ""
          end

        text = column.label <> sort_indicator
        formatted_text = format_cell_content(text, width, column.align)

        style =
          if is_cursor_col do
            Map.merge(state.header_style, state.cursor_style)
          else
            state.header_style
          end

        Segment.new(formatted_text, style)
      end)

    # Pad to full width
    current_width = Enum.sum(column_widths)

    segments =
      if current_width < total_width do
        padding = String.duplicate(" ", total_width - current_width)
        segments ++ [Segment.new(padding, state.header_style)]
      else
        segments
      end

    Strip.new(segments)
  end

  defp render_row(state, row, row_index, column_widths, total_width) do
    is_selected = MapSet.member?(state.selected_indices, row_index)
    is_zebra = state.zebra_stripes && rem(row_index, 2) == 1

    segments =
      state.columns
      |> Enum.zip(column_widths)
      |> Enum.with_index()
      |> Enum.map(fn {{column, width}, _col_index} ->
        # Get cell value
        cell_value =
          Map.get(row, column.key, "")
          |> to_string()

        formatted_text = format_cell_content(cell_value, width, column.align)

        # Determine cell style: no per-column or row-level cursor highlight in rows
        style =
          cond do
            is_selected -> state.selected_style
            is_zebra -> Map.merge(state.style, %{bg: adjust_color(state.style.bg, -10)})
            true -> state.style
          end

        Segment.new(formatted_text, style)
      end)

    # Pad to full width
    current_width = Enum.sum(column_widths)

    segments =
      if current_width < total_width do
        padding = String.duplicate(" ", total_width - current_width)
        segments ++ [Segment.new(padding, state.style)]
      else
        segments
      end

    Strip.new(segments)
  end

  # Helper functions

  defp normalize_columns(columns) do
    Enum.map(columns, fn
      %{} = col ->
        Map.merge(%{width: :auto, align: :left, sortable: true}, col)

      {key, label} ->
        %{key: key, label: label, width: :auto, align: :left, sortable: true}

      key when is_atom(key) ->
        %{key: key, label: to_string(key), width: :auto, align: :left, sortable: true}
    end)
  end

  defp calculate_column_widths(columns, total_width, fit_mode, data) do
    col_count = length(columns)

    if col_count > 0 do
      case fit_mode do
        :fit ->
          # Fit all columns within available width
          base_width = div(total_width, col_count)
          remainder = rem(total_width, col_count)

          widths = List.duplicate(base_width, col_count)

          # Distribute remainder
          if remainder > 0 do
            {first_part, rest} = Enum.split(widths, remainder)
            Enum.map(first_part, &(&1 + 1)) ++ rest
          else
            widths
          end

        :expand ->
          # Calculate optimal widths based on content, allow horizontal scrolling
          calculate_content_based_widths(columns, data, total_width)
      end
    else
      []
    end
  end

  defp calculate_content_based_widths(columns, data, min_total_width) do
    # Calculate optimal width for each column based on content
    optimal_widths =
      columns
      |> Enum.map(fn column ->
        # Header width
        # +2 for sort indicator
        header_width = String.length(column.label) + 2

        # Content width (sample first 20 rows for performance)
        content_width =
          data
          |> Enum.take(20)
          |> Enum.map(fn row ->
            cell_value =
              Map.get(row, column.key, "")
              |> to_string()

            String.length(cell_value)
          end)
          |> Enum.max(fn -> 0 end)

        # Use the larger of header or content width, with reasonable bounds
        width = max(header_width, content_width)
        # Min 8, max 30 characters per column
        max(8, min(30, width))
      end)

    total_optimal = Enum.sum(optimal_widths)

    # If total is less than available space, distribute extra space
    if total_optimal < min_total_width do
      extra_space = min_total_width - total_optimal
      extra_per_col = div(extra_space, length(optimal_widths))
      remainder = rem(extra_space, length(optimal_widths))

      widths = Enum.map(optimal_widths, &(&1 + extra_per_col))

      if remainder > 0 do
        {first_part, rest} = Enum.split(widths, remainder)
        Enum.map(first_part, &(&1 + 1)) ++ rest
      else
        widths
      end
    else
      optimal_widths
    end
  end

  defp format_cell_content(content, width, align) when width > 0 do
    # Truncate if too long
    truncated =
      if String.length(content) > width do
        String.slice(content, 0, max(0, width - 1)) <> "…"
      else
        content
      end

    # Apply alignment
    case align do
      :left ->
        String.pad_trailing(truncated, width)

      :right ->
        String.pad_leading(truncated, width)

      :center ->
        total_padding = width - String.length(truncated)
        left_padding = div(total_padding, 2)
        right_padding = total_padding - left_padding
        String.duplicate(" ", left_padding) <> truncated <> String.duplicate(" ", right_padding)
    end
  end

  defp format_cell_content(_content, _width, _align), do: ""

  defp calculate_column_from_x(state, x) do
    column_widths =
      calculate_column_widths(state.columns, state.width, state.column_fit_mode, state.data)

    {col_index, _} =
      column_widths
      |> Enum.with_index()
      |> Enum.reduce_while({0, 0}, fn {width, col_index}, {current_x, _} ->
        if x >= current_x && x < current_x + width do
          {:halt, {col_index, current_x}}
        else
          {:cont, {col_index, current_x + width}}
        end
      end)

    col_index
  end

  defp adjust_scroll_horizontal(state) do
    if length(state.columns) <= state.fixed_columns do
      state
    else
      fixed_cols = state.fixed_columns
      scrollable_cols = Enum.slice(state.columns, fixed_cols..-1//1)
      num_scrollable = length(scrollable_cols)

      if num_scrollable == 0 do
        state
      else
        content_width = state.width

        fixed_col_widths =
          Enum.slice(state.columns, 0, fixed_cols)
          |> Enum.map(fn col ->
            if col.width == :auto, do: 10, else: col.width
          end)

        fixed_width = Enum.sum(fixed_col_widths) + length(fixed_col_widths) - 1

        remaining_width = max(0, content_width - fixed_width)

        if remaining_width > 0 do
          avg_col_width = div(remaining_width, num_scrollable)
          visible_cols = div(remaining_width - 1, avg_col_width + 1) + 1

          offset = max(0, state.cursor_col - fixed_cols - visible_cols + 1)
          offset = min(offset, max(0, num_scrollable - visible_cols))

          if state.cursor_col < fixed_cols do
            %{state | scroll_offset_col: 0, fixed_col_widths: fixed_col_widths}
          else
            %{state | scroll_offset_col: offset, fixed_col_widths: fixed_col_widths}
          end
        else
          %{state | scroll_offset_col: 0, fixed_col_widths: fixed_col_widths}
        end
      end
    end
  end

  defp sort_data(data, column_key, direction) do
    sorted =
      Enum.sort_by(data, fn row ->
        Map.get(row, column_key, "")
      end)

    if direction == :desc do
      Enum.reverse(sorted)
    else
      sorted
    end
  end

  defp adjust_color({r, g, b}, adjustment) do
    {
      max(0, min(255, r + adjustment)),
      max(0, min(255, g + adjustment)),
      max(0, min(255, b + adjustment))
    }
  end

  defp adjust_color(color, _adjustment), do: color

  defp add_vertical_scrollbar(strips, state, _total_width, data_height) do
    total_rows = length(state.data)
    visible_rows = data_height

    if total_rows > visible_rows do
      # Calculate scrollbar position (consistent with click handling)
      max_scroll = total_rows - visible_rows

      # Determine data start position - if header exists, scrollbar for data starts at row 1
      data_start_y = get_data_start_y(state)

      # Use same calculation as click handling for consistency
      scrollbar_pos =
        if max_scroll > 0 do
          # When fully scrolled (scroll_offset == max_scroll), thumb should be at last data row
          if state.scroll_offset >= max_scroll do
            data_start_y + data_height - 1
          else
            scroll_ratio = state.scroll_offset / max_scroll
            pos = round(scroll_ratio * (data_height - 1))
            # Position relative to data start
            data_start_y + pos
          end
        else
          data_start_y
        end

      # Add scrollbar to each strip
      strips
      |> Enum.with_index()
      |> Enum.map(fn {strip, index} ->
        scrollbar_char =
          cond do
            # Scrollbar thumb
            index == scrollbar_pos -> "█"
            # Scrollbar track (only in data area)
            index >= data_start_y -> "│"
            # Empty space (header area)
            true -> " "
          end

        # Enhanced scrollbar styling with hover effects - independent of row styling
        scrollbar_style =
          cond do
            index == scrollbar_pos and state.hovering_scrollbar ->
              # Vibrant thumb color on hover
              # Bright blue
              %{fg: {255, 255, 255}, bg: {0, 150, 255}}

            index == scrollbar_pos ->
              # Normal thumb color
              %{fg: {200, 200, 200}, bg: {100, 100, 100}}

            true ->
              # Track color - consistent background
              %{fg: {100, 100, 100}, bg: {60, 60, 60}}
          end

        scrollbar_segment = Segment.new(scrollbar_char, scrollbar_style)

        existing_segments = strip.segments || []
        new_segments = existing_segments ++ [scrollbar_segment]

        Strip.new(new_segments)
      end)
    else
      strips
    end
  end

  # DataTable-specific helper functions matching OptionList pattern

  defp get_highlighted_index(state), do: state.highlighted_index

  defp is_selected?(state, index), do: MapSet.member?(state.selected_indices, index)

  defp change_selection(state, target_index, trigger_select) do
    if target_index >= 0 and target_index < length(state.data) do
      # Update highlighted_index and ensure visibility
      new_state =
        %{state | highlighted_index: target_index}
        |> ensure_visible_index(target_index, get_data_height(state))

      # Update selection if needed
      new_state =
        if trigger_select do
          case state.selection_mode do
            :none ->
              new_state

            :single ->
              %{new_state | selected_indices: MapSet.new([target_index])}

            :multiple ->
              new_selected = MapSet.put(state.selected_indices, target_index)
              %{new_state | selected_indices: new_selected}
          end
        else
          new_state
        end

      # Collect actions - ALWAYS trigger re-render, plus callback if needed
      actions = []

      # Add callback action if selection changed and callback exists
      actions =
        if trigger_select && state.on_select do
          selected_items =
            new_state.selected_indices
            |> MapSet.to_list()
            |> Enum.map(fn index -> Enum.at(state.data, index) end)
            |> Enum.filter(& &1)

          [state.on_select.(selected_items) | actions]
        else
          actions
        end

      # Always add render update to ensure visual changes are displayed
      actions = [:render_update | actions]

      {:ok, new_state, actions}
    else
      {:ok, state, []}
    end
  end

  defp ensure_visible_index(state, target_index, visible_height) do
    cond do
      target_index < state.scroll_offset ->
        %{state | scroll_offset: target_index}

      target_index >= state.scroll_offset + visible_height ->
        new_offset = target_index - visible_height + 1
        %{state | scroll_offset: max(0, new_offset)}

      true ->
        state
    end
  end

  defp find_first_enabled(data) do
    # All data rows are enabled
    Enum.find_index(data, fn _row -> true end)
  end

  defp find_last_enabled(data) do
    length(data) - 1
  end

  defp find_next_enabled(data, current_index) do
    start_index = if current_index, do: current_index + 1, else: 0
    if start_index < length(data), do: start_index, else: nil
  end

  defp find_previous_enabled(_data, current_index) do
    if current_index && current_index > 0, do: current_index - 1, else: nil
  end

  defp find_next_enabled_from(data, start_index) do
    if start_index && start_index < length(data) - 1, do: start_index, else: nil
  end

  defp find_previous_enabled_from(_data, end_index) do
    if end_index && end_index > 0, do: end_index, else: nil
  end

  defp trigger_sort(state) do
    if state.on_sort do
      try do
        state.on_sort.(state.sort_column, state.sort_direction)
      rescue
        _error -> :ok
      end
    end
  end

  defp apply_theme_styles(state, theme) do
    %{
      state
      | style: %{fg: theme.text_primary, bg: theme.background},
        header_style: %{fg: theme.text_primary, bg: theme.surface, bold: true},
        selected_style: %{fg: theme.text_primary, bg: theme.primary},
        cursor_style: %{fg: theme.text_primary, bg: theme.primary, bold: true}
    }
  end
end
