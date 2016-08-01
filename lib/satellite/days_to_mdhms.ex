defmodule Satellite.DaysToMDHMS do
  def days2mdhms(year, days) do
    dayofyr = days |> Float.floor |> trunc
    {dayTemp, month} = day_and_month(year, dayofyr)
    day = dayofyr - dayTemp
    temp = (days - dayofyr) * 24.0
    hr = temp |> Float.floor |> trunc
    temp = (temp - hr) * 60.0
    minute = temp |> Float.floor |> trunc
    sec = (temp - minute) * 60.0

    mdhms = %{
      mon: month,
      day: day,
      hr: hr,
      minute: minute,
      second: sec
    }
  end

  def day_and_month(year, dayofyr) do
    lmonth = [31] ++ [days_in_februrary(year)] ++ [31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    [head | tail] = lmonth
    day_and_month(dayofyr, head, tail)
  end

  defp days_in_februrary(year) when rem(year, 4) === 0 , do: 29
  defp days_in_februrary(_year),                         do: 28

  defp _day_and_month(dayofyr, daysToAdd, [days_this_month | remaining_months])
      when (dayofyr > daysToAdd + days_this_month),
      do: day_and_month(dayofyr, daysToAdd + days_this_month, remaining_months)

  defp day_and_month(_dayofyr, daysToAdd, []),       do: {daysToAdd, 12}
  defp day_and_month(_dayofyr, daysToAdd, dayList),  do: {daysToAdd, 12 - Enum.count(dayList) + 1}

end
