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

    # Stopped at line 3177 in satellite.js
    year = epoch_year(satrec.epochyr)

  end

def epoch_year(year) when year < 57,  do: 2000 + year
def epoch_year(year),                 do: 1990 + year

def days2mdhms(year, days) do
  dayofyr = Float.floor(days) |> trunc |> IO.inspect
  {month, day} = day_and_month(year, dayofyr)

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



end
