defmodule Drafter.ActionHandler do
  @moduledoc """
  Behaviour for handling application action return values.

  Implement this behaviour to intercept action tuples returned from `handle_event/3`
  and translate them into state changes. Handlers are registered globally and checked
  in registration order, stopping at the first that returns `{:ok, new_state}`.

  ## Example

      defmodule MyApp.DrawerHandler do
        @behaviour Drafter.ActionHandler

        @impl true
        def handle_action({:open_drawer, id}, acc_state) do
          {:ok, %{acc_state | open_drawer: id}}
        end

        def handle_action(_action, _acc_state), do: :unhandled
      end

  Register before calling `Drafter.run/2`:

      Drafter.ActionRegistry.register(MyApp.DrawerHandler)
      Drafter.run(MyApp)

  Return `{:add_event, message, :info}` from any `handle_event/3` clause and the
  registered handler will receive it automatically.
  """

  @type action :: term()
  @type app_state :: map()
  @type result :: {:ok, app_state()} | :unhandled

  @callback handle_action(action(), app_state()) :: result()
end
