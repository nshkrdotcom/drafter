defmodule Drafter.FocusRegistry do
  @moduledoc false

  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec set([{String.t(), String.t()}]) :: :ok
  def set(bindings), do: GenServer.cast(__MODULE__, {:set, bindings})

  @spec clear() :: :ok
  def clear, do: GenServer.cast(__MODULE__, :clear)

  @spec get() :: [{String.t(), String.t()}]
  def get, do: GenServer.call(__MODULE__, :get)

  @impl GenServer
  def init(_), do: {:ok, []}

  @impl GenServer
  def handle_cast({:set, bindings}, _state), do: {:noreply, bindings}

  @impl GenServer
  def handle_cast(:clear, _state), do: {:noreply, []}

  @impl GenServer
  def handle_call(:get, _from, state), do: {:reply, state, state}
end
