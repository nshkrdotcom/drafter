defmodule Drafter.ModalEventFlowTest do
  use ExUnit.Case, async: false
  alias Drafter.{ScreenManager, Screen, WidgetHierarchy, Widget}

  @moduletag :capture_log

  setup do
    unless Process.whereis(Drafter.EventHandler) do
      {:ok, _pid} = Drafter.EventHandler.start_link([])
    end

    unless Process.whereis(Drafter.ScreenManager) do
      {:ok, _pid} = Drafter.ScreenManager.start_link([])
    end

    ScreenManager.register_app(self())

    # Clean up any existing screens before each test
    case ScreenManager.get_all_screens() do
      [] -> :ok
      screens -> Enum.each(screens, fn _ -> ScreenManager.pop(:setup_cleanup) end)
    end

    # Clean up any existing toasts
    toasts = ScreenManager.get_toasts()
    Enum.each(toasts, fn toast -> ScreenManager.dismiss_toast(toast.id) end)

    on_exit(fn ->
      case ScreenManager.get_all_screens() do
        [] -> :ok
        screens -> Enum.each(screens, fn _ -> ScreenManager.pop(:cleanup) end)
      end
    end)

    :ok
  end

  describe "modal screen widget hierarchy" do
    test "modal screen gets widget hierarchy after render" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      assert screen.id == screen_id
      assert screen.type == :modal
      assert screen.widget_hierarchy == nil

      render_result = screen.module.render(screen.state)
      assert is_tuple(render_result)

      hierarchy = Drafter.ComponentRenderer.render_tree(
        render_result,
        %{x: 0, y: 0, width: 50, height: 10},
        Drafter.Theme.dark_theme(),
        screen.state,
        nil
      )

      assert hierarchy != nil
      assert is_struct(hierarchy, WidgetHierarchy)
      assert map_size(hierarchy.widgets) > 0

      Drafter.ScreenManager.update_screen_hierarchy(screen_id, hierarchy)

      [updated_screen] = ScreenManager.get_all_screens()
      assert updated_screen.widget_hierarchy != nil
      assert updated_screen.widget_hierarchy.root != nil
    end

    test "modal can handle key events through widget hierarchy" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)
      hierarchy = Drafter.ComponentRenderer.render_tree(
        render_result,
        %{x: 0, y: 0, width: 50, height: 10},
        Drafter.Theme.dark_theme(),
        screen.state,
        nil
      )

      Drafter.ScreenManager.update_screen_hierarchy(screen_id, hierarchy)

      [screen_with_hierarchy] = ScreenManager.get_all_screens()

      assert screen_with_hierarchy.widget_hierarchy != nil

      {_hierarchy, actions} = WidgetHierarchy.handle_event(
        screen_with_hierarchy.widget_hierarchy,
        {:key, :tab}
      )

      assert is_list(actions)
    end

    test "button in modal returns app_callback action" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)
      hierarchy = Drafter.ComponentRenderer.render_tree(
        render_result,
        %{x: 0, y: 0, width: 50, height: 10},
        Drafter.Theme.dark_theme(),
        screen.state,
        nil
      )

      Drafter.ScreenManager.update_screen_hierarchy(screen_id, hierarchy)

      [screen_with_hierarchy] = ScreenManager.get_all_screens()

      focused_widget = screen_with_hierarchy.widget_hierarchy.focused_widget
      assert focused_widget != nil

      {_hierarchy, actions} = WidgetHierarchy.handle_event(
        screen_with_hierarchy.widget_hierarchy,
        {:key, :" "}
      )

      assert actions == [{:app_callback, :modal_button_clicked, nil}]
    end

    test "screen handles app_callback from button" do
      {:ok, _screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      result = screen.module.handle_event(:modal_button_clicked, nil, screen.state)

      assert result == {:pop, :button_clicked}
    end
  end

  describe "screen hierarchy rendering flow" do
    test "render_screens_from_manager creates hierarchies for all screens" do
      {:ok, _screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      screens = ScreenManager.get_all_screens()
      assert length(screens) == 1

      screen_rect = %{x: 0, y: 0, width: 80, height: 24}

      Enum.each(screens, fn screen ->
        render_result = screen.module.render(screen.state)

        hierarchy = case render_result do
          component_tree when is_tuple(component_tree) ->
            Drafter.ComponentRenderer.render_tree(
              component_tree,
              screen_rect,
              Drafter.Theme.dark_theme(),
              screen.state,
              nil
            )

          _ ->
            nil
        end

        if hierarchy do
          Drafter.ScreenManager.update_screen_hierarchy(screen.id, hierarchy)
        end
      end)

      [updated_screen] = ScreenManager.get_all_screens()
      assert updated_screen.widget_hierarchy != nil
      assert map_size(updated_screen.widget_hierarchy.widgets) > 0
    end
  end

  describe "event handler registration and hierarchy timing" do
    test "modal has no hierarchy when first pushed" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      assert screen.widget_hierarchy == nil
    end

    test "modal gets hierarchy after rendering" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)
      hierarchy = Drafter.ComponentRenderer.render_tree(
        render_result,
        %{x: 0, y: 0, width: 50, height: 10},
        Drafter.Theme.dark_theme(),
        screen.state,
        nil
      )

      Drafter.ScreenManager.update_screen_hierarchy(screen_id, hierarchy)

      [updated_screen] = ScreenManager.get_all_screens()
      assert updated_screen.widget_hierarchy != nil
    end

    test "modal render creates button widgets in hierarchy" do
      {:ok, screen_id} = ScreenManager.push(Drafter.ModalTestScreen, %{}, type: :modal)

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)

      require Logger
      Logger.error("Modal render result: #{inspect(render_result)}")

      hierarchy = Drafter.ComponentRenderer.render_tree(
        render_result,
        %{x: 0, y: 0, width: 50, height: 10},
        Drafter.Theme.dark_theme(),
        screen.state,
        nil
      )

      Logger.error("Modal hierarchy: #{inspect(hierarchy)}")
      Logger.error("Modal hierarchy widgets: #{inspect(hierarchy.widgets)}")

      assert hierarchy != nil
      assert map_size(hierarchy.widgets) > 0

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      Logger.error("Modal button widgets: #{inspect(button_widgets)}")
      assert length(button_widgets) > 0
    end
  end
end

defmodule Drafter.ModalTestScreen do
  use Drafter.Screen

  def mount(props), do: props

  def render(_state) do
    vertical([
      label("Test Modal"),
      button("Close", on_click: :modal_button_clicked)
    ])
  end

  def handle_event(:modal_button_clicked, _data, _state) do
    {:pop, :button_clicked}
  end

  def handle_event(_event, state), do: {:noreply, state}

  def unmount(_state), do: :ok
end
