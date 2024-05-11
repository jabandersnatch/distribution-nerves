defmodule T2Test do
  use ExUnit.Case
  doctest T2

  test "greets the world" do
    assert T2.hello() == :world
  end
end
