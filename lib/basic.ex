defmodule Skooma.Basic do
  alias Skooma.Utils

  def validator(validator, type, data, schema, path \\ []) do
    data
    |> validator.()
    |> error(data, type, path)
    |> custom_validator(data, schema, path)
  end

  defp error(bool, data, expected_type, path) do
    data_type = Utils.typeof(data)

    if bool do
      :ok
    else
      cond do
        Enum.count(path) > 0 ->
          {:error, {path, "expected #{expected_type}, got #{data_type} #{inspect(data)}"}}

        true ->
          {:error, {path, "expected #{expected_type}, got #{data_type} #{inspect(data)}"}}
      end
    end
  end

  defp custom_validator(:ok, data, schema, path) do
    do_custom_validator(data, schema, path)
  end

  defp custom_validator(result, _, _, _), do: result

  defp do_custom_validator(data, schema, path) do
    validators = Enum.filter(schema, &is_function/1)

    if Enum.count(validators) == 0 do
      :ok
    else
      Enum.map(validators, fn validator ->
        case :erlang.fun_info(validator)[:arity] do
          0 -> validator.()
          1 -> validator.(data)
          2 -> validator.(data, path)
        end
      end)
      |> Enum.reject(&(&1 == :ok || &1 == true))
      |> Enum.map(fn
        false -> {:error, {path, "does not match custom validator"}}
        {:error, {_path, _error}} = result -> result
        {:error, error} -> {:error, {path, error}}
      end)
    end
  end
end
