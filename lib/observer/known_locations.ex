defmodule Observer.KnownLocations do
  @moduledoc """
  Creates observer structs for commonly-used locations, big cities, etc.

  These are mostly to make it easier for users that are manually typing in commands
  but could eventually be built into something more generically useful.

  ## Examples

    iex> Observer.KnownLocations.seattle
    
  """

  def seattle(), do: Observer.create_from(47.6062, -122.3321, 0.370)
  def london(),  do: Observer.create_from(51.528558, -0.2417011, 0.008)
end
