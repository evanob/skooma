defmodule SkoomaErrorTest do
  use ExUnit.Case
  require Logger

  test "bool type error" do
    test_data = "abcdef"
    test_schema = [:bool]
    expected_results = {:error, [{[], "expected BOOLEAN, got STRING \"abcdef\""}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "string type errors" do
    test_data = 7
    test_schema = [:string]
    expected_results = {:error, [{[], "expected STRING, got INTEGER 7"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "int types errors" do
    test_data = false
    test_schema = [:int]
    expected_results = {:error, [{[], "expected INTEGER, got BOOLEAN false"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "float types errors" do
    test_data = 8
    test_schema = [:float]
    expected_results = {:error, [{[], "expected FLOAT, got INTEGER 8"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "number types errors" do
    test_data = "78"
    test_schema = [:number]
    expected_results = {:error, [{[], "expected NUMBER, got STRING \"78\""}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "atom types errors" do
    test_data = "key"
    test_schema = [:atom]
    expected_results = {:error, [{[], "expected ATOM, got STRING \"key\""}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "map types simple errors" do
    test_data = %{:key1 => "value1", "key2" => 3.05}
    test_schema = %{:key1 => [:int], "key2" => [:int], "key3" => [:float]}
    expected_results = {:error, [{[], "missing required keys: [\"key3\"]"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "map types simple errors not_required" do
    test_data = %{:key1 => "value1", "key2" => 3.05}
    test_schema = %{:key1 => [:int, :not_required], "key2" => [:int], "key3" => [:float]}
    expected_results = {:error, [{[], "missing required keys: [\"key3\"]"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "map types errors not_required" do
    test_data = %{:key1 => 8, "key2" => 3}
    test_schema = %{:key1 => [:string, :not_required], "key2" => [:int]}
    expected_results = {:error, [{[:key1], "expected STRING, got INTEGER 8"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "map types errors custom validator" do
    test_data1 = %{"a" => 1, "prefix_b" => 2}
    test_data2 = %{"prefix_a" => "aa", "prefix_b" => 2}

    test_schema = [
      :map,
      fn map ->
        invalid_key = map |> Map.keys() |> Enum.find(&(!(&1 =~ ~r/^prefix_/)))
        invalid_value = map |> Map.values() |> Enum.find(&(!is_number(&1)))

        cond do
          invalid_key -> {:error, "key #{invalid_key} not start with 'prefix_'"}
          invalid_value -> {:error, "value #{invalid_value} is not number"}
          true -> :ok
        end
      end,
      %{}
    ]

    expected_result1 = {:error, [{[], "key a not start with 'prefix_'"}]}
    expected_result2 = {:error, [{[], "value aa is not number"}]}

    assert expected_result1 == Skooma.valid?(test_data1, test_schema)
    assert expected_result2 == Skooma.valid?(test_data2, test_schema)
  end

  test "map types complex errors" do
    test_data = %{
      :key1 => "value1",
      "key2" => %{sports: "blue"},
      "things" => ["thing1", 5],
      "stuff" => %{key3: %{key4: 9}}
    }

    test_schema = %{
      :key1 => [:string],
      "key2" => [:map, %{color: [:string]}],
      "things" => [:list, :string],
      "stuff" => %{key3: %{key4: [:string]}}
    }

    expected_results =
      {:error,
       [
         {["key2"], "missing required keys: [:color]"},
         {["stuff", :key3, :key4], "expected STRING, got INTEGER 9"},
         {["things", 1], "expected STRING, got INTEGER 5"}
       ]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "list types simple errors" do
    test_data = [1, 2, 3, 4]
    test_schema = [:list, :string]

    expected_results =
      {:error,
       [
         {[0], "expected STRING, got INTEGER 1"},
         {[1], "expected STRING, got INTEGER 2"},
         {[2], "expected STRING, got INTEGER 3"},
         {[3], "expected STRING, got INTEGER 4"}
       ]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "list types complex errors" do
    test_data = [%{key1: 1}, %{key1: :value2}, %{key1: "value 3"}]
    obj_schema = %{key1: [:string]}
    test_schema = [:list, :map, fn -> obj_schema end]

    expected_results =
      {:error,
       [
         {[0, :key1], "expected STRING, got INTEGER 1"},
         {[1, :key1], "expected STRING, got ATOM :value2"}
       ]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "tuple types simple error" do
    test_data = {"thing1", "2", 3}
    test_schema = {[:string], [:int], [:atom]}

    expected_results =
      {:error,
       [
         {[1], "expected INTEGER, got STRING \"2\""},
         {[2], "expected ATOM, got INTEGER 3"}
       ]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "tuple types length error" do
    test_data = {"thing1", 2}
    test_schema = {[:string], [:int], [:atom]}
    expected_results = {:error, [{[], "tuple schema doesn't match tuple length"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end

  test "tuple types complex" do
    test_data = {"thing1", %{key1: 1}, :atom3}
    obj_schema = %{key1: [:string]}
    test_schema = {[:string], obj_schema, [:atom]}
    expected_results = {:error, [{[1, :key1], "expected STRING, got INTEGER 1"}]}

    results = Skooma.valid?(test_data, test_schema)
    assert(expected_results == results)
  end
end
