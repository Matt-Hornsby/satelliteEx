defmodule Sun.SunPosition do
  def get_position_at({{year, month, day}, {hour, min, sec}}, observerGd) do
    julian_date = Satellite.DatetimeConversions.jday(year, month, day, hour, min, sec)
    sp = Sun.Orbit.calculate_sun_position_at(julian_date)
    sidereal_angle = Satellite.DatetimeConversions.gstime(julian_date)
    sun_longitude = sp.right_ascension - sidereal_angle

    x_plane = :math.cos(sp.declination) * :math.cos(sp.right_ascension)
    y_plane = :math.cos(sp.declination) * :math.sin(sp.right_ascension)
    z_plane = :math.sin(sp.declination)

    ecfc_x_plane = :math.cos(sp.declination) * :math.cos(sun_longitude)
    ecfc_y_plane = :math.cos(sp.declination) * :math.sin(sun_longitude)
    ecfc_z_plane = :math.sin(sp.declination)

    observerGeodX = :math.cos(observerGd.latitude) * :math.cos(observerGd.longitude)
    observerGeodY = :math.cos(observerGd.latitude) * :math.sin(observerGd.longitude)
    observerGeodZ = :math.sin(observerGd.latitude)

    position =  (ecfc_x_plane * observerGeodX) +
                (ecfc_y_plane * observerGeodY) +
                (ecfc_z_plane * observerGeodZ)

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
