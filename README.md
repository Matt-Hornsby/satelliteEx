# Satellite

This is a satellite prediction library, which will pull TLE records from celestrak (currently.. space-track.org to come) and output satellite pass times for any given time and location.

## Example
```
iex> Satellite.save_tle_from_celestrak("Visual")
iex> Satellite.find_first_pass_for({{2016, 08, 1}, {4,0,0}}, Satellite.seattle_observer, Satellite.iss_satrec)

%{end_time: %{azimuth: 68.54344247459996,
    datetime: {{2016, 8, 1}, {5, 9, 20}},
    elevation: -0.27661620848155793},  
  start_time: %{azimuth: 259.724672631869,  
    datetime: {{2016, 8, 1}, {4, 58, 30}},  
    elevation: -0.5037607182958416}}
```
