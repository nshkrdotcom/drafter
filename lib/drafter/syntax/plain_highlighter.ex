defmodule Drafter.Syntax.PlainHighlighter do
  @moduledoc false

  @behaviour Drafter.Syntax.Highlighter

  @impl true
  @spec highlight(String.t(), atom()) :: []
  def highlight(_source, _language), do: []
end
