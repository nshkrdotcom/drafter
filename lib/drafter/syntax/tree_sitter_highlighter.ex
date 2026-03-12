defmodule Drafter.Syntax.TreeSitterHighlighter do
  @moduledoc """
  Highlighter implementation that delegates to the tree-sitter daemon.
  """

  @behaviour Drafter.Syntax.Highlighter

  alias Drafter.Syntax.TreeSitterDaemon

  @impl true
  @spec highlight(String.t(), atom()) :: [Drafter.Syntax.Highlighter.capture()]
  def highlight(source, language) do
    TreeSitterDaemon.highlight(source, language)
  end
end
