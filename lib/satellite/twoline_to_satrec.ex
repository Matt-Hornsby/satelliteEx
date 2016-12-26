defmodule Satellite.Twoline_To_Satrec do
  import Satellite.DaysToMDHMS
  import Satellite.DatetimeConversions
  import Satellite.SGP4Init

  @opsmode 'i'
  @xpdotp 1440.0 / (2.0 * Constants.pi()) # 229.1831180523293


  def twoline_to_satrec(tle_line_1, tle_line_2) do

    tle1 = extract_tle1(tle_line_1)
    tle2 = extract_tle2(tle_line_2)

    satrec = %Satrec{}
    satrec = %{satrec | satnum: String.to_integer(tle1.satellite_number)}
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

  #def dspace(dspaceParameters) do
    # TODO: Skipping this for now, since I don't have a good way to test yet
  #end

  def extract_tle1(tle_line_1) do
    #tle_line_1 = "1 25544U 98067A   13149.87225694  .00009369  00000-0  16828-3 0  9031"
    <<
      line_number         :: binary-size(1),
      0x20,
      satellite_number    :: binary-size(5),
      classification      :: binary-size(1),
      0x20,
      launch_year         :: binary-size(2),
      launch_number       :: binary-size(3),
      piece_of_launch     :: binary-size(3),
      0x20,
      epoch_year          :: binary-size(2),
      epoch               :: binary-size(12),
      0x20,
      first_deriviative   :: binary-size(10),
      0x20,
      second_deriviative  :: binary-size(8),
      0x20,
      bstar_drag          :: binary-size(8),
      0x20,
      ephemeris_type      :: binary-size(1),
      0x20,
      element_set         :: binary-size(4),
      checksum            :: binary-size(1)
    >> = tle_line_1

    #IO.puts "Line number: #{line_number}"
    #IO.puts "Satellite number: #{satellite_number}"
    #IO.puts "Classification: #{classification}"
    #IO.puts "Launch year: #{launch_year}"
    #IO.puts "Launch number: #{launch_number}"
    #IO.puts "Launch piece: #{piece_of_launch}"
    #IO.puts "Epoch year: #{epoch_year}"
    #IO.puts "Epoch: #{epoch}"
    #IO.puts "First deriviative: #{first_deriviative}"
    #IO.puts "Second deriviative: #{second_deriviative}"
    #IO.puts "Bstar drag: #{bstar_drag}"
    #IO.puts "Ephemeris type: #{ephemeris_type}"
    #IO.puts "Element set: #{element_set}"
    #IO.puts "Checksum: #{checksum}"

    %{
      line_number: String.to_integer(line_number),
      satellite_number: satellite_number,
      classification: classification,
      launch_year: String.to_integer(launch_year),
      launch_number: String.to_integer(launch_number),
      piece_of_launch: String.trim(piece_of_launch),
      epoch_year: String.to_integer(epoch_year),
      epoch: String.to_float(epoch),
      first_deriviative: first_deriviative |> Satellite.Math.string_to_float,
      second_deriviative: second_deriviative |> String.trim |> Satellite.Math.from_fortran_float,
      bstar_drag: bstar_drag |> String.trim |> Satellite.Math.from_fortran_float,
      ephemeris_type: String.to_integer(ephemeris_type),
      element_set: element_set |> String.trim |> String.to_integer,
      checksum: String.to_integer(checksum)
    }
  end

  def extract_tle2(tle_line_2) do
    #tle_line_2 = "2 25544 051.6485 199.1576 0010128 012.7275 352.5669 15.50581403831869"
    <<
      line_number         :: binary-size(1),
      0x20,
      satellite_number    :: binary-size(5),
      0x20,
      inclination         :: binary-size(8),
      0x20,
      right_ascension     :: binary-size(8),
      0x20,
      eccentricity        :: binary-size(7),
      0x20,
      perigee             :: binary-size(8),
      0x20,
      mean_anomaly        :: binary-size(8),
      0x20,
      mean_motion         :: binary-size(11),
      revolutions         :: binary-size(5),
      checksum            :: binary-size(1)
    >> = tle_line_2

    #IO.puts "Line number: #{line_number}"
    #IO.puts "Satellite number: #{satellite_number}"
    #IO.puts "Inclination: #{inclination}"
    #IO.puts "Right ascension of the ascending node: #{right_ascension}"
    #IO.puts "Eccentricity: #{eccentricity}"
    #IO.puts "Argument of Perigee: #{perigee}"
    #IO.puts "Mean anomaly (degrees): #{mean_anomaly}"
    #IO.puts "Mean motion (revolutions per day): #{mean_motion}"
    #IO.puts "Revolutions: #{revolutions}"
    #IO.puts "Checksum: #{checksum}"

    %{
      line_number: line_number |> String.trim |> String.to_integer,
      satellite_number: satellite_number,
      inclination: inclination |> String.trim |> String.to_float,
      right_ascension: right_ascension |> String.trim |> String.to_float,
      eccentricity: "0." <> String.trim(eccentricity) |> String.to_float,
      perigee: perigee |> String.trim |> String.to_float,
      mean_anomaly: mean_anomaly |> String.trim |> String.to_float,
      mean_motion: mean_motion |> String.trim |> String.to_float,
      revolutions: revolutions |> String.trim |> String.to_integer,
      checksum: checksum |> String.trim |> String.to_integer
    }
  end


end
