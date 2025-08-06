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
        
        # Simplified calculation logic
        drive_with_calculations = calculate_drive_metrics(drive)
        drive = TeslaMate.Repo.preload(drive_with_calculations, [:car, :start_address, :end_address, :start_geofence, :end_geofence])

        # Generate email subject
        drive_subject = generate_drive_subject(drive)
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: drive_subject,
          html_body: TeslaMate.Email.Templates.DriveEmail.generate_html(drive)
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
        
        # Simplified calculation logic
        charging_with_calculations = calculate_charging_metrics(charging_process)
        charging_process = TeslaMate.Repo.preload(charging_with_calculations, [:car, :address, :geofence])

        # Generate email subject
        charging_subject = generate_charging_subject(charging_process)
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: charging_subject,
          html_body: TeslaMate.Email.Templates.ChargingEmail.generate_html(charging_process)
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
        
        # Generate startup email subject
        startup_time = format_datetime_local(DateTime.utc_now())
        startup_subject = "🚀 [#{startup_time}] TeslaMate Service Started"
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: startup_subject,
          html_body: TeslaMate.Email.Templates.StartupEmail.generate_html(system_info)
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
      version: get_version(),
      erlang_version: System.otp_release(),
      elixir_version: System.version(),
      hostname: System.cmd("hostname", []) |> elem(0) |> String.trim(),
      uptime: get_uptime(),
      memory: get_memory_info(),
      database_status: check_database_status(),
      settings: get_settings_info(),
      latest_drive: get_latest_drive(),
      latest_charging: get_latest_charging()
    }
  end

  defp get_version() do
    # Try to get version from Application spec first
    case Application.spec(:teslamate, :vsn) do
      nil -> 
        # Fallback to reading VERSION file
        case File.read("VERSION") do
          {:ok, version} -> String.trim(version)
          {:error, _reason} -> "Unknown"
        end
      version when is_binary(version) -> 
        version
      _ -> 
        "Unknown"
    end
  end

  defp get_latest_drive() do
    # Get latest drive record with car information
    Drive
    |> order_by([d], desc: d.end_date)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> 
        Logger.info("No drive records found")
        nil
      drive -> 
        drive
        |> Repo.preload([:car, :start_address, :end_address, :start_geofence, :end_geofence])
        |> calculate_drive_metrics()
    end
  end

  defp calculate_drive_metrics(drive) do
    # Calculate average speed
    avg_speed = if drive.distance && drive.duration_min && drive.duration_min > 0 do
      distance_float = if is_struct(drive.distance, Decimal), do: Decimal.to_float(drive.distance), else: drive.distance
      result = distance_float / (drive.duration_min / 60.0)
      # Ensure result is float
      if is_integer(result), do: result * 1.0, else: result
    else
      nil
    end

    # Get efficiency from drive.car.efficiency
    efficiency = drive.car.efficiency

    # Calculate energy consumption
    energy_consumption_wh_per_km = case {drive.start_rated_range_km, drive.end_rated_range_km, efficiency} do
      {start_range, end_range, eff} when not is_nil(start_range) and not is_nil(end_range) and not is_nil(eff) ->
        # start_rated_range_km and end_rated_range_km are numeric (Decimal)
        start_float = Decimal.to_float(start_range)
        end_float = Decimal.to_float(end_range)
        range_diff = start_float - end_float
        distance_float = if is_struct(drive.distance, Decimal), do: Decimal.to_float(drive.distance), else: drive.distance
        if range_diff > 0 and distance_float > 0 do
          result = range_diff * eff * 1000 / distance_float
          # Ensure result is float
          if is_integer(result), do: result * 1.0, else: result
        else
          nil
        end
      _ -> nil
    end

    # Calculate energy used
    energy_used_kwh = case {drive.start_rated_range_km, drive.end_rated_range_km, efficiency} do
      {start_range, end_range, eff} when not is_nil(start_range) and not is_nil(end_range) and not is_nil(eff) ->
        # start_rated_range_km and end_rated_range_km are numeric (Decimal)
        start_float = Decimal.to_float(start_range)
        end_float = Decimal.to_float(end_range)
        range_diff = start_float - end_float
        range_diff * eff
      _ -> nil
    end

    # Get latest range
    latest_range = get_latest_range(drive.car_id)

    drive
    |> Map.put(:avg_speed, avg_speed)
    |> Map.put(:energy_consumption_wh_per_km, energy_consumption_wh_per_km)
    |> Map.put(:energy_used_kwh, energy_used_kwh)
    |> Map.put(:latest_range, latest_range)
  end

  defp calculate_charging_metrics(charging_process) do
    # Calculate average power
    power_avg = case {charging_process.charge_energy_added, charging_process.duration_min} do
      {energy_added, duration} when not is_nil(energy_added) and not is_nil(duration) and duration > 0 ->
        # charge_energy_added is numeric (Decimal), duration_min is smallint (integer)
        energy_float = Decimal.to_float(energy_added)
        energy_float / (duration / 60.0)
      _ -> nil
    end

    # Calculate cost per kWh
    cost_per_kwh = case {charging_process.cost, charging_process.charge_energy_added} do
      {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
        energy_float = Decimal.to_float(energy_added)
        if energy_float > 0 do
          Decimal.div(cost, energy_added)
        else
          nil
        end
      _ -> nil
    end

    charging_process
    |> Map.put(:power_avg, power_avg)
    |> Map.put(:cost_per_kwh, cost_per_kwh)
  end

  def get_range_analysis(start_rated_range, end_rated_range, actual_distance) do
    cond do
      is_nil(start_rated_range) or is_nil(end_rated_range) or is_nil(actual_distance) ->
        "N/A"
      true ->
        # start_rated_range and end_rated_range are numeric (Decimal)
        start_float = Decimal.to_float(start_rated_range)
        end_float = Decimal.to_float(end_rated_range)
        range_change = start_float - end_float
        actual_distance_float = actual_distance
        
        cond do
          range_change > actual_distance_float ->
            difference = range_change - actual_distance_float
            percentage = (difference / actual_distance_float) * 100
            "Reduced #{Float.round(range_change, 1)}km (Higher than actual distance #{Float.round(difference, 1)}km, +#{Float.round(percentage, 1)}%)"
          range_change < actual_distance_float ->
            difference = actual_distance_float - range_change
            percentage = (difference / actual_distance_float) * 100
            "Reduced #{Float.round(range_change, 1)}km (Lower than actual distance #{Float.round(difference, 1)}km, -#{Float.round(percentage, 1)}%)"
          true ->
            "Reduced #{Float.round(range_change, 1)}km (Matches actual distance)"
        end
    end
  end

  defp get_settings_info() do
    query = """
    SELECT 
      unit_of_length,
      unit_of_temperature,
      preferred_range,
      base_url,
      grafana_url,
      language,
      unit_of_pressure
    FROM settings 
    WHERE id = 1
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [[unit_of_length, unit_of_temperature, preferred_range, base_url, grafana_url, language, unit_of_pressure] | _]}} ->
        Logger.info("Settings query successful", base_url: base_url, grafana_url: grafana_url, language: language)
        %{
          unit_of_length: to_string(unit_of_length),
          unit_of_temperature: to_string(unit_of_temperature),
          preferred_range: to_string(preferred_range),
          base_url: (if is_nil(base_url) or base_url == "", do: "N/A", else: to_string(base_url)),
          grafana_url: (if is_nil(grafana_url) or grafana_url == "", do: "N/A", else: to_string(grafana_url)),
          language: (if is_nil(language) or language == "", do: "en", else: to_string(language)),
          unit_of_pressure: to_string(unit_of_pressure)
        }
      {:ok, %{rows: []}} ->
        Logger.warning("Settings query returned no rows")
        %{
          unit_of_length: "km",
          unit_of_temperature: "C",
          preferred_range: "rated",
          base_url: "N/A",
          grafana_url: "N/A",
          language: "en",
          unit_of_pressure: "bar"
        }
      {:error, reason} ->
        Logger.error("Settings query failed", error: reason)
        %{
          unit_of_length: "km",
          unit_of_temperature: "C",
          preferred_range: "rated",
          base_url: "N/A",
          grafana_url: "N/A",
          language: "en",
          unit_of_pressure: "bar"
        }
    end
  end

  defp get_latest_charging() do
    # Get latest charging process with associations
    ChargingProcess
    |> order_by([cp], desc: cp.end_date)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> 
        Logger.info("No charging records found")
        nil
      charging -> 
        charging
        |> Repo.preload([:car, :address, :geofence])
        |> calculate_charging_metrics()
    end
  end



  defp generate_drive_subject(drive) do
    start_location = case {drive.start_geofence, drive.start_address} do
      {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
        "#{geofence.name} (#{address.name})"
      {nil, address} when not is_nil(address) ->
        address.name
      _ ->
        "Unknown Location"
    end
    
    end_location = case {drive.end_geofence, drive.end_address} do
      {geofence, address} when not is_nil(geofence) and not is_nil(address) ->
        "#{geofence.name} (#{address.name})"
      {nil, address} when not is_nil(address) ->
        address.name
      _ ->
        "Unknown Location"
    end
    
    drive_time = format_datetime_local(drive.start_date)
    distance_float = if is_struct(drive.distance, Decimal), do: Decimal.to_float(drive.distance), else: drive.distance
    "🚗 [#{drive_time}] #{start_location} → #{end_location} (#{Float.round(distance_float, 1)}km, #{drive.duration_min}min)"
  end

  defp generate_charging_subject(charging_process) do
    charging_location = if charging_process.geofence, do: "#{charging_process.geofence.name} (#{charging_process.address.name})", else: charging_process.address.name
    charging_time = format_datetime_local(charging_process.start_date)
    energy_float = if is_struct(charging_process.charge_energy_added, Decimal), do: Decimal.to_float(charging_process.charge_energy_added), else: charging_process.charge_energy_added
    "🔋 [#{charging_time}] #{charging_location} (#{Float.round(energy_float, 1)}kWh, #{charging_process.duration_min}min)"
  end

  defp get_uptime() do
    case System.cmd("uptime", []) do
      {output, 0} -> String.trim(output)
      _ -> "Unable to get"
    end
  end

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
      {:ok, %{rows: [[_date, %Decimal{} = range_km] | _]}} ->
        Float.round(Decimal.to_float(range_km), 1)
      _ ->
        nil
    end
  end

  @doc """
  Call map service to generate drive track map
  """
  def call_map_service(drive_id) do
    service_url = case System.get_env("MAP_SERVICE_URL") do
      nil -> 
        Logger.info("MAP_SERVICE_URL not configured, using default", drive_id: drive_id)
        "http://localhost:5001"
      url when is_binary(url) and byte_size(url) > 0 -> 
        url
      _ ->
        Logger.error("MAP_SERVICE_URL is empty or invalid, using default", drive_id: drive_id)
        "http://localhost:5001"
    end
    
    request_body = Jason.encode!(%{drive_id: drive_id})
    case Finch.build(:post, "#{service_url}/generate_map", 
         [{"Content-Type", "application/json"}], 
         request_body)
         |> Finch.request(TeslaMate.HTTP, timeout: 30000) do
        
        {:ok, %Finch.Response{status: 200, body: body}} ->

          case Jason.decode(body) do
            {:ok, %{"success" => true, "image_base64" => image_base64, "drive_id" => ^drive_id} = map_info} ->
              Logger.info("Map generated successfully", drive_id: drive_id)
              {:ok, image_base64, map_info}
            
            {:ok, %{"success" => false, "error" => error}} ->

              {:error, error}
            
            {:ok, _response} ->

              {:error, "Invalid response format"}
            
            {:error, _decode_error} ->

              {:error, "Failed to parse response"}
          end
        
        {:ok, %Finch.Response{status: status_code, body: _body}} ->

          {:error, "HTTP #{status_code}"}
        
        {:error, _reason} ->

          {:error, "Connection failed"}
      end
  rescue
    _e ->

      {:error, "Service call failed"}
  end



end 