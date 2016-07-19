defmodule Constants do
  def pi, do: :math.pi()
  def earth_radius, do: 6378.137  # in km
  def mu, do: 398600.5           # in km3 / s2
  def xke, do: 60.0 / :math.sqrt(earth_radius * earth_radius * earth_radius / mu)
  def tumin, do: 1.0 / xke()
  def degtorad, do: pi / 180.0

  def all do
    pi = pi()
    mu = 398600.5           # in km3 / s2
    earth_radius =  6378.13  # in km
    xke = 60.0 / :math.sqrt(earth_radius * earth_radius * earth_radius / mu)
    j2 = 0.00108262998905
    j3 = -0.00000253215306

    %{
      :pi => pi,
      :two_pi => 2 * pi,
      :deg2rad => pi / 180.0,
      :rad2deg => 180 / pi,
      :minutes_per_day => 1440.0,
      :mu => mu,
      :earth_radius => earth_radius,
      :xke => xke,
      :tumin => 1.0 / xke,
      :j2 => j2,
      :j3 => j3
    }
  end

end
