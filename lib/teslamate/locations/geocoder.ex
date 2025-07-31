defmodule TeslaMate.Locations.Geocoder do
  use Tesla, only: [:get]

  require Logger

  @version Mix.Project.config()[:version]

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.BaseUrl, "https://restapi.amap.com"
  plug Tesla.Middleware.Headers, [{"user-agent", "TeslaMate/#{@version}"}]
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  alias TeslaMate.Locations.Address

  def reverse_lookup(lat, lon, lang \\ "zh") do
    {lat_float, lon_float} = case {lat, lon} do
      {%Decimal{} = lat_dec, %Decimal{} = lon_dec} ->
        {Decimal.to_float(lat_dec), Decimal.to_float(lon_dec)}
      {%Decimal{} = lat_dec, lon_num} when is_number(lon_num) ->
        {Decimal.to_float(lat_dec), lon_num}
      {lat_num, %Decimal{} = lon_dec} when is_number(lat_num) ->
        {lat_num, Decimal.to_float(lon_dec)}
      {lat_num, lon_num} when is_number(lat_num) and is_number(lon_num) ->
        {lat_num, lon_num}
      _ ->
        Logger.error("Invalid coordinate format", coordinates: {lat, lon})
        {:error, :invalid_coordinates}
    end

    case {lat_float, lon_float} do
      {:error, :invalid_coordinates} ->
        {:error, {:geocoding_failed, "Invalid coordinates"}}
      
      {lat_f, lon_f} ->
        # Step 1: Use Amap coordinate conversion API to convert WGS84 to GCJ-02
        case convert_coordinates_with_amap(lon_f, lat_f) do
          {:ok, {gcj_lon, gcj_lat}} ->
            # Step 2: Use converted coordinates for reverse geocoding
            opts = [
              key: get_amap_key(),
              location: "#{gcj_lon},#{gcj_lat}",
              output: "json",
              radius: "1000",
              extensions: "all"
            ]

            with {:ok, address_raw} <- query("/v3/geocode/regeo", lang, opts),
                 {:ok, address} <- into_address(address_raw, gcj_lat, gcj_lon) do
              {:ok, address}
            else
              {:error, reason} ->
                Logger.error("Amap geocoding failed", reason: reason)
                {:error, reason}
            end
          
          {:error, reason} ->
            Logger.error("Coordinate conversion failed", reason: reason)
            {:error, {:geocoding_failed, "Coordinate conversion failed: #{reason}"}}
        end
    end
  end

  def details(addresses, lang) do
    Logger.info("Starting batch address details query",
      count: length(addresses),
      language: lang
    )

    addresses
    |> Enum.map(fn %Address{} = address ->
      {lat, lon} = case {address.latitude, address.longitude} do
        {%Decimal{} = lat_dec, %Decimal{} = lon_dec} ->
          {Decimal.to_float(lat_dec), Decimal.to_float(lon_dec)}
        {%Decimal{} = lat_dec, lon_num} when is_number(lon_num) ->
          {Decimal.to_float(lat_dec), lon_num}
        {lat_num, %Decimal{} = lon_dec} when is_number(lat_num) ->
          {lat_num, Decimal.to_float(lon_dec)}
        {lat_num, lon_num} when is_number(lat_num) and is_number(lon_num) ->
          {lat_num, lon_num}
        _ ->
          Logger.warning("Invalid address coordinate format",
            address_id: address.id,
            coordinates: {address.latitude, address.longitude}
          )
          {nil, nil}
      end

      case {lat, lon} do
        {nil, nil} ->
          {address, nil}
        {lat_f, lon_f} ->
          case reverse_lookup(lat_f, lon_f, lang) do
            {:ok, attrs} -> {address, attrs}
            {:error, reason} ->
              Logger.warning("Single address failed in batch query",
                address_id: address.id,
                coordinates: {lat_f, lon_f},
                reason: reason
              )
              {address, nil}
          end
      end
    end)
    |> Enum.reject(fn {_address, attrs} -> is_nil(attrs) end)
    |> then(fn addresses_with_attrs ->
      Logger.info("Batch address details query completed",
        total: length(addresses),
        success: length(addresses_with_attrs)
      )
      {:ok, Enum.map(addresses_with_attrs, fn {_address, attrs} -> attrs end)}
    end)
  end

  defp query(url, _lang, params) do
    case get(url, query: params) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %Tesla.Env{body: %{"info" => reason}}} ->
        Logger.error("Amap API returned error message", error_info: reason)
        {:error, reason}
      
      {:ok, %Tesla.Env{status: status, body: _body} = env} ->
        Logger.error("Amap API returned unexpected response", status: status)
        {:error, reason: "Unexpected response", env: env}
      
      {:error, %Tesla.Error{reason: reason}} ->
        Logger.error("Amap API request failed", error: reason)
        {:error, reason}
      
      {:error, reason} ->
        Logger.error("Amap API unknown error", error: reason)
        {:error, reason}
    end
  end

  defp into_address(%{"status" => "0", "info" => reason}, _lat, _lon) do
    Logger.error("Amap API returned status 0 (failed)", reason: reason)
    {:error, {:geocoding_failed, reason}}
  end

  defp into_address(%{"status" => "1", "regeocode" => regeocode}, lat, lon) do
    address_component = Map.get(regeocode, "addressComponent", %{})
    formatted_address = Map.get(regeocode, "formatted_address", "Unknown")

    unique_id = :crypto.hash(:md5, "#{lat}#{lon}")
                |> Base.encode16()
                |> binary_part(0, 8)
                |> String.to_integer(16)
                |> abs()
                |> rem(2_147_483_647)

    neighbourhood = case Map.get(address_component, "neighborhood", %{}) do
      %{"name" => names} when is_list(names) -> Enum.join(names, ", ")
      %{"name" => name} when is_binary(name) -> name
      _ -> nil
    end

    address_name = case get_in(address_component, ["streetNumber", "street"]) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
    
    best_poi = case get_in(regeocode, ["pois"]) do
      pois when is_list(pois) and length(pois) > 0 ->
        pois
        |> Enum.map(fn poi ->
          distance = case poi["distance"] do
            dist when is_binary(dist) -> 
              case Float.parse(dist) do
                {d, _} -> d
                :error -> 999999.0
              end
            dist when is_number(dist) -> dist
            _ -> 999999.0
          end
          
          weight = case poi["poiweight"] do
            w when is_binary(w) -> 
              case Float.parse(w) do
                {wt, _} -> wt
                :error -> 0.0
              end
            w when is_number(w) -> w
            _ -> 0.0
          end
          
          {poi["name"], distance, weight}
        end)
        |> Enum.filter(fn {name, _distance, _weight} -> 
          name != nil and name != ""
        end)
        |> Enum.sort_by(fn {_name, distance, weight} -> 
          {distance, -weight}
        end)
        |> List.first()
        
      _ -> nil
    end
    
    poi_name = case best_poi do
      {name, _distance, _weight} when is_binary(name) -> name
      _ -> nil
    end
    
    name = cond do
      poi_name && address_name -> 
        "#{address_name} #{poi_name}"
      poi_name -> 
        case get_in(address_component, ["streetNumber", "street"]) do
          street when is_binary(street) and street != "" ->
            "#{street} #{poi_name}"
          _ -> 
            poi_name
        end
      address_name -> 
        address_name
      true -> 
        if formatted_address && formatted_address != "Unknown" do
          formatted_address
        else
          parts = [
            address_component["province"],
            address_component["city"], 
            address_component["district"],
            address_component["township"]
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join("")
          
          if parts != "" do
            parts
          else
            "Unknown address (#{lat}, #{lon})"
          end
        end
    end

    city = case address_component["city"] do
      cities when is_list(cities) -> Enum.join(cities, ", ")
      city when is_binary(city) -> city
      _ -> nil
    end

    display_name = if formatted_address && formatted_address != "Unknown" do
      formatted_address
    else
      parts = [
        address_component["province"],
        address_component["city"],
        address_component["district"],
        address_component["township"]
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("")
      
      if parts != "" do
        parts
      else
        "Unknown address (#{lat}, #{lon})"
      end
    end

    address = %{
      display_name: display_name,
      osm_id: unique_id,
      osm_type: "amap",
      latitude: Decimal.new(Float.to_string(lat)),
      longitude: Decimal.new(Float.to_string(lon)),
      name: name,
      house_number: case get_in(address_component, ["streetNumber", "number"]) do
        nil -> nil
        value when is_binary(value) -> value
        value -> to_string(value)
      end,
      road: case get_in(address_component, ["streetNumber", "street"]) do
        nil -> nil
        value when is_binary(value) -> value
        value -> to_string(value)
      end,
      neighbourhood: neighbourhood,
      city: city,
      county: address_component["district"] || nil,
      postcode: address_component["adcode"] || nil,
      state: address_component["province"] || nil,
      state_district: address_component["district"] || nil,
      country: "China",
      raw: %{
        "regeocode" => regeocode,
        "status" => "1"
      }
    }

    required_fields = [:display_name, :osm_id, :osm_type, :latitude, :longitude, :raw]
    missing_fields = Enum.filter(required_fields, fn field ->
      value = Map.get(address, field)
      value == nil || (is_binary(value) && String.trim(value) == "")
    end)

    if length(missing_fields) > 0 do
      Logger.error("Address parsing failed, missing required fields", missing_fields: missing_fields)
      {:error, {:geocoding_failed, "Missing required fields: #{inspect(missing_fields)}"}}
    else
      {:ok, address}
    end
  end

  defp into_address(raw, _lat, _lon) do
    Logger.warning("Failed to parse Amap API response", raw_response: raw)
    {:error, {:geocoding_failed, "Invalid response format"}}
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info

  defp get_amap_key do
    case System.get_env("AMAP_KEY") do
      nil ->
        Logger.error("AMAP_KEY environment variable is not set.")
        raise "AMAP_KEY environment variable is not set. Please set AMAP_KEY in your environment or start.sh file."
      key when is_binary(key) and byte_size(key) > 0 ->
        Logger.debug("Successfully got Amap API key", key_length: byte_size(key))
        key
      _ ->
        Logger.error("AMAP_KEY environment variable is empty")
        raise "AMAP_KEY environment variable is empty. Please set a valid AMAP_KEY."
    end
  end



  # Use Amap coordinate conversion API
  defp convert_coordinates_with_amap(lng, lat) when is_number(lng) and is_number(lat) do
    opts = [
      key: get_amap_key(),
      locations: "#{lng},#{lat}",
      coordsys: "gps"  # gps means input is WGS84 coordinates
    ]

    case query("/v3/assistant/coordinate/convert", "zh", opts) do
      {:ok, %{"status" => "1", "locations" => locations}} ->
        case String.split(locations, ",") do
          [lng_str, lat_str] ->
            case {Float.parse(lng_str), Float.parse(lat_str)} do
              {{lng_float, _}, {lat_float, _}} ->
                {:ok, {lng_float, lat_float}}
              _ ->
                Logger.error("Failed to parse converted coordinates", locations: locations)
                {:error, "Invalid coordinate format"}
            end
          _ ->
            Logger.error("Invalid coordinate conversion response", locations: locations)
            {:error, "Invalid response format"}
        end
      
      {:ok, %{"status" => "0", "info" => reason}} ->
        Logger.error("Coordinate conversion API failed", reason: reason)
        {:error, reason}
      
      {:error, reason} ->
        Logger.error("Coordinate conversion API request failed", reason: reason)
        {:error, reason}
      
      _ ->
        Logger.error("Unexpected coordinate conversion response")
        {:error, "Unexpected response"}
    end
  end

  defp convert_coordinates_with_amap(%Decimal{} = lng, %Decimal{} = lat) do
    convert_coordinates_with_amap(Decimal.to_float(lng), Decimal.to_float(lat))
  end

  defp convert_coordinates_with_amap(lng, %Decimal{} = lat) when is_number(lng) do
    convert_coordinates_with_amap(lng, Decimal.to_float(lat))
  end

  defp convert_coordinates_with_amap(%Decimal{} = lng, lat) when is_number(lat) do
    convert_coordinates_with_amap(Decimal.to_float(lng), lat)
  end

  defp convert_coordinates_with_amap(_lng, _lat) do
    {:error, :invalid_coordinates}
  end


end
