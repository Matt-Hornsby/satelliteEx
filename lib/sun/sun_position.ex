defmodule Sun.SunPosition do
  require Satellite.Constants
  alias Satellite.{Constants, Dates}

  def get_position_at(
        {{_year, _month, _day}, {_hour, _min, _sec}} = input_date,
        observer_latitude,
        observer_longitude
      ) do
    julian_date = Dates.jday(input_date)
    sp = calculate_orbital_coordinates_at(julian_date)
    sidereal_angle = Dates.julian_to_gmst(julian_date)
    sun_longitude = sp.right_ascension - sidereal_angle

    x_plane = :math.cos(sp.declination) * :math.cos(sp.right_ascension)
    y_plane = :math.cos(sp.declination) * :math.sin(sp.right_ascension)
    z_plane = :math.sin(sp.declination)

    ecfc_x_plane = :math.cos(sp.declination) * :math.cos(sun_longitude)
    ecfc_y_plane = :math.cos(sp.declination) * :math.sin(sun_longitude)
    ecfc_z_plane = :math.sin(sp.declination)

    observer_geo_x =
      :math.cos(observer_latitude) *
        :math.cos(observer_longitude)

    observer_geo_y =
      :math.cos(observer_latitude) *
        :math.sin(observer_longitude)

    observer_geo_z = :math.sin(observer_latitude)

    position =
      ecfc_x_plane * observer_geo_x +
        ecfc_y_plane * observer_geo_y +
        ecfc_z_plane * observer_geo_z

    elevation_radians = 90 - :math.acos(position) * Constants.rad2deg()

    %{
      declination: sp.declination,
      right_ascension: sp.right_ascension,
      longitude_degrees: sun_longitude * Constants.rad2deg(),
      longitude_radians: sun_longitude,
      x_plane: x_plane,
      y_plane: y_plane,
      z_plane: z_plane,
      ecfc_x_plane: ecfc_x_plane,
      ecfc_y_plane: ecfc_y_plane,
      ecfc_z_plane: ecfc_z_plane,
      elevation_radians: elevation_radians,
      elevation_degrees: elevation_radians * Constants.rad2deg()
    }
  end

  @doc """
  Approximates the sun's solar coordinates on a given julian date
  """
  def calculate_orbital_coordinates_at(julian_date) do
    # position = %{ra: 0.0, declination: 0.0}
    # 2,451,545 is the julian date on 1/1/2000
    d0 = julian_date - 2_451_545
    m0 = reduce(357.529 + 0.98560028 * d0)
    l0 = reduce(280.459 + 0.98564736 * d0)

    l0 =
      l0 + 1.915 * :math.sin(m0 / 180 * Constants.pi()) +
        0.02 * :math.sin(2 * m0 / 180 * Constants.pi())

    e = reduce(23.439 - 0.00000036 * d0)

    declination =
      :math.asin(
        :math.sin(e / 180 * Constants.pi()) *
          :math.sin(l0 / 180 * Constants.pi())
      )

    right_ascension =
      :math.atan2(
        :math.cos(e / 180 * Constants.pi()) *
          :math.sin(l0 / 180 * Constants.pi()),
        :math.cos(l0 / 180 * Constants.pi())
      )

    right_ascension = correct_for_negative(right_ascension)

    %{right_ascension: right_ascension, declination: declination}
  end

  defp correct_for_negative(right_ascension) when right_ascension < 0,
    do: right_ascension + Constants.two_pi()

  defp correct_for_negative(right_ascension), do: right_ascension

  defp reduce(degrees) when degrees > 360.0, do: reduce(degrees - 360)
  defp reduce(degrees) when degrees < 0.0, do: reduce(degrees + 360)
  defp reduce(degrees), do: degrees
end
