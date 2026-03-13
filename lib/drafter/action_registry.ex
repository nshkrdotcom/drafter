defmodule Drafter.ActionRegistry do
  @moduledoc false

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [Drafter.BuiltinActionHandler] end, name: __MODULE__)
  end

  @spec register(module()) :: :ok
  def register(module) do
    Agent.update(__MODULE__, fn handlers -> [module | handlers] end)
  end

  @spec dispatch(term(), map()) :: map()
  def dispatch(action, acc_state) do
    handlers = Agent.get(__MODULE__, & &1)

    Enum.reduce_while(handlers, :unhandled, fn module, _ ->
      case module.handle_action(action, acc_state) do
        :unhandled -> {:cont, :unhandled}
        {:ok, new_state} -> {:halt, {:ok, new_state}}
      end
    end)
    |> case do
      {:ok, new_state} -> new_state
      :unhandled -> acc_state
    end
  end
end
