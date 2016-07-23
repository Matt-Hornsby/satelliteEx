defmodule Twoline_To_Satrec do

  @opsmode 'i'
  @xpdotp 1440.0 / (2.0 * Constants.pi()) # 229.1831180523293


  def twoline_to_satrec(tle_line_1, tle_line_2) do

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

  def jday(year, mon, day, hr, minute, sec) do
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

      initlResult = initl(initlParameters)

      satrec = %{satrec | no: initlResult.no}

      ao = initlResult.ao
      satrec = %{satrec | con41: initlResult.con41}
      con42 = initlResult.con42
      cosio = initlResult.cosio
      cosio2 = initlResult.cosio2
      eccsq = initlResult.eccsq
      omeosq = initlResult.omeosq
      posq = initlResult.posq
      rp = initlResult.rp
      rteosq = initlResult.rteosq
      sinio = initlResult.sinio

      satrec = %{satrec | gsto: initlResult.gsto}
      satrec = %{satrec | error: 0}

      if (omeosq >= 0.0 || satrec.no >= 0.0) do
        satrec = %{satrec | isimp: 0}
        if (rp < 220.0 / Constants.earth_radius + 1.0) do
          satrec = %{satrec | isimp: 1}
        end
        sfour = ss
        qzms24 = qzms2t
        perige = (rp - 1.0) * Constants.earth_radius

        #  - for perigees below 156 km, s and qoms2t are altered -
        if (perige < 156.0) do
            sfour = perige - 78.0
            if (perige < 98.0) do
                sfour = 20.0
            end
            #  sgp4fix use multiply for speed instead of pow
            qzms24temp =  (120.0 - sfour) / Constants.earth_radius
            qzms24 = qzms24temp * qzms24temp * qzms24temp * qzms24temp
            sfour = sfour / Constants.earth_radius + 1.0
        end
        pinvsq = 1.0 / posq

        tsi = 1.0 / (ao - sfour)
        satrec = %{satrec | eta: ao * satrec.ecco * tsi}
        etasq = satrec.eta * satrec.eta
        eeta = satrec.ecco * satrec.eta
        psisq = abs(1.0 - etasq)
        coef = qzms24 * :math.pow(tsi, 4.0)
        coef1 = coef / :math.pow(psisq, 3.5)
        cc2 = coef1 * satrec.no * (ao * (1.0 + 1.5 * etasq + eeta *
                    (4.0 + etasq)) + 0.375 * Constants.j2 * tsi / psisq * satrec.con41 *
                    (8.0 + 3.0 * etasq * (8.0 + etasq)))
        satrec = %{satrec | cc1: satrec.bstar * cc2}
        cc3 = 0.0
        if (satrec.ecco > 1.0e-4) do
          cc3 = -2.0 * coef * tsi * Constants.j3oj2 * satrec.no * sinio / satrec.ecco
        end

        satrec = %{satrec | x1mth2: 1.0 - cosio2}
        satrec = %{satrec | cc4: 2.0 * satrec.no * coef1 * ao * omeosq *
                            (satrec.eta * (2.0 + 0.5 * etasq) + satrec.ecco *
                            (0.5 + 2.0 * etasq) - Constants.j2 * tsi / (ao * psisq) *
                            (-3.0 * satrec.con41 * (1.0 - 2.0 * eeta + etasq *
                            (1.5 - 0.5 * eeta)) + 0.75 * satrec.x1mth2 *
                            (2.0 * etasq - eeta * (1.0 + etasq)) * :math.cos(2.0 * satrec.argpo)))}
        satrec = %{satrec | cc5: 2.0 * coef1 * ao * omeosq * (1.0 + 2.75 *
                            (etasq + eeta) + eeta * etasq)}
        cosio4 = cosio2 * cosio2
        temp1 = 1.5 * Constants.j2 * pinvsq * satrec.no
        temp2 = 0.5 * temp1 * Constants.j2 * pinvsq
        temp3 = -0.46875 * Constants.j4 * pinvsq * pinvsq * satrec.no
        satrec = %{satrec | mdot: satrec.no + 0.5 * temp1 * rteosq * satrec.con41 + 0.0625 *
                            temp2 * rteosq * (13.0 - 78.0 * cosio2 + 137.0 * cosio4)}
        satrec = %{satrec | argpdot: (-0.5 * temp1 * con42 + 0.0625 * temp2 *
                            (7.0 - 114.0 * cosio2 + 395.0 * cosio4) +
                            temp3 * (3.0 - 36.0 * cosio2 + 49.0 * cosio4))}
        xhdot1 = -temp1 * cosio
        satrec = %{satrec | nodedot: xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * cosio2) +
                            2.0 * temp3 * (3.0 - 7.0 * cosio2)) * cosio}
        xpidot =  satrec.argpdot+ satrec.nodedot
        satrec = %{satrec | omgcof: satrec.bstar * cc3 * :math.cos(satrec.argpo)}
        satrec = %{satrec | xmcof: 0.0}
        if (satrec.ecco > 1.0e-4) do
          satrec = %{satrec | xmcof: -x2o3 * coef * satrec.bstar / eeta}
        end
        satrec = %{satrec | nodecf: 3.5 * omeosq * xhdot1 * satrec.cc1}
        satrec = %{satrec | t2cof: 1.5 * satrec.cc1}
        if (abs(cosio+1.0) > 1.5e-12) do
          satrec = %{satrec | xlcof: -0.25 * Constants.j3oj2 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)}
        else
          satrec = %{satrec | xlcof: -0.25 * Constants.j3oj2 * sinio * (3.0 + 5.0 * cosio) / temp4}
        end

        satrec = %{satrec | aycof: -0.5 * Constants.j3oj2 * sinio}
        delmotemp = 1.0 + satrec.eta * :math.cos(satrec.mo)
        satrec = %{satrec | delmo: delmotemp * delmotemp * delmotemp}
        satrec = %{satrec | sinmao: :math.sin(satrec.mo)}
        satrec = %{satrec | x7thm1: 7.0 * cosio2 - 1.0}

        #  --------------- deep space initialization -------------
        # TODO: Implement deep space initialization.
        # I don't think this is needed for earth-orbiting satellites
        # so I am blowing it off for now (it's hundreds of lines of code that I don't have a good way of testing at the moment)
        # The code starts on line 331 in sgp4init.js

        #----------- set variables if not deep space -----------
        if (satrec.isimp !== 1) do
            cc1sq = satrec.cc1 * satrec.cc1
            satrec = %{satrec | d2: 4.0 * ao * tsi * cc1sq}
            temp = satrec.d2 * tsi * satrec.cc1 / 3.0
            satrec = %{satrec | d3: (17.0 * ao + sfour) * temp}
            satrec = %{satrec | d4: 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * satrec.cc1}
            satrec = %{satrec | t3cof: satrec.d2 + 2.0 * cc1sq}
            satrec = %{satrec | t4cof: 0.25 * (3.0 * satrec.d3 + satrec.cc1 * (12.0 * satrec.d2 + 10.0 * cc1sq))}
            satrec = %{satrec | t5cof: 0.2 * (3.0 * satrec.d4 +
                            12.0 * satrec.cc1 * satrec.d3 +
                            6.0 * satrec.d2 * satrec.d2 +
                            15.0 * cc1sq * (2.0 * satrec.d2 + cc1sq))}
        end

        results = sgp4(satrec, 0.0)
        satrec = %{results.satrec | init: 'n'}
        {:ok, satrec}

      end

  end

  def sgp4(satrec, tsince) do
    temp4 = 1.5e-12
    vkmpersec = Constants.earth_radius * Constants.xke / 60.0

    satrec = %{satrec | t: tsince}
    satrec = %{satrec | error: 0}

    #  ------- update for secular gravity and atmospheric drag -----
    xmdf = satrec.mo + satrec.mdot * satrec.t
    argpdf = satrec.argpo + satrec.argpdot * satrec.t
    nodedf = satrec.nodeo + satrec.nodedot * satrec.t
    argpm = argpdf
    mm = xmdf
    t2 = satrec.t * satrec.t
    nodem = nodedf + satrec.nodecf * t2
    tempa = 1.0 - satrec.cc1 * satrec.t
    tempe = satrec.bstar * satrec.cc4 * satrec.t
    templ = satrec.t2cof * t2
    if (satrec.isimp !== 1) do
        delomg = satrec.omgcof * satrec.t
        #  sgp4fix use mutliply for speed instead of pow
        delmtemp = 1.0 + satrec.eta * :math.cos(xmdf)
        delm = satrec.xmcof * (delmtemp * delmtemp * delmtemp - satrec.delmo)
        temp = delomg + delm
        mm = xmdf + temp
        argpm = argpdf - temp
        t3 = t2 * satrec.t
        t4 = t3 * satrec.t
        tempa = tempa - satrec.d2 * t2 - satrec.d3 * t3 - satrec.d4 * t4
        tempe = tempe + satrec.bstar * satrec.cc5 * (:math.sin(mm) - satrec.sinmao)
        templ = templ + satrec.t3cof * t3 + t4 * (satrec.t4cof + satrec.t * satrec.t5cof)
    end
    nm = satrec.no
    em = satrec.ecco
    inclm = satrec.inclo

    if (satrec.method === 'd') do
      # TODO: Implement deep space logic - line 174-237 in sgp4.js
    end

    if (nm <= 0.0) do
      satrec = %{satrec | error: 2}
      # TODO: Handle this in a more idiomatic way
      {:err, 2, satrec}
      raise "Error 2"
    end

    am = :math.pow((Constants.xke / nm), Constants.x2o3) * tempa * tempa
    nm = Constants.xke / :math.pow(am, 1.5)
    em = em - tempe

    #  fix tolerance for error recognition
    #  sgp4fix am is fixed from the previous nm check
    if (em >= 1.0 || em < -0.001) do
      satrec = %{satrec | error: 1}
      # TODO: Handle this in a more idiomatic way
      {:err, 1, satrec}
      raise "Error 1"
    end

    if (em < 1.0e-6), do: em = 1.0e-6

    mm = mm + satrec.no * templ
    xlm = mm + argpm + nodem
    emsq = em * em
    temp = 1.0 - emsq

    nodem = mod(nodem, Constants.two_pi)
    argpm = mod(argpm, Constants.two_pi)
    xlm = mod(xlm, Constants.two_pi)
    mm = mod(xlm - argpm - nodem, Constants.two_pi)

    #  ----------------- compute extra mean quantities -------------
    sinim = :math.sin(inclm)
    cosim = :math.cos(inclm)

    #  -------------------- add lunar-solar periodics --------------
    ep = em
    xincp = inclm
    argpp = argpm
    nodep = nodem
    mp = mm
    sinip = sinim
    cosip = cosim

    if (satrec.method === 'd') do
      # TODO: Skipping more deep space logic for now - line 282-313 in sgp4.js
    end

    # -------------------- long period periodics ------------------
    if (satrec.method === 'd') do
      # TODO: Skipping more deep space logic for now - line 315-326 in sgp4.js
    end

    axnl = ep * :math.cos(argpp)
    temp = 1.0 / (am * (1.0 - ep * ep))
    aynl = ep * :math.sin(argpp) + temp * satrec.aycof
    xl = mp + argpp + nodep + temp * satrec.xlcof * axnl

    #  --------------------- solve kepler's equation ---------------
    u = mod((xl - nodep), Constants.two_pi)
    eo1 = u
    tem5 = 9999.9
    ktr = 1

    {sineo1, coseo1} = iterate_kepler(tem5, ktr, eo1, axnl, aynl, u, 0.0, 0.0)

    #  ------------- short period preliminary quantities -----------
    ecose = axnl * coseo1 + aynl * sineo1
    esine = axnl * sineo1 - aynl * coseo1
    el2 = axnl * axnl + aynl * aynl
    pl = am * (1.0 - el2)

    if (pl < 0.0) do
      satrec = %{satrec | error: 4}
      # TODO: Handle this in a more idiomatic way
      {:err, 4, satrec}
      raise "Error 4"
    end

    rl = am * (1.0 - ecose)
    rdotl = :math.sqrt(am) * esine / rl
    rvdotl = :math.sqrt(pl) / rl
    betal = :math.sqrt(1.0 - el2)
    temp = esine / (1.0 + betal)
    sinu = am / rl * (sineo1 - aynl - axnl * temp)
    cosu = am / rl * (coseo1 - axnl + aynl * temp)
    su = :math.atan2(sinu, cosu)
    sin2u = (cosu + cosu) * sinu
    cos2u = 1.0 - 2.0 * sinu * sinu
    temp = 1.0 / pl
    temp1 = 0.5 * Constants.j2 * temp
    temp2 = temp1 * temp

    #  -------------- update for short period periodics ------------
    if (satrec.method === 'd') do
        cosisq = cosip * cosip
        satrec = %{satrec | con41: 3.0 * cosisq - 1.0}
        satrec = %{satrec | x1mth2: 1.0 - cosisq}
        satrec = %{satrec | x7thm1: 7.0 * cosisq - 1.0}
    end

    mrt = rl * (1.0 - 1.5 * temp2 * betal * satrec.con41) + 0.5 * temp1 * satrec.x1mth2 * cos2u
    su = su - 0.25 * temp2 * satrec.x7thm1 * sin2u
    xnode = nodep + 1.5 * temp2 * cosip * sin2u
    xinc = xincp + 1.5 * temp2 * cosip * sinip * cos2u
    mvt = rdotl - nm * temp1 * satrec.x1mth2 * sin2u / Constants.xke
    rvdot = rvdotl + nm * temp1 * (satrec.x1mth2 * cos2u + 1.5 * satrec.con41) / Constants.xke

    #  --------------------- orientation vectors -------------------
    sinsu = :math.sin(su)
    cossu = :math.cos(su)
    snod = :math.sin(xnode)
    cnod = :math.cos(xnode)
    sini = :math.sin(xinc)
    cosi = :math.cos(xinc)
    xmx = -snod * cosi
    xmy = cnod * cosi
    ux = xmx * sinsu + cnod * cossu
    uy = xmy * sinsu + snod * cossu
    uz = sini * sinsu
    vx = xmx * cossu - cnod * sinsu
    vy = xmy * cossu - snod * sinsu
    vz = sini * cossu

    #  --------- position and velocity (in km and km/sec) ----------
    r = %{x: 0.0, y: 0.0, z: 0.0}
    r = %{r | x: (mrt * ux) * Constants.earth_radius}
    r = %{r | y: (mrt * uy) * Constants.earth_radius}
    r = %{r | z: (mrt * uz) * Constants.earth_radius}

    v = %{x: 0.0, y: 0.0, z: 0.0}
    v = %{v | x: (mvt * ux + rvdot * vx) * vkmpersec}
    v = %{v | y: (mvt * uy + rvdot * vy) * vkmpersec}
    v = %{v | z: (mvt * uz + rvdot * vz) * vkmpersec}

    #  sgp4fix for decaying satellites
    if (mrt < 1.0) do
      satrec = %{satrec | error: 6}
      # TODO: Handle this in a more idiomatic way
      {:err, 6, satrec}
      raise "Error 6"
    end

    %{satrec: satrec, position: r, velocity: v}

  end

  def propagate(satrec, year, month, day, hour, minute, second) do
    #Return a position and velocity vector for a given date and time.
    j = jday(year, month, day, hour, minute, second)
    m = (j - satrec.jdsatepoch) * Constants.minutes_per_day
    sgp4(satrec, m)
  end

  def iterate_kepler(tem5, ktr, eo1, axnl, aynl, u, sineo1, coseo1) when abs(tem5) > 1.0e-12 and ktr <= 10 do
    sineo1 = :math.sin(eo1)
    coseo1 = :math.cos(eo1)
    tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
    tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
    if (abs(tem5) >= 0.95) do
        if (tem5 > 0.0) do
            tem5 = 0.95
        else
            tem5 = -0.95
        end
    end

    iterate_kepler(tem5, ktr + 1, eo1 + tem5, axnl, aynl, u, sineo1, coseo1)
  end

  def iterate_kepler(_tem5, _ktr, _eo1, _axnl, _aynl, _u, sineo1, coseo1), do: {sineo1, coseo1}

  def dspace(dspaceParameters) do
    # TODO: Skipping this for now, since I don't have a good way to test yet
  end

  def initl(initlParameters) do
    ecco = initlParameters.ecco
    epoch = initlParameters.epoch
    inclo = initlParameters.inclo
    no = initlParameters.no
    method = initlParameters.method
    opsmode = initlParameters.opsmode

    #  ------------- calculate auxillary epoch quantities ----------
    eccsq = ecco * ecco
    omeosq = 1.0 - eccsq
    rteosq = :math.sqrt(omeosq)
    cosio = :math.cos(inclo)
    cosio2 = cosio * cosio

    #  ------------------ un-kozai the mean motion -----------------
    ak = :math.pow(Constants.xke / no, Constants.x2o3)
    d1 = 0.75 * Constants.j2 * (3.0 * cosio2 - 1.0) / (rteosq * omeosq)
    delPrime = d1 / (ak * ak)
    adel = ak * (1.0 - delPrime * delPrime - delPrime *
        (1.0 / 3.0 + 134.0 * delPrime * delPrime / 81.0))
    delPrime = d1 / (adel * adel)
    no = no / (1.0 + delPrime)
    ao = :math.pow(Constants.xke / no, Constants.x2o3)
    sinio = :math.sin(inclo)
    po = ao * omeosq
    con42 = 1.0 - 5.0 * cosio2
    con41 = -con42 - cosio2 - cosio2
    ainv = 1.0 / ao
    posq = po * po
    rp = ao * (1.0 - ecco)
    method = 'n'

    #  sgp4fix modern approach to finding sidereal time
    if (opsmode === 'a') do
      #  sgp4fix use old way of finding gst
      #  count integer number of days from 0 jan 1970
      ts70 = epoch - 7305.0
      ds70 = Float.floor(ts70 + 1.0e-8)
      tfrac = ts70 - ds70
      #  find greenwich location at epoch
      c1 = 1.72027916940703639e-2
      thgr70 = 1.7321343856509374
      fk5r = 5.07551419432269442e-15
      c1p2p = c1 + Constants.two_pi
      gsto = rem(thgr70 + c1 * ds70 + c1p2p * tfrac + ts70 * ts70 * fk5r, Constants.two_pi)
      if (gsto < 0.0) do
          gsto = gsto + Constants.two_pi
      end

    else
      gsto = gstime(epoch + 2433281.5)
    end

    initlResults = %{
            no: no,
            method: method,
            ainv: ainv,
            ao: ao,
            con41: con41,
            con42: con42,
            cosio: cosio,
            cosio2: cosio2,
            eccsq: eccsq,
            omeosq: omeosq,
            posq: posq,
            rp: rp,
            rteosq: rteosq,
            sinio: sinio,
            gsto: gsto
        }
    initlResults
  end

  def gstime(jdut1) do
    tut1 = (jdut1 - 2451545.0) / 36525.0
    temp = -6.2e-6* tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 +
        (876600.0*3600 + 8640184.812866) * tut1 + 67310.54841  # #  sec
    temp = mod((temp * Constants.deg2rad / 240.0), Constants.two_pi) # 360/86400 = 1/240, to deg, to rad

    #  ------------------------ check quadrants ---------------------
    if (temp < 0.0) do
        temp = temp + Constants.two_pi
    end
    temp
  end

  def mod(numer, denom), do: numer - trunc(numer/denom) * denom

end
