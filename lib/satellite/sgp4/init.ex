#
# sgp4init
#

defmodule Satellite.SGP4.Init do
  require Satellite.Constants
  alias Satellite.{Constants, Dates, SGP4}

  def init(satrec, init_parameters) do
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

    # sgp4fix -
    # note the following variables are also passed directly via satrec.
    # it is possible to streamline the sgp4init call by deleting the "x"
    # variables, but the user would need to set the satrec.* values first. we
    # include the additional assignments in case twoline2rv is not used.

    satrec = %{satrec | bstar: xbstar}
    #put_in(satrec.bstar, xbstar)
    satrec = %{satrec | ecco: xecco}
    satrec = %{satrec | argpo: xargpo}
    satrec = %{satrec | inclo: xinclo}
    satrec = %{satrec | mo: xmo}
    satrec = %{satrec | no: xno}
    satrec = %{satrec | nodeo: xnodeo}

    # sgp4fix add opsmode
    satrec = %{satrec | operationmode: opsmode}

    # ------------------------ earth constants -----------------------
    # sgp4fix identify constants and allow alternate values

    ss = 78.0 / Constants.earth_radius_semimajor + 1.0
    qzms2ttemp = (120.0 - 78.0) / Constants.earth_radius_semimajor
    qzms2t = qzms2ttemp * qzms2ttemp * qzms2ttemp * qzms2ttemp
    x2o3 = 2.0 / 3.0

    satrec = %{satrec | init: 'y'}
    satrec = %{satrec | t: 0.0}

    initialization_parameters = %{
            satn: satn,
            ecco: satrec.ecco,
            epoch: epoch,
            inclo: satrec.inclo,
            no: satrec.no,
            method: satrec.method,
            opsmode: satrec.operationmode
        }

      initialization_results = initl(initialization_parameters)

      satrec = %{satrec | no: initialization_results.no}

      ao = initialization_results.ao
      satrec = %{satrec | con41: initialization_results.con41}
      con42 = initialization_results.con42
      cosio = initialization_results.cosio
      cosio2 = initialization_results.cosio2
      _eccsq = initialization_results.eccsq
      omeosq = initialization_results.omeosq
      posq = initialization_results.posq
      rp = initialization_results.rp
      rteosq = initialization_results.rteosq
      sinio = initialization_results.sinio

      satrec = %{satrec | gsto: initialization_results.gsto}
      satrec = %{satrec | error: 0}

      if omeosq >= 0.0 || satrec.no >= 0.0 do

        isimp =
         if rp < 220.0 / Constants.earth_radius_semimajor + 1.0, do: 1, else: 0

        satrec = %{satrec | isimp: isimp}

        sfour = ss
        qzms24 = qzms2t
        perige = (rp - 1.0) * Constants.earth_radius_semimajor

        # TODO NEED TO TEST THIS REFACTORING
        #  - for perigees below 156 km, s and qoms2t are altered -
        #if (perige < 156.0) do
        #    sfour = perige - 78.0
        #    if (perige < 98.0) do
        #        sfour = 20.0
        #    end
        #    #  sgp4fix use multiply for speed instead of pow
        #    qzms24temp =  (120.0 - sfour) / Constants.earth_radius_semimajor
        #    qzms24 = qzms24temp * qzms24temp * qzms24temp * qzms24temp
        #    sfour = sfour / Constants.earth_radius_semimajor + 1.0
        #end
        {sfour, qzms24} = adjust_for_low_perigee(perige, sfour, qzms24)

        pinvsq = 1.0 / posq

        tsi = 1.0 / (ao - sfour)
        satrec = %{satrec | eta: ao * satrec.ecco * tsi}
        etasq = satrec.eta * satrec.eta
        eeta = satrec.ecco * satrec.eta
        psisq = abs(1.0 - etasq)
        coef = qzms24 * :math.pow(tsi, 4.0)
        coef1 = coef / :math.pow(psisq, 3.5)
        cc2 = coef1 * satrec.no * (ao *
              (1.0 + 1.5 * etasq + eeta * (4.0 + etasq)) +
              0.375 * Constants.j2 * tsi / psisq * satrec.con41 *
              (8.0 + 3.0 * etasq * (8.0 + etasq)))
        satrec = %{satrec | cc1: satrec.bstar * cc2}

        cc3 =
         if satrec.ecco > 1.0e-4 do
          -2.0 * coef * tsi * Constants.j3oj2 * satrec.no * sinio / satrec.ecco
         else
          0.0
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
        # xpidot =  satrec.argpdot+ satrec.nodedot
        satrec = %{satrec | omgcof: satrec.bstar * cc3 * :math.cos(satrec.argpo)}
        satrec = %{satrec | xmcof: 0.0}

        xmcof =
         if satrec.ecco > 1.0e-4 do
          -x2o3 * coef * satrec.bstar / eeta
         else
          satrec.xmcof
         end

        satrec = %{satrec | xmcof: xmcof}
        satrec = %{satrec | nodecf: 3.5 * omeosq * xhdot1 * satrec.cc1}
        satrec = %{satrec | t2cof: 1.5 * satrec.cc1}

        xlcof =
         if abs(cosio + 1.0) > 1.5e-12 do
          -0.25 * Constants.j3oj2 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)
         else
          -0.25 * Constants.j3oj2 * sinio * (3.0 + 5.0 * cosio) / temp4
         end

        satrec = %{satrec | xlcof: xlcof}
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
        satrec = if satrec.isimp === 1 do
          satrec
        else
          new_satrec = satrec
          cc1sq = new_satrec.cc1 * new_satrec.cc1
          new_satrec = %{new_satrec | d2: 4.0 * ao * tsi * cc1sq}
          temp = new_satrec.d2 * tsi * new_satrec.cc1 / 3.0
          new_satrec = %{new_satrec | d3: (17.0 * ao + sfour) * temp}
          new_satrec = %{new_satrec | d4: 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * new_satrec.cc1}
          new_satrec = %{new_satrec | t3cof: new_satrec.d2 + 2.0 * cc1sq}
          new_satrec = %{new_satrec | t4cof: 0.25 * (3.0 * new_satrec.d3 + new_satrec.cc1 * (12.0 * new_satrec.d2 + 10.0 * cc1sq))}
          new_satrec = %{new_satrec | t5cof: 0.2 * (3.0 * new_satrec.d4 +
                          12.0 * new_satrec.cc1 * new_satrec.d3 +
                          6.0 * new_satrec.d2 * new_satrec.d2 +
                          15.0 * cc1sq * (2.0 * new_satrec.d2 + cc1sq))}
          new_satrec
        end

        results = SGP4.calculate(satrec, 0.0)
        satrec = %{results.satrec | init: 'n'}
        {:ok, satrec}

      end
  end

  def initl(initialization_parameters) do
    ecco = initialization_parameters.ecco
    epoch = initialization_parameters.epoch
    inclo = initialization_parameters.inclo
    no = initialization_parameters.no
    # method is unused
    #method = initialization_parameters.method
    opsmode = initialization_parameters.opsmode

    #  ------------- calculate auxillary epoch quantities ----------
    eccsq = ecco * ecco
    omeosq = 1.0 - eccsq
    rteosq = :math.sqrt(omeosq)
    cosio = :math.cos(inclo)
    cosio2 = cosio * cosio

    #  ------------------ un-kozai the mean motion -----------------
    ak = :math.pow(Constants.xke / no, Constants.x2o3)
    d1 = 0.75 * Constants.j2 * (3.0 * cosio2 - 1.0) / (rteosq * omeosq)
    del_prime = d1 / (ak * ak)
    adel = ak * (1.0 - del_prime * del_prime - del_prime *
        (1.0 / 3.0 + 134.0 * del_prime * del_prime / 81.0))
    del_prime = d1 / (adel * adel)
    no = no / (1.0 + del_prime)
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
    gsto =
      if opsmode === 'a' do
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
        if gsto < 0.0, do: gsto + Constants.two_pi, else: gsto
      else
        gsto = Dates.julian_to_gmst(epoch + 2_433_281.5)
      end

    %{
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
  end

  defp adjust_for_low_perigee(perige, _sfour, _qzms24) when perige < 156.0 do
    #  - for perigees below 156 km, s and qoms2t are altered -
    sfour = perige - 78.0
    sfour = if perige < 98.0, do: 20.0, else: sfour

    #  sgp4fix use multiply for speed instead of pow
    qzms24temp =  (120.0 - sfour) / Constants.earth_radius_semimajor
    qzms24 = qzms24temp * qzms24temp * qzms24temp * qzms24temp
    sfour = sfour / Constants.earth_radius_semimajor + 1.0
    {sfour, qzms24}
  end

  defp adjust_for_low_perigee(_perige, sfour, qzms24), do: {sfour, qzms24}
end
