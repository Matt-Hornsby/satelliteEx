defmodule ObserverTest do
  use ExUnit.Case

  test "should_be_able_to_lookup_known_observer" do
    assert Observer.KnownLocations.seattle != nil
  end
end
