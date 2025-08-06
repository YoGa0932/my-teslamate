defmodule TeslaMate.Email.Templates.StartupEmail.SystemInfoFormatter do
  @moduledoc """
  System information formatter
  """

  def format_system_info(info) do
    %{
      version: format_value(info.version, "Unknown"),
      erlang_version: format_value(info.erlang_version, "Unknown"),
      elixir_version: format_value(info.elixir_version, "Unknown"),
      hostname: format_value(info.hostname, "Unknown"),
      uptime: format_value(info.uptime, "Unknown")
    }
  end

  def format_memory_info(info) do
    memory = info.memory || %{}
    %{
      total: format_value(memory.total, "Unknown"),
      used: format_value(memory.used, "Unknown"),
      free: format_value(memory.free, "Unknown"),
      database_status: format_value(info.database_status, "Unknown"),
      database_status_class: get_database_status_class(info.database_status)
    }
  end

  def format_settings_info(info) do
    settings = info.settings || %{}
    %{
      unit_of_length: format_value(settings.unit_of_length, "km"),
      unit_of_temperature: format_value(settings.unit_of_temperature, "C"),
      preferred_range: format_value(settings.preferred_range, "rated"),
      language: format_value(settings.language, "en"),
      unit_of_pressure: format_value(settings.unit_of_pressure, "bar"),
      base_url: format_url(settings.base_url),
      grafana_url: format_url(settings.grafana_url)
    }
  end

  defp format_value(value, default) do
    cond do
      is_binary(value) and byte_size(value) > 0 -> value
      is_number(value) -> "#{value}"
      true -> default
    end
  end

  defp format_url(url) when is_binary(url) and byte_size(url) > 0, do: url
  defp format_url(_), do: "N/A"

  defp get_database_status_class("Normal"), do: "status-ok"
  defp get_database_status_class(_), do: "status-error"
end 