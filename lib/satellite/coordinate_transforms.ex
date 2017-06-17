defmodule Satellite.CoordinateTransforms do
  require Satellite.Constants
  alias Satellite.Constants

  def eci_to_ecf(eci_coords, gmst) do
    x = (eci_coords.x * :math.cos(gmst)) + (eci_coords.y * :math.sin(gmst))
    y = (eci_coords.x * (-:math.sin(gmst))) + (eci_coords.y * :math.cos(gmst))
    z = eci_coords.z
    %{ x: x, y: y, z: z }
  end

  def ecf_to_look_angles(observerCoordsEcf, satelliteCoordsEcf) do
    longitude   = observerCoordsEcf.longitude
    latitude    = observerCoordsEcf.latitude

    # TODO: defined but never used
    # height = observerCoordsEcf.height

    observerEcf = geodetic_to_ecf(observerCoordsEcf)
    rx = satelliteCoordsEcf.x - observerEcf.x
    ry = satelliteCoordsEcf.y - observerEcf.y
    rz = satelliteCoordsEcf.z - observerEcf.z

    topS = ((:math.sin(latitude) * :math.cos(longitude) * rx) + (:math.sin(latitude) * :math.sin(longitude) * ry) - (:math.cos(latitude) * rz))
    topE = (-:math.sin(longitude) * rx) + (:math.cos(longitude) * ry)
    topZ = ((:math.cos(latitude)*:math.cos(longitude)*rx) + (:math.cos(latitude)*:math.sin(longitude)*ry) + (:math.sin(latitude)*rz))
    %{ topS: topS, topE: topE, topZ: topZ } |> topocentric_to_look_angles
  end

  defp topocentric_to_look_angles(topocentricCoords) do
    topS = topocentricCoords.topS
    topE = topocentricCoords.topE
    topZ = topocentricCoords.topZ
    rangeSat = :math.sqrt((topS*topS) + (topE*topE) + (topZ*topZ))
    el = :math.asin(topZ/rangeSat)
    az = :math.atan2(-topE, topS) + Constants.pi

    %{azimuth: az, elevation: el, rangeSat: rangeSat}
  end

  # Convert to geocentric (earth centered earth fixed) coordinates
  def geodetic_to_ecf(geodetic_coords) do
    longitude = geodetic_coords.longitude
    latitude = geodetic_coords.latitude
    height = geodetic_coords.height
    a = 6378.137
    b = 6356.7523142
    f = (a - b)/a
    e2 = ((2*f) - (f*f))
    normal = a / :math.sqrt( 1 - (e2*(:math.sin(latitude)*:math.sin(latitude))))

    x = (normal + height) * :math.cos(latitude) * :math.cos(longitude)
    y = (normal + height) * :math.cos(latitude) * :math.sin(longitude)
    z = ((normal*(1-e2)) + height) * :math.sin(latitude)
    local_geo_rad = :math.sqrt(x * x + y * y + z * z)
    geo_lat = :math.asin(z / local_geo_rad)
    %{ x: x, y: y, z: z, local_geo_rad: local_geo_rad, geo_lat: geo_lat}
  end

  def eci_to_geodetic(eciCoords, gmst) do
    a   = 6378.137
    b   = 6356.7523142
    r   = :math.sqrt( (eciCoords.x * eciCoords.x) + (eciCoords.y * eciCoords.y) )
    f   = (a - b)/a
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
    %{longitude: longitude, latitude: result.latitude, height: height }
  end

  def iterate_latitude(iteration_params, k, kmax) when k < kmax do
    c = 1 / :math.sqrt(1 - iteration_params.e2 * (:math.sin(iteration_params.latitude) * :math.sin(iteration_params.latitude)))
    iteration_params = %{iteration_params | c: c, latitude: :math.atan2(iteration_params.eci_z + (iteration_params.a * c * iteration_params.e2 * :math.sin(iteration_params.latitude)), iteration_params.r)}
    iterate_latitude(iteration_params, k + 1, kmax)
  end
  def iterate_latitude(iteration_params, _, _), do: iteration_params

  def iteration_params(iteration_params, _k, _kmax), do: %{a: iteration_params.c, latitude: iteration_params.latitude}
end
