defmodule PredictionTest do
  use ExUnit.Case

  setup_all do
    test_observer = Observer.KnownLocations.london()
    test_satellite = Satellite.SatelliteDatabase.lookup(25_544)

    {
      :ok,
      test_observer: test_observer, test_satellite: test_satellite
    }
  end

  test "should_be_able_to_get_next_pass", state do
    pass =
      Satellite.next_pass(
        state[:test_satellite],
        :calendar.universal_time(),
        state[:test_observer]
      )

    assert pass != nil
  end

  test "should_be_able_to_get_several_passes", state do
    number_of_passes = 3

    passes =
      Satellite.list_passes(
        state[:test_satellite],
        number_of_passes,
        state[:test_observer],
        :calendar.universal_time()
      )

    assert Enum.count(passes) == number_of_passes
  end
end
