defmodule TeslaMate.Email.Templates.DriveEmail.DriveInfoFormatter do
  @moduledoc """
  Drive information formatter
  """

  def format_drive_info(drive) do
    %{
      # Basic statistics
      distance: format_distance(drive.distance),
      duration: format_duration(drive.duration_min),
      speed_max: format_speed(drive.speed_max),
      avg_speed: format_speed(drive.avg_speed),
      energy_consumption: format_energy_consumption(drive.energy_consumption_wh_per_km),
      energy_used: format_energy_used(drive.energy_used_kwh),
      estimated_range: format_estimated_range(drive.car_id),
      drive_cost: format_drive_cost(drive),
      
      # Time information
      start_time: format_datetime(drive.start_date),
      end_time: format_datetime(drive.end_date),
      
      # Route information
      route: format_route_info(drive),
      
      # Battery information
      range_analysis: format_range_analysis(drive.start_rated_range_km, drive.end_rated_range_km, drive.distance),
      
      # Power information
      power_max: format_power(drive.power_max),
      power_min: format_power(drive.power_min),
      
      # Odometer information
      start_km: format_odometer(drive.start_km),
      end_km: format_odometer(drive.end_km),
      odometer_change: format_odometer_change(drive.start_km, drive.end_km),
      
      # Elevation information
      ascent: format_elevation(drive.ascent),
      descent: format_elevation(drive.descent)
    }
  end

  defp format_distance(distance) when is_number(distance), do: "#{Float.round(distance, 3)} km"
  defp format_distance(_), do: "N/A"

  defp format_duration(duration) when is_number(duration), do: format_duration_minutes(duration)
  defp format_duration(_), do: "N/A"

  defp format_speed(speed) when is_number(speed), do: "#{Float.round(speed * 1.0, 3)} km/h"
  defp format_speed(speed) when is_struct(speed, Decimal), do: "#{Float.round(Decimal.to_float(speed), 3)} km/h"
  defp format_speed(_), do: "N/A"

  defp format_energy_consumption(consumption) when is_number(consumption), do: "#{Float.round(consumption * 1.0, 1)} Wh/km"
  defp format_energy_consumption(consumption) when is_struct(consumption, Decimal), do: "#{Float.round(Decimal.to_float(consumption), 1)} Wh/km"
  defp format_energy_consumption(_), do: "N/A"

  defp format_energy_used(energy) when is_number(energy), do: "#{Float.round(energy * 1.0, 3)} kWh"
  defp format_energy_used(energy) when is_struct(energy, Decimal), do: "#{Float.round(Decimal.to_float(energy), 3)} kWh"
  defp format_energy_used(_), do: "N/A"

  defp format_estimated_range(car_id) when not is_nil(car_id) do
    case get_latest_range(car_id) do
      range when is_number(range) -> "#{range} km"
      _ -> "N/A"
    end
  end
  defp format_estimated_range(_), do: "N/A"

  defp format_drive_cost(drive) do
    case TeslaMate.Log.calculate_drive_cost(drive) do
      cost when is_number(cost) -> "¥#{cost}"
      _ -> "N/A"
    end
  end

  defp format_datetime(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: "N/A"

  defp format_route_info(drive) do
    case {drive.start_geofence, drive.start_address} do
      {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
        start_loc = "#{geofence.name} (#{address.name})"
        format_end_location(start_loc, drive.end_geofence, drive.end_address)
      {nil, address} when not is_nil(address) ->
        start_loc = "#{address.name}, #{address.city}"
        format_end_location(start_loc, drive.end_geofence, drive.end_address)
      _ ->
        "Unknown Route"
    end
  end

  defp format_end_location(start_loc, end_geofence, end_address) do
    case {end_geofence, end_address} do
      {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
        "#{start_loc} → #{geofence.name} (#{address.name})"
      {nil, address} when not is_nil(address) ->
        "#{start_loc} → #{address.name}, #{address.city}"
      _ ->
        "#{start_loc} → Unknown Location"
    end
  end

  defp format_range_analysis(start_rated_range, end_rated_range, actual_distance) do
    cond do
      is_nil(start_rated_range) or is_nil(end_rated_range) or is_nil(actual_distance) ->
        "N/A"
      true ->
        # start_rated_range and end_rated_range are numeric (Decimal)
        start_float = Decimal.to_float(start_rated_range)
        end_float = Decimal.to_float(end_rated_range)
        range_change = start_float - end_float
        
        cond do
          range_change > 0 ->
            "↓ #{Float.round(range_change, 1)}km"
          range_change < 0 ->
            "↑ #{Float.round(abs(range_change), 1)}km"
          true ->
            "0km"
        end
    end
  end

  defp format_power(power) when is_number(power), do: "#{power} kW"
  defp format_power(_), do: "N/A"

  defp format_odometer(km) when is_number(km), do: "#{Float.round(km * 1.0, 3)}"
  defp format_odometer(km) when is_struct(km, Decimal), do: "#{Float.round(Decimal.to_float(km), 3)}"
  defp format_odometer(_), do: "N/A"

  defp format_odometer_change(start_km, end_km) when is_number(start_km) and is_number(end_km) do
    change = end_km - start_km
    "#{format_odometer(start_km)} → #{format_odometer(end_km)} (+#{Float.round(change, 3)} km)"
  end
  defp format_odometer_change(start_km, end_km) when is_struct(start_km, Decimal) and is_struct(end_km, Decimal) do
    start_float = Decimal.to_float(start_km)
    end_float = Decimal.to_float(end_km)
    change = end_float - start_float
    "#{format_odometer(start_km)} → #{format_odometer(end_km)} (+#{Float.round(change, 3)} km)"
  end
  defp format_odometer_change(_, _), do: "N/A"

  defp format_elevation(elevation) when is_number(elevation), do: "#{elevation} m"
  defp format_elevation(_), do: "N/A"

  defp format_duration_minutes(minutes) when is_number(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)
    
    cond do
      hours > 0 -> "#{hours}h #{remaining_minutes}m"
      remaining_minutes > 0 -> "#{remaining_minutes}m"
      true -> "0m"
    end
  end
  defp format_duration_minutes(_), do: "N/A"

  defp get_latest_range(car_id) do
    now = DateTime.utc_now()
    yesterday = DateTime.add(now, -24 * 60 * 60, :second)
    
    query = """
    SELECT date AS "time", range as "range_km"
    FROM (
      (SELECT date, est_battery_range_km AS range
       FROM positions
       WHERE car_id = $1 AND est_battery_range_km IS NOT NULL 
       AND date BETWEEN $2 AND $3
       ORDER BY date DESC
       LIMIT 1)
      UNION ALL
      (SELECT date, ideal_battery_range_km AS range
       FROM charges c
       JOIN charging_processes p ON p.id = c.charging_process_id
       WHERE p.car_id = $1 AND date BETWEEN $2 AND $3
       ORDER BY date DESC
       LIMIT 1)
    ) AS data
    ORDER BY date DESC
    LIMIT 1
    """
    
    case TeslaMate.Repo.query(query, [car_id, yesterday, now]) do
      {:ok, %{rows: [[_date, range_km] | _]}} when is_number(range_km) ->
        Float.round(range_km, 1)
      {:ok, %{rows: [[_date, %Decimal{} = range_km] | _]}} ->
        Float.round(Decimal.to_float(range_km), 1)
      _ ->
        nil
    end
  end
end 