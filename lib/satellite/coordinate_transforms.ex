defmodule CoordinateTransforms do
  def eci_to_ecf(eci_coords, gmst) do
    x = (eci_coords.x * :math.cos(gmst)) + (eci_coords.y * :math.sin(gmst))
    y = (eci_coords.x * (-:math.sin(gmst))) + (eci_coords.y * :math.cos(gmst))
    z = eci_coords.z
    %{ x: x, y: y, z: z }
  end

  def ecfToLookAngles(observerCoordsEcf, satelliteCoordsEcf) do
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
    %{ topS: topS, topE: topE, topZ: topZ } |> topocentricToLookAngles
  end

  def topocentricToLookAngles(topocentricCoords) do
        topS = topocentricCoords.topS
        topE = topocentricCoords.topE
        topZ = topocentricCoords.topZ
        rangeSat = :math.sqrt((topS*topS) + (topE*topE) + (topZ*topZ))
        el = :math.asin(topZ/rangeSat)
        az = :math.atan2(-topE, topS) + Constants.pi

        %{azimuth: az, elevation: el, rangeSat: rangeSat}
  end

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
    %{ x: x, y: y, z: z}
  end

  def eci_to_geodetic(eciCoords, gmst) do
    a   = 6378.137
    b   = 6356.7523142
    r   = :math.sqrt( (eciCoords.x * eciCoords.x) + (eciCoords.y * eciCoords.y) )
    f   = (a - b)/a
    e2  = ((2 * f) - (f * f))
    longitude = :math.atan2(eciCoords.y, eciCoords.x) - gmst
    kmax = 20
    k = 0
    latitude = :math.atan2(eciCoords.z, :math.sqrt(eciCoords.x * eciCoords.x + eciCoords.y * eciCoords.y))

    iteration_params = %{a: a, b: b, r: r, f: f, e2: e2, longitude: longitude, latitude: latitude, eci_z: eciCoords.z}
    result = iterate_latitude(iteration_params, k, kmax)

    #while (k < kmax) do
    #    c = 1 / :math.sqrt(1 - e2 * (:math.sin(latitude) * :math.sin(latitude)))
    #    latitude = :math.atan2(eciCoords.z + (a * c * e2 * :math.sin(latitude)), r)
    #    k = k + 1
    #end

    height = (r / :math.cos(result.latitude)) - (a * result.c)
    %{longitude: longitude, latitude: result.latitude, height: height }
  end

  def iterate_latitude(iteration_params, k, kmax) when k < kmax do
    c = 1 / :math.sqrt(1 - iteration_params.e2 * (:math.sin(iteration_params.latitude) * :math.sin(iteration_params.latitude)))
    iteration_params = %{iteration_params | latitude: :math.atan2(iteration_params.eci_z + (iteration_params.a * c * iteration_params.e2 * :math.sin(iteration_params.latitude)), iteration_params.r)}
    iterate_latitude(iteration_params, k + 1, kmax)
  end

  def iteration_params(iteration_params, _k, _kmax), do: %{a: iteration_params.c, latitude: iteration_params.latitude}


end
