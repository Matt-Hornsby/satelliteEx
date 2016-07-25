defmodule Satellite.DatetimeConversions do
  import Satellite.Math

  def jday(year, mon, day, hr, minute, sec) do
    367.0 * year -
    Float.floor((7 * (year + Float.floor((mon + 9) / 12.0))) * 0.25) +
    Float.floor(275 * mon / 9.0) + day + 1721013.5 + ((sec / 60.0 + minute) / 60.0 + hr) / 24.0 #  ut in days
  end

  def gstime(jdut1) do
    tut1 = (jdut1 - 2451545.0) / 36525.0
    temp = -6.2e-6* tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 + (876600.0*3600 + 8640184.812866) * tut1 + 67310.54841  # #  sec
    temp = mod((temp * Constants.deg2rad / 240.0), Constants.two_pi) # 360/86400 = 1/240, to deg, to rad

    #  ------------------------ check quadrants ---------------------

    cond do
      (temp < 0.0) -> temp + Constants.two_pi
      true -> temp
    end

  end
end
