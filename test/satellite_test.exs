defmodule SatelliteTest do
  use ExUnit.Case
  alias Satellite.{CoordinateTransforms, Dates, SGP4.Init}
  doctest Satellite.Dates

  setup_all do
    tle_line_1 = "1 25544U 98067A   13149.87225694  .00009369  00000-0  16828-3 0  9031"
    tle_line_2 = "2 25544 051.6485 199.1576 0010128 012.7275 352.5669 15.50581403831869"

    # AO-07
    # tle_line_1 = "1 07530U 74089B   16195.86511907 -.00000024  00000-0  12706-3 0  9998"
    # tle_line_2 = "2 07530 101.5762 165.9737 0011522 259.3493 129.4719 12.53622068906466"

    {:ok, tle1} = Satellite.TLE.parse_line1(tle_line_1)
    {:ok, tle2} = Satellite.TLE.parse_line2(tle_line_2)

    {
      :ok,
      tle_line_1: tle_line_1, tle_line_2: tle_line_2, tle_1: tle1, tle_2: tle2
    }
  end

  test "propagate", state do
    {:ok, satrec} = Satellite.TLE.to_satrec(state[:tle_line_1], state[:tle_line_2])
    position_and_velocity = Satellite.SGP4.propagate(satrec, {{2017, 1, 1}, {1, 1, 1}})
    position_eci = position_and_velocity.position
    velocity_eci = position_and_velocity.velocity

    observer_gd = Observer.create_from(36.9613422, -122.0308, 0.370)

    # gmst = gstime(jday({{2017,1,1},{1,1,1}}))
    gmst = Dates.utc_to_gmst({{2017, 1, 1}, {1, 1, 1}})
    position_ecf = CoordinateTransforms.eci_to_ecf(position_eci, gmst)
    # observerEcf = CoordinateTransforms.geodetic_to_ecf(observer_gd)
    # positionGd = satellite.eciToGeodetic(position_eci, gmst)
    look_angles = CoordinateTransforms.ecf_to_look_angles(observer_gd, position_ecf)

    tolerance = 0.0000001
    assert_in_delta position_eci.x, -1598.9224945568021, tolerance
    assert_in_delta position_eci.y, -5437.566343316776, tolerance
    assert_in_delta position_eci.z, -3473.0617812839414, tolerance

    assert_in_delta velocity_eci.x, 6.1867840719957465, tolerance
    assert_in_delta velocity_eci.y, 1.067765018113105, tolerance
    assert_in_delta velocity_eci.z, -4.5315790425142675, tolerance

    assert_in_delta look_angles.azimuth_rad, 4.3466709598451425, tolerance
    assert_in_delta look_angles.elevation_rad, -0.9994775790843395, tolerance
    assert_in_delta look_angles.range_sat, 11_036.184604572572, tolerance
  end

  test "gstime returns correct value" do
    assert Dates.utc_to_gmst({{2017, 1, 1}, {1, 1, 1}}) === 2.026918610688881
    assert Dates.julian_to_gmst(Dates.jday({{2017, 1, 1}, {1, 1, 1}})) === 2.026918610688881
  end

  test "initl returns correct response" do
    # this is a pinning test to make sure i don't screw things up during refactoring
    initialization_parameters = %{
      satn: "25544",
      ecco: 0.0010128,
      epoch: 23_160.87225694023,
      inclo: 0.9014363787162912,
      no: 0.0676568770063577,
      method: 'n',
      opsmode: 'i'
    }

    initialization_results = Init.initl(initialization_parameters)
    assert initialization_results.ainv === 0.938835647692083
    assert initialization_results.ao === 1.0651491583838724
    assert initialization_results.con41 === 0.15500182798076345
    assert initialization_results.con42 === -0.9250030466346058
    assert initialization_results.cosio === 0.6204841733089742
    assert initialization_results.cosio2 === 0.38500060932692115
    assert initialization_results.eccsq === 1.02576384e-6
    assert initialization_results.gsto === 3.5178017006182927
    assert initialization_results.method === 'n'
    assert initialization_results.no === 0.0676493708416377
    assert initialization_results.omeosq === 0.99999897423616
    assert initialization_results.posq === 1.1345404020612515
    assert initialization_results.rp === 1.064070375316261
    assert initialization_results.rteosq === 0.9999994871179485
    assert initialization_results.sinio === 0.7842189685751544
  end

  test "parse fortran exponent" do
    assert Satellite.Math.from_fortran_float("12345-3") == 0.12345e-3
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
    assert state[:tle_2][:revolutions] == 83_186
  end

  test "parsed tle2 should return the correct checksum", state do
    assert state[:tle_2][:checksum] == 9
  end
end
