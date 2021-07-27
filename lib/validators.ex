defmodule Skooma.Validators do
  def min_length(min) do
    fn data, path ->
      bool = String.length(data) >= min

      if bool do
        :ok
      else
        {:error, {path, "must be longer than #{min} characters"}}
      end
    end
  end

  def max_length(max) do
    fn data, path ->
      bool = String.length(data) <= max

      if bool do
        :ok
      else
        {:error, {path, "must be shorter than #{max} characters"}}
      end
    end
  end

  def regex(regex) do
    fn data, path ->
      bool = Regex.match?(regex, data)

      if bool do
        :ok
      else
        {:error, {path, "does not match the regex pattern: #{inspect(regex)}"}}
      end
    end
  end

  def inclusion(values_list) when is_list(values_list) do
    fn data, path ->
      bool = data in values_list

      if bool do
        :ok
      else
        {:error, {path, "not included in the options: #{inspect(values_list)}"}}
      end
    end
  end

  def gt(value) do
    fn data, path ->
      bool = data > value

      if bool do
        :ok
      else
        {:error, {path, "has to be greater than #{value}"}}
      end
    end
  end

  def gte(value) do
    fn data, path ->
      bool = data >= value

      if bool do
        :ok
      else
        {:error, {path, "has to be greater or equal than #{value}"}}
      end
    end
  end

  def lt(value) do
    fn data, path ->
      bool = data < value

      if bool do
        :ok
      else
        {:error, {path, "has to be less than #{value}"}}
      end
    end
  end

  def lte(value) do
    fn data, path ->
      bool = data < value

      if bool do
        :ok
      else
        {:error, {path, "has to be less or equal than #{value}"}}
      end
    end
  end
end
