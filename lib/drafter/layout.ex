defmodule Drafter.Layout do
  @moduledoc false

  @type rect :: %{
    x: non_neg_integer(),
    y: non_neg_integer(), 
    width: pos_integer(),
    height: pos_integer()
  }

  @type size_constraint :: :auto | :fill | pos_integer() | {:percent, float()}
  @type alignment :: :start | :center | :end | :stretch

  @type layout_spec :: %{
    type: :vertical | :horizontal | :grid | :absolute,
    spacing: non_neg_integer(),
    padding: non_neg_integer(),
    align_items: alignment(),
    justify_content: alignment()
  }

  @type widget_constraints :: %{
    width: size_constraint(),
    height: size_constraint(),
    min_width: pos_integer(),
    min_height: pos_integer(),
    max_width: pos_integer() | :infinity,
    max_height: pos_integer() | :infinity,
    flex_grow: float(),
    flex_shrink: float()
  }

  @doc "Create a rectangle"
  @spec rect(non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()) :: rect()
  def rect(x, y, width, height) do
    %{x: x, y: y, width: width, height: height}
  end

  @doc "Calculate layouts for children in a container"
  @spec layout_children([widget_constraints()], rect(), layout_spec()) :: [rect()]
  def layout_children(child_constraints, container_rect, layout_spec) do
    case layout_spec.type do
      :vertical ->
        layout_vertical(child_constraints, container_rect, layout_spec)
      
      :horizontal ->
        layout_horizontal(child_constraints, container_rect, layout_spec)
      
      :grid ->
        layout_grid(child_constraints, container_rect, layout_spec)
      
      :absolute ->
        layout_absolute(child_constraints, container_rect, layout_spec)
    end
  end

  @doc "Create default widget constraints"
  @spec default_constraints() :: widget_constraints()
  def default_constraints() do
    %{
      width: :auto,
      height: :auto,
      min_width: 0,
      min_height: 0,
      max_width: :infinity,
      max_height: :infinity,
      flex_grow: 0.0,
      flex_shrink: 1.0
    }
  end

  @doc "Create default layout spec"
  @spec default_layout_spec(atom()) :: layout_spec()
  def default_layout_spec(type \\ :vertical) do
    %{
      type: type,
      spacing: 0,
      padding: 0,
      align_items: :stretch,
      justify_content: :start
    }
  end

  defp layout_vertical(child_constraints, container_rect, layout_spec) do
    content_rect = apply_padding(container_rect, layout_spec.padding)
    available_height = content_rect.height
    
    child_heights = calculate_vertical_heights(child_constraints, available_height, layout_spec.spacing)
    
    {_current_y, child_rects} = Enum.reduce(
      Enum.zip(child_constraints, child_heights),
      {content_rect.y, []},
      fn {constraints, height}, {current_y, acc} ->
        width = calculate_width(constraints, content_rect.width)
        x = calculate_x_position(width, content_rect, layout_spec.align_items)
        
        child_rect = rect(x, current_y, width, height)
        next_y = current_y + height + layout_spec.spacing
        
        {next_y, [child_rect | acc]}
      end
    )
    
    Enum.reverse(child_rects)
  end

  defp layout_horizontal(child_constraints, container_rect, layout_spec) do
    content_rect = apply_padding(container_rect, layout_spec.padding)
    available_width = content_rect.width
    
    child_widths = calculate_horizontal_widths(child_constraints, available_width, layout_spec.spacing)
    
    {_current_x, child_rects} = Enum.reduce(
      Enum.zip(child_constraints, child_widths),
      {content_rect.x, []},
      fn {constraints, width}, {current_x, acc} ->
        height = calculate_height(constraints, content_rect.height)
        y = calculate_y_position(height, content_rect, layout_spec.align_items)
        
        child_rect = rect(current_x, y, width, height)
        next_x = current_x + width + layout_spec.spacing
        
        {next_x, [child_rect | acc]}
      end
    )
    
    Enum.reverse(child_rects)
  end

  defp layout_grid(child_constraints, container_rect, layout_spec) do
    content_rect = apply_padding(container_rect, layout_spec.padding)
    child_count = length(child_constraints)
    
    if child_count == 0 do
      []
    else
      cols = calculate_grid_columns(content_rect, child_count)
      rows = div(child_count + cols - 1, cols)
      
      cell_width = div(content_rect.width, cols)
      cell_height = div(content_rect.height, rows)
      
      child_constraints
      |> Enum.with_index()
      |> Enum.map(fn {_constraints, index} ->
        col = rem(index, cols)
        row = div(index, cols)
        
        rect(
          content_rect.x + col * cell_width,
          content_rect.y + row * cell_height,
          cell_width,
          cell_height
        )
      end)
    end
  end

  defp layout_absolute(child_constraints, container_rect, _layout_spec) do
    List.duplicate(container_rect, length(child_constraints))
  end

  defp apply_padding(container_rect, padding) do
    %{
      x: container_rect.x + padding,
      y: container_rect.y + padding,
      width: max(0, container_rect.width - padding * 2),
      height: max(0, container_rect.height - padding * 2)
    }
  end

  defp calculate_vertical_heights(child_constraints, available_height, spacing) do
    child_count = length(child_constraints)
    total_spacing = max(0, (child_count - 1) * spacing)
    usable_height = max(0, available_height - total_spacing)
    
    if child_count > 0 do
      base_height = div(usable_height, child_count)
      List.duplicate(base_height, child_count)
    else
      []
    end
  end

  defp calculate_horizontal_widths(child_constraints, available_width, spacing) do
    child_count = length(child_constraints)
    total_spacing = max(0, (child_count - 1) * spacing)
    usable_width = max(0, available_width - total_spacing)
    
    if child_count > 0 do
      base_width = div(usable_width, child_count)
      List.duplicate(base_width, child_count)
    else
      []
    end
  end

  defp calculate_width(constraints, container_width) do
    case constraints.width do
      :auto -> container_width
      :fill -> container_width
      value when is_integer(value) -> min(value, container_width)
      {:percent, pct} -> round(container_width * pct)
    end
  end

  defp calculate_height(constraints, container_height) do
    case constraints.height do
      :auto -> container_height
      :fill -> container_height
      value when is_integer(value) -> min(value, container_height)
      {:percent, pct} -> round(container_height * pct)
    end
  end

  defp calculate_x_position(width, content_rect, align) do
    case align do
      :start -> content_rect.x
      :center -> content_rect.x + div(content_rect.width - width, 2)
      :end -> content_rect.x + content_rect.width - width
      :stretch -> content_rect.x
    end
  end

  defp calculate_y_position(height, content_rect, align) do
    case align do
      :start -> content_rect.y
      :center -> content_rect.y + div(content_rect.height - height, 2)
      :end -> content_rect.y + content_rect.height - height
      :stretch -> content_rect.y
    end
  end

  defp calculate_grid_columns(content_rect, child_count) do
    aspect_ratio = content_rect.width / content_rect.height
    ideal_cols = :math.sqrt(child_count * aspect_ratio) |> round()
    max(1, ideal_cols)
  end
end