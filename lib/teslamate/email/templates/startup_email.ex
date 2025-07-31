defmodule TeslaMate.Email.Templates.StartupEmail do
  @moduledoc """
  Startup notification email templates
  """

  def generate_html(info) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>TeslaMate Service Startup Notification</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #28a745; color: white; padding: 20px; border-radius: 5px; }
        .info-section { margin: 20px 0; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
        .info-box { background-color: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }
        .label { font-weight: bold; color: #333; }
        .value { color: #666; margin-top: 5px; }
        .status-ok { color: #28a745; }
        .status-error { color: #dc3545; }
        .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #eee; color: #666; font-size: 12px; }
        .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
        .stat-box { background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); padding: 15px; border-radius: 8px; border-left: 4px solid #667eea; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .stat-box .label { font-weight: bold; color: #333; font-size: 14px; }
        .stat-box .value { color: #667eea; font-size: 16px; font-weight: bold; margin-top: 5px; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #333; font-size: 18px; margin-bottom: 15px; border-bottom: 2px solid #667eea; padding-bottom: 5px; }
        .section h3 { color: #555; font-size: 16px; margin-bottom: 12px; }
        .info-row { background-color: #f8f9fa; padding: 12px; border-radius: 6px; border-left: 3px solid #28a745; }
        .info-row .label { font-weight: bold; color: #333; font-size: 13px; }
        .info-row .value { color: #666; font-size: 14px; margin-top: 3px; }
        .power-section .info-row { border-left-color: #ffc107; }
        .battery-section .info-row { border-left-color: #17a2b8; }
        .elevation-section .info-row { border-left-color: #6f42c1; }
        .route-section .info-row { border-left-color: #fd7e14; }
        .environment-section .info-row { border-left-color: #20c997; }
        .time-section .info-row { border-left-color: #6c757d; }

      </style>
    </head>
    <body>
      <div class="header">
        <h1>🚀 TeslaMate Service Started</h1>
        <p>Your TeslaMate service has been successfully started and is running</p>
      </div>

      <div class="info-section">
        <h2>📊 System Information</h2>
        <div class="info-grid">
          <div class="info-box">
            <div class="label">TeslaMate Version</div>
            <div class="value">#{info.version}</div>
          </div>
          <div class="info-box">
            <div class="label">Erlang Version</div>
            <div class="value">#{info.erlang_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Elixir Version</div>
            <div class="value">#{info.elixir_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Hostname</div>
            <div class="value">#{info.hostname}</div>
          </div>
        </div>

        <h3>💾 Memory Usage</h3>
        <div class="info-grid">
          <div class="info-box">
            <div class="label">Total Memory</div>
            <div class="value">#{info.memory.total}</div>
          </div>
          <div class="info-box">
            <div class="label">Used Memory</div>
            <div class="value">#{info.memory.used}</div>
          </div>
          <div class="info-box">
            <div class="label">Free Memory</div>
            <div class="value">#{info.memory.free}</div>
          </div>
          <div class="info-box">
            <div class="label">Database Status</div>
            <div class="value #{if info.database_status == "Normal", do: "status-ok", else: "status-error"}">#{info.database_status}</div>
          </div>
        </div>

        <h3>⏰ System Uptime</h3>
        <div class="info-box">
          <div class="value">#{info.uptime}</div>
        </div>

        #{if info.latest_drive do
          """
          <h3>🚗 Latest Drive Record</h3>
          <div class="stats">
            <div class="stat-box">
              <div class="label">📏 Distance</div>
              <div class="value">#{Float.round(info.latest_drive.distance, 3)} km</div>
            </div>
            <div class="stat-box">
              <div class="label">⏱️ Duration</div>
              <div class="value">#{info.latest_drive.duration_min} minutes</div>
            </div>
            <div class="stat-box">
              <div class="label">🏎️ Max Speed</div>
              <div class="value">#{info.latest_drive.speed_max} km/h</div>
            </div>
            <div class="stat-box">
              <div class="label">📊 Avg Speed</div>
              <div class="value">#{Float.round(info.latest_drive.avg_speed, 1)} km/h</div>
            </div>
          </div>

          <div class="section power-section">
            <h3>⚡ Power Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Max Power</div>
                <div class="value">#{info.latest_drive.power_max} kW</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 Min Power</div>
                <div class="value">#{info.latest_drive.power_min} kW</div>
              </div>
            </div>
          </div>

          <div class="section">
            <h3>📏 Odometer Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🏁 Start Odometer</div>
                <div class="value">#{Float.round(info.latest_drive.start_km, 3)} km</div>
              </div>
              <div class="info-row">
                <div class="label">🎯 End Odometer</div>
                <div class="value">#{Float.round(info.latest_drive.end_km, 3)} km</div>
              </div>
            </div>
          </div>

          <div class="section elevation-section">
            <h3>🏔️ Elevation Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">📈 Total Ascent</div>
                <div class="value">#{info.latest_drive.ascent} m</div>
              </div>
              <div class="info-row">
                <div class="label">📉 Total Descent</div>
                <div class="value">#{info.latest_drive.descent} m</div>
              </div>
            </div>
          </div>

          <div class="section route-section">
            <h3>📍 Route Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🏁 Start Location</div>
                <div class="value">#{if info.latest_drive.start_geofence, do: info.latest_drive.start_geofence.name, else: "#{info.latest_drive.start_address.name}, #{info.latest_drive.start_address.city}"}</div>
              </div>
              <div class="info-row">
                <div class="label">🎯 End Location</div>
                <div class="value">#{if info.latest_drive.end_geofence, do: info.latest_drive.end_geofence.name, else: "#{info.latest_drive.end_address.name}, #{info.latest_drive.end_address.city}"}</div>
              </div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Start Ideal Range</div>
                <div class="value">#{info.latest_drive.start_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 End Ideal Range</div>
                <div class="value">#{info.latest_drive.end_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 Start Rated Range</div>
                <div class="value">#{info.latest_drive.start_rated_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 End Rated Range</div>
                <div class="value">#{info.latest_drive.end_rated_range_km} km</div>
              </div>
            </div>
          </div>

          <div class="section environment-section">
            <h3>🌡️ Environment Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🌡️ Avg Outside Temp</div>
                <div class="value">#{info.latest_drive.outside_temp_avg}°C</div>
              </div>
              <div class="info-row">
                <div class="label">🌡️ Avg Inside Temp</div>
                <div class="value">#{info.latest_drive.inside_temp_avg}°C</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🕐 Start Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(info.latest_drive.start_date)}</div>
              </div>
              <div class="info-row">
                <div class="label">🕙 End Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(info.latest_drive.end_date)}</div>
              </div>
            </div>
          </div>


          """
        else
          """
          <h3>🚗 Latest Drive Record</h3>
          <div class="info-box">
            <div class="value">No drive records found</div>
          </div>
          """
        end}

        #{if info.latest_charging do
          """
          <h3>🔋 Latest Charging Session</h3>
          <div class="stats">
            <div class="stat-box">
              <div class="label">⚡ Energy Added</div>
              <div class="value">#{info.latest_charging.charge_energy_added} kWh</div>
            </div>
            <div class="stat-box">
              <div class="label">⏱️ Duration</div>
              <div class="value">#{info.latest_charging.duration_min} minutes</div>
            </div>
            <div class="stat-box">
              <div class="label">💰 Cost</div>
              <div class="value">#{if info.latest_charging.cost, do: "#{info.latest_charging.cost} 元", else: "Not available"}</div>
            </div>
            <div class="stat-box">
              <div class="label">⚡ Avg Power</div>
              <div class="value">#{Float.round(info.latest_charging.power_avg, 1)} kW</div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Start Battery Level</div>
                <div class="value">#{info.latest_charging.start_battery_level}%</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 End Battery Level</div>
                <div class="value">#{info.latest_charging.end_battery_level}%</div>
              </div>
              <div class="info-row">
                <div class="label">📊 Start Ideal Range</div>
                <div class="value">#{info.latest_charging.start_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 End Ideal Range</div>
                <div class="value">#{info.latest_charging.end_ideal_range_km} km</div>
              </div>
            </div>
          </div>

          <div class="section location-section">
            <h3>📍 Charging Location</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🏁 Charging Location</div>
                <div class="value">#{if info.latest_charging.geofence, do: info.latest_charging.geofence.name, else: "#{info.latest_charging.address.name}, #{info.latest_charging.address.city}"}</div>
              </div>
            </div>
          </div>

          <div class="section environment-section">
            <h3>🌡️ Environment Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🌡️ Avg Outside Temp</div>
                <div class="value">#{info.latest_charging.outside_temp_avg}°C</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🕐 Start Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(info.latest_charging.start_date)}</div>
              </div>
              <div class="info-row">
                <div class="label">🕙 End Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(info.latest_charging.end_date)}</div>
              </div>
            </div>
          </div>
          """
        else
          """
          <h3>🔋 Latest Charging Session</h3>
          <div class="info-box">
            <div class="value">No charging records found</div>
          </div>
          """
        end}
      </div>

      <div class="footer">
        <p>This email was automatically sent by TeslaMate</p>
        <p>Startup Time: #{TeslaMate.Email.format_datetime(DateTime.utc_now())}</p>
      </div>
    </body>
    </html>
    """
  end

  def generate_text(info) do
    """
    TeslaMate Service Startup Notification

    System Information:
    - TeslaMate Version: #{info.version}
    - Erlang Version: #{info.erlang_version}
    - Elixir Version: #{info.elixir_version}
    - Hostname: #{info.hostname}

    Memory Usage:
    - Total Memory: #{info.memory.total}
    - Used Memory: #{info.memory.used}
    - Free Memory: #{info.memory.free}
    - Database Status: #{info.database_status}

    System Uptime:
    #{info.uptime}

    #{if info.latest_drive do
      """
      Latest Drive Record - #{info.latest_drive.car.name}:

      📊 Drive Statistics:
      - 📏 Distance: #{Float.round(info.latest_drive.distance, 3)} km
      - ⏱️ Duration: #{info.latest_drive.duration_min} minutes
      - 🏎️ Max Speed: #{info.latest_drive.speed_max} km/h
      - 📊 Avg Speed: #{Float.round(info.latest_drive.avg_speed, 1)} km/h

      🔋 Power Information:
      - 🔋 Max Power: #{info.latest_drive.power_max} kW
      - 🔋 Min Power: #{info.latest_drive.power_min} kW

      📏 Odometer Information:
      - 🏁 Start Odometer: #{Float.round(info.latest_drive.start_km, 3)} km
      - 🎯 End Odometer: #{Float.round(info.latest_drive.end_km, 3)} km

      🏔️ Elevation Information:
      - 📈 Total Ascent: #{info.latest_drive.ascent} m
      - 📉 Total Descent: #{info.latest_drive.descent} m

      📍 Route Information:
      - 🏁 Start: #{if info.latest_drive.start_geofence, do: info.latest_drive.start_geofence.name, else: "#{info.latest_drive.start_address.name}, #{info.latest_drive.start_address.city}"}
      - 🎯 End: #{if info.latest_drive.end_geofence, do: info.latest_drive.end_geofence.name, else: "#{info.latest_drive.end_address.name}, #{info.latest_drive.end_address.city}"}

      🔋 Battery Information:
      - 🔋 Start Ideal Range: #{info.latest_drive.start_ideal_range_km} km
      - 🔋 End Ideal Range: #{info.latest_drive.end_ideal_range_km} km
      - 📊 Start Rated Range: #{info.latest_drive.start_rated_range_km} km
      - 📊 End Rated Range: #{info.latest_drive.end_rated_range_km} km

      🌡️ Environment Information:
      - 🌡️ Avg Outside Temp: #{info.latest_drive.outside_temp_avg}°C
      - 🌡️ Avg Inside Temp: #{info.latest_drive.inside_temp_avg}°C

      ⏰ Time Information:
      - 🕐 Start Time: #{TeslaMate.Email.format_datetime_local(info.latest_drive.start_date)}
      - 🕙 End Time: #{TeslaMate.Email.format_datetime_local(info.latest_drive.end_date)}
      """
    else
      """
      Latest Drive Record: No drive records found
      """
    end}

    #{if info.latest_charging do
      """
      Latest Charging Session - #{info.latest_charging.car.name}:

      📊 Charging Statistics:
      - ⚡ Energy Added: #{info.latest_charging.charge_energy_added} kWh
      - ⏱️ Duration: #{info.latest_charging.duration_min} minutes
      - 💰 Cost: #{if info.latest_charging.cost, do: "#{info.latest_charging.cost} 元", else: "Not available"}
      - ⚡ Avg Power: #{Float.round(info.latest_charging.power_avg, 1)} kW

      🔋 Battery Information:
      - 🔋 Start Battery Level: #{info.latest_charging.start_battery_level}%
      - 🔋 End Battery Level: #{info.latest_charging.end_battery_level}%
      - 📊 Start Ideal Range: #{info.latest_charging.start_ideal_range_km} km
      - 📈 End Ideal Range: #{info.latest_charging.end_ideal_range_km} km

      📍 Charging Location:
      - 🏁 Charging Location: #{if info.latest_charging.geofence, do: info.latest_charging.geofence.name, else: "#{info.latest_charging.address.name}, #{info.latest_charging.address.city}"}

      🌡️ Environment Information:
      - 🌡️ Avg Outside Temp: #{info.latest_charging.outside_temp_avg}°C

      ⏰ Time Information:
      - 🕐 Start Time: #{TeslaMate.Email.format_datetime_local(info.latest_charging.start_date)}
      - 🕙 End Time: #{TeslaMate.Email.format_datetime_local(info.latest_charging.end_date)}
      """
    else
      """
      Latest Charging Session: No charging records found
      """
    end}

    ---
    This email was automatically sent by TeslaMate
    Startup Time: #{TeslaMate.Email.format_datetime(DateTime.utc_now())}
    """
  end
end 