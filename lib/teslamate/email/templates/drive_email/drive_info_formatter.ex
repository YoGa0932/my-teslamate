defmodule TeslaMate.Email.Templates.DriveEmail.DriveInfoFormatter do
  @moduledoc """
  Drive information formatter
  """

  alias TeslaMate.Email.Templates.Utils.CommonFormatter

  def format_drive_info(drive) do
    %{
      # Basic statistics
      distance: format_distance(drive.distance),
      duration: format_precise_duration(drive.precise_duration_seconds),
      speed_max: format_speed(drive.speed_max),
      avg_speed: format_speed(drive.avg_speed),
      energy_consumption: format_energy_consumption(drive.energy_consumption_wh_per_km),
      energy_used: format_energy_used(drive.energy_used_kwh),
      efficiency_ratio: format_efficiency_ratio(drive.efficiency_ratio),
      estimated_range: format_estimated_range(drive.car_id),
      projected_range: format_projected_range(drive),
      drive_cost: format_drive_cost(drive),
      
      # Time information
      start_time: CommonFormatter.format_datetime(drive.start_date),
      end_time: CommonFormatter.format_datetime(drive.end_date),
      
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
      descent: format_elevation(drive.descent),
      
      # Temperature information
      outside_temp: CommonFormatter.format_temperature(drive.outside_temp_avg),
      inside_temp: CommonFormatter.format_temperature(drive.inside_temp_avg),
      
      # Since last charge information
      since_last_charge_energy: format_since_last_charge_energy(drive.since_last_charge_energy),
      since_last_charge_distance: format_since_last_charge_distance(drive.since_last_charge_distance),
      since_last_charge_avg_consumption: format_since_last_charge_avg_consumption(drive.since_last_charge_avg_consumption)
    }
  end

  defp format_distance(distance) when is_number(distance), do: "#{Float.round(distance, 3)} km"
  defp format_distance(_), do: "N/A"



  defp format_precise_duration(seconds) when is_number(seconds) and seconds > 0 do
    hours = div(seconds, 3600)
    remaining_seconds = rem(seconds, 3600)
    minutes = div(remaining_seconds, 60)
    final_seconds = rem(remaining_seconds, 60)
    
    cond do
      hours > 0 -> "#{hours}h #{minutes}m #{final_seconds}s"
      minutes > 0 -> "#{minutes}m #{final_seconds}s"
      final_seconds > 0 -> "#{final_seconds}s"
      true -> "0s"
    end
  end
  defp format_precise_duration(_), do: "N/A"

  defp format_speed(speed) when is_number(speed), do: "#{Float.round(speed * 1.0, 3)} km/h"
  defp format_speed(speed) when is_struct(speed, Decimal), do: "#{Float.round(Decimal.to_float(speed), 3)} km/h"
  defp format_speed(_), do: "N/A"

  defp format_energy_consumption(consumption) when is_number(consumption), do: "#{Float.round(consumption * 1.0, 1)} Wh/km"
  defp format_energy_consumption(consumption) when is_struct(consumption, Decimal), do: "#{Float.round(Decimal.to_float(consumption), 1)} Wh/km"
  defp format_energy_consumption(_), do: "N/A"

  defp format_energy_used(energy) when is_number(energy), do: "#{Float.round(energy * 1.0, 3)} kWh"
  defp format_energy_used(energy) when is_struct(energy, Decimal), do: "#{Float.round(Decimal.to_float(energy), 3)} kWh"
  defp format_energy_used(_), do: "N/A"

  defp format_efficiency_ratio(ratio) when is_number(ratio), do: "#{Float.round(ratio * 100, 1)}%"
  defp format_efficiency_ratio(ratio) when is_struct(ratio, Decimal), do: "#{Float.round(Decimal.to_float(ratio) * 100, 1)}%"
  defp format_efficiency_ratio(_), do: "N/A"

  defp format_since_last_charge_energy(energy) when is_number(energy), do: "#{Float.round(energy * 1.0, 3)} kWh"
  defp format_since_last_charge_energy(energy) when is_struct(energy, Decimal), do: "#{Float.round(Decimal.to_float(energy), 3)} kWh"
  defp format_since_last_charge_energy(_), do: "N/A"

  defp format_since_last_charge_distance(distance) when is_number(distance), do: "#{Float.round(distance * 1.0, 3)} km"
  defp format_since_last_charge_distance(distance) when is_struct(distance, Decimal), do: "#{Float.round(Decimal.to_float(distance), 3)} km"
  defp format_since_last_charge_distance(_), do: "N/A"

  defp format_since_last_charge_avg_consumption(consumption) when is_number(consumption), do: "#{Float.round(consumption * 1.0, 1)} Wh/km"
  defp format_since_last_charge_avg_consumption(consumption) when is_struct(consumption, Decimal), do: "#{Float.round(Decimal.to_float(consumption), 1)} Wh/km"
  defp format_since_last_charge_avg_consumption(_), do: "N/A"

  defp format_estimated_range(car_id) when not is_nil(car_id) do
    case get_latest_range(car_id) do
      range when is_struct(range, Decimal) -> "#{Decimal.to_float(range)} km"
      range when is_number(range) -> "#{range} km"
      _ -> "N/A"
    end
  end
  defp format_estimated_range(_), do: "N/A"

  defp format_projected_range(drive) do
    case TeslaMate.Log.calculate_projected_range(drive) do
      range when is_number(range) -> "#{range} km"
      _ -> "N/A"
    end
  end

  defp format_drive_cost(drive) do
    case TeslaMate.Log.calculate_drive_cost(drive) do
      cost when is_number(cost) -> "¥#{cost}"
      _ -> "N/A"
    end
  end

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
        actual_float = if is_struct(actual_distance, Decimal), do: Decimal.to_float(actual_distance), else: actual_distance
        
        range_consumed = start_float - end_float
        
        efficiency_diff = range_consumed - actual_float
        
        # Calculate over/under consumption percentage relative to actual distance
        # This shows what percentage of extra range was consumed compared to actual distance
        over_under_percentage = if actual_float > 0 do
          case efficiency_diff do
            diff when diff > 0 -> (diff / actual_float) * 100  # Over-consumed percentage
            diff when diff < 0 -> (abs(diff) / actual_float) * 100  # Under-consumed percentage
            _ -> 0
          end
        else
          0
        end
        
        cond do
          efficiency_diff > 0 ->
            "🔋 #{Float.round(range_consumed, 1)}km (over-consumed #{Float.round(efficiency_diff, 1)}km, +#{Float.round(over_under_percentage, 1)}%)"
          efficiency_diff < 0 ->
            "🔋 #{Float.round(range_consumed, 1)}km (under-consumed #{Float.round(abs(efficiency_diff), 1)}km, -#{Float.round(over_under_percentage, 1)}%)"
          true ->
            "🔋 #{Float.round(range_consumed, 1)}km (no difference, 0%)"
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

  defp get_latest_range(car_id) do
    import Ecto.Query
    
    case TeslaMate.Repo.one(
      from c in TeslaMate.Log.Car,
      where: c.id == ^car_id,
      select: c.efficiency
    ) do
      efficiency when not is_nil(efficiency) ->
        case TeslaMate.Repo.one(
          from d in TeslaMate.Log.Drive,
          where: d.car_id == ^car_id and not is_nil(d.end_rated_range_km),
          order_by: [desc: d.end_date],
          limit: 1,
          select: d.end_rated_range_km
        ) do
          range when not is_nil(range) -> range
          _ -> nil
        end
      _ -> nil
    end
  end
end 