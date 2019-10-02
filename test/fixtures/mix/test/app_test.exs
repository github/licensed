defmodule AppTest do
  use ExUnit.Case
  doctest App

  test "greets the world" do
    assert App.hello() == :world
  end
end
