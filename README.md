# SatelliteEx

This is a satellite prediction library that provides satellite pass times for any given time and location. Currently, the application provides data on the following satellites:

**Celestrak 100(or so) brightest** - this contains the satellites that are usually visible to the naked eye, such as the International Space Station

**Amsat** - satellites of interest to radio amateurs. Licensed ham radio operators can make contacts with others via these satellites.

## Installation (via Hex)
The SatelliteEx package can be installed by adding `:satellite_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:satellite_ex, "~> 0.1.2"}
  ]
end
```

## Examples - Finding & setting your location

Most of the examples in this document require a known observer location. Several of these are provided for convenience in the Observer.KnownLocation module. For example:

```elixir
iex> my_location = Observer.KnownLocations.seattle
%Observer{height_km: 0.37, latitude_deg: 47.6062,
 latitude_rad: 0.8308849343629245, longitude_deg: -122.3321,
 longitude_rad: -2.1350979258789553}
 ```

The easiest way to create a custom observer location is to use the Observer.create_from/3 method, which takes normal lat/lon (in degrees) + height (in km):

```elixir

iex> my_location = Observer.create_from(47.6062, -122.2231, 0.37)
%Observer{height_km: 0.37, latitude_deg: 47.6062,
 latitude_rad: 0.8308849343629245, longitude_deg: -122.2231,
 longitude_rad: -2.1331955169942813}
 ```

## Example - List all satellites

To get a list of all satellites that are currently known by the system, you can call `Satellite.SatelliteDatabase.list/0`

This will spit out a lot of information about the satellites, most of which you probably don't care about. Fortunately, it's easy to filter on the fields you care about. Here's how you can see just the names and numbers of each satellite:

```elixir
iex> Satellite.SatelliteDatabase.list |> Enum.map(&({&1.name, &1.satnum})) |> Enum.sort
[{"AAUSAT2", 32788}, {"AAUSAT4", 41460} ...]
```

## Example - Find a specific satellite

Once you know the satellite number, getting the satellite record is easy. Here's the satellite record for the International Space Station (aka ZARYA):

```elixir
iex> satellite = Satellite.SatelliteDatabase.lookup(25_544)
%Satrec{...lots of stuff...}
iex> satellite.name
"ISS (ZARYA)"
```

Or, if you don't happen to know the entire name of a satellite:

```elixir
iex> Satellite.SatelliteDatabase.list |> Enum.filter(&(String.contains?(&1.name, "ISS"))) |> Enum.at(0) |> Map.fetch!(:satnum)
25544
```

Once you have the satrec and a location, you can use it to find future passes.

## Example - Find passes for AO-85

Find the satellite number:

```elixir
iex> Satellite.SatelliteDatabase.list |> Enum.filter(&(String.contains?(&1.name, "AO-85"))) |> Enum.at(0) |> Map.fetch!(:satnum)
40967
```

Get the satrec:

```elixir
iex> satrec = Satellite.SatelliteDatabase.lookup(40_967)
```

Set your location:

```elixir
iex> my_location = Observer.create_from(47.6062, -122.2231, 0.37)
```

Now, list the passes:

```elixir
iex> Satellite.list_passes(satrec, 4, my_location, :calendar.universal_time)
... lots of pass data ...
```

## Example - Next Pass of International Space Station (ISS)

Finding the next pass of the ISS from your location is easy!

```elixir
iex> next_pass = Satellite.find_next_iss_pass(:calendar.universal_time, Observer.KnownLocations.seattle)
iex> next_pass.start_time
{{2017, 7, 8}, {9, 25, 8}}
iex> next_pass.end_time
{{2017, 7, 8}, {9, 26, 26}}
```

The pass details contain a lot of information. In addition to general information about start and end times, you are given more details about four key parts of the pass: AOS (Acquisition of signal - when the satellite first rises over the horizon), LOS (Loss of signal - when the satellite descends below the horizon), and Max(the highest point overhead), and the brightest part of the pass (used for visual sightings)

```elixir
iex> next_pass.aos
iex> next_pass.los
iex> next_pass.max
iex> next_pass.brightest_part_of_pass
...lots of stuff
```
