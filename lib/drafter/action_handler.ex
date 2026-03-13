defmodule Drafter.ActionHandler do
  @moduledoc false

  @type action :: term()
  @type app_state :: map()
  @type result :: {:ok, app_state()} | :unhandled

  @callback handle_action(action(), app_state()) :: result()
end
