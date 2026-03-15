defmodule Drafter.Event.MouseProcessor do
  use GenServer

  alias Drafter.Event.Mouse

  defstruct [
    mouse_position: {0, 0},
    mouse_down_widget: nil,
    mouse_hover_widget: nil,
    click_count: 0,
    last_click_time: 0,
    double_click_threshold: 500  # milliseconds
  ]

  @type state :: %__MODULE__{
    mouse_position: {non_neg_integer(), non_neg_integer()},
    mouse_down_widget: module() | nil,
    mouse_hover_widget: module() | nil,
    click_count: non_neg_integer(),
    last_click_time: integer(),
    double_click_threshold: pos_integer()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process_event(event) do
    GenServer.cast(__MODULE__, {:process_event, event})
  end

  def get_position() do
    GenServer.call(__MODULE__, :get_position)
  end

  def get_widget_at(x, y) do
    GenServer.call(__MODULE__, {:get_widget_at, x, y})
  end

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{}
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state) do
    {:reply, state.mouse_position, state}
  end

  def handle_call({:get_widget_at, _x, _y}, _from, state) do
    # TODO: Implement widget hit-testing through compositor
    # For now, return nil - this will be implemented when we add widget registry
    {:reply, nil, state}
  end

  @impl GenServer
  def handle_cast({:process_event, %{type: :mouse_down} = event}, state) do
    widget_id = get_widget_at_position(event.x, event.y)

    new_state = %{state |
      mouse_position: {event.x, event.y},
      mouse_down_widget: widget_id
    }

    forward_event_to_widget(widget_id, event)

    {:noreply, new_state}
  end

  def handle_cast({:process_event, %{type: :mouse_up} = event}, state) do
    new_state = %{state | mouse_position: {event.x, event.y}}

    mouse_up_widget = get_widget_at_position(event.x, event.y)
    if mouse_up_widget == state.mouse_down_widget and state.mouse_down_widget != nil do
      click_event = %{event | type: :click}

      # Handle double-click detection
      current_time = System.monotonic_time(:millisecond)
      time_diff = current_time - state.last_click_time

      {click_count, new_click_time} = if time_diff < state.double_click_threshold do
        {state.click_count + 1, current_time}
      else
        {1, current_time}
      end

      click_event_with_count = Map.put(click_event, :click_count, click_count)

      # Forward the click event to specific widget
      forward_event_to_widget(state.mouse_down_widget, click_event_with_count)

      final_state = %{new_state |
        mouse_down_widget: nil,
        click_count: click_count,
        last_click_time: new_click_time
      }

      {:noreply, final_state}
    else
      if state.mouse_down_widget != nil do
        forward_event_to_widget(state.mouse_down_widget, event)
      else
        forward_event_to_widget(mouse_up_widget, event)
      end

      final_state = %{new_state | mouse_down_widget: nil}
      {:noreply, final_state}
    end
  end

  def handle_cast({:process_event, %{type: :mouse_move} = event}, state) do
    new_state = %{state | mouse_position: {event.x, event.y}}

    if state.mouse_down_widget != nil do
      forward_event_to_widget(state.mouse_down_widget, event)
      {:noreply, new_state}
    else
      current_widget = get_widget_at_position(event.x, event.y)

      cond do
        current_widget != state.mouse_hover_widget and state.mouse_hover_widget != nil ->
          leave_event = Mouse.leave(event.x, event.y)
          forward_event_to_widget(state.mouse_hover_widget, leave_event)

          if current_widget != nil do
            enter_event = Mouse.enter(event.x, event.y)
            forward_event_to_widget(current_widget, enter_event)
          end

          {:noreply, %{new_state | mouse_hover_widget: current_widget}}

        current_widget != nil and state.mouse_hover_widget == nil ->
          enter_event = Mouse.enter(event.x, event.y)
          forward_event_to_widget(current_widget, enter_event)

          {:noreply, %{new_state | mouse_hover_widget: current_widget}}

        true ->
          forward_event_to_widget(current_widget, event)
          {:noreply, new_state}
      end
    end
  end

  def handle_cast({:process_event, event}, state) do
    # Forward other mouse events to current widget
    widget_id = get_widget_at_position(event.x, event.y)
    forward_event_to_widget(widget_id, event)
    {:noreply, state}
  end

  defp forward_event_to_widget(nil, event) do
    # No widget found in registry - forward to app via event manager
    Drafter.Event.Manager.send_event({:mouse, event})
  end

  defp forward_event_to_widget(widget_id, event) do
    case Drafter.WidgetRegistry.get_widget(widget_id) do
      nil ->
        :ok

      widget_info ->
        # Translate event coordinates to widget-local coordinates
        local_event = Drafter.Event.Mouse.translate(event, widget_info.rect)

        # Send the event directly to the app process via the event manager
        # But first, let's try a simpler approach - let the main app loop handle it
        Drafter.Event.Manager.send_event({:widget_event, widget_id, {:mouse, local_event}})
    end
  end

  defp get_widget_at_position(x, y) do
    case Drafter.WidgetRegistry.widget_at(x, y) do
      {widget_id, _widget_info} -> widget_id
      nil -> nil
    end
  end
end
