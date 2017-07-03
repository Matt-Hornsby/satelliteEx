defmodule Sun.SunlightCalculations do
  @moduledoc """
  This module contains the math for determining whether a satellite is 
  illuminated by the sun. 
  """
  require Satellite.Constants
  alias Satellite.{Constants, CoordinateTransforms}

  def calculate_sunlit_status(satellite_position, sun_position) do
    k = satellite_position.x * sun_position.x_plane +
        satellite_position.y * sun_position.y_plane +
        satellite_position.z * sun_position.z_plane

    sunlit?(k, satellite_position)
  end

  defp sunlit?(k, _satellite_position) when k >= 0, do: true
  defp sunlit?(k, satellite_position) do
    new_k = :math.sqrt(satellite_position.x * satellite_position.x +
            satellite_position.y * satellite_position.y +
            satellite_position.z * satellite_position.z -
            k * k)

    if new_k > Constants.earth_radius_semimajor(), do: true, else: false
  end

  def get_base_magnitude(standard_magnitude, satellite_position, sun_position, observer_position, gmst) do
    x1sun = satellite_position.x - sun_position.x_plane * Constants.astronomical_unit / 1000
    y1sun = satellite_position.y - sun_position.y_plane * Constants.astronomical_unit / 1000
    z1sun = satellite_position.z - sun_position.z_plane * Constants.astronomical_unit / 1000
    vlsun = :math.sqrt(x1sun * x1sun + y1sun * y1sun + z1sun * z1sun)

    sidereal_angle = gmst

    observer_geocentric = CoordinateTransforms.geodetic_to_ecf(observer_position)
    observer_geoc_x = :math.cos(observer_geocentric.geo_lat) * :math.cos(observer_position.longitude)
    observer_geoc_y = :math.cos(observer_geocentric.geo_lat) * :math.sin(observer_position.longitude)
    observer_geoc_z = :math.sin(observer_geocentric.geo_lat)

    qx = satellite_position.x - observer_geoc_x * Constants.earth_radius_semimajor() * :math.cos(-sidereal_angle) - observer_geoc_y * Constants.earth_radius_semimajor() * :math.sin(-sidereal_angle)
    qy = satellite_position.y + observer_geoc_x * Constants.earth_radius_semimajor() * :math.sin(-sidereal_angle) - observer_geoc_y * Constants.earth_radius_semimajor() * :math.cos(-sidereal_angle)
    qz = satellite_position.z - observer_geoc_z * Constants.earth_radius_semimajor()

    range =  :math.sqrt(qx * qx + qy * qy + qz * qz)
    cospa = (x1sun * qx + y1sun * qy + z1sun * qz) / vlsun / range
    phasefactor = (1 + cospa) / 2
    xmag = -15.75 + 2.5 * :math.log(range * range / phasefactor) / :math.log(10) + standard_magnitude
    xmag
  end

  def adjust_magnutide_for_low_elevation(base_magnitude, elevation) when elevation < 20 do
    # credo:disable-for-next-line
    base_magnitude + (20 - elevation) / 15 * 1
  end

  def adjust_magnutide_for_low_elevation(base_magnitude, _elevation), do: base_magnitude

  def adjust_magnitude_for_sunset(base_magnitude, sun_elevation) when sun_elevation > -10 and sun_elevation < 0 do
    base_magnitude + (10 + sun_elevation) / 10 * 6
  end

  def adjust_magnitude_for_sunset(base_magnitude, _sun_elevation), do: base_magnitude

  def calculate_magnitude(satellite_position, satellite_magnitude, sun_position, observer, gmst, satellite_elevation) do
    sunlit? = calculate_sunlit_status(satellite_position, sun_position)
    base_magnitude = get_base_magnitude(satellite_magnitude, satellite_position, sun_position, observer, gmst)

    base_magnitude = if !sunlit?, do: 999.0, else: base_magnitude

    adjusted_magnitude = base_magnitude
                          |> adjust_magnutide_for_low_elevation(satellite_elevation * Constants.rad2deg)
                          |> adjust_magnitude_for_sunset(sun_position.elevation_radians)

    %{sunlit: sunlit?, base_magnitude: base_magnitude, adjusted_magnitude: adjusted_magnitude}
  end

end
