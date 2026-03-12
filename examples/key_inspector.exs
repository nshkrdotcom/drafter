Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])

defmodule KeyInspector do
  use Drafter.App
  import Drafter.App

  @max_events 30

  def mount(_props), do: %{events: []}

  keybinding {:q, [:ctrl]}, "quit" do
    {:stop, :normal}
  end

  def render(state) do
    vertical([
      header("Key Inspector"),
      scrollable(
        [
          label("Press any key or use the mouse. Events appear below.", style: %{fg: :bright_black}),
          label(""),
          vertical(
            Enum.map(state.events, fn {tag, desc, raw} ->
              horizontal([
                label(tag, style: %{fg: tag_color(tag), bold: true}, width: 14),
                label(desc, style: %{fg: :white}),
                label("  #{raw}", style: %{fg: :bright_black})
              ])
            end)
          )
        ],
        flex: 1
      ),
      footer()
    ])
  end

  def handle_event({:key, key, modifiers}, state) do
    mod_str = modifiers |> Enum.map_join("+", &Atom.to_string/1)
    desc = "#{mod_str}+#{inspect(key)}"
    {:ok, add_event(state, "KEY+MOD", desc, inspect({:key, key, modifiers}))}
  end

  def handle_event({:key, key}, state) do
    {:ok, add_event(state, "KEY", inspect(key), inspect({:key, key}))}
  end

  def handle_event({:mouse, %{type: :click, button: btn, x: x, y: y}}, state) do
    {:ok, add_event(state, "CLICK", "button=#{btn} x=#{x} y=#{y}", "")}
  end

  def handle_event({:mouse, %{type: :scroll, direction: dir, x: x, y: y}}, state) do
    {:ok, add_event(state, "SCROLL", "#{dir} x=#{x} y=#{y}", "")}
  end

  def handle_event({:mouse, %{type: :move, x: x, y: y}}, state) do
    {:ok, add_event(state, "MOVE", "x=#{x} y=#{y}", "")}
  end

  def handle_event({:mouse, data}, state) do
    {:ok, add_event(state, "MOUSE", inspect(data.type), inspect(data))}
  end

  def handle_event({:resize, {w, h}}, state) do
    {:ok, add_event(state, "RESIZE", "#{w}×#{h}", "")}
  end

#  def handle_event({:key, :q}, state), do: {:stop, :normal}

  def handle_event(event, state) do
    {:ok, add_event(state, "OTHER", inspect(event), "")}
  end

  defp add_event(state, tag, desc, raw) do
    entry = {tag, desc, raw}
    events = [entry | state.events] |> Enum.take(@max_events)
    %{state | events: events}
  end

  defp tag_color("KEY+MOD"), do: :magenta
  defp tag_color("KEY"),     do: :cyan
  defp tag_color("CLICK"),   do: :green
  defp tag_color("SCROLL"),  do: :yellow
  defp tag_color("MOVE"),    do: :bright_black
  defp tag_color("RESIZE"),  do: :blue
  defp tag_color(_),         do: :white
end

Drafter.run(KeyInspector)
