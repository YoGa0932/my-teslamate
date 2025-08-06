defmodule TeslaMate.Email.Templates.StartupEmail.HtmlRenderer do
  @moduledoc """
  Startup email HTML renderer
  """

  alias TeslaMate.Email.Templates.StartupEmail.SystemInfoFormatter
  alias TeslaMate.Email.Templates.DriveSection.DriveSection
  alias TeslaMate.Email.Templates.ChargingSection.ChargingSection

  require Logger

  def render(info) do
    system_info = SystemInfoFormatter.format_system_info(info)
    memory_info = SystemInfoFormatter.format_memory_info(info)
    settings_info = SystemInfoFormatter.format_settings_info(info)
    
    # Integrate drive and charging information
    drive_html = DriveSection.render_drive_section(info.latest_drive)
    charging_html = ChargingSection.render_charging_section(info.latest_charging)

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
        
        #{DriveSection.render_drive_css()}
        #{ChargingSection.render_charging_css()}
        
        .power-section .info-row { border-left-color: #ffc107; }
        .battery-section .info-row { border-left-color: #17a2b8; }
        .elevation-section .info-row { border-left-color: #6f42c1; }
        .route-section .info-row { border-left-color: #fd7e14; }
        .environment-section .info-row { border-left-color: #20c997; }
        .time-section .info-row { border-left-color: #6c757d; }
        
        @media (max-width: 768px) {
          .info-grid { grid-template-columns: 1fr; gap: 15px; }
          .stats { grid-template-columns: 1fr; gap: 15px; }
          .info-box .label { font-size: 13px; }
          .info-box .value { font-size: 14px; }
          .stat-box .label { font-size: 13px; }
          .stat-box .value { font-size: 14px; }
          .info-row .label { font-size: 12px; }
          .info-row .value { font-size: 13px; }
        }
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





  defp format_datetime_local(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime_local(_), do: "Unknown"


end 