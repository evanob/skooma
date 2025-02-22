defmodule Skooma.Map do
  alias Skooma.Utils
  require Logger

  def validate_map(data, schema, path) do
    with :ok <- is_map(data) |> Utils.to_result({path, "data is not a map"}),
         :ok <- key_handler(data, schema, path),
         :ok <- value_handler(data, schema, path),
         do: :ok
  end

  defp key_handler(data, schema, path) do
    schema
    |> Enum.map(&get_required_keys/1)
    |> Enum.reject(&is_nil/1)
    |> validate_keys(data, path)
  end

  defp get_required_keys({k, v}) do
    if is_atom(v) do
      k
    else
      if Enum.member?(v, :not_required), do: nil, else: k
    end
  end

  defp validate_keys(required_keys, data, path) do
    missing_keys = required_keys -- Map.keys(data)

    if Enum.count(missing_keys) == 0 do
      :ok
    else
      {:error, {path, "missing required keys: #{inspect(missing_keys)}"}}
    end
  end

  defp value_handler(data, schema, path) do
    results =
      Enum.map(data, &validate_child(&1, schema, path))
      |> Enum.filter(&(&1 != :ok))

    if Enum.count(results) == 0 do
      :ok
    else
      results
    end
  end

  defp validate_child({k, v}, schema, path) do
    if schema[k] |> is_nil do
      :ok
    else
      Skooma.valid?(v, schema[k], path ++ [k])
    end
  end

  def nested_map(data, parent_schema, path) do
    validators = Enum.filter(parent_schema, &is_function(&1, 1))

    errors =
      Enum.map(validators, & &1.(data))
      |> Enum.reject(&(&1 == :ok || &1 == true))
      |> Enum.map(fn
        false -> {:error, {path, "does not match custom validator"}}
        {:error, {_path, _error}} = result -> result
        {:error, error} -> {:error, {path, error}}
      end)

    if length(errors) > 0 do
      errors
    else
      schema = Enum.find(parent_schema, &is_function(&1, 0))
      clean_schema = if schema, do: schema.(), else: Enum.find(parent_schema, &is_map/1)
      Skooma.valid?(data, clean_schema, path)
    end
  end
end
