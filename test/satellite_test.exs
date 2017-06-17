defmodule SatelliteTest do
  use ExUnit.Case
  import Satellite.Dates
  alias Satellite.CoordinateTransforms
  doctest Satellite

  setup_all do
    tle_line_1 = "1 25544U 98067A   13149.87225694  .00009369  00000-0  16828-3 0  9031"
    tle_line_2 = "2 25544 051.6485 199.1576 0010128 012.7275 352.5669 15.50581403831869"

    #AO-07
    #tle_line_1 = "1 07530U 74089B   16195.86511907 -.00000024  00000-0  12706-3 0  9998"
    #tle_line_2 = "2 07530 101.5762 165.9737 0011522 259.3493 129.4719 12.53622068906466"

    {:ok, tle1} = Satellite.TLE.parse_line1(tle_line_1)
    {:ok, tle2} = Satellite.TLE.parse_line2(tle_line_2)

    {
      :ok,
      tle_line_1: tle_line_1,
      tle_line_2: tle_line_2,
      tle_1: tle1,
      tle_2: tle2
    }
  end

  test "propagate", state do
    {:ok, satrec} = Satellite.TLE.to_satrec(state[:tle_line_1], state[:tle_line_2])
    positionAndVelocity = Satellite.SGP4.propagate(satrec, 2017, 1, 1, 1, 1, 1)
    positionEci = positionAndVelocity.position
    velocityEci = positionAndVelocity.velocity


    deg2rad = :math.pi/180
    observerGd = %{
       longitude: -122.0308 * deg2rad,
       latitude: 36.9613422 * deg2rad,
       height: 0.370}

    gmst = gstime(jday(2017,1,1,1,1,1))
    positionEcf = CoordinateTransforms.eci_to_ecf(positionEci, gmst)
    # observerEcf = CoordinateTransforms.geodetic_to_ecf(observerGd)
    #positionGd = satellite.eciToGeodetic(positionEci, gmst)
    lookAngles = CoordinateTransforms.ecf_to_look_angles(observerGd, positionEcf)

    tolerance = 0.0000001
    assert_in_delta positionEci.x, -1598.9224945568021, tolerance
    assert_in_delta positionEci.y, -5437.566343316776, tolerance
    assert_in_delta positionEci.z, -3473.0617812839414, tolerance

    assert_in_delta velocityEci.x, 6.1867840719957465, tolerance
    assert_in_delta velocityEci.y, 1.067765018113105, tolerance
    assert_in_delta velocityEci.z, -4.5315790425142675, tolerance

    assert_in_delta lookAngles.azimuth, 4.3466709598451425, tolerance
    assert_in_delta lookAngles.elevation, -0.9994775790843395, tolerance
    assert_in_delta lookAngles.rangeSat, 11036.184604572572, tolerance
  end

  test "gstime returns correct value" do
    assert gstime(jday(2017,1,1,1,1,1)) === 2.026918610688881
  end

  test "initl returns correct response" do
    # this is a pinning test to make sure i don't screw things up during refactoring
    initlParameters = %{
            satn: "25544",
            ecco: 0.0010128,
            epoch: 23160.87225694023,
            inclo: 0.9014363787162912,
            no: 0.0676568770063577,
            method: 'n',
            opsmode: 'i'
        }
    initlResult = Satellite.SGP4.Init.initl(initlParameters)
    assert initlResult.ainv === 0.938835647692083
    assert initlResult.ao === 1.0651491583838724
    assert initlResult.con41 === 0.15500182798076345
    assert initlResult.con42 === -0.9250030466346058
    assert initlResult.cosio === 0.6204841733089742
    assert initlResult.cosio2 === 0.38500060932692115
    assert initlResult.eccsq === 1.02576384e-6
    assert initlResult.gsto === 3.5178017006182927
    assert initlResult.method === 'n'
    assert initlResult.no === 0.0676493708416377
    assert initlResult.omeosq === 0.99999897423616
    assert initlResult.posq === 1.1345404020612515
    assert initlResult.rp === 1.064070375316261
    assert initlResult.rteosq === 0.9999994871179485
    assert initlResult.sinio === 0.7842189685751544

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
    assert state[:tle_2][:revolutions] == 83186
  end

  test "parsed tle2 should return the correct checksum", state do
    assert state[:tle_2][:checksum] == 9
  end
end
