Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])
require Logger
Logger.configure(level: :error)

defmodule CustomLoopExample do
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
      btn_width = div(width, 3)

      WidgetManager.add_widget(manager, :btn_a, Button, %{
        text: "Button A",
        button_type: :primary,
        on_click: fn -> send(app_pid, {:clicked, :btn_a}) end
      }, %{x: 0, y: 3, width: btn_width, height: 3})

      WidgetManager.add_widget(manager, :btn_b, Button, %{
        text: "Button B",
        button_type: :success,
        on_click: fn -> send(app_pid, {:clicked, :btn_b}) end
      }, %{x: btn_width, y: 3, width: btn_width, height: 3})

      WidgetManager.add_widget(manager, :btn_c, Button, %{
        text: "Button C",
        button_type: :warning,
        on_click: fn -> send(app_pid, {:clicked, :btn_c}) end
      }, %{x: btn_width * 2, y: 3, width: btn_width, height: 3})

      Drafter.Event.Manager.subscribe(self())

      render(manager, width, height, "Custom event loop — Ctrl+D to quit, click buttons")
      loop(manager, width, height)

      WidgetManager.clear(manager)
      Driver.cleanup()
    end
  end

  defp loop(manager, width, height) do
    receive do
      {:tui_event, {:key, :d, [:ctrl]}} -> :ok
      {:tui_event, {:key, :q, [:ctrl]}} -> :ok

      {:tui_event, {:mouse, mouse_event}} ->
        WidgetManager.handle_mouse_event(manager, mouse_event)
        render(manager, width, height, "Mouse: #{mouse_event.type}")
        loop(manager, width, height)

      {:tui_event, {:resize, {w, h}}} ->
        render(manager, w, h, "Resized to #{w}x#{h}")
        loop(manager, w, h)

      {:widget_render_needed, _widget_id} ->
        render(manager, width, height, "Widget updated")
        loop(manager, width, height)

      {:clicked, btn_id} ->
        render(manager, width, height, "Clicked: #{btn_id}")
        loop(manager, width, height)

      _ ->
        loop(manager, width, height)
    end
  end

  defp render(manager, width, height, status) do
    theme = ThemeManager.get_current_theme()
    bg_style = %{bg: theme.background, fg: theme.text_primary}
    blank = Strip.new([Segment.new(String.duplicate(" ", width), bg_style)])

    background =
      for _ <- 0..(height - 1), do: blank

    status_strip =
      Strip.new([
        Segment.new(
          " #{status}" <> String.duplicate(" ", max(0, width - String.length(status) - 1)),
          %{fg: theme.text_primary, bg: theme.surface}
        )
      ])

    background = List.replace_at(background, 0, status_strip)
    screen_rect = %{x: 0, y: 0, width: width, height: height}

    widget_layers =
      Enum.map(WidgetManager.render_all(manager), fn {id, rect, strips} ->
        LayerCompositor.widget_layer(id, strips, rect)
      end)

    layers = [LayerCompositor.background_layer(background, screen_rect) | widget_layers]
    Compositor.render_strips(LayerCompositor.composite(layers, %{width: width, height: height}), 0, 0)
  end
end

CustomLoopExample.run()
