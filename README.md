# SatelliteEx

This is a satellite prediction library that provides satellite pass times for any given time and location. Currently, the application provides data on the following satellites:

**Celestrak 100(or so) brightest** - this contains the satellites that are usually visible to the naked eye, such as the International Space Station (and ISS or Zarya)

**Amsat** - satellites of interest to radio amateurs. Licensed ham radio operators can make contacts with others via these satellites.

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
iex> next_pass.best_part_of_pass
...lots of stuff

```
