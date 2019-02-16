defmodule Satellite.Constants do
  defmacro pi, do: :math.pi()
  defmacro two_pi, do: 2 * pi()
  # in km
  defmacro earth_radius_semimajor, do: 6378.137
  # in km
  defmacro earth_radius_semiminor, do: 6356.7523142
  # in km3 / s2
  defmacro mu, do: 398_600.5

  defmacro xke,
    do:
      60.0 /
        :math.sqrt(
          earth_radius_semimajor() * earth_radius_semimajor() * earth_radius_semimajor() / mu()
        )

  defmacro tumin, do: 1.0 / xke()
  defmacro x2o3, do: 2.0 / 3.0
  defmacro j2, do: 0.00108262998905
  defmacro j3, do: -0.00000253215306
  defmacro j4, do: -0.00000161098761
  defmacro deg2rad, do: pi() / 180.0
  defmacro rad2deg, do: 180.0 / pi()
  defmacro j3oj2, do: j3() / j2()
  defmacro minutes_per_day, do: 1440.0
  defmacro seconds_per_day, do: minutes_per_day() * 60
  defmacro astronomical_unit, do: 149_597_892_000
end
