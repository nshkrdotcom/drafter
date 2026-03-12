defmodule Drafter.IntegrationTest do
  use ExUnit.Case, async: false
  alias Drafter.{ScreenManager, ComponentRenderer, WidgetHierarchy}

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

  describe "full modal widget generation and interaction" do
    test "modal is pushed and mounted correctly" do
      {:ok, screen_id} = ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.InfoModal,
        %{title: "Test Modal"},
        [title: "Test Modal", width: 50, height: 15]
      )

      [screen] = ScreenManager.get_all_screens()

      assert screen.id == screen_id
      assert screen.type == :modal
      assert screen.module == Drafter.Examples.ScreenDemo.InfoModal
      assert screen.state != nil
      assert screen.state.title == "Test Modal"
    end

    test "modal render produces valid component tree" do
      ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.InfoModal,
        %{title: "Test Modal"},
        [title: "Test Modal", width: 50, height: 15]
      )

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)

      assert is_tuple(render_result)
      assert elem(render_result, 0) in [:layout, :vertical, :horizontal]
    end

    test "modal render creates widget hierarchy with buttons" do
      ScreenManager.show_modal(
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

      assert hierarchy != nil
      assert is_struct(hierarchy, WidgetHierarchy)
      assert map_size(hierarchy.widgets) > 0

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      assert length(button_widgets) > 0

      {button_id, _button_info} = hd(button_widgets)
      assert button_id != nil
    end

    test "modal button hierarchy is stored in screen" do
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

      [updated_screen] = ScreenManager.get_all_screens()

      assert updated_screen.widget_hierarchy != nil
      assert map_size(updated_screen.widget_hierarchy.widgets) > 0
    end

    test "modal button can be focused" do
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

      [updated_screen] = ScreenManager.get_all_screens()

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      assert length(button_widgets) > 0

      {button_id, _button_info} = hd(button_widgets)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      assert focused_hierarchy.focused_widget == button_id
    end

    test "modal button responds to space key press" do
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

      [updated_screen] = ScreenManager.get_all_screens()

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      {button_id, _button_info} = hd(button_widgets)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      {final_hierarchy, actions} = WidgetHierarchy.handle_event(focused_hierarchy, {:key, :" "})

      assert actions == [{:app_callback, :close, nil}]
    end

    test "modal close action pops the screen" do
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

      [updated_screen] = ScreenManager.get_all_screens()

      button_widgets = Enum.filter(updated_screen.widget_hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      {button_id, _button_info} = hd(button_widgets)

      focused_hierarchy = WidgetHierarchy.focus_widget(updated_screen.widget_hierarchy, button_id)

      {_final_hierarchy, actions} = WidgetHierarchy.handle_event(focused_hierarchy, {:key, :" "})

      assert [{:app_callback, :close, nil}] = actions

      result = updated_screen.module.handle_event(:close, updated_screen.state)

      assert result == {:pop, :closed}
    end

    test "confirm modal has two buttons" do
      ScreenManager.show_modal(
        Drafter.Examples.ScreenDemo.ConfirmModal,
        %{message: "Are you sure?"},
        [title: "Confirm", width: 45, height: 10]
      )

      [screen] = ScreenManager.get_all_screens()

      render_result = screen.module.render(screen.state)

      screen_rect = %{x: 0, y: 0, width: 45, height: 10}
      theme = Drafter.Theme.dark_theme()

      hierarchy = ComponentRenderer.render_tree(
        render_result,
        screen_rect,
        theme,
        screen.state,
        nil
      )

      assert hierarchy != nil

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      assert length(button_widgets) == 2
    end
  end
end
