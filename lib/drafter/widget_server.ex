defmodule Drafter.WidgetServer do
  @moduledoc false

  use GenServer

  defstruct [
    :id,
    :module,
    :state,
    :rect,
    :render_cache
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_event(pid, event) do
    GenServer.cast(pid, {:event, event})
  end

  def send_event_sync(pid, event) do
    GenServer.call(pid, {:event_sync, event})
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def get_render(pid) do
    GenServer.call(pid, :get_render)
  end

  def update_rect(pid, rect) do
    GenServer.call(pid, {:update_rect, rect})
  end

  def update_props(pid, props) do
    GenServer.cast(pid, {:update_props, props})
  end

  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  def call_capture_handler(pid, event) do
    GenServer.call(pid, {:capture_event, event})
  end

  @impl true
  def init(opts) do
    module = Keyword.fetch!(opts, :module)
    props = Keyword.get(opts, :props, %{})
    rect = Keyword.get(opts, :rect, %{x: 0, y: 0, width: 10, height: 3})
    id = Keyword.get(opts, :id)

    widget_state = module.mount(props)

    state = %__MODULE__{
      id: id,
      module: module,
      state: widget_state,
      rect: rect,
      render_cache: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    case apply(state.module, :handle_event, [event, state.state]) do
      {:ok, new_widget_state} ->
        notify_render_needed(state.id)
        {:noreply, %{state | state: new_widget_state, render_cache: nil}}

      {:ok, new_widget_state, actions} ->
        handle_actions(state.id, actions)
        notify_render_needed(state.id)
        {:noreply, %{state | state: new_widget_state, render_cache: nil}}

      {:noreply, _} ->
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:update_props, props}, state) do
    new_widget_state =
      if function_exported?(state.module, :update, 2) do
        apply(state.module, :update, [props, state.state])
      else
        state.state
      end

    new_cache =
      if new_widget_state === state.state, do: state.render_cache, else: nil

    {:noreply, %{state | state: new_widget_state, render_cache: new_cache}}
  end

  @impl true
  def handle_call({:update_rect, rect}, _from, state) do
    new_widget_state =
      if function_exported?(state.module, :on_rect_change, 2) do
        apply(state.module, :on_rect_change, [rect, state.state])
      else
        state.state
      end

    new_cache =
      if rect == state.rect and new_widget_state === state.state,
        do: state.render_cache,
        else: nil

    {:reply, :ok, %{state | rect: rect, state: new_widget_state, render_cache: new_cache}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  def handle_call(:get_render, _from, state) do
    case state.render_cache do
      {rect, strips} ->
        {:reply, {rect, strips}, state}

      nil ->
        strips = apply(state.module, :render, [state.state, state.rect])
        new_cache = {state.rect, strips}
        {:reply, new_cache, %{state | render_cache: new_cache}}
    end
  end

  def handle_call({:event_sync, event}, _from, state) do
    result = apply(state.module, :handle_event, [event, state.state])

    case result do
      {:ok, new_widget_state} ->
        notify_render_needed(state.id)
        {:reply, {:ok, new_widget_state}, %{state | state: new_widget_state, render_cache: nil}}

      {:ok, new_widget_state, actions} ->
        notify_render_needed(state.id)
        {:reply, {:ok, new_widget_state, actions}, %{state | state: new_widget_state, render_cache: nil}}

      {:noreply, new_state} ->
        {:reply, {:noreply, new_state}, state}

      other ->
        {:reply, other, state}
    end
  end

  def handle_call({:capture_event, event}, _from, state) do
    if function_exported?(state.module, :handle_event_capture, 2) do
      result = apply(state.module, :handle_event_capture, [event, state.state])

      case result do
        {:continue, updated_event, new_widget_state} ->
          {:reply, {:continue, updated_event, new_widget_state}, %{state | state: new_widget_state}}

        {:stop, updated_event, new_widget_state, actions} ->
          handle_actions(state.id, actions)
          {:reply, {:stop, updated_event, new_widget_state, actions}, %{state | state: new_widget_state}}

        {:prevent, updated_event, new_widget_state} ->
          {:reply, {:prevent, updated_event, new_widget_state}, %{state | state: new_widget_state}}

        other ->
          {:reply, other, state}
      end
    else
      {:reply, {:continue, event, state.state}, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    result =
      if function_exported?(state.module, :handle_info, 2) do
        apply(state.module, :handle_info, [msg, state.state])
      else
        apply(state.module, :handle_event, [msg, state.state])
      end

    case result do
      {:ok, new_widget_state} ->
        notify_render_needed(state.id)
        {:noreply, %{state | state: new_widget_state, render_cache: nil}}

      {:ok, new_widget_state, _actions} ->
        notify_render_needed(state.id)
        {:noreply, %{state | state: new_widget_state, render_cache: nil}}

      {:noreply, _} ->
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp notify_render_needed(widget_id) do
    app_pid = Process.whereis(:tui_app_loop)

    if app_pid do
      send(:tui_app_loop, {:widget_render_needed, widget_id})
    end
  end

  defp handle_actions(widget_id, actions) do
    app_pid = Process.whereis(:tui_app_loop)

    if app_pid do
      Enum.each(actions, fn action ->
        send(:tui_app_loop, {:widget_action, widget_id, action})
      end)
    end
  end
end
