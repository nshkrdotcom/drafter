defmodule Drafter.Session do
  @moduledoc false

  use DynamicSupervisor

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec start_isolated(module(), map(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_isolated(app_module, driver_config, opts \\ []) do
    spec =
      {Drafter.Session.Worker,
       [app_module: app_module, driver_config: driver_config, mode: :isolated] ++ opts}

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @spec start_shared(module(), map(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_shared(app_module, driver_config, opts \\ []) do
    shared_state = Drafter.Session.SharedState.get_or_start(app_module, opts)

    spec =
      {Drafter.Session.Worker,
       [app_module: app_module, driver_config: driver_config, mode: :shared, shared_state: shared_state] ++
         opts}

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl DynamicSupervisor
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)
end
