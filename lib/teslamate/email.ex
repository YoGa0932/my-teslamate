defmodule TeslaMate.Email.Mailer do
  use Swoosh.Mailer, otp_app: :teslamate
end

defmodule TeslaMate.Email do

  require Logger

  @doc """
  Send drive record notification email
  """
  def send_drive_notification(drive) do
    # Check if email address is configured
    case System.get_env("DRIVE_NOTIFICATION_EMAIL") do
      nil ->
        Logger.info("Email address not configured, skipping drive notification email send", car_id: drive.car_id, drive_id: drive.id)
        {:ok, "Email address not configured"}

      email_address when email_address == "your-email@example.com" ->
        Logger.info("Using default email address, skipping drive notification email send", car_id: drive.car_id, drive_id: drive.id)
        {:ok, "Using default email address"}

      email_address ->
        Logger.info("Attempting to send drive notification email to: #{email_address}", car_id: drive.car_id, drive_id: drive.id)
        drive = TeslaMate.Repo.preload(drive, [:car, :start_address, :end_address, :start_geofence, :end_geofence])

        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("EMAIL_FROM_ADDRESS", "teslamate@example.com")},
          to: [{"User", email_address}],
          subject: "New Drive Record - #{drive.car.name}",
          html_body: generate_drive_email_html(drive),
          text_body: generate_drive_email_text(drive)
        }

        case TeslaMate.Email.Mailer.deliver(email) do
          {:ok, _response} ->
            Logger.info("Drive record email sent successfully", car_id: drive.car.id, drive_id: drive.id)
            {:ok, "Email sent successfully"}

          {:error, reason} ->
            Logger.error("Drive record email send failed: #{inspect(reason)}", car_id: drive.car.id, drive_id: drive.id)
            {:error, reason}
        end
    end
  end

  defp generate_drive_email_html(drive) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>New Drive Record</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .drive-info { margin: 20px 0; }
        .info-row { margin: 10px 0; }
        .label { font-weight: bold; color: #333; }
        .value { color: #666; }
        .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }
        .stat-box { background-color: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }
        .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #eee; color: #666; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🚗 New Drive Record</h1>
        <p>Your vehicle <strong>#{drive.car.name}</strong> completed a drive</p>
      </div>

      <div class="drive-info">
        <h2>📊 Drive Statistics</h2>
        <div class="stats">
          <div class="stat-box">
            <div class="label">Distance</div>
            <div class="value">#{format_distance(drive.distance)}</div>
          </div>
          <div class="stat-box">
            <div class="label">Duration</div>
            <div class="value">#{format_duration(drive.duration_min)}</div>
          </div>
          <div class="stat-box">
            <div class="label">Max Speed</div>
            <div class="value">#{format_speed(drive.speed_max)}</div>
          </div>
          <div class="stat-box">
            <div class="label">Avg Speed</div>
            <div class="value">#{format_speed(calculate_avg_speed(drive))}</div>
          </div>
        </div>

        <h3>📍 Route Information</h3>
        <div class="info-row">
          <span class="label">Start:</span>
          <span class="value">#{format_location(drive.start_address, drive.start_geofence)}</span>
        </div>
        <div class="info-row">
          <span class="label">End:</span>
          <span class="value">#{format_location(drive.end_address, drive.end_geofence)}</span>
        </div>

        <h3>🔋 Battery Information</h3>
        <div class="info-row">
          <span class="label">Start Range:</span>
          <span class="value">#{format_battery(drive.start_ideal_range_km)}</span>
        </div>
        <div class="info-row">
          <span class="label">End Range:</span>
          <span class="value">#{format_battery(drive.end_ideal_range_km)}</span>
        </div>

        <h3>🌡️ Environment Information</h3>
        <div class="info-row">
          <span class="label">Avg Outside Temp:</span>
          <span class="value">#{format_temperature(drive.outside_temp_avg)}</span>
        </div>
        <div class="info-row">
          <span class="label">Avg Inside Temp:</span>
          <span class="value">#{format_temperature(drive.inside_temp_avg)}</span>
        </div>

        <h3>⏰ Time Information</h3>
        <div class="info-row">
          <span class="label">Start Time:</span>
          <span class="value">#{format_datetime(drive.start_date)}</span>
        </div>
        <div class="info-row">
          <span class="label">End Time:</span>
          <span class="value">#{format_datetime(drive.end_date)}</span>
        </div>
      </div>

      <div class="footer">
        <p>This email was automatically sent by TeslaMate</p>
        <p>Drive Record ID: #{drive.id}</p>
      </div>
    </body>
    </html>
    """
  end

  defp generate_drive_email_text(drive) do
    """
    New Drive Record - #{drive.car.name}

    Drive Statistics:
    - Distance: #{format_distance(drive.distance)}
    - Duration: #{format_duration(drive.duration_min)}
    - Max Speed: #{format_speed(drive.speed_max)}
    - Avg Speed: #{format_speed(calculate_avg_speed(drive))}

    Route Information:
    - Start: #{format_location(drive.start_address, drive.start_geofence)}
    - End: #{format_location(drive.end_address, drive.end_geofence)}

    Battery Information:
    - Start Range: #{format_battery(drive.start_ideal_range_km)}
    - End Range: #{format_battery(drive.end_ideal_range_km)}

    Environment Information:
    - Avg Outside Temp: #{format_temperature(drive.outside_temp_avg)}
    - Avg Inside Temp: #{format_temperature(drive.inside_temp_avg)}

    Time Information:
    - Start Time: #{format_datetime(drive.start_date)}
    - End Time: #{format_datetime(drive.end_date)}

    ---
    This email was automatically sent by TeslaMate
    Drive Record ID: #{drive.id}
    """
  end

  defp format_distance(distance) when is_number(distance) do
    "#{Float.round(distance, 2)} km"
  end
  defp format_distance(_), do: "Unknown"

  defp format_duration(duration) when is_integer(duration) do
    hours = div(duration, 60)
    minutes = rem(duration, 60)
    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end
  defp format_duration(_), do: "Unknown"

  defp format_speed(speed) when is_integer(speed) do
    "#{speed} km/h"
  end
  defp format_speed(_), do: "Unknown"

  defp calculate_avg_speed(drive) do
    case {drive.distance, drive.duration_min} do
      {distance, duration} when is_number(distance) and is_integer(duration) and duration > 0 ->
        round(distance / (duration / 60))
      _ -> nil
    end
  end

  defp format_location(address, geofence) do
    cond do
      geofence && geofence.name -> geofence.name
      address && address.name -> "#{address.name}, #{address.city}"
      address -> "#{address.road}, #{address.city}"
      true -> "Unknown location"
    end
  end

  defp format_battery(range) when is_number(range) and range > 0 do
    "#{Float.round(range, 1)} km"
  end
  defp format_battery(_), do: "Unknown"

  defp format_temperature(temp) when is_number(temp) do
    "#{Float.round(temp, 1)}°C"
  end
  defp format_temperature(_), do: "Unknown"

  defp format_datetime(datetime) when not is_nil(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: "Unknown"

  @doc """
  Send service startup notification email
  """
  def send_startup_notification() do
    # Check if email address is configured
    case System.get_env("DRIVE_NOTIFICATION_EMAIL") do
      nil ->
        Logger.info("Email address not configured, skipping startup notification email send")
        {:ok, "Email address not configured"}

      email_address when email_address == "your-email@example.com" ->
        Logger.info("Using default email address, skipping startup notification email send")
        {:ok, "Using default email address"}

      email_address ->
        Logger.info("Attempting to send startup notification email to: #{email_address}")
        # Get system information
        system_info = get_system_info()
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("EMAIL_FROM_ADDRESS", "teslamate@example.com")},
          to: [{"User", email_address}],
          subject: "TeslaMate Service Started",
          html_body: generate_startup_email_html(system_info),
          text_body: generate_startup_email_text(system_info)
        }

        case TeslaMate.Email.Mailer.deliver(email) do
          {:ok, _response} ->
            Logger.info("Startup notification email sent successfully")
            {:ok, "Startup notification email sent successfully"}

          {:error, reason} ->
            Logger.error("Startup notification email send failed: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp get_system_info() do
    %{
      version: Application.spec(:teslamate, :vsn) || "Unknown",
      erlang_version: System.otp_release(),
      elixir_version: System.version(),
      hostname: System.cmd("hostname", []) |> elem(0) |> String.trim(),
      uptime: get_uptime(),
      memory: get_memory_info(),
      database_status: check_database_status()
    }
  end

  defp get_uptime() do
    case System.cmd("uptime", []) do
      {output, 0} -> String.trim(output)
      _ -> "Unable to get"
    end
  end

  defp get_memory_info() do
    case System.cmd("free", ["-h"]) do
      {output, 0} -> 
        lines = String.split(output, "\n")
        case lines do
          [_header, memory_line | _] ->
            # Parse memory line (e.g., "Mem:    7.7Gi  2.1Gi  5.6Gi")
            parts = String.split(memory_line, ~r/\s+/, trim: true)
            case parts do
              ["Mem:", total, used, free | _] ->
                %{total: total, used: used, free: free}
              _ ->
                %{total: "System Memory", used: "Running", free: "Available"}
            end
          _ -> 
            %{total: "System Memory", used: "Running", free: "Available"}
        end
      _ -> 
        # Fallback to basic info if free command fails
        %{total: "System Memory", used: "Running", free: "Available"}
    end
  end

  defp check_database_status() do
    try do
      TeslaMate.Repo.query!("SELECT version()")
      "Normal"
    rescue
      _ -> "Abnormal"
    end
  end

  defp generate_startup_email_html(info) do
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
            <div class="value">#{info.version}</div>
          </div>
          <div class="info-box">
            <div class="label">Erlang Version</div>
            <div class="value">#{info.erlang_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Elixir Version</div>
            <div class="value">#{info.elixir_version}</div>
          </div>
          <div class="info-box">
            <div class="label">Hostname</div>
            <div class="value">#{info.hostname}</div>
          </div>
        </div>

        <h3>💾 Memory Usage</h3>
        <div class="info-grid">
          <div class="info-box">
            <div class="label">Total Memory</div>
            <div class="value">#{info.memory.total}</div>
          </div>
          <div class="info-box">
            <div class="label">Used Memory</div>
            <div class="value">#{info.memory.used}</div>
          </div>
          <div class="info-box">
            <div class="label">Free Memory</div>
            <div class="value">#{info.memory.free}</div>
          </div>
          <div class="info-box">
            <div class="label">Database Status</div>
            <div class="value #{if info.database_status == "Normal", do: "status-ok", else: "status-error"}">#{info.database_status}</div>
          </div>
        </div>

        <h3>⏰ System Uptime</h3>
        <div class="info-box">
          <div class="value">#{info.uptime}</div>
        </div>
      </div>

      <div class="footer">
        <p>This email was automatically sent by TeslaMate</p>
        <p>Startup Time: #{format_datetime(DateTime.utc_now())}</p>
      </div>
    </body>
    </html>
    """
  end

  defp generate_startup_email_text(info) do
    """
    TeslaMate Service Startup Notification

    System Information:
    - TeslaMate Version: #{info.version}
    - Erlang Version: #{info.erlang_version}
    - Elixir Version: #{info.elixir_version}
    - Hostname: #{info.hostname}

    Memory Usage:
    - Total Memory: #{info.memory.total}
    - Used Memory: #{info.memory.used}
    - Free Memory: #{info.memory.free}
    - Database Status: #{info.database_status}

    System Uptime:
    #{info.uptime}

    ---
    This email was automatically sent by TeslaMate
    Startup Time: #{format_datetime(DateTime.utc_now())}
    """
  end
end 