defmodule Observer do
  require Satellite.Constants
  alias Satellite.Constants

  defstruct [:latitude_rad,
            :longitude_rad,
            :latitude_deg,
            :longitude_deg,
            :height_km]

  def create_from(latitude_degrees, longitude_degrees, height_km) do
    %Observer{
      latitude_deg: latitude_degrees,
      longitude_deg: longitude_degrees,
      latitude_rad: latitude_degrees * Constants.deg2rad,
      longitude_rad: longitude_degrees * Constants.deg2rad,
      height_km: height_km}
  end

end
