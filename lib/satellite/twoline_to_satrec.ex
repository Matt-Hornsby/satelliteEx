defmodule Twoline_To_Satrec do

  @opsmode 'i'
  @xpdotp 1440.0 / (2.0 * Constants.pi()) # 229.1831180523293


  def twoline_to_satrec(tle_line_1, tle_line_2) do
    IO.puts @xpdotp

    tle1 = Satellite.extract_tle1(tle_line_1)
    tle2 = Satellite.extract_tle2(tle_line_2)

    satrec = %Satrec{}
    satrec = %{satrec | satnum: tle1.satellite_number}
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

    sgp4_init_parameters =
      %{
        opsmode: @opsmode,
        satn: satrec.satnum,
        epoch: (satrec.jdsatepoch - 2433281.5),
        xbstar: satrec.bstar,
        xecco: satrec.ecco,
        xargpo: satrec.argpo,
        xinclo: satrec.inclo,
        xmo: satrec.mo,
        xno: satrec.no,
        xnodeo: satrec.nodeo
      }

      sgp4init(satrec, sgp4_init_parameters)

  end

  def epoch_year(year) when year < 57,  do: 2000 + year
  def epoch_year(year),                 do: 1990 + year

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
    367.0 * year -
    Float.floor((7 * (year + Float.floor((mon + 9) / 12.0))) * 0.25) +
    Float.floor(275 * mon / 9.0) +
    day + 1721013.5 +
    ((sec / 60.0 + minute) / 60.0 + hr) / 24.0 #  ut in days
  end

  defp sgp4init(satrec, init_parameters) do

    opsmode = init_parameters.opsmode
    satn    = init_parameters.satn
    epoch   = init_parameters.epoch

    xbstar  = init_parameters.xbstar
    xecco   = init_parameters.xecco
    xargpo  = init_parameters.xargpo

    xinclo  = init_parameters.xinclo
    xmo     = init_parameters.xmo
    xno     = init_parameters.xno

    xnodeo  = init_parameters.xnodeo

    #------------------------ initialization ---------------------
    # sgp4fix divisor for divide by zero check on inclination
    # the old check used 1.0 + Math.cos(pi-1.0e-9), but then compared it to
    # 1.5 e-12, so the threshold was changed to 1.5e-12 for consistency

    temp4 = 1.5e-12

    # sgp4fix - note the following variables are also passed directly via satrec.
    # it is possible to streamline the sgp4init call by deleting the "x"
    # variables, but the user would need to set the satrec.* values first. we
    # include the additional assignments in case twoline2rv is not used.

    satrec = %{satrec | bstar: xbstar}
    satrec = %{satrec | ecco: xecco}
    satrec = %{satrec | argpo: xargpo}
    satrec = %{satrec | inclo: xinclo}
    satrec = %{satrec | mo: xmo}
    satrec = %{satrec | no: xno}
    satrec = %{satrec | nodeo: xnodeo}

    # sgp4fix add opsmode\
    satrec = %{satrec | operationmode: opsmode}

    # ------------------------ earth constants -----------------------
    # sgp4fix identify constants and allow alternate values

    ss = 78.0 / Constants.earth_radius + 1.0
    qzms2ttemp = (120.0 - 78.0) / Constants.earth_radius
    qzms2t = qzms2ttemp * qzms2ttemp * qzms2ttemp * qzms2ttemp
    x2o3 = 2.0 / 3.0

    satrec = %{satrec | init: 'y'}
    satrec = %{satrec | t: 0.0}

    initlParameters = %{
            satn: satn,
            ecco: satrec.ecco,
            epoch: epoch,
            inclo: satrec.inclo,
            no: satrec.no,
            method: satrec.method,
            opsmode: satrec.operationmode
        }

      # Stopped at line 217 in sgp4init.js

  end

end
