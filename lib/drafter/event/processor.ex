defmodule Drafter.Event.Processor do
  @moduledoc false

  alias Drafter.Event

  @doc """
  Process an event through the proper chain of handlers.

  Returns:
    - :consumed - event was handled and should not propagate
    - :bubble - event should bubble to parent/app
    - :system - event was handled at system level
  """
  @spec process_event(Event.t(), map()) :: :consumed | :bubble | :system
  def process_event(event, context \\ %{}) do
    cond do
      system_level_event?(event) ->
        handle_system_event(event, context)
        :system

      widget_level_event?(event) ->
        handle_widget_event(event, context)

      true ->
        :bubble
    end
  end

  @doc """
  Check if event should be handled at system level and never reach app.
  """
  @spec system_level_event?(Event.t()) :: boolean()
  def system_level_event?({:mouse, %{type: :move}}), do: true
  def system_level_event?(_), do: false

  @doc """
  Check if event could be handled at widget level.
  """
  @spec widget_level_event?(Event.t()) :: boolean()
  def widget_level_event?({:mouse, %{type: type}}) when type in [:click, :drag, :mouse_down, :mouse_up, :scroll], do: true
  def widget_level_event?({:key, _}), do: true
  def widget_level_event?({:key, _, _}), do: true
  def widget_level_event?(_), do: false

  @doc """
  Handle system-level events that should never reach the application.
  """
  def handle_system_event({:mouse, %{type: :move} = _mouse_data}, _context) do
    # Handle mouse move at system level - update hover states, cursors, etc.
    # This is similar to Python Textual's screen._handle_mouse_move

    # TODO: Update widget hover states, cursor position, etc.
    # For now, just consume the event
    :ok
  end

  def handle_system_event(_event, _context) do
    :ok
  end

  @doc """
  Handle widget-level events.
  Returns :consumed if handled, :bubble if should propagate.
  """
  def handle_widget_event({:mouse, %{type: type}} = event, context) when type in [:click, :mouse_down, :mouse_up, :scroll] do
    # Find widget at mouse position and forward event; fall back to focused widget
    case find_widget_at_position(event, context) do
      nil ->
        case get_focused_widget(context) do
          nil ->
            :bubble

          widget_info ->
            forward_to_widget(event, widget_info)
        end

      widget_info ->
        forward_to_widget(event, widget_info)
    end
  end

  def handle_widget_event({:mouse, %{type: :drag}} = event, context) do
    # Only deliver drag events to the widget under the pointer; do not fall back to focused widget
    case find_widget_at_position(event, context) do
      nil ->
        :bubble

      widget_info ->
        forward_to_widget(event, widget_info)
    end
  end

  def handle_widget_event({:key, _} = event, context) do
    # Forward to focused widget if any
    case get_focused_widget(context) do
      nil -> :bubble
      widget_info -> forward_to_widget(event, widget_info)
    end
  end

  def handle_widget_event({:key, _, _} = event, context) do
    # Forward to focused widget if any
    case get_focused_widget(context) do
      nil -> :bubble
      widget_info -> forward_to_widget(event, widget_info)
    end
  end

  def handle_widget_event(_event, _context), do: :bubble

  # Private helper functions

  defp find_widget_at_position({:mouse, %{_x: _x, _y: _y}}, _context) do
    # TODO: Implement widget hit testing
    # For now, return nil so events bubble to app
    nil
  end

  defp get_focused_widget(_context) do
    # TODO: Implement focus management
    # For now, return nil so events bubble to app
    nil
  end

  defp forward_to_widget(_event, _widget_info) do
    # TODO: Forward event to specific widget
    :bubble
  end

  @doc """
  Handle event results from widgets/apps to determine next action.
  """
  @spec handle_event_result(Event.event_result()) :: :consumed | :bubble | :error
  def handle_event_result({:ok, _state}), do: :consumed
  def handle_event_result({:noreply, _state}), do: :consumed
  def handle_event_result({:stop, _state}), do: :consumed
  def handle_event_result({:consume, _state}), do: :consumed
  def handle_event_result({:error, _reason}) do
    :consumed
  end
  def handle_event_result(_other) do
    :consumed
  end
end
