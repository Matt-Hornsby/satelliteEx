defmodule Satellite.Dates do
  import Satellite.Math
  require Satellite.Constants
  alias Satellite.Constants

  @doc """
  Converts a time represented in epoch time to
  %{month, day, hour, minute, second} format.

  This format comes from the two line element(TLE) set format,
  which provides a reference for all other time-based fields in
  the data.

  See the following for a detailed explanation:
  https://celestrak.com/columns/v04n03/#FAQ02

  ## Examples

        iex> Satellite.Dates.epoch_time_to_mdhms(131, 49.872256942)
        %{day: 18, hr: 20, minute: 56, mon: 2, second: 2.9996159999791416}
  """
  def epoch_time_to_mdhms(year, days) do
    dayofyr = days |> Float.floor |> trunc
    {day_temp, month} = day_and_month(year, dayofyr)
    day = dayofyr - day_temp
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
    lmonth = [31] ++ [days_in_february(year)] ++ [31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    [head | tail] = lmonth
    day_and_month(dayofyr, head, tail)
  end

  defp day_and_month(_dayofyr, daysToAdd, []),       do: {daysToAdd, 12}
  defp day_and_month(_dayofyr, daysToAdd, dayList),  do: {daysToAdd, 12 - Enum.count(dayList) + 1}

  defp days_in_february(year) do
    if :calendar.is_leap_year(year), do: 29, else: 28
  end

  @doc """
  Converts a gregorian date to julian date
  ## Examples

        iex> Satellite.Dates.jday(2016, 8, 6, 17, 35, 12)
        2457607.2327777776
  """
  def jday({{year, month, day}, {hour, min, sec}}) do
    367.0 * year -
      Float.floor((7 * (year + Float.floor((month + 9) / 12.0))) * 0.25) +
      Float.floor(275 * month / 9.0) + day + 1_721_013.5 + ((sec / 60.0 + min) / 60.0 + hour)
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
    tut1 = (jdut1 - 2_451_545.0) / 36_525.0
    # 24_110.54841 + 86_40_184.812866 * T + 0.093104 * T^2 - 0.0000062 * T^3
    # temp = 24_110.54841 + 8_640_184.812866 * tut1 + 0.093104 * (tut1 * tut1) - (0.000062 * tut1 * tut1 * tut1)
    temp = -6.2e-6 * tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 + (876_600.0 * 3600 + 8_640_184.812866) * tut1 + 67_310.54841  # sec
    temp = mod((temp * Constants.deg2rad / 240.0), Constants.two_pi) # 360/86400 = 1/240, to deg, to rad

    #  ------------------------ check quadrants ---------------------
    if temp < 0.0, do: temp + Constants.two_pi, else: temp
  end
end
