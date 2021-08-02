defmodule SkoomaTest do
  use ExUnit.Case
  require Logger

  def assert_valid_values(type, values) do
    for value <- values do
      assert :ok = Skooma.valid?(value, type)

      if is_atom(type) do
        assert :ok = Skooma.valid?(value, [type])
      end
    end

    type
  end

  def assert_supports_not_required(type) do
    if is_list(type) do
      assert {:error, _} = Skooma.valid?(nil, type |> List.delete(:not_required))
    end

    assert :ok = Skooma.valid?(nil, [type, :not_required])

    type
  end

  def assert_invalid_values(type, values) do
    for value <- values do
      assert {:error, _} = Skooma.valid?(value, type)
    end

    type
  end

  test "bool types" do
    :bool
    |> assert_valid_values([true, false])
    |> assert_invalid_values(["true", 1])
    |> assert_supports_not_required()
  end

  test "string types" do
    :string
    |> assert_valid_values(["", "test"])
    |> assert_invalid_values([:atom])
    |> assert_supports_not_required()
  end

  test "int types" do
    :int
    |> assert_valid_values([-1, 0, 1])
    |> assert_supports_not_required()
  end

  test "float types" do
    :float
    |> assert_valid_values([-3.14, 0.0, 3.14])
    |> assert_supports_not_required()
  end

  test "number types" do
    :number
    |> assert_valid_values([-1, -1.0, 0, 0.0, 1, 1.0])
    |> assert_invalid_values(["-1", "-1.0", "0"])
    |> assert_supports_not_required()
  end

  test "atom types" do
    :atom
    |> assert_valid_values([:thing])
    |> assert_invalid_values(["thing"])
    |> assert_supports_not_required()
  end

  test "union types with map" do
    [:union, [%{key1: [:string]}, [:int]]]
    |> assert_valid_values([2, %{key1: "string"}])
    |> assert_invalid_values(["foo", %{wrong_key: "string"}, %{key1: nil}])
    |> assert_supports_not_required()
  end

  test "union types" do
    [:union, [[:map, %{key1: [:string]}], [:int]]]
    |> assert_valid_values([3, %{key1: "string"}])
    |> assert_invalid_values(["8", %{key1: -1}, %{wrong_key: "string"}])
    |> assert_supports_not_required()
  end

  test "union types with not required" do
    [:union, [[:map, %{key1: [:string]}], [:int]], :not_required]
    |> assert_valid_values([3, %{key1: "string"}, nil])
    |> assert_invalid_values(["3", %{key1: -1}])
    |> assert_supports_not_required()
  end

  test "keyword list types" do
    [key1: :string, key2: :int, key3: :atom]
    |> assert_valid_values([[key1: "value1", key2: 2, key3: :atom3]])
    |> assert_invalid_values([
      [key1: -1, key2: "string", key3: :atom3],
      [key1: "value1", key2: 2, key3: "foo"],
      [key1: "value1", key2: 2]
    ])
  end

  test "keyword list types complex" do
    [key1: [:map, %{key4: [:int]}], key2: [:int], key3: [:atom]]
    |> assert_valid_values([[key1: %{key4: 6}, key2: 2, key3: :atom3]])
    |> assert_invalid_values([
      [key1: %{key4: 6}, key2: "two", key3: :atom3],
      [key1: %{key4: 6}, key2: "two", key3: "string"],
      [key1: %{}, key2: 2, key3: :atom3],
      [key1: nil, key2: 2, key3: :atom3]
    ])
  end

  test "map types simple" do
    %{:key1 => :string, "key2" => :int}
    |> assert_valid_values([%{:key1 => "value1", "key2" => 3}])
    |> assert_invalid_values([
      %{:key1 => 1, "key2" => 3},
      %{:key1 => "value1", "key2" => "three"}
    ])
    |> assert_supports_not_required()
  end

  test "map types not_required" do
    %{:key1 => [:string, :not_required], "key2" => [:int]}
    |> assert_valid_values([
      %{:key1 => nil, "key2" => 3},
      %{"key2" => 3}
    ])
    |> assert_invalid_values([
      %{"key2" => nil},
      %{:key1 => "value"},
      %{:key1 => "value", "key2" => nil}
    ])
    |> assert_supports_not_required()
  end

  test "map types not_required with nil" do
    %{:key1 => [:string, :not_required], "key2" => [:int]}
    |> assert_valid_values([
      %{:key1 => nil, "key2" => 3},
      %{"key2" => 3}
    ])
    |> assert_invalid_values([
      %{"key2" => nil},
      %{:key1 => "value"},
      %{:key1 => "value", "key2" => nil}
    ])
    |> assert_supports_not_required()
  end

  test "map types with custom validator" do
    [
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
    |> assert_valid_values([
      %{"prefix_a" => 1, "prefix_b" => 2},
      %{"prefix_a" => 1},
      %{}
    ])
    |> assert_invalid_values([
      %{"prefix_a" => 1, "b" => 1}
    ])
  end

  test "map types complex" do
    %{
      :key1 => [:string],
      "key2" => [:map, %{color: [:string]}],
      "things" => [:list, :string],
      "stuff" => %{key3: %{key4: [:string]}}
    }
    |> assert_valid_values([
      %{
        :key1 => "value1",
        "key2" => %{color: "blue"},
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{key4: "thing4"}}
      }
    ])
    |> assert_invalid_values([
      %{
        :key1 => 1,
        "key2" => %{color: "blue"},
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{key4: "thing4"}}
      },
      %{
        :key1 => "value1",
        "key2" => %{color: 3},
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{key4: "thing4"}}
      },
      %{
        :key1 => "value1",
        "key2" => %{color: 3},
        "things" => [1, 2],
        "stuff" => %{key3: %{key4: "thing4"}}
      }
    ])
  end

  test "map types complex not_required" do
    %{
      :key1 => [:string],
      "key2" => [:map, %{color: [:string]}],
      :key3 => [:map, %{foo: :string}, :not_required],
      "things" => [:list, :string],
      "stuff" => %{key3: %{key4: [:string, :not_required]}}
    }
    |> assert_valid_values([
      %{
        :key1 => "value1",
        "key2" => %{color: "blue"},
        :key3 => nil,
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{}}
      },
      %{
        :key1 => "value1",
        "key2" => %{color: "blue"},
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{key4: nil}}
      }
    ])
    |> assert_invalid_values([
      %{
        :key1 => "value1",
        "key2" => %{color: "blue"},
        :key3 => nil,
        "things" => ["thing1", "thing2"],
        "stuff" => %{key3: %{key4: 2}}
      }
    ])
  end

  def hero_schema() do
    %{
      name: [:string],
      race: [:string],
      friends: [:list, :map, :not_required, &hero_schema/0]
    }
  end

  test "recursive map" do
    hero_schema()
    |> assert_valid_values([
      %{
        name: "Alkosh",
        race: "Khajiit",
        friends: [
          %{name: "Asurah", race: "Khajiit"},
          %{name: "Carlos", race: "Dwarf"}
        ]
      },
      %{
        name: "Alkosh",
        race: "Khajiit",
        friends: [
          %{name: "Asurah", race: "Khajiit"},
          %{name: "Carlos", race: "Dwarf", friends: []}
        ]
      },
      %{
        name: "Alkosh",
        race: "Khajiit",
        friends: [
          %{name: "Asurah", race: "Khajiit"},
          %{
            name: "Carlos",
            race: "Dwarf",
            friends: [
              %{name: "Somebody", race: "Else"}
            ]
          }
        ]
      }
    ])
  end

  test "list types simple" do
    [:list, :int]
    |> assert_valid_values([
      [1, 2, 3, 4],
      []
    ])
    |> assert_invalid_values([
      [1, 2, 3, 4.0],
      ["4"],
      [nil]
    ])
  end

  test "list types complex" do
    obj_schema = %{key1: [:string]}

    [:list, :map, fn -> obj_schema end]
    |> assert_valid_values([
      [%{key1: "value1"}],
      [%{key1: "value1"}, %{key1: "value2"}, %{key1: "value 3"}],
      []
    ])
    |> assert_invalid_values([
      [%{key2: "value1"}],
      [%{key1: 1}],
      [%{key1: "value1"}, %{key1: -1}]
    ])
  end

  test "list of union types" do
    [:list, [:union, [:string, :int]]]
    |> assert_valid_values([
      ["value", 1],
      [1],
      ["value"],
      []
    ])
    |> assert_invalid_values([
      [1.0],
      ["value", 1.0],
      [nil]
    ])
  end

  test "list of union types, with not required" do
    [:list, [:union, [:string, :int], :not_required]]
    |> assert_valid_values([
      ["value", 1, nil],
      [nil],
      [1, nil]
    ])
    |> assert_invalid_values([
      [1.0],
      ["value", 1.0]
    ])
  end

  test "list of lists types" do
    [:list, [:list, :string]]
    |> assert_valid_values([
      [["value", "foo"], ["test"]],
      [],
      [[]]
    ])
    |> assert_invalid_values([
      [["value", 1], ["test"]],
      [nil],
      [[nil]]
    ])
  end

  test "list of lists types, with not required" do
    [:list, [:list, :string, :not_required]]
    |> assert_valid_values([
      [["value", "foo"], ["test"], [nil]],
      [[nil]]
    ])
    |> assert_invalid_values([
      [["value", 1], ["test"]],
      [nil]
    ])
  end

  test "list of list of union types" do
    [:list, [:list, [:union, [:string, :number]]]]
    |> assert_valid_values([
      [["value", "foo", 1], ["test", 0], [-2]],
      [["value", "foo", 1], ["test", 0], ["foo"], [-2]]
    ])
    |> assert_invalid_values([
      [["value", "foo", 1], ["test", 0], [-2], [nil]],
      [[1.0], [-2], [nil]],
      [[nil]]
    ])
  end

  test "list of list of union types with not required" do
    [:list, [:list, [:union, [:string, :number], :not_required]]]
    |> assert_valid_values([
      [["value", "foo", 1], ["test", 0], [-2], [nil]],
      [[nil]]
    ])
    |> assert_invalid_values([
      [["value", false], ["test"]],
      [nil]
    ])
  end

  test "tuple types simple" do
    {:string, :int, :atom}
    |> assert_valid_values([
      {"thing1", 2, :atom3}
    ])
    |> assert_invalid_values([
      {nil, 2, :atom3},
      {"thing1", false, :atom3},
      {"thing1", 2, 1.0}
    ])
  end

  test "tuple types complex" do
    obj_schema = %{key1: [:string]}

    {[:string], obj_schema, [:atom]}
    |> assert_valid_values([
      {"thing1", %{key1: "value1"}, :atom3}
    ])
    |> assert_invalid_values([
      {1, %{key1: "value1"}, :atom3},
      {"thing1", %{key1: 1}, :atom3},
      {"thing1", %{key1: nil}, :atom3}
    ])
  end
end
