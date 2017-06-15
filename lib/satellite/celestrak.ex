defmodule Satellite.Celestrak do
  require Logger
  
  def update_visual_tles, do: save_tle("Visual")
  def update_amateur_tles, do: save_tle("Amateur")

  defp save_tle(tle_name) do
    {:ok, body} = download_tle(tle_name)
    File.write!("tle/#{tle_name}.txt", body)
  end

  def download_tle(tle_name) do
    Application.ensure_all_started :inets

    with {:ok, resp} <- :httpc.request(:get, {'http://www.celestrak.com/NORAD/elements/#{tle_name}.txt', []}, [], [body_format: :binary]),
      {{_, 200, 'OK'}, _headers, body} <- resp
    do
      Logger.info "#{tle_name}: #{String.length(body)} bytes read."
      {:ok, body}
    else
      _ -> :error
    end
  end
end