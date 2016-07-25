defmodule Satellite.Math do
    def mod(numer, denom), do: numer - trunc(numer/denom) * denom
end
