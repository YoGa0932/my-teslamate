defmodule TeslaMate.Email.Templates.ChargingEmail do
  @moduledoc """
  Charging completion notification email templates
  """

  def generate_html(charging_process) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Charging Complete</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f9f9f9; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 25px; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { padding: 25px; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #333; font-size: 18px; margin-bottom: 15px; border-bottom: 2px solid #28a745; padding-bottom: 5px; }
        .section h3 { color: #555; font-size: 16px; margin-bottom: 12px; }
        .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
        .stat-box { background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); padding: 15px; border-radius: 8px; border-left: 4px solid #28a745; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .stat-box .label { font-weight: bold; color: #333; font-size: 14px; }
        .stat-box .value { color: #28a745; font-size: 16px; font-weight: bold; margin-top: 5px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 15px 0; }
        .info-row { background-color: #f8f9fa; padding: 12px; border-radius: 6px; border-left: 3px solid #28a745; }
        .info-row .label { font-weight: bold; color: #333; font-size: 13px; }
        .info-row .value { color: #666; font-size: 14px; margin-top: 3px; }
        .battery-section .info-row { border-left-color: #17a2b8; }
        .location-section .info-row { border-left-color: #fd7e14; }
        .environment-section .info-row { border-left-color: #20c997; }
        .time-section .info-row { border-left-color: #6c757d; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; border-top: 1px solid #eee; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔋 Charging Complete</h1>
          <p>Your vehicle <strong>#{charging_process.car.name}</strong> has finished charging</p>
        </div>

        <div class="content">
          <div class="section">
            <h2>📊 Charging Statistics</h2>
            <div class="stats">
              <div class="stat-box">
                <div class="label">⚡ Energy Added</div>
                <div class="value">#{charging_process.charge_energy_added} kWh</div>
              </div>
              <div class="stat-box">
                <div class="label">⏱️ Duration</div>
                <div class="value">#{charging_process.duration_min} minutes</div>
              </div>
              <div class="stat-box">
                <div class="label">💰 Cost</div>
                <div class="value">#{if charging_process.cost, do: "#{charging_process.cost} 元", else: "Not available"}</div>
              </div>
              <div class="stat-box">
                <div class="label">⚡ Avg Power</div>
                <div class="value">#{if charging_process.power_avg, do: "#{Float.round(charging_process.power_avg, 1)} kW", else: "Not available"}</div>
              </div>
            </div>
          </div>

          <div class="section battery-section">
            <h3>🔋 Battery Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🔋 Start Battery Level</div>
                <div class="value">#{charging_process.start_battery_level}%</div>
              </div>
              <div class="info-row">
                <div class="label">🔋 End Battery Level</div>
                <div class="value">#{charging_process.end_battery_level}%</div>
              </div>
              <div class="info-row">
                <div class="label">📊 Start Ideal Range</div>
                <div class="value">#{charging_process.start_ideal_range_km} km</div>
              </div>
              <div class="info-row">
                <div class="label">📊 End Ideal Range</div>
                <div class="value">#{charging_process.end_ideal_range_km} km</div>
              </div>
            </div>
          </div>

          <div class="section location-section">
            <h3>📍 Charging Location</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🏁 Charging Location</div>
                <div class="value">#{if charging_process.geofence, do: charging_process.geofence.name, else: "#{charging_process.address.name}, #{charging_process.address.city}"}</div>
              </div>
            </div>
          </div>

          <div class="section environment-section">
            <h3>🌡️ Environment Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🌡️ Avg Outside Temp</div>
                <div class="value">#{charging_process.outside_temp_avg}°C</div>
              </div>
            </div>
          </div>

          <div class="section time-section">
            <h3>⏰ Time Information</h3>
            <div class="info-grid">
              <div class="info-row">
                <div class="label">🕐 Start Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(charging_process.start_date)}</div>
              </div>
              <div class="info-row">
                <div class="label">🕙 End Time</div>
                <div class="value">#{TeslaMate.Email.format_datetime_local(charging_process.end_date)}</div>
              </div>
            </div>
          </div>
        </div>

        <div class="footer">
          <p>This email was automatically sent by TeslaMate</p>
          <p>Charging Process ID: #{charging_process.id}</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def generate_text(charging_process) do
    """
    Charging Complete - #{charging_process.car.name}

    📊 Charging Statistics:
    - ⚡ Energy Added: #{charging_process.charge_energy_added} kWh
    - ⏱️ Duration: #{charging_process.duration_min} minutes
    - 💰 Cost: #{if charging_process.cost, do: "#{charging_process.cost} 元", else: "Not available"}
    - ⚡ Avg Power: #{if charging_process.power_avg, do: "#{Float.round(charging_process.power_avg, 1)} kW", else: "Not available"}

    🔋 Battery Information:
    - 🔋 Start Battery Level: #{charging_process.start_battery_level}%
    - 🔋 End Battery Level: #{charging_process.end_battery_level}%
    - 📊 Start Ideal Range: #{charging_process.start_ideal_range_km} km
    - 📈 End Ideal Range: #{charging_process.end_ideal_range_km} km

    📍 Charging Location:
    - 🏁 Charging Location: #{if charging_process.geofence, do: charging_process.geofence.name, else: "#{charging_process.address.name}, #{charging_process.address.city}"}

    🌡️ Environment Information:
    - 🌡️ Avg Outside Temp: #{charging_process.outside_temp_avg}°C

    ⏰ Time Information:
    - 🕐 Start Time: #{TeslaMate.Email.format_datetime_local(charging_process.start_date)}
    - 🕙 End Time: #{TeslaMate.Email.format_datetime_local(charging_process.end_date)}

    ---
    This email was automatically sent by TeslaMate
    Charging Process ID: #{charging_process.id}
    """
  end
end 