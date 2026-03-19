defmodule Drafter.Examples.CalculatorTest do
  use ExUnit.Case, async: true

  alias Drafter.Examples.Calculator

  setup do
    if pid = Process.whereis(:tui_app_loop) do
      Process.unregister(:tui_app_loop)
      on_exit(fn -> Process.register(pid, :tui_app_loop) end)
    end

    Process.register(self(), :tui_app_loop)

    on_exit(fn ->
      if Process.whereis(:tui_app_loop) == self() do
        Process.unregister(:tui_app_loop)
      end
    end)

    :ok
  end

  test "keyboard digits update state once without widget activation side effects" do
    state = Calculator.mount(%{})

    assert {:ok, %{value: 1, entering: true}} = Calculator.handle_event({:key, :"1"}, state)
    refute_received {:activate_widget, :btn_1}
  end

  test "keyboard operators apply once without widget activation side effects" do
    state = %{value: 12, left: 0, op: nil, entering: true}

    assert {:ok, %{value: 12, left: 12, op: :+, entering: false}} =
             Calculator.handle_event({:key, :+}, state)

    refute_received {:activate_widget, :btn_plus}
  end
end
