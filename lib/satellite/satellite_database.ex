defmodule Satellite.SatelliteDatabase do
  use GenServer
  require Logger

  @tles ["Visual", "Amateur"]

  ## Client API

  @doc """
  Starts the database.
  """
  def start_link do
    Logger.info "Starting satellite database"
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def lookup(satellite_name) when is_binary(satellite_name) do
    GenServer.call(__MODULE__, {:lookup, satellite_name})
  end
  def lookup(number) when is_integer(number) do
    GenServer.call(__MODULE__, {:lookup_number, number})
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

 ## Server API

  def init(:ok) do
    # Open and parse file
    satellites = @tles |> Enum.map(&load_tle(&1)) |> List.flatten
    {:ok, satellites}
  end

  def handle_call({:lookup, name}, _from, satellites) do
    satellite = Enum.find(satellites, &(&1.name == name))
    {:reply, satellite, satellites}
  end
  def handle_call({:lookup_number, number}, _from, satellites) do
    satellite = Enum.find(satellites, &(&1.satnum == number))
    {:reply, satellite, satellites}
  end

  def handle_call(:list, _from, satellites) do
    {:reply, satellites, satellites}
  end

  ## Private

  defp load_tle(tle_name) do
    case Satellite.Celestrak.download_tle(tle_name) do
      {:ok, body} ->
        body    
        |> String.split("\n")
        |> parse_tle_stream
      _ ->
        Logger.warn("Error getting Celestrak TLE '#{tle_name}.txt'; using local copy")
        File.stream!("tle/#{tle_name}.txt") |> parse_tle_stream
    end
  end

  defp parse_tle_stream(tle_stream) do
    tle_stream
    |> Stream.chunk(3)
    |> Enum.map(&parse_entry/1)
    |> Enum.map(&entry_to_satrec/1)
  end

  defp parse_entry(tle_lines) do
    [satellite_name, tle_line_1, tle_line_2] = tle_lines

    {
      String.trim(satellite_name),
      String.trim(tle_line_1),
      String.trim(tle_line_2)
    }
  end

  defp entry_to_satrec({name, tle1, tle2}) do
    {:ok, satrec} = Satellite.TLE.to_satrec(tle1, tle2)
    %{satrec | name: name}
  end
end
