defmodule Skooma do
  require Logger
  alias Skooma.Basic

  def valid?(data, schema, path \\ []) do
    results =
      cond do
        is_atom(schema) ->
          valid?(data, [schema], path)

        is_tuple(schema) ->
          validate_tuple(data, schema, path)

        Keyword.keyword?(schema) ->
          validate_keyword(data, schema, path)

        is_map(schema) ->
          Skooma.Map.validate_map(data, schema, path)

        Enum.member?(schema, :list) ->
          validate_list(data, schema, path)

        Enum.member?(schema, :not_required) ->
          handle_not_required(data, schema, path)

        Enum.member?(schema, :map) ->
          Skooma.Map.nested_map(data, schema, path)

        Enum.member?(schema, :union) ->
          union_handler(data, schema, path)

        Enum.member?(schema, :string) ->
          Basic.validator(&is_binary/1, "STRING", data, schema, path)

        Enum.member?(schema, :int) ->
          Basic.validator(&is_integer/1, "INTEGER", data, schema, path)

        Enum.member?(schema, :float) ->
          Basic.validator(&is_float/1, "FLOAT", data, schema, path)

        Enum.member?(schema, :number) ->
          Basic.validator(&is_number/1, "NUMBER", data, schema, path)

        Enum.member?(schema, :bool) ->
          Basic.validator(&is_boolean/1, "BOOLEAN", data, schema, path)

        Enum.member?(schema, :atom) ->
          atom_handler(data, schema, path)

        Enum.member?(schema, :any) ->
          :ok

        true ->
          {:error, {path, "Your data is all jacked up"}}
      end

    handle_results(results)
  end

  defp handle_results(:ok), do: :ok
  defp handle_results({:error, error}), do: {:error, [error]}

  defp handle_results(results) do
    case results |> Enum.reject(&(&1 == :ok)) do
      [] ->
        :ok

      errors ->
        errors
        |> List.flatten()
        |> Enum.map(fn {:error, error} -> {:error, List.flatten([error])} end)
        |> Enum.map(fn {:error, error} -> error end)
        |> List.flatten()
        |> (fn n -> {:error, n} end).()
    end
  end

  defp atom_handler(data, schema, path) do
    Basic.validator(
      fn value -> is_atom(value) and not is_nil(value) end,
      "ATOM",
      data,
      schema,
      path
    )
  end

  defp union_handler(data, schema, path) do
    schemas = Enum.find(schema, &is_list/1)
    results = Enum.map(schemas, &valid?(data, &1, path))

    if Enum.any?(results, &(&1 == :ok)) do
      :ok
    else
      results
    end
  end

  defp handle_not_required(data, schema, path) do
    if data == nil do
      :ok
    else
      valid?(data, Enum.reject(schema, &(&1 == :not_required)), path)
    end
  end

  defp validate_keyword(data, schema, path) do
    if Keyword.keys(data) |> length == Keyword.keys(schema) |> length do
      Enum.map(data, fn {k, v} -> valid?(v, schema[k], path ++ [k]) end)
      |> Enum.reject(&(&1 == :ok))
    else
      {:error, {path, "missing some keys"}}
    end
  end

  defp validate_list(data, schema, path) do
    cond do
      is_list(data) ->
        list_schema =
          case Enum.reject(schema, &(&1 == :list)) do
            [[:list | _] = nested_list_schema | _] -> nested_list_schema
            [[:union | _] = union_list_schema | _] -> union_list_schema
            list_schema -> list_schema
          end

        data
        |> Enum.with_index()
        |> Enum.map(fn {v, k} -> valid?(v, list_schema, path ++ [k]) end)

      is_list(schema) and :not_required in schema and data == nil ->
        :ok

      true ->
        {:error, {path, "expected list"}}
    end
  end

  defp validate_tuple(data, schema, path) do
    data_list = Tuple.to_list(data)
    schema_list = Tuple.to_list(schema)

    if Enum.count(data_list) == Enum.count(schema_list) do
      Enum.zip(data_list, schema_list)
      |> Enum.with_index()
      |> Enum.map(fn {v, k} -> valid?(elem(v, 0), elem(v, 1), path ++ [k]) end)
      # |> Enum.map(&(valid?(elem(&1, 0), elem(&1, 1))))
      |> Enum.reject(&(&1 == :ok))
    else
      {:error, {path, "tuple schema doesn't match tuple length"}}
    end
  end
end
