defmodule SkoomaTest do
  use ExUnit.Case
  require Logger

  test "bool types" do
    test_data = false
    test_schema = [:bool]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "string types" do
    test_data = "test"
    test_schema = [:string]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "int types" do
    test_data = 7
    test_schema = :int

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "float types" do
    test_data = 3.14
    test_schema = :float

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "number types" do
    test_data = 3.14
    test_schema = :number

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "atom types" do
    test_data = :thing
    test_schema = [:atom]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "union types with map" do
    test_data = %{key1: "value1"}
    test_schema = [:union, [%{key1: [:string]}, [:int]]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "union types" do
    test_data = 8
    test_schema = [:union, [[:map, %{key1: [:string]}], [:int]]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "union types with not required" do
    test_schema = [:union, [[:map, %{key1: [:string]}], [:int]], :not_required]

    assert :ok = Skooma.valid?(8, test_schema)
    assert :ok = Skooma.valid?(%{key1: "foo"}, test_schema)
    assert :ok = Skooma.valid?(nil, test_schema)
  end

  test "keyword list types" do
    test_data = [key1: "value1", key2: 2, key3: :atom3]
    test_schema = [key1: :string, key2: :int, key3: :atom]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "keyword list types complex" do
    test_data = [key1: %{key4: 6}, key2: 2, key3: :atom3]
    test_schema = [key1: [:map, %{key4: [:int]}], key2: [:int], key3: [:atom]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types simple" do
    test_data = %{:key1 => "value1", "key2" => 3}
    test_schema = %{:key1 => :string, "key2" => :int}

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types not_required" do
    test_data = %{"key2" => 3}
    test_schema = %{:key1 => [:string, :not_required], "key2" => [:int]}

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types not_required with nil" do
    test_data = %{:key1 => nil, "key2" => 3}
    test_schema = %{:key1 => [:string, :not_required], "key2" => [:int]}

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types with custom validator" do
    test_data = %{"prefix_a" => 1, "prefix_b" => 2}

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

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types complex" do
    test_data = %{
      :key1 => "value1",
      "key2" => %{color: "blue"},
      "things" => ["thing1", "thing2"],
      "stuff" => %{key3: %{key4: "thing4"}}
    }

    test_schema = %{
      :key1 => [:string],
      "key2" => [:map, %{color: [:string]}],
      "things" => [:list, :string],
      "stuff" => %{key3: %{key4: [:string]}}
    }

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "map types complex not_required" do
    test_data = %{
      :key1 => "value1",
      "key2" => %{color: "blue"},
      "things" => ["thing1", "thing2"],
      "stuff" => %{key3: %{}}
    }

    test_schema = %{
      :key1 => [:string],
      "key2" => [:map, %{color: [:string]}],
      "things" => [:list, :string],
      "stuff" => %{key3: %{key4: [:string, :not_required]}}
    }

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  def hero_schema() do
    %{
      name: [:string],
      race: [:string],
      friends: [:list, :map, :not_required, &hero_schema/0]
    }
  end

  test "recursive map" do
    my_hero = %{
      name: "Alkosh",
      race: "Khajiit",
      friends: [
        %{name: "Asurah", race: "Khajiit"},
        %{name: "Carlos", race: "Dwarf"}
      ]
    }

    Skooma.valid?(my_hero, hero_schema())
  end

  test "list types simple" do
    test_data = [1, 2, 3, 4]
    test_schema = [:list, :int]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list types empty" do
    test_data = []
    test_schema = [:list, :int]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list types complex" do
    test_data = [%{key1: "value1"}, %{key1: "value2"}, %{key1: "value 3"}]
    obj_schema = %{key1: [:string]}
    test_schema = [:list, :map, fn -> obj_schema end]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of union types" do
    test_data = ["value", 1]
    test_schema = [:list, [:union, [:string, :int]]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of union types, with not required" do
    test_data = ["value", 1, nil]
    test_schema = [:list, [:union, [:string, :int], :not_required]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of lists types" do
    test_data = [["value", "foo"], ["test"]]
    test_schema = [:list, [:list, :string]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of lists types, with not required" do
    test_data = [["value", "foo"], ["test"], [nil]]
    test_schema = [:list, [:list, :string, :not_required]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of list of union types" do
    test_data = [["value", "foo", 1], ["test", 0], [-2]]
    test_schema = [:list, [:list, [:union, [:string, :number]]]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "list of list of union types with not required" do
    test_data = [["value", "foo", 1], ["test", 0], [-2], [nil]]
    test_schema = [:list, [:list, [:union, [:string, :number], :not_required]]]

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "tuple types simple" do
    test_data = {"thing1", 2, :atom3}
    test_schema = {:string, :int, :atom}

    assert :ok = Skooma.valid?(test_data, test_schema)
  end

  test "tuple types complex" do
    test_data = {"thing1", %{key1: "value1"}, :atom3}
    obj_schema = %{key1: [:string]}
    test_schema = {[:string], obj_schema, [:atom]}

    assert :ok = Skooma.valid?(test_data, test_schema)
  end
end
