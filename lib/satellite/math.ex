defmodule Satellite.Math do
    def mod(numer, denom), do: numer - trunc(numer/denom) * denom

    def string_to_float(" " <> rest), do: string_to_float(rest)           # trim spaces
    def string_to_float("-." <> rest), do: string_to_float("-0." <> rest) # prepend with 0, negative case
    def string_to_float("." <> rest), do: string_to_float("0." <> rest)   # prepend with 0
    def string_to_float(string), do: String.to_float(string)

    def from_fortran_float(<<mantissa::binary-size(5),"-",exponent::binary-size(1)>>) do
      "0.#{mantissa}e-#{exponent}" |> String.to_float
    end

    def from_fortran_float(<<"-",mantissa::binary-size(5),"-", exponent::binary-size(1)>>) do
      "-0.#{mantissa}e-#{exponent}" |> String.to_float
    end

    def from_fortran_float(<<mantissa::binary-size(5),"+", exponent::binary-size(1)>>) do
      "0.#{mantissa}e#{exponent}" |> String.to_float
    end

    def from_fortran_float(<<"-",mantissa::binary-size(5),"+", exponent::binary-size(1)>>) do
      "-0.#{mantissa}e#{exponent}" |> String.to_float
    end

end
