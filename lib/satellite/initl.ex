defmodule Satellite.Initl do
  import Satellite.DatetimeConversions

  def initl(initlParameters) do
    ecco = initlParameters.ecco
    epoch = initlParameters.epoch
    inclo = initlParameters.inclo
    no = initlParameters.no
    # method is unused
    #method = initlParameters.method
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
    gsto = if (opsmode === 'a') do
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
      cond do
        (gsto < 0.0) -> gsto + Constants.two_pi
        true -> gsto
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
end
