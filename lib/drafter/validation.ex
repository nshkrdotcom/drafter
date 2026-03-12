defmodule Drafter.Validation do
  @moduledoc """
  Input validation framework for TUI widgets.

  Validators are either anonymous functions of arity 1, named atoms (`:required`,
  `:email`), or tuples with options (`{:min_length, 5}`, `{:max_length, 100, "Too long"}`,
  `{:pattern, ~r/.../}`, `{:range, 1, 10}`, `{:custom, fun}`).
  `validate/2` runs a list of validators and returns `:ok` or the first `{:error, message}`.
  """

  @type validation_result :: :ok | {:error, String.t()}
  @type validator :: (any() -> validation_result()) | atom() | {atom(), any()}

  @doc """
  Validate a value against a list of validators.
  Returns :ok if all validators pass, or the first error.
  """
  @spec validate(any(), [validator()]) :: validation_result()
  def validate(_value, []), do: :ok

  def validate(value, [validator | rest]) do
    case run_validator(value, validator) do
      :ok -> validate(value, rest)
      error -> error
    end
  end

  @doc """
  Run a single validator against a value.
  """
  @spec run_validator(any(), validator()) :: validation_result()
  def run_validator(value, validator) when is_function(validator, 1) do
    validator.(value)
  end

  def run_validator(value, :required) do
    required(value)
  end

  def run_validator(value, :email) do
    email(value)
  end

  def run_validator(value, {:required, message}) do
    required(value, message)
  end

  def run_validator(value, {:email, message}) do
    email(value, message)
  end

  def run_validator(value, {:min_length, min}) do
    min_length(value, min)
  end

  def run_validator(value, {:min_length, min, message}) do
    min_length(value, min, message)
  end

  def run_validator(value, {:max_length, max}) do
    max_length(value, max)
  end

  def run_validator(value, {:max_length, max, message}) do
    max_length(value, max, message)
  end

  def run_validator(value, {:pattern, pattern}) do
    pattern(value, pattern)
  end

  def run_validator(value, {:pattern, pattern, message}) do
    pattern(value, pattern, message)
  end

  def run_validator(value, {:range, min, max}) do
    range(value, min, max)
  end

  def run_validator(value, {:range, min, max, message}) do
    range(value, min, max, message)
  end

  def run_validator(value, {:custom, fun}) when is_function(fun, 1) do
    fun.(value)
  end

  @doc """
  Required validator - ensures value is not nil or empty.
  """
  @spec required(any()) :: validation_result()
  def required(value) do
    required(value, "This field is required")
  end

  @spec required(any(), String.t()) :: validation_result()
  def required(nil, message), do: {:error, message}
  def required("", message), do: {:error, message}
  def required([], message), do: {:error, message}
  def required(_value, _message), do: :ok

  @doc """
  Email validator - validates email format.
  """
  @spec email(any()) :: validation_result()
  def email(value) do
    email(value, "Invalid email address")
  end

  @spec email(any(), String.t()) :: validation_result()
  def email(value, message) when is_binary(value) do
    if String.match?(value, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      :ok
    else
      {:error, message}
    end
  end

  def email(_value, message), do: {:error, message}

  @doc """
  Minimum length validator.
  """
  @spec min_length(any(), non_neg_integer()) :: validation_result()
  def min_length(value, min) do
    min_length(value, min, "Must be at least #{min} characters")
  end

  @spec min_length(any(), non_neg_integer(), String.t()) :: validation_result()
  def min_length(value, min, message) when is_binary(value) do
    if String.length(value) >= min do
      :ok
    else
      {:error, message}
    end
  end

  def min_length(_value, _min, message), do: {:error, message}

  @doc """
  Maximum length validator.
  """
  @spec max_length(any(), non_neg_integer()) :: validation_result()
  def max_length(value, max) do
    max_length(value, max, "Must be at most #{max} characters")
  end

  @spec max_length(any(), non_neg_integer(), String.t()) :: validation_result()
  def max_length(value, max, message) when is_binary(value) do
    if String.length(value) <= max do
      :ok
    else
      {:error, message}
    end
  end

  def max_length(_value, _max, message), do: {:error, message}

  @doc """
  Pattern (regex) validator.
  """
  @spec pattern(any(), Regex.t() | String.t()) :: validation_result()
  def pattern(value, regex) do
    pattern(value, regex, "Invalid format")
  end

  @spec pattern(any(), Regex.t() | String.t(), String.t()) :: validation_result()
  def pattern(value, regex, message) when is_binary(value) and is_binary(regex) do
    pattern(value, Regex.compile!(regex), message)
  end

  def pattern(value, %Regex{} = regex, message) when is_binary(value) do
    if Regex.match?(regex, value) do
      :ok
    else
      {:error, message}
    end
  end

  def pattern(_value, _regex, message), do: {:error, message}

  @doc """
  Numeric range validator.
  """
  @spec range(any(), number(), number()) :: validation_result()
  def range(value, min, max) do
    range(value, min, max, "Must be between #{min} and #{max}")
  end

  @spec range(any(), number(), number(), String.t()) :: validation_result()
  def range(value, min, max, message) when is_number(value) do
    if value >= min and value <= max do
      :ok
    else
      {:error, message}
    end
  end

  def range(_value, _min, _max, message), do: {:error, message}

  @doc """
  Create a custom validator from a function.
  """
  @spec custom((any() -> validation_result())) :: validator()
  def custom(fun) when is_function(fun, 1) do
    {:custom, fun}
  end

  @doc """
  Combine multiple validators into one.
  """
  @spec combine([validator()]) :: validator()
  def combine(validators) when is_list(validators) do
    {:combined, validators}
  end
end
