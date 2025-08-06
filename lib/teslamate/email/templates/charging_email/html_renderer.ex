defmodule TeslaMate.Email.Templates.ChargingEmail.HtmlRenderer do
  @moduledoc """
  Charging email HTML renderer
  """

  alias TeslaMate.Email.Templates.ChargingEmail.ChargingInfoFormatter

  def render(charging) do
    charging_info = ChargingInfoFormatter.format_charging_info(charging)

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
        .primary-stats { grid-template-columns: 1fr 1fr; gap: 20px; }
        .stat-box { background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); padding: 15px; border-radius: 8px; border-left: 4px solid #28a745; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .stat-box.primary { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; border-left: 4px solid #1e7e34; }
        .stat-box.primary .label { color: rgba(255,255,255,0.9); font-size: 16px; }
        .stat-box.primary .value { color: white; font-size: 18px; font-weight: bold; }
        .stat-box .label { font-weight: bold; color: #333; font-size: 14px; }
        .stat-box .value { color: #28a745; font-size: 16px; font-weight: bold; margin-top: 5px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 15px 0; }
        .info-row { background-color: #f8f9fa; padding: 12px; border-radius: 6px; border-left: 3px solid #28a745; }
        .info-row .label { font-weight: bold; color: #333; font-size: 13px; }
        .info-row .value { color: #666; font-size: 14px; margin-top: 3px; }
        
        .stats-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; margin: 20px 0; }
        .stat-group { background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #e9ecef; }
        .stat-group h4 { color: #28a745; font-size: 14px; margin-bottom: 10px; border-bottom: 2px solid #28a745; padding-bottom: 5px; }
        .stat-group .stat-box { margin-bottom: 10px; }
        .stat-group .stat-box:last-child { margin-bottom: 0; }
        
        .details-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
        .detail-group { background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #e9ecef; }
        .detail-group h4 { color: #6c757d; font-size: 13px; margin-bottom: 10px; border-bottom: 1px solid #dee2e6; padding-bottom: 5px; }
        .detail-group .info-row { margin-bottom: 8px; }
        .detail-group .info-row:last-child { margin-bottom: 0; }
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
          <p>Your vehicle <strong>#{charging.car.name}</strong> has finished charging</p>
        </div>

        <div class="content">
          <div class="section core-stats">
            <h2>🎯 Core Statistics</h2>
            <div class="stats primary-stats">
              <div class="stat-box primary">
                <div class="label">⚡ Energy Added</div>
                <div class="value">#{charging_info.energy_added}</div>
              </div>
              <div class="stat-box primary">
                <div class="label">⏱️ Duration</div>
                <div class="value">#{charging_info.duration}</div>
              </div>
              <div class="stat-box primary">
                <div class="label">🔌 Charging Type</div>
                <div class="value">#{charging_info.charging_type}</div>
              </div>
              <div class="stat-box primary">
                <div class="label">💰 Total Cost</div>
                <div class="value">#{charging_info.total_cost}</div>
              </div>
            </div>
          </div>

          <div class="section detailed-stats">
            <h3>📈 Detailed Statistics</h3>
            <div class="stats-grid">
              <div class="stat-group">
                <h4>⚡ Energy</h4>
                <div class="stat-box">
                  <div class="label">💵 Price per kWh</div>
                  <div class="value">#{charging_info.cost_per_kwh}</div>
                </div>
                <div class="stat-box">
                  <div class="label">⚡ Energy Used (Grid)</div>
                  <div class="value">#{charging_info.energy_used}</div>
                </div>
              </div>
              <div class="stat-group">
                <h4>⚡ Power</h4>
                <div class="stat-box">
                  <div class="label">⚡ Avg Power</div>
                  <div class="value">#{charging_info.power_avg}</div>
                </div>
                <div class="stat-box">
                  <div class="label">📊 Efficiency</div>
                  <div class="value">#{charging_info.efficiency}</div>
                </div>
              </div>
              <div class="stat-group">
                <h4>🔋 Battery</h4>
                <div class="stat-box">
                  <div class="label">🔋 Battery Level Change</div>
                  <div class="value">#{charging_info.battery_level_change}</div>
                </div>
                <div class="stat-box">
                  <div class="label">📊 Rated Range Change</div>
                  <div class="value">#{charging_info.rated_range_change}</div>
                </div>
              </div>
            </div>
          </div>

          <div class="section details">
            <h3>📊 Additional Details</h3>
            <div class="details-grid">
              <div class="detail-group">
                <h4>📍 Location</h4>
                <div class="info-row">
                  <div class="label">🏁 Charging Location</div>
                  <div class="value">#{charging_info.charging_location}</div>
                </div>
              </div>
              
              <div class="detail-group">
                <h4>⏰ Time</h4>
                <div class="info-row">
                  <div class="label">⏰ Time Period</div>
                  <div class="value">#{charging_info.start_time} - #{charging_info.end_time} (Duration: #{charging_info.duration})</div>
                </div>
              </div>
              
              <div class="detail-group">
                <h4>🌡️ Environment</h4>
                <div class="info-row">
                  <div class="label">🌡️ Avg Outside Temp</div>
                  <div class="value">#{charging_info.outside_temp}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="footer">
          <p>This email was automatically sent by TeslaMate</p>
          <p>Charging Process ID: #{charging.id}</p>
        </div>
      </div>
    </body>
    </html>
    """
  end
end 