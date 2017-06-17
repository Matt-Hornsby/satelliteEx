defmodule Satellite.Dates do
  import Satellite.Math
  require Satellite.Constants
  alias Satellite.Constants

  #
  # DaysToMDHMS
  #
  def days2mdhms(year, days) do
    dayofyr = days |> Float.floor |> trunc
    {dayTemp, month} = day_and_month(year, dayofyr)
    day = dayofyr - dayTemp
    temp = (days - dayofyr) * 24.0
    hr = temp |> Float.floor |> trunc
    temp = (temp - hr) * 60.0
    minute = temp |> Float.floor |> trunc
    sec = (temp - minute) * 60.0

    %{
      mon: month,
      day: day,
      hr: hr,
      minute: minute,
      second: sec
    }
  end

  defp day_and_month(year, dayofyr) do
    lmonth = [31] ++ [days_in_februrary(year)] ++ [31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    [head | tail] = lmonth
    day_and_month(dayofyr, head, tail)
  end

  defp days_in_februrary(year) when rem(year, 4) === 0 , do: 29
  defp days_in_februrary(_year),                         do: 28

  defp day_and_month(_dayofyr, daysToAdd, []),       do: {daysToAdd, 12}
  defp day_and_month(_dayofyr, daysToAdd, dayList),  do: {daysToAdd, 12 - Enum.count(dayList) + 1}


  @doc """
  Converts a gregorian date to julian date
  ## Examples

        iex> Satellite.Dates.jday(2016, 8, 6, 17, 35, 12)
        2457607.2327777776
  """
  def jday(year, mon, day, hr, minute, sec) do
    367.0 * year -
      Float.floor((7 * (year + Float.floor((mon + 9) / 12.0))) * 0.25) +
      Float.floor(275 * mon / 9.0) + day + 1721013.5 + ((sec / 60.0 + minute) / 60.0 + hr)
      / 24.0 #  ut in days
  end

  @doc """
  Converts a julian date to greenwich sidereal angle (GST)
  ## Examples

        iex> jd = Satellite.Dates.jday(2016, 8, 6, 17, 35, 12)
        iex> Satellite.Dates.gstime(jd)
        3.8307254407191067
  """
  def gstime(jdut1) do
    tut1 = (jdut1 - 2451545.0) / 36525.0
    # 24110.54841 + 8640184.812866 * T + 0.093104 * T^2 - 0.0000062 * T^3
    # temp = 24110.54841 + 8640184.812866 * tut1 + 0.093104 * (tut1 * tut1) - (0.000062 * tut1 * tut1 * tut1)
    temp = -6.2e-6* tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 + (876600.0*3600 + 8640184.812866) * tut1 + 67310.54841  # #  sec
    temp = mod((temp * Constants.deg2rad / 240.0), Constants.two_pi) # 360/86400 = 1/240, to deg, to rad

    #  ------------------------ check quadrants ---------------------
    cond do
      (temp < 0.0) -> temp + Constants.two_pi
      true -> temp
    end
  end
end