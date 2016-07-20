defmodule Twoline_To_Satrec do

  @opsmode 'i'
  @xpdotp 1440.0 / (2.0 * Constants.pi()) # 229.1831180523293


  def twoline_to_satrec(tle_line_1, tle_line_2) do
    IO.puts @xpdotp

    tle1 = Satellite.extract_tle1(tle_line_1)
    tle2 = Satellite.extract_tle2(tle_line_2)

    satrec = %Satrec{}
    satrec = %{satrec | satname: tle1.satellite_number}
    satrec = %{satrec | epochyr: tle1.epoch_year}
    satrec = %{satrec | epochdays: tle1.epoch}
    satrec = %{satrec | ndot: tle1.first_deriviative}
    satrec = %{satrec | nddot: tle1.second_deriviative}
    satrec = %{satrec | bstar: tle1.bstar_drag}

    #elnum = tle1.element_set

    satrec = %{satrec | inclo: tle2.inclination}
    satrec = %{satrec | nodeo: tle2.right_ascension}
    satrec = %{satrec | ecco: tle2.eccentricity}
    satrec = %{satrec | argpo: tle2.perigee}
    satrec = %{satrec | mo: tle2.mean_anomaly}
    satrec = %{satrec | no: tle2.mean_motion / @xpdotp}

    #revnum = tle2.revolutions

    satrec = %{satrec | a: :math.pow(satrec.no * Constants.tumin, (-2.0 / 3.0))}
    satrec = %{satrec | ndot: satrec.ndot / (@xpdotp * 1440.0)}
    satrec = %{satrec | ndot: satrec.nddot / (@xpdotp * 1440.0 * 1440.0)}
    satrec = %{satrec | inclo: satrec.inclo * Constants.degtorad()}
    satrec = %{satrec | nodeo: satrec.nodeo * Constants.degtorad()}
    satrec = %{satrec | argpo: satrec.argpo * Constants.degtorad()}
    satrec = %{satrec | mo: satrec.mo * Constants.degtorad()}
    satrec = %{satrec | alta: satrec.a * (1.0 + satrec.ecco) - 1.0}
    satrec = %{satrec | altp: satrec.a * (1.0 - satrec.ecco) - 1.0}

    year = epoch_year(satrec.epochyr)
    mdhms_result = days2mdhms(year, satrec.epochdays)
    mon = mdhms_result.mon
    day = mdhms_result.day
    hr = mdhms_result.hr
    minute = mdhms_result.minute
    sec = mdhms_result.second

    satrec = %{satrec | jdsatepoch: jday(year, mon, day, hr, minute, sec)}

    # Stopped at line 128 in twoline2satrec.js
  end

  def epoch_year(year) when year < 57,  do: 2000 + year
  def epoch_year(year),                 do: 1990 + year

  def days2mdhms(year, days) do
    dayofyr = Float.floor(days) |> trunc |> IO.inspect
    {dayTemp, month} = day_and_month(year, dayofyr)
    day = dayofyr - dayTemp
    temp = (days - dayofyr) * 24.0
    hr = Float.floor(temp) |> trunc
    temp = (temp - hr) * 60.0
    minute = Float.floor(temp) |> trunc
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
    #lmonth = cond do
    #  rem(year, 4) === 0 -> [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    #  true               -> [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    #end

    lmonth = [31] ++ [days_in_februrary(year)] ++ [31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    [head | tail] = lmonth
    _day_and_month(dayofyr, head, tail)
  end

  def days_in_februrary(year) when rem(year, 4) === 0 , do: 29
  def days_in_februrary(_year),                         do: 28

  defp _day_and_month(dayofyr, daysToAdd, [days_this_month | remaining_months])
      when (dayofyr > daysToAdd + days_this_month),
      do: _day_and_month(dayofyr, daysToAdd + days_this_month, remaining_months)

  defp _day_and_month(_dayofyr, daysToAdd, []),       do: {daysToAdd, 12}
  defp _day_and_month(_dayofyr, daysToAdd, dayList),  do: {daysToAdd, 12 - Enum.count(dayList) + 1}

  defp jday(year, mon, day, hr, minute, sec) do
    367.0 * year - Float.floor((7 * (year + Float.floor((mon + 9) / 12.0))) * 0.25) + Float.floor(275 * mon / 9.0) + day + 1721013.5 + ((sec / 60.0 + minute) / 60.0 + hr) / 24.0 #  ut in days
  end

end
