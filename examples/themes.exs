Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])

defmodule Themes do
  use Drafter.App
  import Drafter.App

  def mount(_props) do
    themes = Drafter.Theme.available_themes() |> Map.keys()
    %{current_theme: "textual-dark", available_themes: themes}
  end

  def keybindings, do: [{"q", "quit"}, {"tab", "next"}, {"enter", "select"}]

  def render(state) do
    vertical([
      header("Theme Switcher"),
      scrollable(
        [
          label(""),
          label("Select a theme:", style: %{fg: {100, 150, 255}, bold: true}),
          label(""),
          render_theme_switches(state.available_themes, state.current_theme)
        ],
        flex: 1
      ),
      footer()
    ])
  end

  def handle_event({:theme_changed, theme_name}, enabled, state) do
    if enabled and state.current_theme != theme_name do
      Drafter.ThemeManager.set_theme(theme_name)
      {:ok, %{state | current_theme: theme_name}}
    else
      {:noreply, state}
    end
  end

  def handle_event(_widget_event, _data, state), do: {:noreply, state}

  def handle_event({:key, :q}, _state), do: {:stop, :normal}
  def handle_event(_event, state), do: {:noreply, state}

  defp render_theme_switches(themes, current_theme) do
    {left_col, right_col} = Enum.split(themes, div(length(themes) + 1, 2))

    horizontal(
      [
        vertical(
          Enum.map(left_col, fn name ->
            switch(
              label: name,
              enabled: current_theme == name,
              on_change: {:theme_changed, name},
              size: :compact
            )
          end),
          width: 30
        ),
        vertical(
          Enum.map(right_col, fn name ->
            switch(
              label: name,
              enabled: current_theme == name,
              on_change: {:theme_changed, name},
              size: :compact
            )
          end),
          width: 30
        )
      ],
      gap: 2
    )
  end
end

Drafter.run(Themes)
