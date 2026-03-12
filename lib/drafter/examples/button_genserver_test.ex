defmodule Drafter.Examples.ButtonGenserverTest do

  alias Drafter.{WidgetManager, Compositor, ThemeManager, LayerCompositor}
  alias Drafter.Widget.Button
  alias Drafter.Terminal.Driver
  alias Drafter.Draw.{Segment, Strip}

  def run do
    with {:ok, _} <- Drafter.Event.Manager.start_link(),
         {:ok, _} <- Driver.start_link(),
         {:ok, _} <- Compositor.start_link(),
         {:ok, _} <- ThemeManager.start_link(),
         :ok <- Driver.setup() do
      app_pid = self()
      {:ok, manager} = WidgetManager.start_link(app_pid: app_pid)

      {width, height} = Compositor.get_screen_size()

      button_width = div(width, 3)

      WidgetManager.add_widget(
        manager,
        :btn1,
        Button,
        %{
          text: "Primary",
          button_type: :primary,
          on_click: fn -> send(app_pid, {:clicked, :btn1}) end
        },
        %{x: 0, y: 2, width: button_width, height: 3}
      )

      WidgetManager.add_widget(
        manager,
        :btn2,
        Button,
        %{
          text: "Success",
          button_type: :success,
          on_click: fn -> send(app_pid, {:clicked, :btn2}) end
        },
        %{x: button_width, y: 2, width: button_width, height: 3}
      )

      WidgetManager.add_widget(
        manager,
        :btn3,
        Button,
        %{
          text: "Warning",
          button_type: :warning,
          on_click: fn -> send(app_pid, {:clicked, :btn3}) end
        },
        %{x: button_width * 2, y: 2, width: button_width, height: 3}
      )

      Drafter.Event.Manager.subscribe(self())

      render(manager, width, height, "Press Ctrl+D to quit. Click buttons!")

      event_loop(manager, width, height)

      WidgetManager.clear(manager)
      Driver.cleanup()
    end
  end

  defp event_loop(manager, width, height) do
    receive do
      {:tui_event, {:key, :d, [:ctrl]}} ->
        :ok

      {:tui_event, {:key, :q, [:ctrl]}} ->
        :ok

      {:tui_event, {:mouse, mouse_event}} ->
        WidgetManager.handle_mouse_event(manager, mouse_event)
        render(manager, width, height, "Mouse: #{inspect(mouse_event.type)}")
        event_loop(manager, width, height)

      {:tui_event, {:resize, {new_width, new_height}}} ->
        render(manager, new_width, new_height, "Resized")
        event_loop(manager, new_width, new_height)

      {:widget_render_needed, widget_id} ->
        render(manager, width, height, "Widget updated: #{widget_id}")
        event_loop(manager, width, height)

      {:widget_action, widget_id, action} ->
        render(manager, width, height, "Action from #{widget_id}: #{inspect(action)}")
        event_loop(manager, width, height)

      {:clicked, btn_id} ->
        render(manager, width, height, "Clicked: #{btn_id}")
        event_loop(manager, width, height)

      {:tui_event, _event} ->
        event_loop(manager, width, height)

      _other ->
        event_loop(manager, width, height)
    end
  end

  defp render(manager, width, height, status_text) do
    theme = ThemeManager.get_current_theme()

    bg_style = %{bg: theme.background, fg: theme.text_primary}
    bg_line = String.duplicate(" ", width)

    background_strips =
      for _ <- 0..(height - 1) do
        Strip.new([Segment.new(bg_line, bg_style)])
      end

    status_strip =
      Strip.new([
        Segment.new(
          " #{status_text}" <>
            String.duplicate(" ", max(0, width - String.length(status_text) - 1)),
          %{fg: theme.text_primary, bg: theme.background}
        )
      ])

    background_strips = List.replace_at(background_strips, 0, status_strip)

    renders = WidgetManager.render_all(manager)

    widget_layers =
      Enum.map(renders, fn {id, rect, strips} ->
        LayerCompositor.widget_layer(id, strips, rect)
      end)

    viewport = %{width: width, height: height}
    screen_rect = %{x: 0, y: 0, width: width, height: height}
    background_layer = LayerCompositor.background_layer(background_strips, screen_rect)

    layers = [background_layer | widget_layers]
    final_strips = LayerCompositor.composite(layers, viewport)

    Compositor.render_strips(final_strips, 0, 0)
  end
end
