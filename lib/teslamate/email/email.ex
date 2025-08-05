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
                range_diff = (if is_struct(start_range, Decimal), do: Decimal.to_float(start_range), else: start_range) - 
                             (if is_struct(end_range, Decimal), do: Decimal.to_float(end_range), else: end_range)
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

        # Generate drive subject with location and stats
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
        
        drive_time = TeslaMate.Email.format_datetime_local(drive.start_date)
        drive_subject = "🚗 [#{drive_time}] #{start_location} → #{end_location} (#{Float.round(drive.distance, 1)}km, #{drive.duration_min}min)"
        
        # Get map generation info from Python service
        map_info = case call_map_service(drive.id) do
          {:ok, base64_image, map_info} -> Map.put(map_info, :image_base64, base64_image)
          _ -> nil
        end
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: drive_subject,
          html_body: TeslaMate.Email.Templates.DriveEmail.generate_html(drive, map_info),
          text_body: TeslaMate.Email.Templates.DriveEmail.generate_text(drive, map_info)
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
        # Calculate power_avg and cost_per_kwh and add them to the charging_process struct
        charging_with_calculations = case {charging_process.charge_energy_added, charging_process.duration_min} do
          {charge_energy_added, duration} when not is_nil(charge_energy_added) and not is_nil(duration) and duration > 0 -> 
            try do
              power_avg = charge_energy_added / (duration / 60.0)
              charging_with_power = Map.put(charging_process, :power_avg, power_avg)
              
              # Calculate cost_per_kwh if cost and charge_energy_added are available
              cost_per_kwh = case {charging_process.cost, charging_process.charge_energy_added} do
                {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
                  try do
                    if Decimal.equal?(energy_added, Decimal.new("0")) do
                      nil
                    else
                      cost_per_kwh = Decimal.div(cost, energy_added)
                      Logger.info("Charging cost_per_kwh calculation", cost: cost, energy_added: energy_added, cost_per_kwh: cost_per_kwh)
                      Decimal.to_float(cost_per_kwh) |> Float.round(2)
                    end
                  rescue
                    error ->
                      Logger.error("Failed to calculate charging cost_per_kwh", error: error, cost: cost, energy_added: energy_added)
                      nil
                  end
                _ -> nil
              end
              
              Map.put(charging_with_power, :cost_per_kwh, cost_per_kwh)
            rescue
              ArithmeticError ->
                Logger.warning("Failed to calculate power_avg due to arithmetic error", 
                              charge_energy_added: charge_energy_added, duration: duration)
                charging_with_power = Map.put(charging_process, :power_avg, nil)
                
                # Still try to calculate cost_per_kwh
                cost_per_kwh = case {charging_process.cost, charging_process.charge_energy_added} do
                  {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
                    try do
                      if Decimal.equal?(energy_added, Decimal.new("0")) do
                        nil
                      else
                        Decimal.div(cost, energy_added) |> Decimal.to_float() |> Float.round(2)
                      end
                    rescue
                      _ -> nil
                    end
                  _ -> nil
                end
                
                Map.put(charging_with_power, :cost_per_kwh, cost_per_kwh)
            end
          _ -> 
            Logger.warning("Cannot calculate power_avg: missing or invalid data", 
                          charge_energy_added: charging_process.charge_energy_added, 
                          duration: charging_process.duration_min)
            charging_with_power = Map.put(charging_process, :power_avg, nil)
            
            # Still try to calculate cost_per_kwh
            cost_per_kwh = case {charging_process.cost, charging_process.charge_energy_added} do
              {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
                try do
                  if Decimal.equal?(energy_added, Decimal.new("0")) do
                    nil
                  else
                    Decimal.div(cost, energy_added) |> Decimal.to_float() |> Float.round(2)
                  end
                rescue
                  _ -> nil
                end
              _ -> nil
            end
            
            Map.put(charging_with_power, :cost_per_kwh, cost_per_kwh)
        end
        
        charging_process = TeslaMate.Repo.preload(charging_with_calculations, [:car, :address, :geofence])

        # Generate charging subject with location and stats
        charging_location = if charging_process.geofence, do: "#{charging_process.geofence.name} (#{charging_process.address.name})", else: charging_process.address.name
        charging_time = TeslaMate.Email.format_datetime_local(charging_process.start_date)
        charging_subject = "🔋 [#{charging_time}] #{charging_location} (#{Float.round(charging_process.charge_energy_added, 1)}kWh, #{charging_process.duration_min}min)"
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: charging_subject,
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
        
        # Generate startup subject with current time
        startup_time = TeslaMate.Email.format_datetime_local(DateTime.utc_now())
        startup_subject = "🚀 [#{startup_time}] TeslaMate Service Started"
        
        email = %Swoosh.Email{
          from: {System.get_env("EMAIL_FROM_NAME", "TeslaMate"), System.get_env("SMTP_USERNAME")},
          to: [{"User", email_address}],
          subject: startup_subject,
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
      settings: get_settings_info(),
      latest_drive: get_latest_drive(),
      latest_charging: get_latest_charging()
    }
  end

  defp get_latest_drive() do
    # 先获取最新的驾驶记录
    query = """
    SELECT d.*, c.efficiency
    FROM drives d
    JOIN cars c ON c.id = d.car_id
    ORDER BY d.end_date DESC
    LIMIT 1
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [row]}} ->
        # 转换行数据为结构体
        columns = ["id", "car_id", "start_date", "end_date", "outside_temp_avg", "inside_temp_avg", 
                   "speed_max", "power_max", "power_min", "start_ideal_range_km", "end_ideal_range_km",
                   "start_rated_range_km", "end_rated_range_km", "start_km", "end_km", "distance", 
                   "duration_min", "ascent", "descent", "start_position_id", "end_position_id",
                   "start_address_id", "end_address_id", "start_geofence_id", "end_geofence_id", "efficiency"]
        
        drive_data = Enum.zip_with(columns, row, fn field, value -> 
          {String.to_atom(field), value}
        end) |> Map.new()
        
        # 在应用层进行复杂计算
        drive_with_calculations = calculate_drive_metrics(drive_data)
        
        # 预加载关联数据
        drive_id = drive_data.id
        Drive
        |> where(id: ^drive_id)
        |> Repo.one()
        |> case do
          nil -> 
            Logger.warning("Latest drive record not found in database", drive_id: drive_id)
            nil
          drive -> 
            drive
            |> Repo.preload([:car, :start_address, :end_address, :start_geofence, :end_geofence])
            |> Map.put(:avg_speed, drive_with_calculations.avg_speed)
            |> Map.put(:energy_consumption_wh_per_km, drive_with_calculations.energy_consumption_wh_per_km)
            |> Map.put(:energy_used_kwh, drive_with_calculations.energy_used_kwh)
        end
        
      {:error, reason} ->
        Logger.error("Failed to query latest drive record", error: reason)
        nil
        
      _ -> 
        Logger.info("No drive records found")
        nil
    end
  end

  defp calculate_drive_metrics(drive_data) do
    # 计算平均速度
    avg_speed = case {drive_data.distance, drive_data.duration_min} do
      {distance, duration} when not is_nil(distance) and not is_nil(duration) and duration > 0 ->
        Float.round(distance / (duration / 60.0), 1)
      _ ->
        Logger.warning("Cannot calculate avg_speed: missing distance or duration", 
                      distance: drive_data.distance, duration: drive_data.duration_min)
        nil
    end

    # 计算能量消耗
    {energy_consumption, energy_used} = case {drive_data.start_rated_range_km, drive_data.end_rated_range_km, 
                                              drive_data.distance, drive_data.efficiency} do
      {start_range, end_range, distance, efficiency} 
        when not is_nil(start_range) and not is_nil(end_range) and not is_nil(distance) and not is_nil(efficiency) ->
        start_range_float = if is_struct(start_range, Decimal), do: Decimal.to_float(start_range), else: start_range
        end_range_float = if is_struct(end_range, Decimal), do: Decimal.to_float(end_range), else: end_range
        range_diff = start_range_float - end_range_float
        Logger.info("Energy calculation debug", start_range: start_range, end_range: end_range, range_diff: range_diff, efficiency: efficiency, distance: distance, start_range_type: (if is_struct(start_range, Decimal), do: "Decimal", else: "Float"), end_range_type: (if is_struct(end_range, Decimal), do: "Decimal", else: "Float"))
        if range_diff > 0 do
          energy_consumption = range_diff * efficiency * 1000 / distance
          energy_used = range_diff * efficiency
          Logger.info("Energy calculation successful", energy_consumption: energy_consumption, energy_used: energy_used)
          {Float.round(energy_consumption, 1), Float.round(energy_used, 3)}
        else
          Logger.warning("Range change is not positive, cannot calculate energy consumption", 
                        start_range: start_range, end_range: end_range, range_diff: range_diff)
          {nil, nil}
        end
      _ ->
        Logger.warning("Cannot calculate energy consumption: missing required data", 
                      start_range: drive_data.start_rated_range_km, 
                      end_range: drive_data.end_rated_range_km,
                      distance: drive_data.distance, 
                      efficiency: drive_data.efficiency)
        {nil, nil}
    end

    %{
      avg_speed: avg_speed,
      energy_consumption_wh_per_km: energy_consumption,
      energy_used_kwh: energy_used
    }
  end

  def get_range_analysis(start_rated_range, end_rated_range, actual_distance) do
    cond do
      is_nil(start_rated_range) or is_nil(end_rated_range) or is_nil(actual_distance) ->
        "N/A"
      true ->
        range_change = (if is_struct(start_rated_range, Decimal), do: Decimal.to_float(start_rated_range), else: start_rated_range) - 
                       (if is_struct(end_rated_range, Decimal), do: Decimal.to_float(end_rated_range), else: end_rated_range)
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
            # Calculate cost_per_kwh if cost and charge_energy_added are available
            cost_per_kwh = case {charging_data.cost, charging_data.charge_energy_added} do
              {cost, energy_added} when not is_nil(cost) and not is_nil(energy_added) ->
                try do
                  if Decimal.equal?(energy_added, Decimal.new("0")) do
                    nil
                  else
                    cost_per_kwh = Decimal.div(cost, energy_added)
                    cost_per_kwh_float = Decimal.to_float(cost_per_kwh) |> Float.round(2)
                    Logger.info("Calculated cost_per_kwh", cost: cost, energy_added: energy_added, cost_per_kwh: cost_per_kwh, cost_per_kwh_float: cost_per_kwh_float, cost_type: (if is_struct(cost, Decimal), do: "Decimal", else: "Float"), energy_type: (if is_struct(energy_added, Decimal), do: "Decimal", else: "Float"))
                    cost_per_kwh_float
                  end
                rescue
                  error ->
                    Logger.error("Failed to calculate cost_per_kwh", error: error, cost: cost, energy_added: energy_added)
                    nil
                end
              _ -> nil
            end
            
            charging
            |> Repo.preload([:car, :address, :geofence])
            |> Map.put(:power_avg, charging_data.power_avg)
            |> Map.put(:cost_per_kwh, cost_per_kwh)
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

  def format_duration_minutes(minutes) when is_number(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)
    seconds = rem(round((minutes - trunc(minutes)) * 60), 60)
    
    cond do
      hours > 0 -> "#{hours}h #{remaining_minutes}m #{seconds}s"
      remaining_minutes > 0 -> "#{remaining_minutes}m #{seconds}s"
      true -> "#{seconds}s"
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
  调用地图服务生成驾驶轨迹地图
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
    
    Logger.info("Using map service URL", service_url: service_url, drive_id: drive_id)
    case Finch.build(:post, "#{service_url}/generate_map", 
         [{"Content-Type", "application/json"}], 
         Jason.encode!(%{drive_id: drive_id}))
         |> Finch.request(Finch, timeout: 30000) do
        
        {:ok, %Finch.Response{status: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"success" => true, "image_base64" => image_base64, "drive_id" => ^drive_id} = map_info} ->
              Logger.info("地图生成成功", drive_id: drive_id)
              {:ok, image_base64, map_info}
            
            {:ok, %{"success" => false, "error" => error}} ->
              Logger.warning("地图服务返回错误", drive_id: drive_id, error: error)
              {:error, error}
            
            _ ->
              Logger.error("解析地图服务响应失败", drive_id: drive_id)
              {:error, "解析响应失败"}
          end
        
        {:ok, %Finch.Response{status: status_code, body: body}} ->
          Logger.error("地图服务HTTP错误", status_code: status_code, body: body)
          {:error, "HTTP #{status_code}"}
        
        {:error, reason} ->
          Logger.error("地图服务连接失败", drive_id: drive_id, error: reason)
          {:error, "连接失败"}
      end
  rescue
    e ->
      Logger.error("地图服务调用失败", drive_id: drive_id, error: inspect(e))
      {:error, "服务调用失败"}
  end

end 