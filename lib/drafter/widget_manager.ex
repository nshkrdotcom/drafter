defmodule Drafter.WidgetManager do
  @moduledoc false

  use GenServer

  alias Drafter.WidgetServer

  defstruct [
    :widgets,
    :widget_rects,
    :focused_widget,
    :hover_widget,
    :app_pid
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_widget(manager, id, module, props, rect) do
    GenServer.call(manager, {:add_widget, id, module, props, rect})
  end

  def remove_widget(manager, id) do
    GenServer.call(manager, {:remove_widget, id})
  end

  def send_event(manager, id, event) do
    GenServer.cast(manager, {:send_event, id, event})
  end

  def broadcast_event(manager, event) do
    GenServer.cast(manager, {:broadcast, event})
  end

  def set_focus(manager, id) do
    GenServer.cast(manager, {:set_focus, id})
  end

  def get_focus(manager) do
    GenServer.call(manager, :get_focus)
  end

  def update_rect(manager, id, rect) do
    GenServer.cast(manager, {:update_rect, id, rect})
  end

  def get_widget_at(manager, x, y) do
    GenServer.call(manager, {:get_widget_at, x, y})
  end

  def render_all(manager) do
    GenServer.call(manager, :render_all)
  end

  def get_widgets(manager) do
    GenServer.call(manager, :get_widgets)
  end

  def handle_mouse_event(manager, mouse_event) do
    GenServer.call(manager, {:handle_mouse, mouse_event})
  end

  def clear(manager) do
    GenServer.call(manager, :clear)
  end

  @impl true
  def init(opts) do
    app_pid = Keyword.get(opts, :app_pid, self())

    state = %__MODULE__{
      widgets: %{},
      widget_rects: %{},
      focused_widget: nil,
      hover_widget: nil,
      app_pid: app_pid
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_widget, id, module, props, rect}, _from, state) do
    {:ok, pid} =
      WidgetServer.start_link(
        id: id,
        module: module,
        props: props,
        rect: rect,
        parent_pid: state.app_pid
      )

    new_widgets = Map.put(state.widgets, id, pid)
    new_rects = Map.put(state.widget_rects, id, rect)

    {:reply, {:ok, pid}, %{state | widgets: new_widgets, widget_rects: new_rects}}
  end

  def handle_call({:remove_widget, id}, _from, state) do
    case Map.get(state.widgets, id) do
      nil ->
        {:reply, :ok, state}

      pid ->
        WidgetServer.stop(pid)
        new_widgets = Map.delete(state.widgets, id)
        new_rects = Map.delete(state.widget_rects, id)
        new_focused = if state.focused_widget == id, do: nil, else: state.focused_widget
        new_hover = if state.hover_widget == id, do: nil, else: state.hover_widget

        {:reply, :ok,
         %{
           state
           | widgets: new_widgets,
             widget_rects: new_rects,
             focused_widget: new_focused,
             hover_widget: new_hover
         }}
    end
  end

  def handle_call(:get_focus, _from, state) do
    {:reply, state.focused_widget, state}
  end

  def handle_call({:get_widget_at, x, y}, _from, state) do
    found =
      Enum.find(state.widget_rects, fn {_id, rect} ->
        x >= rect.x and x < rect.x + rect.width and
          y >= rect.y and y < rect.y + rect.height
      end)

    result =
      case found do
        {id, _rect} -> id
        nil -> nil
      end

    {:reply, result, state}
  end

  def handle_call(:render_all, _from, state) do
    renders =
      Enum.map(state.widgets, fn {id, pid} ->
        {rect, strips} = WidgetServer.get_render(pid)
        {id, rect, strips}
      end)

    {:reply, renders, state}
  end

  def handle_call(:get_widgets, _from, state) do
    {:reply, state.widgets, state}
  end

  def handle_call({:handle_mouse, mouse_event}, _from, state) do
    target_id = find_widget_at(state, mouse_event.x, mouse_event.y)

    state = handle_hover(state, target_id, mouse_event)

    state =
      case {mouse_event.type, target_id} do
        {:move, _} ->
          state

        {_, nil} ->
          state

        {type, widget_id} when type in [:click, :mouse_up] ->
          state = set_focus_internal(state, widget_id)
          send_to_widget(state, widget_id, {:mouse, mouse_event})
          state

        {_type, widget_id} ->
          send_to_widget(state, widget_id, {:mouse, mouse_event})
          state
      end

    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    Enum.each(state.widgets, fn {_id, pid} ->
      WidgetServer.stop(pid)
    end)

    {:reply, :ok,
     %{state | widgets: %{}, widget_rects: %{}, focused_widget: nil, hover_widget: nil}}
  end

  @impl true
  def handle_cast({:send_event, id, event}, state) do
    send_to_widget(state, id, event)
    {:noreply, state}
  end

  def handle_cast({:broadcast, event}, state) do
    Enum.each(state.widgets, fn {_id, pid} ->
      WidgetServer.send_event(pid, event)
    end)

    {:noreply, state}
  end

  def handle_cast({:set_focus, id}, state) do
    {:noreply, set_focus_internal(state, id)}
  end

  def handle_cast({:update_rect, id, rect}, state) do
    case Map.get(state.widgets, id) do
      nil ->
        {:noreply, state}

      pid ->
        WidgetServer.update_rect(pid, rect)
        new_rects = Map.put(state.widget_rects, id, rect)
        {:noreply, %{state | widget_rects: new_rects}}
    end
  end

  defp find_widget_at(state, x, y) do
    found =
      Enum.find(state.widget_rects, fn {_id, rect} ->
        x >= rect.x and x < rect.x + rect.width and
          y >= rect.y and y < rect.y + rect.height
      end)

    case found do
      {id, _rect} -> id
      nil -> nil
    end
  end

  defp handle_hover(state, target_id, mouse_event) do
    prev_hover = state.hover_widget

    cond do
      target_id == prev_hover ->
        state

      prev_hover != nil and target_id != prev_hover ->
        send_to_widget(state, prev_hover, {:hover_leave, mouse_event})

        if target_id do
          send_to_widget(state, target_id, {:hover_enter, mouse_event})
        end

        %{state | hover_widget: target_id}

      prev_hover == nil and target_id != nil ->
        send_to_widget(state, target_id, {:hover_enter, mouse_event})
        %{state | hover_widget: target_id}

      true ->
        %{state | hover_widget: target_id}
    end
  end

  defp set_focus_internal(state, nil), do: state

  defp set_focus_internal(state, id) do
    prev_focus = state.focused_widget

    if prev_focus != id do
      if prev_focus do
        send_to_widget(state, prev_focus, {:blur})
      end

      send_to_widget(state, id, {:focus})
      %{state | focused_widget: id}
    else
      state
    end
  end

  defp send_to_widget(state, id, event) do
    case Map.get(state.widgets, id) do
      nil ->
        :ok

      pid ->
        adjusted_event = adjust_mouse_event(state, id, event)
        WidgetServer.send_event(pid, adjusted_event)
    end
  end

  defp adjust_mouse_event(state, id, {:mouse, mouse_event}) do
    rect = Map.get(state.widget_rects, id, %{x: 0, y: 0})
    adjusted = %{mouse_event | x: mouse_event.x - rect.x, y: mouse_event.y - rect.y}
    {:mouse, adjusted}
  end

  defp adjust_mouse_event(_state, _id, event), do: event
end
