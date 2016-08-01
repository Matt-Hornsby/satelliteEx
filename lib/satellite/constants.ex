defmodule Constants do
  def pi, do: :math.pi()
  def earth_radius, do: 6378.137  # in km
  def mu, do: 398600.5           # in km3 / s2
  def xke, do: 60.0 / :math.sqrt(earth_radius * earth_radius * earth_radius / mu)
  def tumin, do: 1.0 / xke()
  def degtorad, do: pi / 180.0
  def x2o3, do: 2.0 / 3.0
  def j2, do: 0.00108262998905
  def j3, do: -0.00000253215306
  def j4, do: -0.00000161098761
  def deg2rad, do: pi() / 180.0
  def rad2deg, do: 180.0 / pi()
  def two_pi, do: 2 * pi()
  def j3oj2, do: j3 / j2
  def minutes_per_day, do: 1440.0
end
