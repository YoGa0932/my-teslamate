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
        # Calculate avg_speed and add it to the drive struct
        drive_with_avg_speed = case drive.duration_min do
          duration when duration > 0 -> 
            avg_speed = drive.distance / (duration / 60.0)
            Map.put(drive, :avg_speed, avg_speed)
          _ -> 
            Map.put(drive, :avg_speed, nil)
        end
        
        drive = TeslaMate.Repo.preload(drive_with_avg_speed, [:car, :start_address, :end_address, :start_geofence, :end_geofence])

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
      END as avg_speed
    FROM drives d
    ORDER BY d.end_date DESC
    LIMIT 1
    """
    
    case Repo.query(query) do
      {:ok, %{rows: [row]}} ->
        # Convert row to struct with calculated avg_speed
        drive_data = Enum.zip_with(
          ["id", "car_id", "start_date", "end_date", "outside_temp_avg", "inside_temp_avg", 
           "speed_max", "power_max", "power_min", "start_ideal_range_km", "end_ideal_range_km",
           "start_rated_range_km", "end_rated_range_km", "start_km", "end_km", "distance", 
           "duration_min", "ascent", "descent", "start_position_id", "end_position_id",
           "start_address_id", "end_address_id", "start_geofence_id", "end_geofence_id", "avg_speed"],
          row,
          fn field, value -> 
            case field do
              "avg_speed" -> 
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
  Generate route map image for a drive
  """
  def generate_route_map(drive_id) do
    route_data = get_route_data(drive_id)
    
    case route_data do
      {:ok, positions} when length(positions) > 1 ->
        generate_amap_route_image(positions)
      
      _ ->
        {:error, "Insufficient route data"}
    end
  end

  defp get_route_data(drive_id) do
    query = """
    SELECT latitude, longitude, date, speed
    FROM positions 
    WHERE drive_id = $1 
    AND latitude IS NOT NULL 
    AND longitude IS NOT NULL
    ORDER BY date
    """
    
    case TeslaMate.Repo.query(query, [drive_id]) do
      {:ok, %{rows: rows}} when length(rows) > 1 ->
        positions = Enum.map(rows, fn [lat, lng, date, speed] ->
          %{
            latitude: lat,
            longitude: lng,
            date: date,
            speed: speed
          }
        end)
        {:ok, positions}
      
      _ ->
        {:error, "No route data found"}
    end
  end

  defp generate_amap_route_image(positions) do
    simplified_positions = simplify_route(positions)

    lat_sum = simplified_positions |> Enum.map(&Decimal.to_float(&1.latitude)) |> Enum.sum()
    lng_sum = simplified_positions |> Enum.map(&Decimal.to_float(&1.longitude)) |> Enum.sum()
    count = length(simplified_positions)
    center_lat = lat_sum / count
    center_lng = lng_sum / count

    path_string = build_path_string(simplified_positions)

    amap_key = System.get_env("AMAP_KEY")
    url = "https://restapi.amap.com/v3/staticmap?" <>
          "key=#{amap_key}&" <>
          "location=#{center_lng},#{center_lat}&" <>
          "zoom=13&" <>
          "size=600*400&" <>
          "paths=5,0x0000ff,1,,:#{path_string}&" <>
          "markers=mid,0x00ff00,A:#{Decimal.to_float(List.first(simplified_positions).longitude)},#{Decimal.to_float(List.first(simplified_positions).latitude)}&" <>
          "markers=mid,0xff0000,B:#{Decimal.to_float(List.last(simplified_positions).longitude)},#{Decimal.to_float(List.last(simplified_positions).latitude)}"

    case Tesla.get(url) do
      {:ok, %Tesla.Env{status: 200, body: image_data}} ->
        base64_image = Base.encode64(image_data)
        {:ok, "data:image/png;base64,#{base64_image}"}

      {:ok, %Tesla.Env{status: status_code}} ->
        Logger.error("Amap API error: #{status_code}")
        {:error, "Failed to generate map image"}

      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Failed to fetch map image"}
    end
  end

  defp simplify_route(positions) do
    step = max(1, div(length(positions), 50))
    
    positions
    |> Enum.with_index()
    |> Enum.filter(fn {_, index} -> rem(index, step) == 0 end)
    |> Enum.map(fn {pos, _} -> pos end)
  end

  defp build_path_string(positions) do
    positions
    |> Enum.map(fn pos -> "#{Decimal.to_float(pos.longitude)},#{Decimal.to_float(pos.latitude)}" end)
    |> Enum.join(";")
  end

  def generate_route_map_html(drive_id) do
    case generate_route_map(drive_id) do
      {:ok, image_data_url} ->
        """
        <div class="route-map">
          <img src="#{image_data_url}" alt="Drive Route" style="width: 100%; max-width: 600px; height: auto; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />
        </div>
        """
      
      {:error, reason} ->
        """
        <div class="route-map-error">
          <p style="color: #666; font-style: italic;">Route map not available: #{reason}</p>
        </div>
        """
    end
  end
end 