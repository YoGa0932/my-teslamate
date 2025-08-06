defmodule TeslaMate.Email.Templates.StartupEmail.HtmlRenderer do
  @moduledoc """
  Startup email HTML renderer
  """

  alias TeslaMate.Email.Templates.StartupEmail.SystemInfoFormatter
  alias TeslaMate.Email.Templates.DriveEmail.DriveInfoFormatter
  alias TeslaMate.Email.Templates.ChargingEmail.ChargingInfoFormatter
  alias TeslaMate.Email.Templates.TrajectoryMap.TrajectoryMapService

  require Logger

  def render(info) do
    system_info = SystemInfoFormatter.format_system_info(info)
    memory_info = SystemInfoFormatter.format_memory_info(info)
    settings_info = SystemInfoFormatter.format_settings_info(info)
    
    # Integrate drive and charging information
    drive_html = render_drive_section(info.latest_drive)
    charging_html = render_charging_section(info.latest_charging)

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
            <div class="value">#{system_info.version}</div>
          </div>
          <div class="info-box">
            <div class="label">Erlang Version</div>
            <div class="value">#{system_info.erlang_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Elixir Version</div>
            <div class="value">#{system_info.elixir_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Hostname</div>
            <div class="value">#{system_info.hostname}</div>
          </div>
        </div>

        <h3>⚙️ System Settings</h3>
        <div class="info-grid">
          <div class="info-box">
            <div class="label">📏 Unit of Length</div>
            <div class="value">#{settings_info.unit_of_length}</div>
          </div>
          <div class="info-box">
            <div class="label">🌡️ Unit of Temperature</div>
            <div class="value">#{settings_info.unit_of_temperature}</div>
          </div>
          <div class="info-box">
            <div class="label">📊 Preferred Range</div>
            <div class="value">#{settings_info.preferred_range}</div>
          </div>
          <div class="info-box">
            <div class="label">🌐 Language</div>
            <div class="value">#{settings_info.language}</div>
          </div>
          <div class="info-box">
            <div class="label">📊 Unit of Pressure</div>
            <div class="value">#{settings_info.unit_of_pressure}</div>
          </div>
          <div class="info-box">
            <div class="label">🔗 Base URL</div>
            <div class="value">#{settings_info.base_url}</div>
          </div>
          <div class="info-box">
            <div class="label">📈 Grafana URL</div>
            <div class="value">#{settings_info.grafana_url}</div>
          </div>
        </div>

        <h3>💾 Memory Usage</h3>
        <div class="info-grid">
          <div class="info-box">
            <div class="label">Total Memory</div>
            <div class="value">#{memory_info.total}</div>
          </div>
          <div class="info-box">
            <div class="label">Used Memory</div>
            <div class="value">#{memory_info.used}</div>
          </div>
          <div class="info-box">
            <div class="label">Free Memory</div>
            <div class="value">#{memory_info.free}</div>
          </div>
          <div class="info-box">
            <div class="label">Database Status</div>
            <div class="value #{memory_info.database_status_class}">#{memory_info.database_status}</div>
          </div>
        </div>

        <h3>⏰ System Uptime</h3>
        <div class="info-box">
          <div class="value">#{system_info.uptime}</div>
        </div>

        #{drive_html}

        #{charging_html}
      </div>

      <div class="footer">
        <p>This email was automatically sent by TeslaMate</p>
        <p>Startup Time: #{format_datetime_local(DateTime.utc_now())}</p>
      </div>
    </body>
    </html>
    """
  end

  defp render_drive_section(nil) do
    """
    <h3>🚗 Latest Drive Record</h3>
    <div class="info-box">
      <div class="value">No drive records found</div>
    </div>
    """
  end

  defp render_drive_section(drive) do
    # Use drive info formatter to get formatted drive information
    drive_info = DriveInfoFormatter.format_drive_info(drive)
    
    # Try to get map trajectory
    map_html = render_map_section(drive.id)

    """
    <h3>🚗 Latest Drive Record</h3>
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
    """
  end

  defp render_charging_section(nil) do
    """
    <h3>🔋 Latest Charging Session</h3>
    <div class="info-box">
      <div class="value">No charging records found</div>
    </div>
    """
  end

  defp render_charging_section(charging) do
    # Use charging info formatter to get formatted charging information
    charging_info = ChargingInfoFormatter.format_charging_info(charging)

    """
    <h3>🔋 Latest Charging Session</h3>
    <div class="stats">
      <div class="stat-box">
        <div class="label">⚡ Energy Added</div>
        <div class="value">#{charging_info.energy_added}</div>
      </div>
      <div class="stat-box">
        <div class="label">⏱️ Duration</div>
        <div class="value">#{charging_info.duration}</div>
      </div>
      <div class="stat-box">
        <div class="label">🔌 Charging Type</div>
        <div class="value">#{charging_info.charging_type}</div>
      </div>
      <div class="stat-box">
        <div class="label">💰 Total Cost</div>
        <div class="value">#{charging_info.total_cost}</div>
      </div>
      <div class="stat-box">
        <div class="label">⚡ Avg Power</div>
        <div class="value">#{charging_info.power_avg}</div>
      </div>
      <div class="stat-box">
        <div class="label">⚡ Energy Used (Grid)</div>
        <div class="value">#{charging_info.energy_used}</div>
      </div>
      <div class="stat-box">
        <div class="label">📊 Efficiency</div>
        <div class="value">#{charging_info.efficiency}</div>
      </div>
      <div class="stat-box">
        <div class="label">💵 Price per kWh</div>
        <div class="value">#{charging_info.cost_per_kwh}</div>
      </div>
    </div>

    <div class="section battery-section">
      <h3>🔋 Battery Information</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">🔋 Battery Level Change</div>
          <div class="value">#{charging_info.battery_level_change}</div>
        </div>
        <div class="info-row">
          <div class="label">📊 Rated Range Change</div>
          <div class="value">#{charging_info.rated_range_change}</div>
        </div>
      </div>
    </div>

    <div class="section location-section">
      <h3>📍 Charging Location</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">🏁 Charging Location</div>
          <div class="value">#{charging_info.charging_location}</div>
        </div>
      </div>
    </div>

    <div class="section environment-section">
      <h3>🌡️ Environment Information</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">🌡️ Avg Outside Temp</div>
          <div class="value">#{charging_info.outside_temp}</div>
        </div>
      </div>
    </div>

    <div class="section time-section">
      <h3>⏰ Time Information</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">⏰ Time Period</div>
          <div class="value">#{charging_info.start_time} - #{charging_info.end_time} (Duration: #{charging_info.duration})</div>
        </div>
      </div>
    </div>
    """
  end

  defp format_datetime_local(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime_local(_), do: "Unknown"

  defp render_map_section(drive_id) do
    TrajectoryMapService.render_map_section(drive_id)
  end
end 