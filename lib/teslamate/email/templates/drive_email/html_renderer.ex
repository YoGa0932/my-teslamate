defmodule TeslaMate.Email.Templates.DriveEmail.HtmlRenderer do
  @moduledoc """
  Drive email HTML renderer
  """

  alias TeslaMate.Email.Templates.DriveEmail.DriveInfoFormatter

  def render(drive) do
    drive_info = DriveInfoFormatter.format_drive_info(drive)
    map_html = render_map_section(drive.id)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>New Drive Record</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f9f9f9; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 25px; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { padding: 25px; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #333; font-size: 18px; margin-bottom: 15px; border-bottom: 2px solid #667eea; padding-bottom: 5px; }
        .section h3 { color: #555; font-size: 16px; margin-bottom: 12px; }
        .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
        .stat-box { background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); padding: 15px; border-radius: 8px; border-left: 4px solid #667eea; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .stat-box .label { font-weight: bold; color: #333; font-size: 14px; }
        .stat-box .value { color: #667eea; font-size: 16px; font-weight: bold; margin-top: 5px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 15px 0; }
        .info-row { background-color: #f8f9fa; padding: 12px; border-radius: 6px; border-left: 3px solid #28a745; }
        .info-row .label { font-weight: bold; color: #333; font-size: 13px; }
        .info-row .value { color: #666; font-size: 14px; margin-top: 3px; }
        .power-section .info-row { border-left-color: #ffc107; }
        .battery-section .info-row { border-left-color: #17a2b8; }
        .elevation-section .info-row { border-left-color: #6f42c1; }
        .route-section .info-row { border-left-color: #fd7e14; }
        .time-section .info-row { border-left-color: #6c757d; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; border-top: 1px solid #eee; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🚗 New Drive Record</h1>
          <p>Your vehicle <strong>#{drive.car.name}</strong> completed a drive</p>
        </div>

        <div class="content">
          <div class="section">
            <h2>📊 Drive Statistics</h2>
            <div class="stats">
              <div class="stat-box">
                <div class="label">📏 Distance</div>
                <div class="value">#{drive_info.distance}</div>
              </div>
              <div class="stat-box">
                <div class="label">⏱️ Duration</div>
                <div class="value">#{drive_info.duration}</div>
              </div>
              <div class="stat-box">
                <div class="label">🏎️ Max Speed</div>
                <div class="value">#{drive_info.speed_max}</div>
              </div>
              <div class="stat-box">
                <div class="label">📊 Avg Speed</div>
                <div class="value">#{drive_info.avg_speed}</div>
              </div>
              <div class="stat-box">
                <div class="label">⚡ Energy Consumption</div>
                <div class="value">#{drive_info.energy_consumption}</div>
              </div>
              <div class="stat-box">
                <div class="label">🔋 Energy Used</div>
                <div class="value">#{drive_info.energy_used}</div>
              </div>
              <div class="stat-box">
                <div class="label">📊 Estimated Range</div>
                <div class="value">#{drive_info.estimated_range}</div>
              </div>
              <div class="stat-box">
                <div class="label">💰 Drive Cost</div>
                <div class="value">#{drive_info.drive_cost}</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">⏰ Time Period</div>
                <div class="value">#{drive_info.start_time} - #{drive_info.end_time} (Duration: #{drive_info.duration})</div>
              </div>
            </div>
          </div>

          <div class="section route-section">
            <h3>📍 Route Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📍 Route</div>
                <div class="value">#{drive_info.route}</div>
              </div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📊 Rated Range Change</div>
                <div class="value">#{drive_info.range_analysis}</div>
              </div>
            </div>
          </div>

          <div class="section power-section">
            <h3>⚡ Power Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Max Power</div>
                <div class="value">#{drive_info.power_max}</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 Min Power</div>
                <div class="value">#{drive_info.power_min}</div>
              </div>
            </div>
          </div>

          <div class="section">
            <h3>📏 Odometer Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📏 Odometer Change</div>
                <div class="value">#{drive_info.odometer_change}</div>
              </div>
            </div>
          </div>

          <div class="section elevation-section">
            <h3>🏔️ Elevation Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📈 Total Ascent</div>
                <div class="value">#{drive_info.ascent}</div>
              </div>
              <div class="info-row">
                <div class="label">📉 Total Descent</div>
                <div class="value">#{drive_info.descent}</div>
              </div>
            </div>
          </div>

          #{map_html}
        </div>

        <div class="footer">
          <p>This email was automatically sent by TeslaMate</p>
          <p>Drive Record ID: #{drive.id}</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp render_map_section(drive_id) do
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

  defp call_map_service(drive_id) do
    service_url = case System.get_env("MAP_SERVICE_URL") do
      nil -> 
        "http://localhost:5001"
      url when is_binary(url) and byte_size(url) > 0 -> 
        url
      _ ->
        "http://localhost:5001"
    end
    
    request_body = Jason.encode!(%{drive_id: drive_id})
    case Finch.build(:post, "#{service_url}/generate_map", 
         [{"Content-Type", "application/json"}], 
         request_body)
         |> Finch.request(TeslaMate.HTTP, timeout: 30000) do
        
        {:ok, %Finch.Response{status: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"success" => true, "image_base64" => image_base64, "drive_id" => ^drive_id} = map_info} ->
              {:ok, image_base64, map_info}
            {:ok, %{"success" => false, "error" => error}} ->
              {:error, error}
            {:ok, _response} ->
              {:error, "Invalid response format"}
            {:error, _decode_error} ->
              {:error, "Failed to parse response"}
          end
        
        {:ok, %Finch.Response{status: status_code, body: _body}} ->
          {:error, "HTTP #{status_code}"}
        
        {:error, _reason} ->
          {:error, "Connection failed"}
      end
  rescue
    _e ->
      {:error, "Service call failed"}
  end
end 