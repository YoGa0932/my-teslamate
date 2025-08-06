defmodule TeslaMate.Email.Templates.ChargingEmail.ChargingInfoFormatter do
  @moduledoc """
  Charging information formatter
  """

  def format_charging_info(charging) do
    %{
      # Basic statistics
      energy_added: format_energy_added(charging.charge_energy_added),
      duration: format_duration(charging.duration_min),
      charging_type: format_charging_type(charging),
      total_cost: format_total_cost(charging),
      power_avg: format_power_avg(charging.power_avg),
      energy_used: format_energy_used(charging.charge_energy_used),
      efficiency: format_efficiency(charging.charge_energy_added, charging.charge_energy_used),
      cost_per_kwh: format_cost_per_kwh(charging),
      
      # Battery information
      battery_level_change: format_battery_level_change(charging.start_battery_level, charging.end_battery_level),
      rated_range_change: format_rated_range_change(charging.start_rated_range_km, charging.end_rated_range_km),
      
      # Location information
      charging_location: format_charging_location(charging.geofence, charging.address),
      
      # Environment information
      outside_temp: format_outside_temp(charging.outside_temp_avg),
      
      # Time information
      start_time: format_datetime(charging.start_date),
      end_time: format_datetime(charging.end_date)
    }
  end

  defp format_energy_added(energy) when is_number(energy), do: "#{energy} kWh"
  defp format_energy_added(energy) when is_struct(energy, Decimal), do: "#{Decimal.to_float(energy)} kWh"
  defp format_energy_added(_), do: "N/A"

  defp format_duration(duration) when is_number(duration), do: format_duration_minutes(duration)
  defp format_duration(_), do: "N/A"

  defp format_charging_type(charging) do
    # Use TeslaMate's standard method to determine charging type
    case TeslaMate.Log.determine_charging_type(charging) do
      "DC" -> "DC Fast Charging"
      "AC" -> "AC Charging"
      _ -> "Unknown"
    end
  end

  defp format_total_cost(charging_process) do
    cond do
      charging_process.cost ->
        cost_float = if is_struct(charging_process.cost, Decimal), do: Decimal.to_float(charging_process.cost), else: charging_process.cost
        "¥#{Float.round(cost_float, 2)}"
      charging_process.charge_energy_added ->
        energy_float = if is_struct(charging_process.charge_energy_added, Decimal), do: Decimal.to_float(charging_process.charge_energy_added), else: charging_process.charge_energy_added
        "¥#{Float.round(energy_float * 1.0, 2)}"
      true ->
        "N/A"
    end
  end

  defp format_power_avg(power) when is_number(power), do: "#{Float.round(power, 1)} kW"
  defp format_power_avg(_), do: "N/A"

  defp format_energy_used(energy) when is_number(energy), do: "#{energy} kWh"
  defp format_energy_used(energy) when is_struct(energy, Decimal), do: "#{Decimal.to_float(energy)} kWh"
  defp format_energy_used(_), do: "N/A"

  defp format_efficiency(energy_added, energy_used) do
    case {energy_used, energy_added} do
      {energy_used, energy_added} when not is_nil(energy_used) and not is_nil(energy_added) ->
        try do
          if not Decimal.equal?(energy_used, Decimal.new("0")) do
            efficiency = Decimal.to_float(Decimal.div(energy_added, energy_used)) * 100
            "#{Float.round(efficiency, 1)}%"
          else
            "N/A"
          end
        rescue
          _ -> "N/A"
        end
      _ -> "N/A"
    end
  end

  defp format_cost_per_kwh(charging_process) do
    case {charging_process.cost, charging_process.charge_energy_added} do
      {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
        try do
          if Decimal.equal?(energy_added, Decimal.new("0")) do
            "N/A"
          else
            cost_per_kwh = Decimal.div(cost, energy_added)
            "¥#{Float.round(Decimal.to_float(cost_per_kwh), 3)}/kWh"
          end
        rescue
          _ -> "N/A"
        end
      _ -> "N/A"
    end
  end

  defp format_battery_level_change(start_level, end_level) when is_number(start_level) and is_number(end_level) do
    "#{start_level}% → #{end_level}%"
  end
  defp format_battery_level_change(_, _), do: "N/A"

  defp format_rated_range_change(start_range, end_range) when is_number(start_range) and is_number(end_range) do
    "#{start_range} → #{end_range} km"
  end
  defp format_rated_range_change(start_range, end_range) when is_struct(start_range, Decimal) and is_struct(end_range, Decimal) do
    start_float = Decimal.to_float(start_range)
    end_float = Decimal.to_float(end_range)
    "#{start_float} → #{end_float} km"
  end
  defp format_rated_range_change(_, _), do: "N/A"

  defp format_charging_location(geofence, address) do
    cond do
      not is_nil(geofence) and not is_nil(address) ->
        "#{geofence.name} (#{address.name})"
      not is_nil(address) ->
        "#{address.name}, #{address.city}"
      true ->
        "Unknown Location"
    end
  end

  defp format_outside_temp(temp) when is_number(temp), do: "#{temp}°C"
  defp format_outside_temp(temp) when is_struct(temp, Decimal), do: "#{Decimal.to_float(temp)}°C"
  defp format_outside_temp(_), do: "N/A"

  defp format_datetime(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: "N/A"

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
end 