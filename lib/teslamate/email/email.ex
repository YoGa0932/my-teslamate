defmodule TeslaMate.Email.Mailer do
  use Swoosh.Mailer, otp_app: :teslamate
end

defmodule TeslaMate.Email do

  require Logger
  import Ecto.Query
  alias TeslaMate.Log.{Drive, ChargingProcess}
  alias TeslaMate.Repo

  @doc """
  Send drive record notification email
  """
  def send_drive_notification(drive) do
    case System.get_env("DRIVE_NOTIFICATION_EMAIL") do
      nil ->
        Logger.info("Email address not configured, skipping drive notification email send", car_id: drive.car_id, drive_id: drive.id)
        {:ok, "Email address not configured"}

      email_address when email_address == "your-email@example.com" ->
        Logger.info("Using default email address, skipping drive notification email send", car_id: drive.car_id, drive_id: drive.id)
        {:ok, "Using default email address"}

      email_address ->
        Logger.info("Attempting to send drive notification email to: #{email_address}", car_id: drive.car_id, drive_id: drive.id)
        # Calculate avg_speed and energy consumption and add them to the drive struct
        drive_with_calculations = case drive.duration_min do
          duration when duration > 0 -> 
            avg_speed = drive.distance / (duration / 60.0)
            drive_with_speed = Map.put(drive, :avg_speed, avg_speed)
            
            # Calculate energy consumption if we have the required data
            case {drive.start_rated_range_km, drive.end_rated_range_km, drive.distance, drive.car.efficiency} do
              {start_range, end_range, distance, efficiency} when not is_nil(start_range) and not is_nil(end_range) and not is_nil(distance) and not is_nil(efficiency) ->
                range_diff = Decimal.to_float(start_range) - Decimal.to_float(end_range)
                energy_consumption = if range_diff > 0, do: range_diff * efficiency * 1000 / distance, else: 0
                energy_used = if range_diff > 0, do: range_diff * efficiency, else: 0
                
                drive_with_speed
                |> Map.put(:energy_consumption_wh_per_km, Float.round(energy_consumption, 1))
                |> Map.put(:energy_used_kwh, Float.round(energy_used, 3))
              
              _ ->
                drive_with_speed
                |> Map.put(:energy_consumption_wh_per_km, nil)
                |> Map.put(:energy_used_kwh, nil)
            end
          _ -> 
            Map.put(drive, :avg_speed, nil)
            |> Map.put(:energy_consumption_wh_per_km, nil)
            |> Map.put(:energy_used_kwh, nil)
        end
        
        drive = TeslaMate.Repo.preload(drive_with_calculations, [:car, :start_address, :end_address, :start_geofence, :end_geofence])

        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: "New Drive Record - #{drive.car.name}",
          html_body: TeslaMate.Email.Templates.DriveEmail.generate_html(drive),
          text_body: TeslaMate.Email.Templates.DriveEmail.generate_text(drive)
        }

        smtp_config = get_smtp_config()
        
        smtp_config_keywords = [
          relay: smtp_config.relay,
          port: smtp_config.port,
          username: smtp_config.username,
          password: smtp_config.password,
          tls: smtp_config.tls,
          auth: smtp_config.auth,
          retries: smtp_config.retries,
          no_mx_lookups: smtp_config.no_mx_lookups
        ]
        
        case Swoosh.Adapters.SMTP.deliver(email, smtp_config_keywords) do
          {:ok, _response} ->
            Logger.info("Drive record email sent successfully", car_id: drive.car.id, drive_id: drive.id)
            {:ok, "Email sent successfully"}

          {:error, reason} ->
            Logger.error("Drive record email send failed: #{inspect(reason)}", car_id: drive.car.id, drive_id: drive.id)
            {:error, reason}
        end
    end
  end

  @doc """
  Send charging completion notification email
  """
  def send_charging_notification(charging_process) do
    case System.get_env("DRIVE_NOTIFICATION_EMAIL") do
      nil ->
        Logger.info("Email address not configured, skipping charging notification email send", car_id: charging_process.car_id, charging_process_id: charging_process.id)
        {:ok, "Email address not configured"}

      email_address when email_address == "your-email@example.com" ->
        Logger.info("Using default email address, skipping charging notification email send", car_id: charging_process.car_id, charging_process_id: charging_process.id)
        {:ok, "Using default email address"}

      email_address ->
        Logger.info("Attempting to send charging notification email to: #{email_address}", car_id: charging_process.car_id, charging_process_id: charging_process.id)
        # Calculate power_avg and add it to the charging_process struct
        charging_with_power_avg = case charging_process.duration_min do
          duration when duration > 0 -> 
            power_avg = charging_process.charge_energy_added / (duration / 60.0)
            Map.put(charging_process, :power_avg, power_avg)
          _ -> 
            Map.put(charging_process, :power_avg, nil)
        end
        
        charging_process = TeslaMate.Repo.preload(charging_with_power_avg, [:car, :address, :geofence])

        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: "Charging Complete - #{charging_process.car.name}",
          html_body: TeslaMate.Email.Templates.ChargingEmail.generate_html(charging_process),
          text_body: TeslaMate.Email.Templates.ChargingEmail.generate_text(charging_process)
        }

        smtp_config = get_smtp_config()
        
        smtp_config_keywords = [
          relay: smtp_config.relay,
          port: smtp_config.port,
          username: smtp_config.username,
          password: smtp_config.password,
          tls: smtp_config.tls,
          auth: smtp_config.auth,
          retries: smtp_config.retries,
          no_mx_lookups: smtp_config.no_mx_lookups
        ]
        
        case Swoosh.Adapters.SMTP.deliver(email, smtp_config_keywords) do
          {:ok, _response} ->
            Logger.info("Charging notification email sent successfully", car_id: charging_process.car.id, charging_process_id: charging_process.id)
            {:ok, "Email sent successfully"}

          {:error, reason} ->
            Logger.error("Charging notification email send failed: #{inspect(reason)}", car_id: charging_process.car.id, charging_process_id: charging_process.id)
            {:error, reason}
        end
    end
  end

  @doc """
  Send service startup notification email
  """
  def send_startup_notification() do
    case System.get_env("DRIVE_NOTIFICATION_EMAIL") do
      nil ->
        Logger.info("Email address not configured, skipping startup notification email send")
        {:ok, "Email address not configured"}

      email_address when email_address == "your-email@example.com" ->
        Logger.info("Using default email address, skipping startup notification email send")
        {:ok, "Using default email address"}

      email_address ->
        Logger.info("Attempting to send startup notification email to: #{email_address}")
        
        system_info = get_system_info()
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: "TeslaMate Service Started",
          html_body: TeslaMate.Email.Templates.StartupEmail.generate_html(system_info),
          text_body: TeslaMate.Email.Templates.StartupEmail.generate_text(system_info)
        }

        smtp_config = get_smtp_config()
        
        smtp_config_keywords = [
          relay: smtp_config.relay,
          port: smtp_config.port,
          username: smtp_config.username,
          password: smtp_config.password,
          tls: smtp_config.tls,
          auth: smtp_config.auth,
          retries: smtp_config.retries,
          no_mx_lookups: smtp_config.no_mx_lookups
        ]
        
        case Swoosh.Adapters.SMTP.deliver(email, smtp_config_keywords) do
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
      database_status: check_database_status(),
      latest_drive: get_latest_drive(),
      latest_charging: get_latest_charging()
    }
  end

  defp get_latest_drive() do
    query = """
    SELECT 
      d.*,
      CASE 
        WHEN d.duration_min > 0 THEN d.distance / (d.duration_min / 60.0)
        ELSE NULL 
      END as avg_speed,
      CASE 
        WHEN d.start_rated_range_km IS NOT NULL AND d.end_rated_range_km IS NOT NULL AND d.distance IS NOT NULL AND c.efficiency IS NOT NULL THEN
          CASE 
            WHEN (d.start_rated_range_km - d.end_rated_range_km) > 0 THEN 
              (d.start_rated_range_km - d.end_rated_range_km) * c.efficiency * 1000 / d.distance
            ELSE 0 
          END
        ELSE NULL 
      END as energy_consumption_wh_per_km,
      CASE 
        WHEN d.start_rated_range_km IS NOT NULL AND d.end_rated_range_km IS NOT NULL AND c.efficiency IS NOT NULL THEN
          CASE 
            WHEN (d.start_rated_range_km - d.end_rated_range_km) > 0 THEN 
              (d.start_rated_range_km - d.end_rated_range_km) * c.efficiency
            ELSE 0 
          END
        ELSE NULL 
      END as energy_used_kwh
    FROM drives d
    JOIN cars c ON c.id = d.car_id
    ORDER BY d.end_date DESC
    LIMIT 1
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [row]}} ->
        # Convert row to struct with calculated fields
        drive_data = Enum.zip_with(
          ["id", "car_id", "start_date", "end_date", "outside_temp_avg", "inside_temp_avg", 
           "speed_max", "power_max", "power_min", "start_ideal_range_km", "end_ideal_range_km",
           "start_rated_range_km", "end_rated_range_km", "start_km", "end_km", "distance", 
           "duration_min", "ascent", "descent", "start_position_id", "end_position_id",
           "start_address_id", "end_address_id", "start_geofence_id", "end_geofence_id", "avg_speed",
           "energy_consumption_wh_per_km", "energy_used_kwh"],
          row,
          fn field, value -> 
            case field do
              field_name when field_name in ["avg_speed", "energy_consumption_wh_per_km", "energy_used_kwh"] -> 
                case value do
                  %Decimal{} -> {String.to_atom(field), Float.round(Decimal.to_float(value), 1)}
                  value when is_number(value) -> {String.to_atom(field), Float.round(value, 1)}
                  _ -> {String.to_atom(field), nil}
                end
              _ -> {String.to_atom(field), value}
            end
          end
        ) |> Map.new()
        
        # Preload associations
        drive_id = drive_data.id
        Drive
        |> where(id: ^drive_id)
        |> Repo.one()
        |> case do
          nil -> nil
          drive -> 
            drive
            |> Repo.preload([:car, :start_address, :end_address, :start_geofence, :end_geofence])
            |> Map.put(:avg_speed, drive_data.avg_speed)
        end
        
      _ -> nil
    end
  end

  defp get_latest_charging() do
    query = """
    SELECT 
      cp.*,
      CASE 
        WHEN cp.duration_min > 0 THEN cp.charge_energy_added / (cp.duration_min / 60.0)
        ELSE NULL 
      END as power_avg
    FROM charging_processes cp
    ORDER BY cp.end_date DESC
    LIMIT 1
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [row]}} ->
        # Convert row to struct with calculated power_avg
        charging_data = Enum.zip_with(
          ["id", "car_id", "start_date", "end_date", "charge_energy_added", "charge_energy_used",
           "start_ideal_range_km", "end_ideal_range_km", "start_rated_range_km", "end_rated_range_km",
           "start_battery_level", "end_battery_level", "duration_min", "outside_temp_avg", "cost",
           "position_id", "address_id", "geofence_id", "power_avg"],
          row,
          fn field, value -> 
            case field do
              "power_avg" -> 
                case value do
                  %Decimal{} -> {String.to_atom(field), Decimal.to_float(value)}
                  value when is_number(value) -> {String.to_atom(field), value}
                  _ -> {String.to_atom(field), nil}
                end
              _ -> {String.to_atom(field), value}
            end
          end
        ) |> Map.new()
        
        # Preload associations
        charging_id = charging_data.id
        ChargingProcess
        |> where(id: ^charging_id)
        |> Repo.one()
        |> case do
          nil -> nil
          charging -> 
            charging
            |> Repo.preload([:car, :address, :geofence])
            |> Map.put(:power_avg, charging_data.power_avg)
        end
        
      _ -> nil
    end
  end

  defp get_uptime() do
    case System.cmd("uptime", []) do
      {output, 0} -> String.trim(output)
      _ -> "Unable to get"
    end
  end

  defp get_smtp_config() do
    username = case System.get_env("SMTP_USERNAME") do
      nil ->
        Logger.error("SMTP_USERNAME environment variable is not set.")
        raise "SMTP_USERNAME environment variable is not set. Please set SMTP_USERNAME in your environment or systemd service file."
      username when is_binary(username) and byte_size(username) > 0 ->
        Logger.debug("Successfully got SMTP username", username_length: byte_size(username))
        username
      _ ->
        Logger.error("SMTP_USERNAME environment variable is empty")
        raise "SMTP_USERNAME environment variable is empty. Please set a valid SMTP_USERNAME."
    end

    password = case System.get_env("SMTP_PASSWORD") do
      nil ->
        Logger.error("SMTP_PASSWORD environment variable is not set.")
        raise "SMTP_PASSWORD environment variable is not set. Please set SMTP_PASSWORD in your environment or systemd service file."
      password when is_binary(password) and byte_size(password) > 0 ->
        Logger.debug("Successfully got SMTP password", password_length: byte_size(password))
        password
      _ ->
        Logger.error("SMTP_PASSWORD environment variable is empty")
        raise "SMTP_PASSWORD environment variable is empty. Please set a valid SMTP_PASSWORD."
    end

    relay = System.get_env("SMTP_RELAY", "smtp.qq.com")
    port = case System.get_env("SMTP_PORT", "587") do
      port_str when is_binary(port_str) ->
        case Integer.parse(port_str) do
          {port_int, _} -> port_int
          :error -> 587
        end
      _ -> 587
    end

    %{
      relay: relay,
      port: port,
      username: username,
      password: password,
      tls: :always,
      auth: :always,
      retries: 2,
      no_mx_lookups: false,
      ssl_options: [
        verify: :verify_none,
        server_name_indication: relay
      ]
    }
  end

  defp get_memory_info() do
    case System.cmd("free", ["-h"]) do
      {output, 0} -> 
        lines = String.split(output, "\n")
        case lines do
          [_header, memory_line | _] ->
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
        %{total: "System Memory", used: "Running", free: "Available"}
    end
  end

  defp check_database_status() do
    case TeslaMate.Repo.query("SELECT 1") do
      {:ok, _} -> "Normal"
      {:error, _} -> "Error"
    end
  end

  def format_datetime(datetime) when not is_nil(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  def format_datetime(_), do: "Unknown"

  def format_datetime_local(datetime) when not is_nil(datetime) do
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, "%Y-%m-%d %H:%M:%S")
  end
  def format_datetime_local(_), do: "Unknown"

  @doc """
  Get the latest estimated range for a car
  """
  def get_latest_range(car_id) do
    # Get current time and 24 hours ago
    now = DateTime.utc_now()
    yesterday = DateTime.add(now, -24 * 60 * 60, :second)
    
    # Query for latest range from positions or charges
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
      _ ->
        nil
    end
  end

end 