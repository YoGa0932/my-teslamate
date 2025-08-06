defmodule TeslaMate.Email.Templates.DriveSection.DriveSection do
  @moduledoc """
  Shared drive section for email templates
  """

  alias TeslaMate.Email.Templates.DriveEmail.DriveInfoFormatter
  alias TeslaMate.Email.Templates.TrajectoryMap.TrajectoryMapService

  def render_drive_section(drive) do
    drive_info = DriveInfoFormatter.format_drive_info(drive)
    map_html = render_map_section(drive.id)

    """
    <h3>🚗 Latest Drive Record</h3>
    
    <div class="stats primary-stats">
      <div class="stat-box primary">
        <div class="label">📏 Distance</div>
        <div class="value">#{drive_info.distance}</div>
      </div>
      <div class="stat-box primary">
        <div class="label">⏱️ Duration</div>
        <div class="value">#{drive_info.duration}</div>
      </div>
      <div class="stat-box primary">
        <div class="label">🔋 Energy Used</div>
        <div class="value">#{drive_info.energy_used}</div>
      </div>
      <div class="stat-box primary">
        <div class="label">📊 Efficiency Ratio</div>
        <div class="value">#{drive_info.efficiency_ratio}</div>
      </div>
    </div>
    
    <div class="section route-section">
      <h3>📍 Route & Map</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">📍 Route</div>
          <div class="value">#{drive_info.route}</div>
        </div>
      </div>
      #{map_html}
    </div>
    
    <div class="section detailed-stats">
      <h3>📈 Detailed Statistics</h3>
      <div class="stats-grid">
        <div class="stat-group">
          <h4>🏎️ Speed</h4>
          <div class="stat-box">
            <div class="label">🏎️ Max Speed</div>
            <div class="value">#{drive_info.speed_max}</div>
          </div>
          <div class="stat-box">
            <div class="label">📊 Avg Speed</div>
            <div class="value">#{drive_info.avg_speed}</div>
          </div>
        </div>
        <div class="stat-group">
          <h4>⚡ Energy</h4>
          <div class="stat-box">
            <div class="label">⚡ Energy Consumption</div>
            <div class="value">#{drive_info.energy_consumption}</div>
          </div>
          <div class="stat-box">
            <div class="label">💰 Drive Cost</div>
            <div class="value">#{drive_info.drive_cost}</div>
          </div>
        </div>
        <div class="stat-group">
          <h4>🔋 Range</h4>
          <div class="stat-box">
            <div class="label">📊 Estimated Range</div>
            <div class="value">#{drive_info.estimated_range}</div>
          </div>
          <div class="stat-box">
            <div class="label">🔮 Projected Range</div>
            <div class="value">#{drive_info.projected_range}</div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="section since-charge">
      <h3>🔋 Since Last Charge</h3>
      <div class="stats">
        <div class="stat-box">
          <div class="label">🔋 Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_energy}</div>
        </div>
        <div class="stat-box">
          <div class="label">📏 Distance Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_distance}</div>
        </div>
        <div class="stat-box">
          <div class="label">⚡ Avg Consumption Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_avg_consumption}</div>
        </div>
      </div>
    </div>
    
    <div class="section details">
      <h3>📊 Additional Details</h3>
      <div class="details-grid">
        <div class="detail-group">
          <h4>⏰ Time</h4>
          <div class="info-row">
            <div class="label">⏰ Time Period</div>
            <div class="value">#{drive_info.start_time} - #{drive_info.end_time} (⏰: #{drive_info.duration})</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🔋 Battery</h4>
          <div class="info-row">
            <div class="label">📊 Rated Range Change</div>
            <div class="value">#{drive_info.range_analysis}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>⚡ Power</h4>
          <div class="info-row">
            <div class="label">🔋 Max Power</div>
            <div class="value">#{drive_info.power_max}</div>
          </div>
          <div class="info-row">
            <div class="label">🔋 Min Power</div>
            <div class="value">#{drive_info.power_min}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>📏 Odometer</h4>
          <div class="info-row">
            <div class="label">📏 Odometer Change</div>
            <div class="value">#{drive_info.odometer_change}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🏔️ Elevation</h4>
          <div class="info-row">
            <div class="label">📈 Total Ascent</div>
            <div class="value">#{drive_info.ascent}</div>
          </div>
          <div class="info-row">
            <div class="label">📉 Total Descent</div>
            <div class="value">#{drive_info.descent}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🌡️ Temperature</h4>
          <div class="info-row">
            <div class="label">🌡️ Avg Outside Temp</div>
            <div class="value">#{drive_info.outside_temp}</div>
          </div>
          <div class="info-row">
            <div class="label">🌡️ Avg Inside Temp</div>
            <div class="value">#{drive_info.inside_temp}</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_drive_content(drive) do
    drive_info = DriveInfoFormatter.format_drive_info(drive)
    map_html = render_map_section(drive.id)

    """
    <div class="section core-stats">
      <h2>🎯 Core Statistics</h2>
      <div class="stats primary-stats">
        <div class="stat-box primary">
          <div class="label">📏 Distance</div>
          <div class="value">#{drive_info.distance}</div>
        </div>
        <div class="stat-box primary">
          <div class="label">⏱️ Duration</div>
          <div class="value">#{drive_info.duration}</div>
        </div>
        <div class="stat-box primary">
          <div class="label">🔋 Energy Used</div>
          <div class="value">#{drive_info.energy_used}</div>
        </div>
        <div class="stat-box primary">
          <div class="label">📊 Efficiency Ratio</div>
          <div class="value">#{drive_info.efficiency_ratio}</div>
        </div>
      </div>
    </div>

    <div class="section route-section">
      <h3>📍 Route & Map</h3>
      <div class="info-grid">
        <div class="info-row">
          <div class="label">📍 Route</div>
          <div class="value">#{drive_info.route}</div>
        </div>
      </div>
      #{map_html}
    </div>
    
    <div class="section detailed-stats">
      <h3>📈 Detailed Statistics</h3>
      <div class="stats-grid">
        <div class="stat-group">
          <h4>🏎️ Speed</h4>
          <div class="stat-box">
            <div class="label">🏎️ Max Speed</div>
            <div class="value">#{drive_info.speed_max}</div>
          </div>
          <div class="stat-box">
            <div class="label">📊 Avg Speed</div>
            <div class="value">#{drive_info.avg_speed}</div>
          </div>
        </div>
        <div class="stat-group">
          <h4>⚡ Energy</h4>
          <div class="stat-box">
            <div class="label">⚡ Energy Consumption</div>
            <div class="value">#{drive_info.energy_consumption}</div>
          </div>
          <div class="stat-box">
            <div class="label">💰 Drive Cost</div>
            <div class="value">#{drive_info.drive_cost}</div>
          </div>
        </div>
        <div class="stat-group">
          <h4>🔋 Range</h4>
          <div class="stat-box">
            <div class="label">📊 Estimated Range</div>
            <div class="value">#{drive_info.estimated_range}</div>
          </div>
          <div class="stat-box">
            <div class="label">🔮 Projected Range</div>
            <div class="value">#{drive_info.projected_range}</div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="section since-charge">
      <h3>🔋 Since Last Charge</h3>
      <div class="stats">
        <div class="stat-box">
          <div class="label">🔋 Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_energy}</div>
        </div>
        <div class="stat-box">
          <div class="label">📏 Distance Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_distance}</div>
        </div>
        <div class="stat-box">
          <div class="label">⚡ Avg Consumption Since Last Charge</div>
          <div class="value">#{drive_info.since_last_charge_avg_consumption}</div>
        </div>
      </div>
    </div>
    
    <div class="section details">
      <h3>📊 Additional Details</h3>
      <div class="details-grid">
        <div class="detail-group">
          <h4>⏰ Time</h4>
          <div class="info-row">
            <div class="label">⏰ Time Period</div>
            <div class="value">#{drive_info.start_time} - #{drive_info.end_time} (⏰: #{drive_info.duration})</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🔋 Battery</h4>
          <div class="info-row">
            <div class="label">📊 Rated Range Change</div>
            <div class="value">#{drive_info.range_analysis}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>⚡ Power</h4>
          <div class="info-row">
            <div class="label">🔋 Max Power</div>
            <div class="value">#{drive_info.power_max}</div>
          </div>
          <div class="info-row">
            <div class="label">🔋 Min Power</div>
            <div class="value">#{drive_info.power_min}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>📏 Odometer</h4>
          <div class="info-row">
            <div class="label">📏 Odometer Change</div>
            <div class="value">#{drive_info.odometer_change}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🏔️ Elevation</h4>
          <div class="info-row">
            <div class="label">📈 Total Ascent</div>
            <div class="value">#{drive_info.ascent}</div>
          </div>
          <div class="info-row">
            <div class="label">📉 Total Descent</div>
            <div class="value">#{drive_info.descent}</div>
          </div>
        </div>
        
        <div class="detail-group">
          <h4>🌡️ Temperature</h4>
          <div class="info-row">
            <div class="label">🌡️ Avg Outside Temp</div>
            <div class="value">#{drive_info.outside_temp}</div>
          </div>
          <div class="info-row">
            <div class="label">🌡️ Avg Inside Temp</div>
            <div class="value">#{drive_info.inside_temp}</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_drive_css do
    """
    .primary-stats { grid-template-columns: 1fr 1fr; gap: 20px; }
    .stat-box.primary { background: linear-gradient(135deg, #1E40AF 0%, #3B82F6 100%); color: white; border-left: 4px solid #1D4ED8; }
    .stat-box.primary .label { color: rgba(255,255,255,0.9); font-size: 16px; }
    .stat-box.primary .value { color: white; font-size: 18px; font-weight: bold; }
    
    .stats-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; margin: 20px 0; }
    .stat-group { background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #e9ecef; }
    .stat-group h4 { color: #667eea; font-size: 14px; margin-bottom: 10px; border-bottom: 2px solid #667eea; padding-bottom: 5px; }
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

  defp render_map_section(drive_id) do
    TrajectoryMapService.render_map_section(drive_id)
  end
end 