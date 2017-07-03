defmodule Satellite.SatelliteDatabase do
  @moduledoc """
  This module serves as a system-wide repository of satellite information.
  On startup, this genserver looks for locally-cached copies of satellite TLE
  data, and downloads it from the respective remote data sources (celestrak, amsat, etc)
  when the local cache does not exist or is stale.

  The server will periodically attempt to refresh its data.
  """
  use GenServer
  require Logger

  @source_urls [
    {'http://www.amsat.org/amsat/ftp/keps/current/', 'nasabare.txt'},
    {'http://www.celestrak.com/NORAD/elements/', 'Visual.txt'}
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
    # Set up process to periodically update TLEs if this server runs for a long time
    schedule_tle_update()

    # Download and parse TLEs from sources
    fetch_satellites()
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

  def handle_info(:update_tle, state) do
    Logger.info "Updating tle data on schedule"
    {:ok, satellites} = fetch_satellites()
    schedule_tle_update() # Reschedule
    {:noreply, satellites}
  end

  ## Private

  defp schedule_tle_update do
    next_update = 2 * 60 * 60 * 1000 # In 2 hours (in ms)
    Logger.info "Scheduling next TLE update in 2 hours"
    Process.send_after(self(), :update_tle, next_update)
  end

  defp fetch_satellites do
    sat_map =
      @source_urls
      |> Stream.map(&load_satrecs/1)
      |> Enum.to_list
      |> List.flatten
      |> Enum.map(&{&1.satnum, &1})
      |> Enum.into(%{})

    {:ok, sat_map}
  end

  defp download(tle_url) do
    Application.ensure_all_started :inets

    with {:ok, resp} <- :httpc.request(:get, {tle_url, []}, [], [body_format: :binary]),
      {{_, 200, 'OK'}, _headers, body} <- resp
    do
      Logger.info "#{tle_url}: #{String.length(body)} bytes read."
      {:ok, body}
    else
      _ -> :error
    end
  end

  defp load_satrecs({base_url, filename}) do

    # We're going to try to use a locally cached file, and if it's too old or doesn't exist
    # then we try to get it from the internets.

    file_path = "priv/#{filename}.dat"

    Logger.debug fn -> "Looking for local file #{file_path}" end
    cache_status = cache_status(file_path)

    Logger.debug fn -> "Status of file cache for #{file_path}: #{cache_status}" end
    url = base_url ++ filename

    case cache_status do
       :cache_available ->
         Logger.info "Found up to date cache for #{filename}, skipping update"

       :cache_expired   ->
        with {:ok, body} <- download(url),
              :ok        <- File.write(file_path, body)
        do
          Logger.info "Successfully updated stale cache"
        else
           _ ->
          Logger.warn "Unable to update stale cache! Falling back to old cache. Predictions may be wildly inaccurate!"
        end

       :cache_not_found ->
        with {:ok, body} <- download(url),
              :ok        <- File.write(file_path, body)
        do
          Logger.info "Successfully downloaded remote data and updated local cache"
        else
           _ ->
          raise "Unable to load satellite data from remote data source or local cache. Unable to continue!"
        end
    end

    # If we got here, then a file should exist.
    file_path |> File.read! |> parse_tle_string

  end

  defp cache_status(filename) do
    case File.stat(filename) do
      {:ok, %{mtime: last_modified_time}} ->
        if cache_expired?(last_modified_time), do: :cache_expired, else: :cache_available
      {:error, :enoent} -> :cache_not_found
    end
  end

  defp cache_expired?({{_yr, _mth, _day}, {_hr, _min, _sec}} = last_modified_time, cache_ttl \\ 12) do
    last_modified_time_seconds = :calendar.datetime_to_gregorian_seconds(last_modified_time)
    #Logger.debug("File last modified: #{last_modified_time_seconds}")
    now = :calendar.universal_time() |> :calendar.datetime_to_gregorian_seconds()
    good_until = now + (cache_ttl * 60 * 60)
    #Logger.debug("Cache good until: #{good_until}")
    last_modified_time_seconds >= good_until
  end

  defp parse_tle_string(string) do
    parsed_satrecs =
      string
      |> String.split("\n")
      |> Stream.chunk(3)
      |> Enum.map(&parse_entry/1)
      |> Enum.map(&entry_to_satrec/1)

    for {:ok, satrec} <- parsed_satrecs, do: satrec
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
    case Satellite.TLE.to_satrec(tle1, tle2) do
      {:ok, satrec} ->
        {:ok, put_magnitude(%{satrec | name: name})}
      {:error, :invalid_tle} ->
        Logger.warn("Invalid TLE format for '#{name}'")
        {:error, :invalid_tle}
    end
  end

  defp put_magnitude(satrec) do
    case Satellite.MagnitudeDatabase.lookup(satrec.satnum) do
      {:ok, magnitude} -> %{satrec | magnitude: magnitude}
      _ -> satrec
    end
  end
end
