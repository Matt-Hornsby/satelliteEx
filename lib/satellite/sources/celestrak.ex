defmodule Satellite.Sources.Celestrak do
  # require Logger

  def download(tle_name) do
    Application.ensure_all_started :inets

    with {:ok, resp} <- :httpc.request(:get, {'http://www.celestrak.com/NORAD/elements/#{tle_name}.txt', []}, [], [body_format: :binary]),
      {{_, 200, 'OK'}, _headers, body} <- resp
    do
      # Logger.info "#{tle_name}: #{String.length(body)} bytes read."
      {:ok, body}
    else
      _ -> :error
    end
  end
end