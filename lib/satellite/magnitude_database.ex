defmodule Satellite.MagnitudeDatabase do
  use GenServer
  require Logger

  ## Client API

  @doc """
  Starts the database.
  """
  def start_link do
    Logger.info("Starting magnitude database")
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Look up the standard magnitude for the satellite with the given norad_id

  Returns `{:ok, magnitude}` if the satellite exists, `{:error, "Not Found"}` otherwise.

  ## Examples

      iex> {:ok, pid} = Satellite.MagnitudeDatabase.start_link
      iex> Satellite.MagnitudeDatabase.lookup(pid, 5)

  """
  def lookup(norad_id) do
    GenServer.call(__MODULE__, {:lookup, norad_id})
  end

  @doc """
  Returns a list of all norad_id values

  ## Examples

      iex> {:ok, pid} = Satellite.MagnitudeDatabase.start_link
      iex> Satellite.MagnitudeDatabase.all_satellites(pid)

  """
  def all_satellites do
    GenServer.call(__MODULE__, {:all_satellites})
  end

  def list do
    GenServer.call(__MODULE__, {:list})
  end

  def get_magnitudes do
    GenServer.call(__MODULE__, {:get_magnitudes})
  end

  ## Server Callbacks

  def init(:ok) do
    magnitudes =
      :satellite_ex
      |> :code.priv_dir()
      |> Path.join("satmag.txt")
      |> File.stream!()
      |> parse_satmag_stream

    map =
      Enum.reduce(magnitudes, %{}, fn x, acc ->
        Map.put(acc, x.norad_id, x.magnitude)
      end)

    {:ok, map}
  end

  def handle_call({:list}, _from, magnitudes) do
    {:reply, magnitudes, magnitudes}
  end

  def handle_call({:get_magnitudes}, _from, magnitudes) do
    {:reply, magnitudes, magnitudes}
  end

  def handle_call({:all_satellites}, _from, magnitudes) do
    {:reply, Map.keys(magnitudes), magnitudes}
  end

  def handle_call({:lookup, norad_id}, _from, magnitudes) do
    magnitude = magnitudes[norad_id]

    if magnitude == nil do
      {:reply, {:error, "Not found"}, magnitudes}
    else
      {:reply, {:ok, magnitude}, magnitudes}
    end
  end

  defp parse_satmag_stream(stream) do
    stream |> Enum.map(&parse_magnitude/1)
  end

  defp parse_magnitude(magnitude_line) do
    <<
      norad_id::binary-size(5),
      0x20,
      magnitude::binary
    >> = magnitude_line

    converted_norad_id = String.to_integer(norad_id)
    {converted_magnitude, _} = Float.parse(magnitude)

    %{
      norad_id: converted_norad_id,
      magnitude: converted_magnitude
    }
  end
end
