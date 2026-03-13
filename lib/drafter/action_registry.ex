defmodule Drafter.ActionRegistry do
  @moduledoc """
  Global registry for `Drafter.ActionHandler` modules.

  Handlers are checked in reverse-registration order (last registered = highest priority).
  The built-in handler is always present and handles the standard return values
  (`{:ok, state}`, `{:noreply, state}`, `{:show_modal, ...}`, `{:show_toast, ...}`,
  `{:push, ...}`, `{:pop, ...}`, `{:replace, ...}`).

  Registering your own handler lets you intercept custom action tuples returned from
  `handle_event/3` without modifying any framework code.

  ## Usage

      Drafter.ActionRegistry.register(MyApp.DrawerHandler)

  ## Priority

  Registered handlers take priority over the built-in handler. A handler that returns
  `{:ok, new_state}` stops dispatch; one that returns `:unhandled` passes control to
  the next handler in the chain.
  """

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
