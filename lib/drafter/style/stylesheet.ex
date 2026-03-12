defmodule Drafter.Style.Stylesheet do
  @moduledoc false

  alias Drafter.Style
  alias Drafter.Style.Selector

  @type rule :: {Selector.t() | [Selector.t()], Style.t()}

  @type t :: %__MODULE__{
          rules: [rule()]
        }

  defstruct rules: []

  def new(rules \\ []) do
    %__MODULE__{rules: normalize_rules(rules)}
  end

  def add_rule(%__MODULE__{} = stylesheet, selector, style) do
    parsed_selector = parse_selector(selector)
    rule = {parsed_selector, Style.new(style)}
    %{stylesheet | rules: stylesheet.rules ++ [rule]}
  end

  def add_rules(%__MODULE__{} = stylesheet, rules) when is_list(rules) do
    Enum.reduce(rules, stylesheet, fn {selector, style}, acc ->
      add_rule(acc, selector, style)
    end)
  end

  def add_rules(%__MODULE__{} = stylesheet, rules) when is_map(rules) do
    rules
    |> Enum.to_list()
    |> then(&add_rules(stylesheet, &1))
  end

  def merge(%__MODULE__{} = s1, %__MODULE__{} = s2) do
    %__MODULE__{rules: s1.rules ++ s2.rules}
  end

  def compute_style(%__MODULE__{} = stylesheet, context) do
    stylesheet.rules
    |> Enum.filter(fn {selectors, _style} -> matches_any?(selectors, context) end)
    |> Enum.sort_by(fn {selectors, _style} -> max_specificity(selectors) end)
    |> Enum.map(fn {_selectors, style} -> style end)
    |> Style.merge()
  end

  def compute_style_for_part(%__MODULE__{} = stylesheet, context, part) do
    part_context = Map.put(context, :part, part)
    compute_style(stylesheet, part_context)
  end

  defp normalize_rules(rules) when is_list(rules) do
    Enum.map(rules, fn
      {selector, style} -> {parse_selector(selector), Style.new(style)}
      other -> other
    end)
  end

  defp normalize_rules(rules) when is_map(rules) do
    rules
    |> Enum.map(fn {selector, style} -> {parse_selector(selector), Style.new(style)} end)
  end

  defp parse_selector(selector) when is_binary(selector), do: Selector.parse(selector)
  defp parse_selector(selector) when is_atom(selector), do: Selector.parse(selector)
  defp parse_selector(%Selector{} = selector), do: [selector]
  defp parse_selector(selectors) when is_list(selectors), do: selectors

  defp matches_any?(selectors, context) when is_list(selectors) do
    Enum.any?(selectors, &Selector.matches?(&1, context))
  end

  defp matches_any?(selector, context) do
    Selector.matches?(selector, context)
  end

  defp max_specificity(selectors) when is_list(selectors) do
    selectors
    |> Enum.map(&Selector.specificity/1)
    |> Enum.max()
  end

  defp max_specificity(selector) do
    Selector.specificity(selector)
  end
end
