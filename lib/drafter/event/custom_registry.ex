defmodule Drafter.Event.CustomRegistry do
  @moduledoc """
  Agent-backed registry for defining and validating application-specific event types.

  Register a custom event type with a schema using `register_event_type/2`. A schema
  map may include a `:required` list of field keys and a `:types` map of
  `field_key => type_atom` pairs. Supported type atoms: `:string`, `:integer`,
  `:float`, `:boolean`, `:atom`, `:list`, `:map`, `{:list, inner_type}`, `:any`.

  Call `validate_event/2` before dispatching a custom event to verify required
  fields are present and values match their declared types.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def register_event_type(type, schema) when is_atom(type) do
    Agent.update(__MODULE__, fn registry ->
      Map.put(registry, type, schema)
    end)
  end

  def get_event_schema(type) do
    Agent.get(__MODULE__, fn registry ->
      Map.get(registry, type)
    end)
  end

  def validate_event(type, data) do
    case get_event_schema(type) do
      nil -> {:ok, data}
      schema -> apply_schema(schema, data)
    end
  end

  defp apply_schema(%{required: required} = schema, data) when is_map(data) do
    missing = Enum.filter(required, fn key -> not Map.has_key?(data, key) end)

    if missing == [] do
      validate_types(schema, data)
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp apply_schema(_schema, data), do: {:ok, data}

  defp validate_types(%{types: types}, data) when is_map(types) do
    invalid = Enum.filter(types, fn {key, expected_type} ->
      case Map.get(data, key) do
        nil -> false
        value -> not matches_type?(value, expected_type)
      end
    end)

    if invalid == [] do
      {:ok, data}
    else
      {:error, {:type_mismatch, invalid}}
    end
  end

  defp validate_types(_schema, data), do: {:ok, data}

  defp matches_type?(value, :string), do: is_binary(value)
  defp matches_type?(value, :integer), do: is_integer(value)
  defp matches_type?(value, :float), do: is_float(value)
  defp matches_type?(value, :boolean), do: is_boolean(value)
  defp matches_type?(value, :atom), do: is_atom(value)
  defp matches_type?(value, :list), do: is_list(value)
  defp matches_type?(value, :map), do: is_map(value)
  defp matches_type?(_value, :any), do: true
  defp matches_type?(value, {:list, inner_type}) do
    is_list(value) and Enum.all?(value, &matches_type?(&1, inner_type))
  end
  defp matches_type?(_value, _type), do: false
end
