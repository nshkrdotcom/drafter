defmodule Drafter.WidgetRegistry do
  @moduledoc false

  use GenServer

  defstruct [
    widgets: %{}
  ]

  @type widget_info :: %{
    module: module(),
    state: map(),
    rect: map(),
    z_index: integer()
  }

  @type state :: %__MODULE__{
    widgets: %{atom() => widget_info()}
  }

  @doc "Start the widget registry"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register a widget with its position"
  @spec register_widget(atom(), module(), map(), map()) :: :ok
  def register_widget(widget_id, module, state, rect) do
    GenServer.cast(__MODULE__, {:register, widget_id, module, state, rect})
  end

  @doc "Unregister a widget"
  @spec unregister_widget(atom()) :: :ok
  def unregister_widget(widget_id) do
    GenServer.cast(__MODULE__, {:unregister, widget_id})
  end

  @doc "Find widget at coordinates"
  @spec widget_at(non_neg_integer(), non_neg_integer()) :: {atom(), widget_info()} | nil
  def widget_at(x, y) do
    GenServer.call(__MODULE__, {:widget_at, x, y})
  end

  @doc "Update widget state"
  @spec update_widget(atom(), map()) :: :ok
  def update_widget(widget_id, new_state) do
    GenServer.cast(__MODULE__, {:update, widget_id, new_state})
  end

  @doc "Clear all widgets"
  @spec clear() :: :ok
  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc "Get widget by ID"
  @spec get_widget(atom()) :: widget_info() | nil
  def get_widget(widget_id) do
    GenServer.call(__MODULE__, {:get_widget, widget_id})
  end

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{}
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:widget_at, x, y}, _from, state) do
    # Find the topmost widget (highest z-index) that contains the coordinates
    result = state.widgets
    |> Enum.filter(fn {_id, widget_info} ->
      rect = widget_info.rect
      x >= rect.x and x < rect.x + rect.width and
      y >= rect.y and y < rect.y + rect.height
    end)
    |> Enum.max_by(fn {_id, widget_info} -> 
      Map.get(widget_info, :z_index, 0) 
    end, fn -> nil end)

    case result do
      {widget_id, widget_info} -> {:reply, {widget_id, widget_info}, state}
      nil -> {:reply, nil, state}
    end
  end

  def handle_call({:get_widget, widget_id}, _from, state) do
    widget_info = Map.get(state.widgets, widget_id)
    {:reply, widget_info, state}
  end

  @impl GenServer
  def handle_cast({:register, widget_id, module, widget_state, rect}, state) do
    widget_info = %{
      module: module,
      state: widget_state,
      rect: rect,
      z_index: Map.get(widget_state, :z_index, 0)
    }
    
    new_widgets = Map.put(state.widgets, widget_id, widget_info)
    {:noreply, %{state | widgets: new_widgets}}
  end

  def handle_cast({:unregister, widget_id}, state) do
    new_widgets = Map.delete(state.widgets, widget_id)
    {:noreply, %{state | widgets: new_widgets}}
  end

  def handle_cast({:update, widget_id, new_state}, state) do
    case Map.get(state.widgets, widget_id) do
      nil -> 
        {:noreply, state}
      
      widget_info ->
        updated_widget_info = %{widget_info | state: new_state}
        new_widgets = Map.put(state.widgets, widget_id, updated_widget_info)
        {:noreply, %{state | widgets: new_widgets}}
    end
  end

  def handle_cast(:clear, state) do
    {:noreply, %{state | widgets: %{}}}
  end
end