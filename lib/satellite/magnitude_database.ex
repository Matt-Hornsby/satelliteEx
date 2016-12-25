defmodule Satellite.MagnitudeDatabase do
  use GenServer

  ## Client API

  @doc """
  Starts the database.
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  @doc """
  Look up the standard magnitude for the satellite with the given norad_id

  Returns `{:ok, magnitude}` if the satellite exists, `{:error, "Not Found"}` otherwise.

  ## Examples

      iex> {:ok, pid} = Satellite.MagnitudeDatabase.start_link
      iex> Satellite.MagnitudeDatabase.lookup(pid, 5)

  """
  def lookup(server, norad_id) do
    GenServer.call(server, {:lookup, norad_id})
  end

  @doc """
  Returns a list of all norad_id values

  ## Examples

      iex> {:ok, pid} = Satellite.MagnitudeDatabase.start_link
      iex> Satellite.MagnitudeDatabase.all_satellites(pid)

  """
  def all_satellites(server) do
    GenServer.call(server, {:all_satellites})
  end

  ## Server Callbacks

  def init(:ok) do
    magnitudes = File.stream!("satmag.txt") |> parse_satmag_stream
    {:ok, magnitudes}
  end

  def handle_call({:all_satellites}, _from, magnitudes) do
    satellites = magnitudes |> Enum.map(&(&1.norad_id))
    {:reply, satellites, magnitudes}
  end

  def handle_call({:lookup, norad_id}, _from, magnitudes) do
    satellite = magnitudes |> Enum.filter(&(&1.norad_id == norad_id)) |> Enum.at(0)
    if satellite == nil do
      {:reply, {:error, "Not found"}, magnitudes}
    else
      {:reply, {:ok, satellite.magnitude}, magnitudes}
    end
  end

  defp parse_satmag_stream(stream) do
    stream |> Enum.map(&parse_magnitude/1)
  end

  defp parse_magnitude(magnitude_line) do
    <<
      norad_id     :: binary-size(5),
      0x20,
      magnitude    :: binary
    >> = magnitude_line

    converted_norad_id = String.to_integer(norad_id)
    {converted_magnitude, _} = Float.parse(magnitude)

    %{
      norad_id: converted_norad_id ,
      magnitude: converted_magnitude
    }
  end

end
