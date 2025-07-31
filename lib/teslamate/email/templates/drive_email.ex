defmodule TeslaMate.Email.Templates.DriveEmail do
  @moduledoc """
  Drive completion notification email templates
  """

  def generate_html(drive) do
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
        .environment-section .info-row { border-left-color: #20c997; }
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
                <div class="value">#{drive.duration_min} minutes</div>
              </div>
              <div class="stat-box">
                <div class="label">🏎️ Max Speed</div>
                <div class="value">#{drive.speed_max} km/h</div>
              </div>
              <div class="stat-box">
                <div class="label">📊 Avg Speed</div>
                <div class="value">#{Float.round(drive.avg_speed, 1)} km/h</div>
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
                <div class="label">🏁 Start Odometer</div>
                <div class="value">#{Float.round(drive.start_km, 3)} km</div>
              </div>
              <div class="info-row">
                <div class="label">🎯 End Odometer</div>
                <div class="value">#{Float.round(drive.end_km, 3)} km</div>
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

          <div class="section route-section">
            <h3>📍 Route Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🏁 Start Location</div>
                <div class="value">#{if drive.start_geofence, do: drive.start_geofence.name, else: "#{drive.start_address.name}, #{drive.start_address.city}"}</div>
              </div>
              <div class="info-row">
                <div class="label">🎯 End Location</div>
                <div class="value">#{if drive.end_geofence, do: drive.end_geofence.name, else: "#{drive.end_address.name}, #{drive.end_address.city}"}</div>
              </div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Start Ideal Range</div>
                <div class="value">#{drive.start_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 End Ideal Range</div>
                <div class="value">#{drive.end_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 Start Rated Range</div>
                <div class="value">#{drive.start_rated_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 End Rated Range</div>
                <div class="value">#{drive.end_rated_range_km} km</div>
              </div>
            </div>
          </div>

          <div class="section environment-section">
            <h3>🌡️ Environment Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🌡️ Avg Outside Temp</div>
                <div class="value">#{drive.outside_temp_avg}°C</div>
              </div>
              <div class="info-row">
                <div class="label">🌡️ Avg Inside Temp</div>
                <div class="value">#{drive.inside_temp_avg}°C</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🕐 Start Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(drive.start_date)}</div>
              </div>
              <div class="info-row">
                <div class="label">🕙 End Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(drive.end_date)}</div>
              </div>
            </div>
          </div>


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

  def generate_text(drive) do
    """
    New Drive Record - #{drive.car.name}

    📊 Drive Statistics:
    - 📏 Distance: #{Float.round(drive.distance, 3)} km
    - ⏱️ Duration: #{drive.duration_min} minutes
    - 🏎️ Max Speed: #{drive.speed_max} km/h
    - 📊 Avg Speed: #{Float.round(drive.avg_speed, 1)} km/h

    🔋 Power Information:
    - 🔋 Max Power: #{drive.power_max} kW
    - 🔋 Min Power: #{drive.power_min} kW

    📏 Odometer Information:
    - 🏁 Start Odometer: #{Float.round(drive.start_km, 3)} km
    - 🎯 End Odometer: #{Float.round(drive.end_km, 3)} km

    🏔️ Elevation Information:
    - 📈 Total Ascent: #{drive.ascent} m
    - 📉 Total Descent: #{drive.descent} m

    📍 Route Information:
    - 🏁 Start: #{if drive.start_geofence, do: drive.start_geofence.name, else: "#{drive.start_address.name}, #{drive.start_address.city}"}
    - 🎯 End: #{if drive.end_geofence, do: drive.end_geofence.name, else: "#{drive.end_address.name}, #{drive.end_address.city}"}

    🔋 Battery Information:
    - 🔋 Start Ideal Range: #{drive.start_ideal_range_km} km
    - 🔋 End Ideal Range: #{drive.end_ideal_range_km} km
    - 📊 Start Rated Range: #{drive.start_rated_range_km} km
    - 📊 End Rated Range: #{drive.end_rated_range_km} km

    🌡️ Environment Information:
    - 🌡️ Avg Outside Temp: #{drive.outside_temp_avg}°C
    - 🌡️ Avg Inside Temp: #{drive.inside_temp_avg}°C

    ⏰ Time Information:
    - 🕐 Start Time: #{TeslaMate.Email.format_datetime_local(drive.start_date)}
    - 🕙 End Time: #{TeslaMate.Email.format_datetime_local(drive.end_date)}

    ---
    This email was automatically sent by TeslaMate
    Drive Record ID: #{drive.id}
    """
  end
end 