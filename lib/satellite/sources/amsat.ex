defmodule Satellite.Sources.Amsat do
  # require Logger

  @url 'http://www.amsat.org/amsat/ftp/keps/current/nasabare.txt'

  def download do
    Application.ensure_all_started :inets

    with {:ok, resp} <- :httpc.request(:get, {@url, []}, [], [body_format: :binary]),
      {{_, 200, 'OK'}, _headers, body} <- resp
    do
      # Logger.info "AMSAT: #{String.length(body)} bytes read."
      {:ok, body}
    else
      _ -> :error
    end
  end
end