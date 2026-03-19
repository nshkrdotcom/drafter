Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])

defmodule GaugeDemo do
  use Drafter.App
  import Drafter.App

  @step 0.004
  @min_distance 0.10

  def keybindings, do: [{"q", "quit"}]

  def mount(_props) do
    %{
      animated_value: 0.20,
      target: random_target(0.20, :up),
      direction: :up
    }
  end

  def on_ready(state) do
    send(self(), {:set_interval, 16, :tick})
    state
  end

  def on_timer(:tick, state) do
    step = if state.direction == :up, do: @step, else: -@step
    new_value = clamp(Float.round(state.animated_value + step, 4))

    reached =
      (state.direction == :up and new_value >= state.target) or
        (state.direction == :down and new_value <= state.target)

    if reached do
      new_dir = if state.direction == :up, do: :down, else: :up
      new_target = random_target(new_value, new_dir)
      %{state | animated_value: new_value, target: new_target, direction: new_dir}
    else
      %{state | animated_value: new_value}
    end
  end

  def on_timer(_id, state), do: state

  def render(state) do
    vertical([
      header("GAUGE DEMO"),
      horizontal(
        [
          gauge(value: 0.20, label: "CPU Busy", flex: 1),
          gauge(value: 0.30, label: "RAM Used", flex: 1),
          gauge(value: 0.88, label: "Root FS", flex: 1),
          gauge(value: state.animated_value, label: "Sys Load", flex: 1)
        ],
        gap: 2,
        flex: 1
      )
    ])
  end

  defp clamp(v), do: v |> max(0.0) |> min(1.0)

  defp random_target(current, :up) do
    min_t = min(1.0, current + @min_distance)
    min_t + :rand.uniform() * (1.0 - min_t)
  end

  defp random_target(current, :down) do
    max_t = max(0.0, current - @min_distance)
    :rand.uniform() * max_t
  end
end

Drafter.run(GaugeDemo)
