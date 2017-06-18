defmodule Observer do
require Satellite.Constants
  defstruct [:latitude, :longitude, :height]

  def create_from(latitude_degrees, longitude_degrees, height_km) do
    %Observer{latitude: latitude_degrees, longitude: longitude_degrees, height: height_km}
    |> to_radians
  end

  defp to_radians(%Observer{} = observer) do
    observer = %{observer | longitude: observer.longitude * Satellite.Constants.deg2rad}
    %{observer | latitude: observer.latitude * Satellite.Constants.deg2rad}
  end
end
