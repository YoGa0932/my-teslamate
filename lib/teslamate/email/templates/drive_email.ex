defmodule TeslaMate.Email.Templates.DriveEmail do
  @moduledoc """
  Drive completion notification email templates
  """

  def generate_html(drive, map_info \\ nil) do
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
                <div class="value">#{Float.round(drive.distance, 3)} km</div>
              </div>
              <div class="stat-box">
                <div class="label">⏱️ Duration</div>
                <div class="value">#{TeslaMate.Email.format_duration_minutes(drive.duration_min)}</div>
              </div>
              <div class="stat-box">
                <div class="label">🏎️ Max Speed</div>
                <div class="value">#{drive.speed_max} km/h</div>
              </div>
              <div class="stat-box">
                <div class="label">📊 Avg Speed</div>
                <div class="value">#{Float.round(drive.avg_speed, 1)} km/h</div>
              </div>
              <div class="stat-box">
                <div class="label">⚡ Energy Consumption</div>
                <div class="value">#{if drive.energy_consumption_wh_per_km, do: "#{Float.round(drive.energy_consumption_wh_per_km, 1)}", else: "N/A"} Wh/km</div>
              </div>
              <div class="stat-box">
                <div class="label">🔋 Energy Used</div>
                <div class="value">#{if drive.energy_used_kwh, do: "#{Float.round(drive.energy_used_kwh, 3)}", else: "N/A"} kWh</div>
              </div>
              <div class="stat-box">
                <div class="label">📊 Estimated Range</div>
                <div class="value">#{TeslaMate.Email.get_latest_range(drive.car_id)} km</div>
              </div>
              <div class="stat-box">
                <div class="label">💰 Drive Cost</div>
                <div class="value">#{if TeslaMate.Log.calculate_drive_cost(drive), do: "¥#{TeslaMate.Log.calculate_drive_cost(drive)}", else: "N/A"}</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">⏰ Time Period</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(drive.start_date)} - #{TeslaMate.Email.format_datetime_local(drive.end_date)} (Duration: #{drive.duration_min} minutes)</div>
              </div>
            </div>
          </div>

          <div class="section route-section">
            <h3>📍 Route Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📍 Route</div>
                <div class="value">#{case {drive.start_geofence, drive.start_address} do
                  {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
                    start_loc = "#{geofence.name} (#{address.name})"
                    case {drive.end_geofence, drive.end_address} do
                      {end_geofence, end_address} when not is_nil(end_geofence) and not is_nil(end_address) ->
                        "#{start_loc} → #{end_geofence.name} (#{end_address.name})"
                      {nil, end_address} when not is_nil(end_address) ->
                        "#{start_loc} → #{end_address.name}, #{end_address.city}"
                      _ ->
                        "#{start_loc} → Unknown Location"
                    end
                  {nil, address} when not is_nil(address) ->
                    start_loc = "#{address.name}, #{address.city}"
                    case {drive.end_geofence, drive.end_address} do
                      {end_geofence, end_address} when not is_nil(end_geofence) and not is_nil(end_address) ->
                        "#{start_loc} → #{end_geofence.name} (#{end_address.name})"
                      {nil, end_address} when not is_nil(end_address) ->
                        "#{start_loc} → #{end_address.name}, #{end_address.city}"
                      _ ->
                        "#{start_loc} → Unknown Location"
                    end
                  _ ->
                    "Unknown Route"
                end}</div>
              </div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📊 Rated Range Change</div>
                <div class="value">#{TeslaMate.Email.get_range_analysis(drive.start_rated_range_km, drive.end_rated_range_km, drive.distance)}</div>
              </div>
            </div>
          </div>

          <div class="section power-section">
            <h3>⚡ Power Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Max Power</div>
                <div class="value">#{drive.power_max} kW</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 Min Power</div>
                <div class="value">#{drive.power_min} kW</div>
              </div>
            </div>
          </div>

          <div class="section">
            <h3>📏 Odometer Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📏 Odometer Change</div>
                <div class="value">#{Float.round(drive.start_km, 3)} → #{Float.round(drive.end_km, 3)} km</div>
              </div>
            </div>
          </div>

          <div class="section elevation-section">
            <h3>🏔️ Elevation Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📈 Total Ascent</div>
                <div class="value">#{drive.ascent} m</div>
              </div>
              <div class="info-row">
                <div class="label">📉 Total Descent</div>
                <div class="value">#{drive.descent} m</div>
              </div>
            </div>
          </div>

          #{case map_info do
            %{coordinates_processed: processed_count} when not is_nil(processed_count) ->
              map_generation_info = """
              <div class="info-grid">
                <div class="info-row">
                  <div class="label">🗺️ Map Generation</div>
                  <div class="value">Processed #{processed_count} coordinates via Python GPX Animator Service</div>
                </div>
              </div>
              """
              
              """
              <div class="section trajectory-section">
                <h3>🗺️ Drive Trajectory</h3>
                #{map_generation_info}
                <div class="map-container" style="text-align: center; margin: 20px 0;">
                  <img src="data:image/png;base64,#{map_info.image_base64}" 
                       alt="Drive Trajectory" 
                       style="width: 100%; max-width: 800px; height: auto; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);" />
                </div>
              </div>
              """
            _ ->
              ""
          end}

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

  def generate_text(drive, map_info \\ nil) do
    map_generation_text = if map_info && map_info.processing_time_seconds do
      """
      
    🗺️ Map Generation:
    - 📊 Coordinates Processed: #{map_info.coordinates_processed}
    - ⏱️ Processing Time: #{map_info.processing_time_seconds} seconds
    """
    else
      ""
    end

    """
    New Drive Record - #{drive.car.name}

    📊 Drive Statistics:
    - 📏 Distance: #{Float.round(drive.distance, 3)} km
    - ⏱️ Duration: #{TeslaMate.Email.format_duration_minutes(drive.duration_min)}
    - 🏎️ Max Speed: #{drive.speed_max} km/h
    - 📊 Avg Speed: #{Float.round(drive.avg_speed, 1)} km/h
    - ⚡ Energy Consumption: #{if drive.energy_consumption_wh_per_km, do: "#{Float.round(drive.energy_consumption_wh_per_km, 1)}", else: "N/A"} Wh/km
    - 🔋 Energy Used: #{if drive.energy_used_kwh, do: "#{Float.round(drive.energy_used_kwh, 3)}", else: "N/A"} kWh
    - 📊 Estimated Range: #{TeslaMate.Email.get_latest_range(drive.car_id)} km
    - 💰 Drive Cost: #{if TeslaMate.Log.calculate_drive_cost(drive), do: "¥#{TeslaMate.Log.calculate_drive_cost(drive)}", else: "N/A"}

          ⏰ Time Information:
      - 🕐 Start Time: #{TeslaMate.Email.format_datetime_local(drive.start_date)} - 🕙 End Time: #{TeslaMate.Email.format_datetime_local(drive.end_date)} (Duration: #{drive.duration_min} minutes)

    📍 Route Information:
    - 📍 Route: #{case {drive.start_geofence, drive.start_address} do
      {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
        start_loc = "#{geofence.name} (#{address.name})"
        case {drive.end_geofence, drive.end_address} do
          {end_geofence, end_address} when not is_nil(end_geofence) and not is_nil(end_address) ->
            "#{start_loc} → #{end_geofence.name} (#{end_address.name})"
          {nil, end_address} when not is_nil(end_address) ->
            "#{start_loc} → #{end_address.name}, #{end_address.city}"
          _ ->
            "#{start_loc} → Unknown Location"
        end
      {nil, address} when not is_nil(address) ->
        start_loc = "#{address.name}, #{address.city}"
        case {drive.end_geofence, drive.end_address} do
          {end_geofence, end_address} when not is_nil(end_geofence) and not is_nil(end_address) ->
            "#{start_loc} → #{end_geofence.name} (#{end_address.name})"
          {nil, end_address} when not is_nil(end_address) ->
            "#{start_loc} → #{end_address.name}, #{end_address.city}"
          _ ->
            "#{start_loc} → Unknown Location"
        end
      _ ->
        "Unknown Route"
    end}

          🔋 Battery Information:
      - 📊 Rated Range Change: #{TeslaMate.Email.get_range_analysis(drive.start_rated_range_km, drive.end_rated_range_km, drive.distance)}

    ⚡ Power Information:
    - 🔋 Max Power: #{drive.power_max} kW
    - 🔋 Min Power: #{drive.power_min} kW

    📏 Odometer Information:
    - 📏 Odometer Change: #{Float.round(drive.start_km, 3)} → #{Float.round(drive.end_km, 3)} km

    🏔️ Elevation Information:
    - 📈 Total Ascent: #{drive.ascent} m
    - 📉 Total Descent: #{drive.descent} m#{map_generation_text}

    ---
    This email was automatically sent by TeslaMate
    Drive Record ID: #{drive.id}
    """
  end
end 