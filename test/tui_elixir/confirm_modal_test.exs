defmodule Drafter.ConfirmModalTest do
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

    case ScreenManager.get_all_screens() do
      [] -> :ok
      screens -> Enum.each(screens, fn _ -> ScreenManager.pop(:setup_cleanup) end)
    end

    :ok
  end

  describe "Confirm modal button interactions" do
    test "confirm modal creates two buttons" do
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

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      assert length(button_widgets) == 2
    end

    test "both buttons have on_click callbacks" do
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

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      Enum.each(button_widgets, fn {button_id, widget_info} ->
        button_state = WidgetHierarchy.get_widget_state(hierarchy, button_id)
        assert button_state.on_click != nil
        assert is_function(button_state.on_click)
      end)
    end

    test "pressing Space on first button returns :confirm callback" do
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

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      [{first_button_id, _}, {second_button_id, _}] = button_widgets

      first_focused = WidgetHierarchy.focus_widget(hierarchy, first_button_id)
      {_hierarchy, actions} = WidgetHierarchy.handle_event(first_focused, {:key, :" "})

      assert [{:app_callback, :confirm, nil}] = actions
    end

    test "pressing Space on second button returns :cancel callback" do
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

      button_widgets = Enum.filter(hierarchy.widgets, fn {_id, widget_info} ->
        widget_info.module == Drafter.Widget.Button
      end)

      [{first_button_id, _}, {second_button_id, _}] = button_widgets

      second_focused = WidgetHierarchy.focus_widget(hierarchy, second_button_id)
      {_hierarchy, actions} = WidgetHierarchy.handle_event(second_focused, {:key, :" "})

      assert [{:app_callback, :cancel, nil}] = actions
    end
  end
end
