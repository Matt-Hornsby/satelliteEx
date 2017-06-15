defmodule Satellite.SatelliteDatabase do
  use GenServer
  require Logger

  @sources [
    {Satellite.Sources.Amsat, []},
    {Satellite.Sources.Celestrak, ["Visual"]},
  ]

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
    # Download and parse TLEs from sources
    sat_map =
      @sources
      |> Stream.map(&load_satrecs/1)
      |> Enum.to_list
      |> List.flatten
      |> Enum.map(&{&1.satnum, &1})
      |> Enum.into(%{})

    {:ok, sat_map}
  end

  def handle_call({:lookup, name}, _from, satellites) do
    satellite = 
      satellites
      |> Map.values
      |> Enum.find(&(&1.name == name))

    {:reply, satellite, satellites}
  end
  def handle_call({:lookup_number, number}, _from, satellites) do
    {:reply, satellites[number], satellites}
  end

  def handle_call(:list, _from, satellites) do
    {:reply, Map.values(satellites), satellites}
  end

  ## Private

  defp load_satrecs({source, args}) do
    with {:ok, body} <- apply(source, :download, args) do
      satrecs = parse_tle_string(body)
      Logger.info("Added #{Enum.count(satrecs)} satellites")
      satrecs
    else
      _ ->
        Logger.warn("Error downloading from #{source}")
        []
    end
  end

  defp parse_tle_string(string) do
    string
    |> String.split("\n")
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
