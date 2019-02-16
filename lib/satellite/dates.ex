defmodule Satellite.Dates do
  require Satellite.Constants
  alias Satellite.{Constants, Math}

  @doc """
  Converts a time represented in epoch time to
  %{month, day, hour, minute, second} format.

  This format comes from the two line element(TLE) set format,
  which provides a reference for all other time-based fields in
  the data.

  See the following for a detailed explanation:
  https://celestrak.com/columns/v04n03/#FAQ02

  ## Examples

        iex> Satellite.Dates.epoch_time_to_mdhms(131, 349.872256942)
        %{day: 15, hr: 20, minute: 56, mon: 12, second: 2.9997887981517124}
  """
  def epoch_time_to_mdhms(year, days) do
    # Find month and day of month
    dayofyr = days |> Float.floor() |> trunc
    {day, month} = day_and_month(year, dayofyr)

    # Find minutes and seconds
    temp = (days - dayofyr) * 24.0
    hr = temp |> Float.floor() |> trunc
    temp = (temp - hr) * 60.0
    minute = temp |> Float.floor() |> trunc
    sec = (temp - minute) * 60.0

    %{
      mon: month,
      day: day,
      hr: hr,
      minute: minute,
      second: sec
    }
  end

  defp day_and_month(year, julian_day) when is_number(julian_day) do
    months =
      [31] ++
        [days_in_february(year)] ++
        [31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    total_days_in_year = Enum.sum(months)

    if total_days_in_year < julian_day do
      raise "There are only #{total_days_in_year} days in the year, " <>
              "but #{julian_day} was given!"
    end

    # start with the julian day, and iteratively subtract the days
    # in each month. When the remaining days become less than a full month
    # then we know we found the right month.x
    day_and_month(julian_day, months)
  end

  defp day_and_month(days_remaining, [days_this_month | _] = day_list)
       when days_remaining <= days_this_month do
    # The count of remaining days isn't enough to fill the current month, so
    # we are done. The fractional days remaining become the days, and we
    # count the remaining months to figure out which month we are in.
    {days_remaining, 12 - Enum.count(day_list) + 1}
  end

  defp day_and_month(days_remaining, [days_this_month | remaining_months]) do
    # Subtract the days in the current month and move to the next month
    day_and_month(days_remaining - days_this_month, remaining_months)
  end

  defp days_in_february(year) do
    if :calendar.is_leap_year(year), do: 29, else: 28
  end

  @doc """
  Converts a gregorian date to julian date
  ## Examples

        iex> Satellite.Dates.jday({{2016, 8, 6}, {17, 35, 12}})
        2457607.2327777776
  """
  def jday({{year, month, day}, {hour, min, sec}}) do
    #  ut in days
    367.0 * year -
      Float.floor(7 * (year + Float.floor((month + 9) / 12.0)) * 0.25) +
      Float.floor(275 * month / 9.0) + day + 1_721_013.5 +
      ((sec / 60.0 + min) / 60.0 + hour) /
        24.0
  end

  @doc """
  Converts a julian date to greenwich mean sidereal time (GMST)
  ## Examples

        iex> jd = Satellite.Dates.jday({{2016, 8, 6}, {17, 35, 12}})
        iex> Satellite.Dates.julian_to_gmst(jd)
        3.8307254407191067
  """
  def julian_to_gmst(jdut1) do
    tut1 = (jdut1 - 2_451_545.0) / 36_525.0
    # 24_110.54841 + 86_40_184.812866 * T + 0.093104 * T^2 - 0.0000062 * T^3
    # temp = 24_110.54841 + 8_640_184.812866 * tut1 + 0.093104 * (tut1 * tut1) - (0.000062 * tut1 * tut1 * tut1)
    # sec
    temp =
      -6.2e-6 * tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 +
        (876_600.0 * 3600 + 8_640_184.812866) * tut1 + 67_310.54841

    # 360/86400 = 1/240, to deg, to rad
    temp = Math.mod(temp * Constants.deg2rad() / 240.0, Constants.two_pi())

    #  ------------------------ check quadrants ---------------------
    if temp < 0.0, do: temp + Constants.two_pi(), else: temp
  end

  @doc """
  Converts a datetime to greenwich mean sidereal time
  """
  def utc_to_gmst({{_year, _month, _day}, {_hour, _min, _sec}} = input_date_utc) do
    input_date_utc
    # convert to julian date
    |> jday
    # then convert to gmst
    |> julian_to_gmst
  end
end
