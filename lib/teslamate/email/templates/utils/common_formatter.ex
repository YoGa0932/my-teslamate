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

  def format_duration_minutes(minutes) when is_number(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)
    
    cond do
      hours > 0 -> "#{hours}h #{remaining_minutes}m"
      remaining_minutes > 0 -> "#{remaining_minutes}m"
      true -> "0m"
    end
  end
  def format_duration_minutes(_), do: "N/A"
end 