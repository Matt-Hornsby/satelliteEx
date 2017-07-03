defmodule Sun.SunPosition do
  require Satellite.Constants
  alias Satellite.Constants

  def get_position_at({{_year, _month, _day}, {_hour, _min, _sec}} = input_date, observerGd) do
    julian_date = Satellite.Dates.jday(input_date)
    sp = Sun.Orbit.calculate_orbital_coordinates_at(julian_date)
    sidereal_angle = Satellite.Dates.gstime(julian_date)
    sun_longitude = sp.right_ascension - sidereal_angle

    x_plane = :math.cos(sp.declination) * :math.cos(sp.right_ascension)
    y_plane = :math.cos(sp.declination) * :math.sin(sp.right_ascension)
    z_plane = :math.sin(sp.declination)

    ecfc_x_plane = :math.cos(sp.declination) * :math.cos(sun_longitude)
    ecfc_y_plane = :math.cos(sp.declination) * :math.sin(sun_longitude)
    ecfc_z_plane = :math.sin(sp.declination)

    observer_geo_x = :math.cos(observerGd.latitude) * :math.cos(observerGd.longitude)
    observer_geo_y = :math.cos(observerGd.latitude) * :math.sin(observerGd.longitude)
    observer_geo_z = :math.sin(observerGd.latitude)

    position =  (ecfc_x_plane * observer_geo_x) +
                (ecfc_y_plane * observer_geo_y) +
                (ecfc_z_plane * observer_geo_z)

    elevation_radians = 90 - :math.acos(position) * Constants.rad2deg

    %{
      declination: sp.declination,
      right_ascension: sp.right_ascension,
      longitude_degrees: sun_longitude * Constants.rad2deg,
      longitude_radians: sun_longitude,
      x_plane: x_plane,
      y_plane: y_plane,
      z_plane: z_plane,
      ecfc_x_plane: ecfc_x_plane,
      ecfc_y_plane: ecfc_y_plane,
      ecfc_z_plane: ecfc_z_plane,
      elevation_radians: elevation_radians,
      elevation_degrees: elevation_radians * Constants.rad2deg
    }
  end
end
