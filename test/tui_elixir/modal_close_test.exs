defmodule Drafter.ModalCloseTest do
  use ExUnit.Case, async: false
  alias Drafter.{ScreenManager, ComponentRenderer, WidgetHierarchy, EventHandler}

  @moduletag :capture_log

  setup do
    unless Process.whereis(Drafter.EventHandler) do
      {:ok, _pid} = Drafter.EventHandler.start_link([])
    end

    unless Process.whereis(Drafter.ScreenManager) do
      {:ok, _pid} = Drafter.ScreenManager.start_link([])
    end

    ScreenManager.register_app(self())

    case ScreenManager.get_all_screens() do
      [] -> :ok
      screens -> Enum.each(screens, fn _ -> ScreenManager.pop(:setup_cleanup) end)
    end

    :ok
  end

  describe "full modal close flow" do
    test "modal close via space key press" do
      {:ok, screen_id} = ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.InfoModal,
        %{title: "Test Modal"},
        [title: "Test Modal", width: 50, height: 15]
      )

      [screen] = ScreenManager.get_all_screens()
      assert screen.id == screen_id
      assert length(ScreenManager.get_all_screens()) == 1

      render_result = screen.module.render(screen.state)

      screen_rect = %{x: 0, y: 0, width: 50, height: 15}
      theme = Drafter.Theme.dark_theme()

      hierarchy = ComponentRenderer.render_tree(
        render_result,
        screen_rect,
        theme,
        screen.state,
        nil
      )

      ScreenManager.update_screen_hierarchy(screen_id, hierarchy)
      ScreenManager.update_screen_rect(screen_id, screen_rect)

      [updated_screen] = ScreenManager.get_all_screens()
      assert updated_screen.widget_hierarchy != nil

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      assert length(button_widgets) > 0

      {button_id, _button_info} = hd(button_widgets)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      {_final_hierarchy, actions} = WidgetHierarchy.handle_event(focused_hierarchy, {:key, :" "})

      assert [{:app_callback, :close, nil}] = actions

      ScreenManager.update_screen_hierarchy(screen_id, focused_hierarchy)

      result = updated_screen.module.handle_event(:close, updated_screen.state)

      assert result == {:pop, :closed}

      {:ok, _pop_result} = ScreenManager.pop(:closed)

      screens_after = ScreenManager.get_all_screens()
      assert length(screens_after) == 0
    end

    test "modal close via mouse click" do
      {:ok, screen_id} = ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.InfoModal,
        %{title: "Test Modal"},
        [title: "Test Modal", width: 50, height: 15]
      )

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)

      screen_rect = %{x: 0, y: 0, width: 50, height: 15}
      theme = Drafter.Theme.dark_theme()

      hierarchy = ComponentRenderer.render_tree(
        render_result,
        screen_rect,
        theme,
        screen.state,
        nil
      )

      ScreenManager.update_screen_hierarchy(screen_id, hierarchy)
      ScreenManager.update_screen_rect(screen_id, screen_rect)

      [updated_screen] = ScreenManager.get_all_screens()

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      {button_id, button_info} = hd(button_widgets)
      button_rect = Map.get(updated_screen.widget_hierarchy.widget_rects, button_id)

      assert button_rect != nil

      mouse_x = div(button_rect.x + button_rect.width, 2)
      mouse_y = div(button_rect.y + button_rect.height, 2)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      {_final_hierarchy, actions} = WidgetHierarchy.handle_event(focused_hierarchy, {:mouse, %{type: :press, x: button_rect.x + 1, y: button_rect.y + 1}})

      assert [{:app_callback, :close, nil}] = actions
    end

    test "modal screen manager handles button press and closes" do
      {:ok, screen_id} = ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.InfoModal,
        %{title: "Test Modal"},
        [title: "Test Modal", width: 50, height: 15]
      )

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)

      screen_rect = %{x: 0, y: 0, width: 50, height: 15}
      theme = Drafter.Theme.dark_theme()

      hierarchy = ComponentRenderer.render_tree(
        render_result,
        screen_rect,
        theme,
        screen.state,
        nil
      )

      ScreenManager.update_screen_hierarchy(screen_id, hierarchy)
      ScreenManager.update_screen_rect(screen_id, screen_rect)

      [updated_screen] = ScreenManager.get_all_screens()

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      {button_id, _button_info} = hd(button_widgets)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      ScreenManager.update_screen_hierarchy(screen_id, focused_hierarchy)

      event = {:key, :" "}

      result = Drafter.EventHandler.dispatch_event_sync(event)

      assert result == :handled

      Process.sleep(100)

      screens_after = ScreenManager.get_all_screens()
      assert length(screens_after) == 0
    end
  end
end
