defmodule Drafter.Widget.Grid do
  @moduledoc """
  Arranges child widgets in a uniform column grid, wrapping into multiple rows.

  Children are laid out left-to-right, top-to-bottom. The number of columns is
  set via `:grid_size`. Column width is `floor(total_width / columns)` and row
  height is divided evenly across the number of rows required. Each child widget
  is mounted fresh on every render pass from its `{module, props}` tuple.

  ## Options

    * `:children` - list of `{module, props}` tuples (default `[]`)
    * `:grid_size` - number of columns (default `2`)
    * `:grid_rows` - number of rows or `:auto` (default `:auto`)
    * `:padding` - inner cell padding in columns (default `1`)
    * `:style` - map of style properties

  ## Usage

      grid(children: [
        {Drafter.Widget.Label, %{text: "A"}},
        {Drafter.Widget.Label, %{text: "B"}},
        {Drafter.Widget.Label, %{text: "C"}},
        {Drafter.Widget.Label, %{text: "D"}}
      ], grid_size: 2)
  """

  @behaviour Drafter.Widget

  alias Drafter.Draw.{Segment, Strip}

  def mount(props) do
    %{
      children: Map.get(props, :children, []),
      grid_size: Map.get(props, :grid_size, 2),
      grid_rows: Map.get(props, :grid_rows, :auto),
      style: Map.get(props, :style, %{}),
      padding: Map.get(props, :padding, 1)
    }
  end

  def render(state, rect) do
    if Enum.empty?(state.children) do
      []
    else
      render_grid(state, rect)
    end
  end

  def update(props, state) do
    Map.merge(state, props)
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  defp render_grid(state, rect) do
    cols = state.grid_size
    children_count = length(state.children)

    if children_count == 0 do
      []
    else
      # Calculate dimensions
      col_width = div(rect.width, cols)
      rows_needed = div(children_count + cols - 1, cols)
      row_height = if rows_needed > 0, do: div(rect.height, rows_needed), else: rect.height

      # Create a grid of strips
      0..(rect.height - 1)
      |> Enum.map(fn y ->
        # Determine which row this y belongs to
        row = div(y, row_height)

        # Build the horizontal line for this y position
        segments =
          0..(cols - 1)
          |> Enum.map(fn col ->
            child_index = row * cols + col

            if child_index < children_count do
              {module, props} = Enum.at(state.children, child_index)

              # Calculate position within this cell
              _cell_x = col * col_width
              cell_y = rem(y, row_height)

              child_rect = %{
                x: 0,
                y: 0,
                width: col_width,
                height: row_height
              }

              child_strips = render_child({module, props}, child_rect)

              # Get the appropriate strip for this y position
              if cell_y < length(child_strips) do
                strip = Enum.at(child_strips, cell_y)
                # Take only the portion that fits in this column
                strip.segments
                |> Enum.take_while(fn segment ->
                  String.length(segment.text) <= col_width
                end)
              else
                [Segment.new(String.duplicate(" ", col_width))]
              end
            else
              # Empty cell
              [Segment.new(String.duplicate(" ", col_width))]
            end
          end)
          |> List.flatten()

        Strip.new(segments)
      end)
    end
  end

  defp render_child({module, props}, rect) do
    state = module.mount(props)

    case module.render(state, rect) do
      strips when is_list(strips) -> strips
      {:error, _} -> []
    end
  end
end
