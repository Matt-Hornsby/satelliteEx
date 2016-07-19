defmodule Satellite do

  def not_implemented do
    fn() -> raise("Not implemented") end
  end

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
      first_deriviative: first_deriviative |> string_to_float,
      second_deriviative: second_deriviative |> String.trim |> from_fortran_float,
      bstar_drag: bstar_drag |> String.trim |> from_fortran_float,
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
      line_number: String.to_integer(line_number),
      satellite_number: satellite_number,
      inclination: String.to_float(inclination),
      right_ascension: String.to_float(right_ascension),
      eccentricity: "0." <> eccentricity |> String.to_float,
      perigee: String.to_float(perigee),
      mean_anomaly: String.to_float(mean_anomaly),
      mean_motion: String.to_float(mean_motion),
      revolutions: String.to_integer(revolutions),
      checksum: String.to_integer(checksum)
    }
  end

  def string_to_float(" " <> rest), do: string_to_float(rest)           # trim spaces
  def string_to_float("-." <> rest), do: string_to_float("-0." <> rest) # prepend with 0, negative case
  def string_to_float("." <> rest), do: string_to_float("0." <> rest)   # prepend with 0
  def string_to_float(string), do: String.to_float(string)

  def from_fortran_float(<<mantissa::binary-size(5),"-",exponent::binary-size(1)>>) do
    "0.#{mantissa}e-#{exponent}" |> String.to_float
  end

  def create do
    %{
      :version => "1.0.0",
      :constants => Constants.all(),

      # Coordinate transforms
      :degrees_latitude => not_implemented,
      :degrees_longitude => not_implemented,
      :eci_to_ecf => not_implemented,
      :ecf_to_eci => not_implemented,
      :eci_to_geodetic => not_implemented,
      :ecf_to_look_angles => not_implemented,
      :geodetic_to_ecf => not_implemented,

      :doppler_factor => not_implemented,
      :gstime_from_jday => not_implemented,
      :gstime_from_date => not_implemented,
      :propagate => not_implemented,
      :twoline_to_satrec => fn(tle1, tle2) -> not_implemented end,
      :sgp4 => not_implemented
    }
  end
end
