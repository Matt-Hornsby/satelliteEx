defmodule Satellite.CoordinateTransforms do
  require Satellite.Constants
  alias Satellite.Constants

  def eci_to_ecf(eci_coords, gmst) do
    x = (eci_coords.x * :math.cos(gmst)) + (eci_coords.y * :math.sin(gmst))
    y = (eci_coords.x * (-:math.sin(gmst))) + (eci_coords.y * :math.cos(gmst))
    z = eci_coords.z
    %{x: x, y: y, z: z}
  end

  def ecf_to_look_angles(%Observer{latitude_rad: latitude, longitude_rad: longitude} = observerCoordsEcf, satelliteCoordsEcf) do
    observer_ecf = geodetic_to_ecf(observerCoordsEcf)
    rx = satelliteCoordsEcf.x - observer_ecf.x
    ry = satelliteCoordsEcf.y - observer_ecf.y
    rz = satelliteCoordsEcf.z - observer_ecf.z

    top_s = ((:math.sin(latitude) * :math.cos(longitude) * rx) + (:math.sin(latitude) * :math.sin(longitude) * ry) - (:math.cos(latitude) * rz))
    top_e = (-:math.sin(longitude) * rx) + (:math.cos(longitude) * ry)
    top_z = ((:math.cos(latitude) * :math.cos(longitude) * rx) + (:math.cos(latitude) * :math.sin(longitude) * ry) + (:math.sin(latitude) * rz))
    %{top_s: top_s, top_e: top_e, top_z: top_z} |> topocentric_to_look_angles
  end

  defp topocentric_to_look_angles(topocentricCoords) do
    top_s = topocentricCoords.top_s
    top_e = topocentricCoords.top_e
    top_z = topocentricCoords.top_z
    range_sat = :math.sqrt((top_s * top_s) + (top_e * top_e) + (top_z * top_z))
    el = :math.asin(top_z/range_sat)
    az = :math.atan2(-top_e, top_s) + Constants.pi

    %{azimuth_rad: az, azimuth_deg: az * Constants.rad2deg, elevation_rad: el, range_sat: range_sat, elevation_deg: el * Constants.rad2deg}
  end

  # Convert to geocentric (earth centered earth fixed) coordinates
  def geodetic_to_ecf(geodetic_coords) do
    longitude = geodetic_coords.longitude_rad
    latitude = geodetic_coords.latitude_rad
    height = geodetic_coords.height_km
    a = Constants.earth_radius_semimajor
    b = Constants.earth_radius_semiminor
    f = (a - b) / a
    e2 = ((2 * f) - (f * f))
    normal = a / :math.sqrt(1 - (e2 * (:math.sin(latitude) * :math.sin(latitude))))

    x = (normal + height) * :math.cos(latitude) * :math.cos(longitude)
    y = (normal + height) * :math.cos(latitude) * :math.sin(longitude)
    z = ((normal * (1 - e2)) + height) * :math.sin(latitude)
    local_geo_rad = :math.sqrt(x * x + y * y + z * z)
    geo_lat = :math.asin(z / local_geo_rad)
    %{x: x, y: y, z: z, local_geo_rad: local_geo_rad, geo_lat: geo_lat}
  end

  def eci_to_geodetic(eciCoords, gmst) do
    a   = Constants.earth_radius_semimajor
    b   = Constants.earth_radius_semiminor
    r   = :math.sqrt((eciCoords.x * eciCoords.x) + (eciCoords.y * eciCoords.y))
    f   = (a - b) / a
    e2  = ((2 * f) - (f * f))
    longitude = :math.atan2(eciCoords.y, eciCoords.x) - gmst
    # Adding to get sign correct:
    longitude = if longitude < 0, do: longitude + Constants.two_pi, else: longitude
    kmax = 20
    k = 0
    latitude = :math.atan2(eciCoords.z, :math.sqrt(eciCoords.x * eciCoords.x + eciCoords.y * eciCoords.y))

    iteration_params = %{a: a, b: b, c: 0, r: r, f: f, e2: e2, latitude: latitude, eci_z: eciCoords.z}
    result = iterate_latitude(iteration_params, k, kmax)

    height = (r / :math.cos(result.latitude)) - (a * result.c)
    %{longitude: longitude, latitude: result.latitude, height: height}
  end

  def iterate_latitude(iteration_params, k, kmax) when k < kmax do
    c = 1 / :math.sqrt(1 - iteration_params.e2 * (:math.sin(iteration_params.latitude) * :math.sin(iteration_params.latitude)))
    iteration_params = %{iteration_params | c: c, latitude: :math.atan2(iteration_params.eci_z + (iteration_params.a * c * iteration_params.e2 * :math.sin(iteration_params.latitude)), iteration_params.r)}
    iterate_latitude(iteration_params, k + 1, kmax)
  end
  def iterate_latitude(iteration_params, _, _), do: iteration_params

  def iteration_params(iteration_params, _k, _kmax), do: %{a: iteration_params.c, latitude: iteration_params.latitude}
end
