defmodule A6Test do
  use ExUnit.Case
  doctest A6

  test "greets the world" do
    assert A6.hello() == :world
  end
end
