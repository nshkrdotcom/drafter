defmodule Drafter.WidgetSystem do
  @moduledoc false

  defstruct [
    :focused_widget,
    :widgets,
    :bindings
  ]

  @type widget_id :: atom() | String.t()
  @type event :: term()
  @type action :: atom()
  @type binding :: %{key: term(), action: action(), description: String.t()}

  @type t :: %__MODULE__{
    focused_widget: widget_id() | nil,
    widgets: %{widget_id() => map()},
    bindings: %{widget_id() => [binding()]}
  }

  @doc "Create a new widget system"
  @spec new() :: t()
  def new do
    %__MODULE__{
      focused_widget: nil,
      widgets: %{},
      bindings: %{}
    }
  end

  @doc "Register a widget with the system"
  @spec register_widget(t(), widget_id(), module(), map()) :: t()
  def register_widget(system, widget_id, widget_module, widget_state) do
    # Get widget's default bindings
    bindings = get_widget_bindings(widget_module)
    
    %{system |
      widgets: Map.put(system.widgets, widget_id, %{module: widget_module, state: widget_state}),
      bindings: Map.put(system.bindings, widget_id, bindings)
    }
  end

  @doc "Set focus to a widget"
  @spec focus_widget(t(), widget_id()) :: t()
  def focus_widget(system, widget_id) do
    if Map.has_key?(system.widgets, widget_id) do
      %{system | focused_widget: widget_id}
    else
      system
    end
  end

  @doc "Handle an event in the widget system"
  @spec handle_event(t(), event()) :: {t(), list(action())}
  def handle_event(system, event) do
    case system.focused_widget do
      nil ->
        {system, []}
      
      widget_id ->
        handle_widget_event(system, widget_id, event)
    end
  end

  @doc "Check if an event should be handled by the widget system"
  @spec should_handle_event?(event()) :: boolean()
  def should_handle_event?({:key, _}), do: true
  def should_handle_event?({:key, _, _}), do: true
  def should_handle_event?({:mouse, _}), do: true
  def should_handle_event?({:action, _}), do: true
  def should_handle_event?(_), do: false

  defp handle_widget_event(system, widget_id, event) do
    widget_info = Map.get(system.widgets, widget_id)
    widget_bindings = Map.get(system.bindings, widget_id, [])
    
    # First try to match event to a binding action
    case find_binding_action(event, widget_bindings) do
      {:ok, action} ->
        execute_widget_action(system, widget_id, action, widget_info)
      
      :not_found ->
        # Let widget handle the raw event
        handle_raw_widget_event(system, widget_id, event, widget_info)
    end
  end

  defp find_binding_action(event, bindings) do
    Enum.find_value(bindings, :not_found, fn binding ->
      if binding.key == event, do: {:ok, binding.action}, else: nil
    end)
  end

  defp execute_widget_action(system, widget_id, action, widget_info) do
    action_method = String.to_atom("action_#{action}")
    
    if function_exported?(widget_info.module, action_method, 1) do
      case apply(widget_info.module, action_method, [widget_info.state]) do
        {:ok, new_state, actions} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, actions}
        
        {:ok, new_state} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, []}
        
        {:noreply, new_state} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, []}
        
        _ ->
          {system, []}
      end
    else
      {system, []}
    end
  end

  defp handle_raw_widget_event(system, widget_id, event, widget_info) do
    if function_exported?(widget_info.module, :handle_event, 2) do
      case apply(widget_info.module, :handle_event, [event, widget_info.state]) do
        {:ok, new_state, actions} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, actions}
        
        {:ok, new_state} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, []}
        
        {:noreply, new_state} ->
          new_system = update_widget_state(system, widget_id, new_state)
          {new_system, []}
        
        _ ->
          {system, []}
      end
    else
      {system, []}
    end
  end

  defp update_widget_state(system, widget_id, new_state) do
    case Map.get(system.widgets, widget_id) do
      nil -> system
      widget_info ->
        updated_widget = %{widget_info | state: new_state}
        %{system | widgets: Map.put(system.widgets, widget_id, updated_widget)}
    end
  end

  defp get_widget_bindings(widget_module) do
    if function_exported?(widget_module, :bindings, 0) do
      apply(widget_module, :bindings, [])
    else
      []
    end
  end

  @doc "Get the current state of a widget"
  @spec get_widget_state(t(), widget_id()) :: map() | nil
  def get_widget_state(system, widget_id) do
    case Map.get(system.widgets, widget_id) do
      nil -> nil
      widget_info -> widget_info.state
    end
  end

  @doc "Update a widget's state directly"
  @spec set_widget_state(t(), widget_id(), map()) :: t()
  def set_widget_state(system, widget_id, new_state) do
    update_widget_state(system, widget_id, new_state)
  end

  @doc "Get the currently focused widget ID"
  @spec get_focused_widget(t()) :: widget_id() | nil
  def get_focused_widget(system) do
    system.focused_widget
  end
end