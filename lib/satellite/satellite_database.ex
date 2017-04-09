defmodule Satellite.SatelliteDatabase do
  use GenServer

  ## Client API

  @doc """
  Starts the database.
  """
  def start_link do
    IO.puts "Starting satellite database"
    GenServer.start_link(__MODULE__, :ok, name: :satellite_database)
  end

  def lookup(satellite_name) do
   GenServer.call(:satellite_database, {:lookup, satellite_name})
 end

 ## Server API

 def init(:ok) do
   # Open and parse file
   satellites = "Visual" |> parse_local_tle
  {:ok, satellites}
end

def handle_call({:lookup, satellite_name}, _from, satellites) do
  satellite = satellites
       |> Enum.filter(&(&1.satellite_name == satellite_name))
       |> Enum.at(0)
  {:reply, satellite, satellites}
end

defp parse_local_tle(tle_name) do
  File.stream!("#{tle_name}.txt") |> parse_tle_stream
end

defp parse_tle_stream(tle_stream) do
  tle_stream |> Stream.chunk(3) |> Enum.map(&parse_satellite/1) |> Enum.map(&to_satrec/1)
end

defp parse_satellite(tle_lines) do
  [satellite_name | tail] = tle_lines   # line 1 - satellite name
  [tle_line_1 | tail] = tail            # line 2 - TLE line 1
  [tle_line_2 | []] = tail              # line 3 - TLE line 2

  %{
    satellite_name: String.trim(satellite_name),
    tle_line_1: String.trim(tle_line_1),
    tle_line_2: String.trim(tle_line_2)
  }
end

defp to_satrec(satellite_map) do
  {:ok, satrec} = Satellite.Twoline_To_Satrec.twoline_to_satrec(satellite_map.tle_line_1, satellite_map.tle_line_2)
  %{satellite_name: satellite_map.satellite_name, satrec: satrec}
end

end
