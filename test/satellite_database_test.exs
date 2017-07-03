defmodule SatelliteDatabaseTest do
 use ExUnit.Case

 test "should_be_able_to_list_satellites" do
  count_of_satellites = Enum.count(Satellite.SatelliteDatabase.list)
  assert count_of_satellites > 0
 end 

 test "should_be_able_to_search_by_name" do
  assert Satellite.SatelliteDatabase.lookup("PHOENIX") != nil
 end
end