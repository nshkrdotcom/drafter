defmodule Drafter.Test.FrameworkTest do
  use ExUnit.Case
  import Drafter.Test

  defmodule CounterApp do
    use Drafter.App
    import Drafter.App

    def mount(_props) do
      %{count: 0}
    end

    def render(state) do
      vertical([
        label("Count: #{state.count}", id: :count_label),
        button("Increment", id: :inc_btn, on_click: :increment),
        button("Decrement", id: :dec_btn, on_click: :decrement)
      ])
    end

    def handle_event(:increment, _data, state) do
      {:ok, %{state | count: state.count + 1}}
    end

    def handle_event(:decrement, _data, state) do
      {:ok, %{state | count: state.count - 1}}
    end

    def handle_event(_event, _data, state) do
      {:noreply, state}
    end
  end

  test "can start and stop app in headless mode" do
    ctx = Drafter.Test.start_headless(CounterApp)
    assert ctx.app_pid != nil
    assert Process.alive?(ctx.app_pid)

    :ok = Drafter.Test.stop(ctx)
    refute Process.alive?(ctx.app_pid)
  end

  test "can get app state" do
    ctx = Drafter.Test.start_headless(CounterApp)

    state = Drafter.Test.get_state(ctx)
    assert state.count == 0

    Drafter.Test.stop(ctx)
  end

  test "can send keyboard events" do
    ctx = Drafter.Test.start_headless(CounterApp)

    Drafter.Test.send_key(ctx, :enter)
    Drafter.Test.await_render(ctx)

    state = Drafter.Test.get_state(ctx)
    assert state.count > 0

    Drafter.Test.stop(ctx)
  end

  test "can query widgets" do
    ctx = Drafter.Test.start_headless(CounterApp)

    label_id = Drafter.Test.query_one(ctx, "label#count_label")
    assert label_id == :count_label

    buttons = Drafter.Test.query_all(ctx, "button")
    assert length(buttons) == 2

    Drafter.Test.stop(ctx)
  end

  test "can use assert macros" do
    ctx = Drafter.Test.start_headless(CounterApp)

    Drafter.Test.assert_widget_present(ctx, "button#inc_btn")
    Drafter.Test.refute_widget_present(ctx, "button#nonexistent")

    Drafter.Test.stop(ctx)
  end
end
