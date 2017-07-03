defmodule Observer.KnownLocations do
  def seattle, do: Observer.create_from(47.6062, -122.3321, 0.370)
  def london,  do: Observer.create_from(51.528558, -0.2417011, 0.008)
end
