Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])

defmodule CodeBrowser do
  use Drafter.App
  import Drafter.App

  def mount(_props) do
    %{
      root: File.cwd!(),
      selected_path: nil
    }
  end

  def keybindings do
    [{"^Q", "quit"}, {"↑↓/Enter", "navigate"}, {"Tab", "switch pane"}]
  end

  def render(state) do
    vertical([
      header("Code Browser — #{state.root}"),
      horizontal(
        [
          directory_tree(
            id: :tree,
            path: state.root,
            on_file_select: :file_selected,
            width: 30,
            flex: 0
          ),
          code_view(
            id: :preview,
            path: state.selected_path,
            source: "",
            show_line_numbers: true,
            flex: 1
          )
        ],
        flex: 1
      ),
      footer()
    ])
  end

  def handle_event(:file_selected, path, state) do
    {:ok, %{state | selected_path: path}}
  end

  def handle_event({:key, :q, [:ctrl]}, _state), do: {:stop, :normal}
  def handle_event(_event, state), do: {:noreply, state}
end

Drafter.run(CodeBrowser, syntax_highlighting: true)
