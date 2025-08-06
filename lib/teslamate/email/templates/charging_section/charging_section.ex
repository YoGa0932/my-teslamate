defmodule TeslaMate.Email.Templates.ChargingSection.ChargingSection do
  @moduledoc """
  Shared charging section for email templates
  """

  alias TeslaMate.Email.Templates.ChargingEmail.ChargingInfoFormatter

  def render_charging_section(charging) do
    charging_info = ChargingInfoFormatter.format_charging_info(charging)

    """
    <h3>🔋 Latest Charging Session</h3>
    
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
            <div class="value">#{charging_info.start_time} - #{charging_info.end_time} (⏰: #{charging_info.duration})</div>
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
    """
  end

  def render_charging_content(charging) do
    charging_info = ChargingInfoFormatter.format_charging_info(charging)

    """
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
            <div class="value">#{charging_info.start_time} - #{charging_info.end_time} (⏰: #{charging_info.duration})</div>
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
    """
  end

  def render_charging_css do
    """
    .primary-stats { grid-template-columns: 1fr 1fr; gap: 20px; }
    .stat-box.primary { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; border-left: 4px solid #1e7e34; }
    .stat-box.primary .label { color: rgba(255,255,255,0.9); font-size: 16px; }
    .stat-box.primary .value { color: white; font-size: 18px; font-weight: bold; }
    
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
    
    @media (max-width: 768px) {
      .primary-stats { grid-template-columns: 1fr; gap: 15px; }
      .stats-grid { grid-template-columns: 1fr; gap: 15px; }
      .details-grid { grid-template-columns: 1fr; gap: 15px; }
      .stat-box.primary .label { font-size: 14px; }
      .stat-box.primary .value { font-size: 16px; }
      .stat-group h4 { font-size: 13px; }
      .detail-group h4 { font-size: 12px; }
      .info-row .label { font-size: 12px; }
      .info-row .value { font-size: 13px; }
    }
    """
  end
end 