defmodule TeslaMate.Email.Templates.TrajectoryMap.TrajectoryMapService do
  @moduledoc """
  trajectory map service module for email templates
  """

  require Logger

  @doc """
  Render trajectory map section
  """
  def render_map_section(drive_id) do
    case call_map_service(drive_id) do
      {:ok, base64_image, _map_info} ->
        """
        <div class="section trajectory-section">
          <h3>🗺️ Drive Trajectory</h3>
          <div class="map-container" style="text-align: center; margin: 20px 0;">
            <img src="data:image/png;base64,#{base64_image}" 
                 alt="Drive Trajectory" 
                 style="width: 100%; max-width: 800px; height: auto; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);" />
          </div>
        </div>
        """
      {:error, _reason} ->
        ""
    end
  end

  @doc """
  Call map service to get trajectory image
  """
  def call_map_service(drive_id) do
    service_url = case System.get_env("MAP_SERVICE_URL") do
      nil -> 
        "http://localhost:5001"
      url when is_binary(url) -> 
        url
      _ -> 
        "http://localhost:5001"
    end

    request_body = Jason.encode!(%{
      "drive_id" => drive_id
    })

    case TeslaMate.HTTP.post("#{service_url}/generate_map", request_body, [
      headers: [{"Content-Type", "application/json"}],
      pool_timeout: 30000
    ]) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"image" => base64_image, "map_info" => map_info}} ->
            {:ok, base64_image, map_info}
          {:ok, %{"image" => base64_image}} ->
            {:ok, base64_image, %{}}
          {:error, _reason} ->
            Logger.warning("Failed to parse map service response", drive_id: drive_id)
            {:error, :invalid_response}
        end
      {:ok, %Finch.Response{status: status_code}} ->
        Logger.warning("Map service returned error status", 
          drive_id: drive_id, 
          status_code: status_code
        )
        {:error, :service_error}
      {:error, _reason} ->
        Logger.warning("Failed to call map service", 
          drive_id: drive_id
        )
        {:error, :network_error}
    end
  rescue
    error ->
      Logger.error("Exception in map service call", 
        drive_id: drive_id, 
        error: error
      )
      {:error, :exception}
  end
end 