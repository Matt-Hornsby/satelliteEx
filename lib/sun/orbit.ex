defmodule Sun.Orbit do
  require Satellite.Constants
  alias Satellite.Constants

  def calculate_orbital_coordinates_at(julian_date) do
    # position = %{ra: 0.0, declination: 0.0}

    d0 = julian_date - 2_451_545
    m0 = reduce(357.529 + 0.98560028 * d0)
    l0 = reduce(280.459 + 0.98564736 * d0)
    l0 = l0 + 1.915 * :math.sin(m0 / 180 * Constants.pi) + 0.02 * :math.sin(2 * m0 / 180 * Constants.pi)
    e = reduce(23.439 - 0.00000036 * d0)

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
