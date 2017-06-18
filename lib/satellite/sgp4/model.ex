#
# spg4
#

defmodule Satellite.SGP4.Model do
  require Satellite.Constants
  alias Satellite.Constants
  import Satellite.{Math, Dates}

  def calculate(satrec, tsince) do
    #temp4 = 1.5e-12
    vkmpersec = Constants.earth_radius_semimajor * Constants.xke / 60.0

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

    {tempa, tempe, templ, mm, argpm} = if satrec.isimp === 1 do
      {tempa, tempe, templ, mm, argpm}
    else
      delomg = satrec.omgcof * satrec.t
      #  sgp4fix use mutliply for speed instead of pow
      delmtemp = 1.0 + satrec.eta * :math.cos(xmdf)
      delm = satrec.xmcof * (delmtemp * delmtemp * delmtemp - satrec.delmo)
      temp = delomg + delm
      mm_new = xmdf + temp
      argpm_new = argpdf - temp
      t3 = t2 * satrec.t
      t4 = t3 * satrec.t

      tempa_new = tempa - satrec.d2 * t2 - satrec.d3 * t3 - satrec.d4 * t4
      tempe_new = tempe + satrec.bstar * satrec.cc5 * (:math.sin(mm_new) - satrec.sinmao)
      templ_new = templ + satrec.t3cof * t3 + t4 * (satrec.t4cof + satrec.t * satrec.t5cof)

      {tempa_new, tempe_new, templ_new, mm_new, argpm_new}
    end

    nm = satrec.no
    em = satrec.ecco
    inclm = satrec.inclo

    if (satrec.method === 'd') do
      # TODO: Implement deep space logic - line 174-237 in sgp4.js
    end

    if (nm <= 0.0) do
      # satrec = %{satrec | error: 2}
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
      # satrec = %{satrec | error: 1}
      # TODO: Handle this in a more idiomatic way
      {:err, 1, satrec}
      raise "Error 1"
    end

    em = max(1.0e-6, em)

    mm = mm + satrec.no * templ
    xlm = mm + argpm + nodem
    #emsq = em * em
    #temp = 1.0 - emsq

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
      # satrec = %{satrec | error: 4}
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
    satrec = if (satrec.method === 'd') do
        cosisq = cosip * cosip
        %{satrec | con41: 3.0 * cosisq - 1.0,
          x1mth2: 1.0 - cosisq,
          x7thm1: 7.0 * cosisq - 1.0}
      else
        satrec
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
    r = %{r | x: (mrt * ux) * Constants.earth_radius_semimajor}
    r = %{r | y: (mrt * uy) * Constants.earth_radius_semimajor}
    r = %{r | z: (mrt * uz) * Constants.earth_radius_semimajor}

    v = %{x: 0.0, y: 0.0, z: 0.0}
    v = %{v | x: (mvt * ux + rvdot * vx) * vkmpersec}
    v = %{v | y: (mvt * uy + rvdot * vy) * vkmpersec}
    v = %{v | z: (mvt * uz + rvdot * vz) * vkmpersec}

    #  sgp4fix for decaying satellites
    if (mrt < 1.0) do
      # satrec = %{satrec | error: 6}
      # TODO: Handle this in a more idiomatic way
      {:err, 6, satrec}
      raise "Error 6"
    end

    %{satrec: satrec, position: r, velocity: v}
  end

  defp iterate_kepler(tem5, ktr, eo1, axnl, aynl, u, _sineo1, _coseo1) when abs(tem5) > 1.0e-12 and ktr <= 10 do
    sineo1 = :math.sin(eo1)
    coseo1 = :math.cos(eo1)
    tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
    tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
    tem5 = min(max(tem5, -0.95), 0.95)

    iterate_kepler(tem5, ktr + 1, eo1 + tem5, axnl, aynl, u, sineo1, coseo1)
  end

  defp iterate_kepler(_tem5, _ktr, _eo1, _axnl, _aynl, _u, sineo1, coseo1), do: {sineo1, coseo1}

  def propagate(satrec, year, month, day, hour, minute, second) do
    #TODO: THIS NEEDS TO BE UTC TIME!!!

    #Return a position and velocity vector for a given date and time.
    j = jday(year, month, day, hour, minute, second)
    m = (j - satrec.jdsatepoch) * Constants.minutes_per_day
    calculate(satrec, m)
  end
end