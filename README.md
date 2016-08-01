# Satellite

This is a satellite prediction library, which will pull TLE records from celestrak (currently.. space-track.org to come) and output satellite pass times for any given time and location.

## Example
```
iex> Satellite.save_tle_from_celestrak("Visual")
iex> Satellite.find_first_pass_for({{2016, 08, 1}, {4,0,0}}, Satellite.seattle_observer, Satellite.iss_satrec)
```
