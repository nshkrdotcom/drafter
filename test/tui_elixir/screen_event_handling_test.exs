defmodule Drafter.ScreenEventHandlingTest do
  use ExUnit.Case, async: false
  alias Drafter.{ScreenManager, Screen}

  @moduletag :capture_log

  setup do
    unless Process.whereis(Drafter.EventHandler) do
      {:ok, _pid} = Drafter.EventHandler.start_link([])
    end

    unless Process.whereis(Drafter.ScreenManager) do
      {:ok, _pid} = Drafter.ScreenManager.start_link([])
    end

    ScreenManager.register_app(self())

    on_exit(fn ->
      case ScreenManager.get_all_screens() do
        [] -> :ok
        screens -> Enum.each(screens, fn _ -> ScreenManager.pop(:cleanup) end)
      end
    end)

    :ok
  end

  describe "screen event handling with app_callback actions" do
    test "handle_event with 3 arity for app_callback" do
      ScreenManager.push(Drafter.EventTestScreen, %{})

      [screen] = ScreenManager.get_all_screens()

      result = Screen.handle_screen_event(screen, :show_modal)
      assert result == {:show_modal, Drafter.EventTestScreen.InfoModal, %{}, []}
    end

    test "handle_event forwards data correctly" do
      ScreenManager.push(Drafter.EventTestScreen, %{})

      [screen] = ScreenManager.get_all_screens()

      result = Screen.handle_screen_event(screen, :custom_event)
      assert {:ok, updated_screen} = result
      assert updated_screen.state.custom_data == true
    end
  end

  describe "action return values" do
    test "show_modal action is returned correctly" do
      ScreenManager.push(Drafter.EventTestScreen, %{})

      [screen] = ScreenManager.get_all_screens()

      result = screen.module.handle_event(:show_modal, nil, screen.state)
      assert result == {:show_modal, Drafter.EventTestScreen.InfoModal, %{}, []}
    end

    test "show_toast action is returned correctly" do
      ScreenManager.push(Drafter.EventTestScreen, %{})

      [screen] = ScreenManager.get_all_screens()

      result = screen.module.handle_event(:show_toast, nil, screen.state)
      assert result == {:show_toast, "Test toast", [variant: :info]}
    end

    test "pop action is returned correctly" do
      ScreenManager.push(Drafter.EventTestScreen, %{})

      [screen] = ScreenManager.get_all_screens()

      result = screen.module.handle_event(:close, nil, screen.state)
      assert result == {:pop, :closed}
    end
  end

  describe "screen state updates" do
    test "handle_event returns updated state" do
      ScreenManager.push(Drafter.EventTestScreen, %{counter: 0})

      [screen] = ScreenManager.get_all_screens()
      assert screen.state.counter == 0

      result = Screen.handle_screen_event(screen, :increment)
      assert {:ok, updated_screen} = result
      assert updated_screen.state.counter == 1
    end
  end
end

defmodule Drafter.EventTestScreen do
  use Drafter.Screen

  def mount(props) do
    Map.put(props, :mounted, true)
  end

  def render(state) do
    []
  end

  def handle_event(:show_modal, _data, state) do
    {:show_modal, Drafter.EventTestScreen.InfoModal, %{}, []}
  end

  def handle_event(:show_toast, _data, state) do
    {:show_toast, "Test toast", [variant: :info]}
  end

  def handle_event(:close, _data, state) do
    {:pop, :closed}
  end

  def handle_event(:increment, _data, state) do
    counter = Map.get(state, :counter, 0) + 1
    {:ok, Map.put(state, :counter, counter)}
  end

  def handle_event(:custom_event, _data, state) do
    {:ok, Map.put(state, :custom_data, true)}
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  def unmount(_state), do: :ok
end

defmodule Drafter.EventTestScreen.InfoModal do
  use Drafter.Screen

  def mount(props), do: props

  def render(_state), do: []

  def handle_event(_event, state), do: {:noreply, state}

  def unmount(_state), do: :ok
end
