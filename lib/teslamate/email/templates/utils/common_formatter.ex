defmodule TeslaMate.Email.Templates.Utils.CommonFormatter do
  @moduledoc """
  Common formatter for shared fields across email templates
  """

  def format_temperature(temp) when is_number(temp), do: "#{temp}°C"
  def format_temperature(temp) when is_struct(temp, Decimal), do: "#{Decimal.to_float(temp)}°C"
  def format_temperature(_), do: "N/A"

  def format_datetime(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  def format_datetime(_), do: "N/A"



  def format_precise_duration(seconds) when is_number(seconds) and seconds > 0 do
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
  def format_precise_duration(_), do: "N/A"

  def format_energy_used(energy) when is_number(energy), do: "#{Float.round(energy * 1.0, 3)} kWh"
  def format_energy_used(energy) when is_struct(energy, Decimal), do: "#{Float.round(Decimal.to_float(energy), 3)} kWh"
  def format_energy_used(_), do: "N/A"

  def format_distance(distance) when is_number(distance), do: "#{Float.round(distance, 3)} km"
  def format_distance(distance) when is_struct(distance, Decimal), do: "#{Float.round(Decimal.to_float(distance), 3)} km"
  def format_distance(_), do: "N/A"

  def format_speed(speed) when is_number(speed), do: "#{Float.round(speed * 1.0, 3)} km/h"
  def format_speed(speed) when is_struct(speed, Decimal), do: "#{Float.round(Decimal.to_float(speed), 3)} km/h"
  def format_speed(_), do: "N/A"

  def format_power(power) when is_number(power), do: "#{power} kW"
  def format_power(power) when is_struct(power, Decimal), do: "#{Decimal.to_float(power)} kW"
  def format_power(_), do: "N/A"

  def format_power_avg(power) when is_number(power), do: "#{Float.round(power, 1)} kW"
  def format_power_avg(power) when is_struct(power, Decimal), do: "#{Float.round(Decimal.to_float(power), 1)} kW"
  def format_power_avg(_), do: "N/A"

  def format_elevation(elevation) when is_number(elevation), do: "#{elevation} m"
  def format_elevation(elevation) when is_struct(elevation, Decimal), do: "#{Decimal.to_float(elevation)} m"
  def format_elevation(_), do: "N/A"

  def format_odometer(km) when is_number(km), do: "#{Float.round(km * 1.0, 3)}"
  def format_odometer(km) when is_struct(km, Decimal), do: "#{Float.round(Decimal.to_float(km), 3)}"
  def format_odometer(_), do: "N/A"
end 