defmodule ObserverTest do
  use ExUnit.Case

  test "should_be_able_to_lookup_known_observer" do
    assert Observer.KnownLocations.seattle() != nil
  end

  test "should_be_able_to_create_observer_struct" do
    sut = %Observer{latitude_deg: 47.6062, longitude_deg: -122.3321, height_km: 0.370}
    assert sut != nil
  end
end
