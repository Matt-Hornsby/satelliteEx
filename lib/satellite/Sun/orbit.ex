defmodule Sun.Orbit do
  def calculate_sun_orbit_at(julian_date) do
    position = %{ra: 0.0, declination: 0.0}

    d0 = julian_date - 2451545
    m0 = 357.529 + 0.98560028 * d0 |> reduce
    l0 = 280.459 + 0.98564736 * d0 |> reduce
    l0 = l0 + 1.915 * :math.sin(m0 / 180 * Constants.pi) + 0.02 * :math.sin(2 * m0 / 180 * Constants.pi)

    r = 1.00014 - 0.01671 * :math.cos(m0 / 180 * Constants.pi) - 0.00014 * :math.cos(2 * m0 / 180 * Constants.pi)
    e = 23.439 - 0.00000036 * d0 |> reduce

    declination = :math.asin(:math.sin(e / 180 * Constants.pi) * :math.sin(l0 / 180 * Constants.pi))
    right_ascension = (:math.atan2(
                                    :math.cos(e / 180 * Constants.pi) * :math.sin(l0 / 180 * Constants.pi),
                                    :math.cos(l0 / 180 * Constants.pi)
                                  )
                      ) |> correct_for_negative

    %{right_ascension: right_ascension, declination: declination}
  end

  defp correct_for_negative(right_ascension) when right_ascension < 0, do: right_ascension + Constants.two_pi
  defp correct_for_negative(right_ascension), do: right_ascension

  defp reduce(degrees) when degrees > 360.0, do: reduce(degrees - 360)
  defp reduce(degrees) when degrees < 0.0, do: reduce(degrees + 360)
  defp reduce(degrees), do: degrees

end
