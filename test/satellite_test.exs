defmodule SatelliteTest do
  use ExUnit.Case
  doctest Satellite

  setup_all do
    tle_line_1 = "1 25544U 98067A   13149.87225694  .00009369  00000-0  16828-3 0  9031"
    tle_line_2 = "2 25544 051.6485 199.1576 0010128 012.7275 352.5669 15.50581403831869"
    tle1 = Satellite.extract_tle1(tle_line_1)
    tle2 = Satellite.extract_tle2(tle_line_2)

    {
      :ok,
      tle_line_1: tle_line_1,
      tle_line_2: tle_line_2,
      tle_1: tle1,
      tle_2: tle2
    }
  end

  @tag :skip
  test "initialize", state do
    sat = Satellite.create()
    assert sat[:twoline_to_satrec].(state[:tle_line_1], state[:tle_line_2])
  end

  test "parse fortran exponent" do
    assert Satellite.from_fortran_float("12345-3") == 0.12345e-3
  end

  test "parsed tle1 should return line 1", state do
    assert state[:tle_1][:line_number] == 1
  end

  test "parsed tle1 should return the correct bstar drag", state do
    assert state[:tle_1][:bstar_drag] == 0.16828e-3
  end

  test "parsed tle1 should return the correct ephemeris type", state do
    assert state[:tle_1][:ephemeris_type] == 0
  end

  test "parsed tle1 should return the correct checksum", state do
    assert state[:tle_1][:checksum] == 1
  end

  test "parsed tle1 should return the correct element set", state do
    assert state[:tle_1][:element_set] == 903
  end

  test "parsed tle1 should return the correct satellite number", state do
    assert state[:tle_1][:satellite_number] == "25544"
  end

  test "parsed tle1 should return the correct classification", state do
    assert state[:tle_1][:classification] == "U"
  end

  test "parsed tle1 should return the correct launch year", state do
    assert state[:tle_1][:launch_year] == 98
  end

  test "parsed tle1 should return the correct launch number", state do
    assert state[:tle_1][:launch_number] == 67
  end

  test "parsed tle1 should return the correct launch piece", state do
    assert state[:tle_1][:piece_of_launch] == "A"
  end

  test "parsed tle1 should return the correct epoch year", state do
    assert state[:tle_1][:epoch_year] == 13
  end

  test "parsed tle1 should return the correct epoch", state do
    assert state[:tle_1][:epoch] == 149.87225694
  end

  test "parsed tle1 should return the correct first deriviative", state do
    assert state[:tle_1][:first_deriviative] == 9.369e-5
  end

  test "parsed tle1 should return the correct second deriviative", state do
    assert state[:tle_1][:second_deriviative] == 0
  end

  test "parsed tle2 should return line number 2", state do
    assert state[:tle_2][:line_number] == 2
  end

  test "parsed tle2 should return the correct satellite number", state do
    assert state[:tle_2][:satellite_number] == "25544"
  end

  test "parsed tle2 should return the correct inclination", state do
    assert state[:tle_2][:inclination] == 51.6485
  end

  test "parsed tle2 should return the correct right ascension", state do
    assert state[:tle_2][:right_ascension] == 199.1576
  end

  test "parsed tle2 should return the correct eccentricity", state do
    assert state[:tle_2][:eccentricity] == 0.0010128
  end

  test "parsed tle2 should return the correct perigee", state do
    assert state[:tle_2][:perigee] == 12.7275
  end

  test "parsed tle2 should return the correct mean anomaly", state do
    assert state[:tle_2][:mean_anomaly] == 352.5669
  end

  test "parsed tle2 should return the correct mean motion", state do
    assert state[:tle_2][:mean_motion] == 15.50581403
  end

  test "parsed tle2 should return the correct revolutions", state do
    assert state[:tle_2][:revolutions] == 83186
  end

  test "parsed tle2 should return the correct checksum", state do
    assert state[:tle_2][:checksum] == 9
  end
end
