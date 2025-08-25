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
    case convert_coordinates_to_float(lat, lon) do
      {:error, reason} ->
        {:error, {:geocoding_failed, reason}}

      {lat_f, lon_f} ->
        perform_reverse_lookup(lat_f, lon_f, lang)
    end
  end

  defp convert_coordinates_to_float(lat, lon) do
    case {normalize_coordinate(lat), normalize_coordinate(lon)} do
      {nil, _} -> {:error, "Invalid latitude format"}
      {_, nil} -> {:error, "Invalid longitude format"}
      {lat_f, lon_f} -> {lat_f, lon_f}
    end
  end

  defp normalize_coordinate(coord) do
    case coord do
      %Decimal{} -> Decimal.to_float(coord)
      coord when is_number(coord) -> coord
      _ -> nil
    end
  end

  defp perform_reverse_lookup(lat_f, lon_f, lang) do
    case convert_coordinates_with_amap(lon_f, lat_f) do
      {:ok, {gcj_lon, gcj_lat}} ->
        opts = build_geocoding_options(gcj_lon, gcj_lat)

        with {:ok, address_raw} <- query("/v3/geocode/regeo", lang, opts),
             {:ok, address} <- parse_address_response(address_raw, gcj_lat, gcj_lon) do
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

  defp build_geocoding_options(lon, lat) do
    [
      key: get_amap_key(),
      location: "#{lon},#{lat}",
      output: "json",
      radius: "1000",
      extensions: "all"
    ]
  end

  def details(addresses, lang) do
    Logger.info("Starting batch address details query",
      count: length(addresses),
      language: lang
    )

    addresses
    |> Enum.map(fn %Address{} = address ->
      process_single_address(address, lang)
    end)
    |> filter_successful_addresses()
    |> log_batch_results(length(addresses))
  end

  defp process_single_address(address, lang) do
    case convert_coordinates_to_float(address.latitude, address.longitude) do
      {nil, nil} ->
        Logger.warning("Invalid address coordinate format",
          address_id: address.id,
          coordinates: {address.latitude, address.longitude}
        )

        {address, nil}

      {lat_f, lon_f} ->
        case reverse_lookup(lat_f, lon_f, lang) do
          {:ok, attrs} ->
            {address, attrs}

          {:error, reason} ->
            Logger.warning("Single address failed in batch query",
              address_id: address.id,
              coordinates: {lat_f, lon_f},
              reason: reason
            )

            {address, nil}
        end
    end
  end

  defp filter_successful_addresses(addresses_with_attrs) do
    addresses_with_attrs
    |> Enum.reject(fn {_address, attrs} -> is_nil(attrs) end)
    |> Enum.map(fn {_address, attrs} -> attrs end)
  end

  defp log_batch_results(addresses_with_attrs, total_count) do
    Logger.info("Batch address details query completed",
      total: total_count,
      success: length(addresses_with_attrs)
    )

    {:ok, addresses_with_attrs}
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

  defp parse_address_response(%{"status" => "0", "info" => reason}, _lat, _lon) do
    Logger.error("Amap API returned status 0 (failed)", reason: reason)
    {:error, {:geocoding_failed, reason}}
  end

  defp parse_address_response(%{"status" => "1", "regeocode" => regeocode}, lat, lon) do
    address_component = Map.get(regeocode, "addressComponent", %{})
    formatted_address = Map.get(regeocode, "formatted_address", "Unknown")

    address = build_address_struct(regeocode, address_component, formatted_address, lat, lon)

    validate_address_fields(address)
  end

  defp parse_address_response(raw, _lat, _lon) do
    Logger.warning("Failed to parse Amap API response", raw_response: raw)
    {:error, {:geocoding_failed, "Invalid response format"}}
  end

  defp build_address_struct(regeocode, address_component, formatted_address, lat, lon) do
    unique_id = generate_unique_id(lat, lon)
    neighbourhood = extract_neighbourhood(address_component)
    address_name = extract_address_name(address_component)
    poi_name = extract_best_poi_name(regeocode)

    name =
      build_address_name(poi_name, address_name, address_component, formatted_address, lat, lon)

    city = extract_city(address_component)
    display_name = build_display_name(address_component, formatted_address, lat, lon)

    %{
      display_name: display_name,
      osm_id: unique_id,
      osm_type: "amap",
      latitude: Decimal.new(Float.to_string(lat)),
      longitude: Decimal.new(Float.to_string(lon)),
      name: name,
      house_number: extract_house_number(address_component),
      road: extract_road(address_component),
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
  end

  defp generate_unique_id(lat, lon) do
    :crypto.hash(:md5, "#{lat}#{lon}")
    |> Base.encode16()
    |> binary_part(0, 8)
    |> String.to_integer(16)
    |> abs()
    |> rem(2_147_483_647)
  end

  defp extract_neighbourhood(address_component) do
    case Map.get(address_component, "neighborhood", %{}) do
      %{"name" => names} when is_list(names) -> Enum.join(names, ", ")
      %{"name" => name} when is_binary(name) -> name
      _ -> nil
    end
  end

  defp extract_address_name(address_component) do
    case get_in(address_component, ["streetNumber", "street"]) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp extract_best_poi_name(regeocode) do
    # Extract AOI name (area of interest) first
    aoi_name = extract_best_aoi_name(regeocode)

    case get_in(regeocode, ["pois"]) do
      pois when is_list(pois) and length(pois) > 0 ->
        poi_name =
          pois
          |> Enum.map(&calculate_poi_score/1)
          |> Enum.filter(&valid_poi?/1)
          |> Enum.sort_by(fn {_name, distance, weight} -> {distance, -weight} end)
          |> List.first()
          |> extract_poi_name()

        # Simple comparison: prioritize AOI if closer, otherwise use POI
        compare_and_select_name(aoi_name, poi_name, regeocode)

      _ ->
        aoi_name
    end
  end

  # Extract best AOI name
  defp extract_best_aoi_name(regeocode) do
    case get_in(regeocode, ["aois"]) do
      aois when is_list(aois) and length(aois) > 0 ->
        aois
        |> Enum.map(&calculate_aoi_score/1)
        |> Enum.filter(&valid_aoi?/1)
        |> Enum.sort_by(fn {_name, distance, area} -> {distance, -area} end)
        |> List.first()
        |> extract_aoi_name()

      _ ->
        nil
    end
  end

  # Calculate AOI score
  defp calculate_aoi_score(aoi) do
    distance = parse_aoi_distance(aoi["distance"])
    area = parse_aoi_area(aoi["area"])
    {aoi["name"], distance, area}
  end

  # Parse AOI distance
  defp parse_aoi_distance(dist) when is_binary(dist) do
    case Float.parse(dist) do
      {d, _} -> d
      :error -> 999_999.0
    end
  end

  defp parse_aoi_distance(dist) when is_number(dist), do: dist
  defp parse_aoi_distance(_), do: 999_999.0

  # Parse AOI area
  defp parse_aoi_area(area) when is_binary(area) do
    case Float.parse(area) do
      {a, _} -> a
      :error -> 0.0
    end
  end

  defp parse_aoi_area(area) when is_number(area), do: area
  defp parse_aoi_area(_), do: 0.0

  # Validate AOI
  defp valid_aoi?({name, _distance, _area}), do: name != nil and name != ""
  defp valid_aoi?(_), do: false

  # Extract AOI name
  defp extract_aoi_name({name, _distance, _area}) when is_binary(name), do: name
  defp extract_aoi_name(_), do: nil

  # Compare and select name (distance first, weight second)
  defp compare_and_select_name(aoi_name, poi_name, regeocode) do
    cond do
      # If AOI distance is 0 (within the area), prioritize AOI
      aoi_name && get_aoi_distance(regeocode, aoi_name) == 0 ->
        aoi_name

      # If AOI distance is very close (less than 50m), prioritize AOI
      aoi_name && get_aoi_distance(regeocode, aoi_name) < 50 ->
        aoi_name

      # Otherwise use POI name
      poi_name && poi_name != "" ->
        poi_name

      # Finally fallback to AOI
      aoi_name && aoi_name != "" ->
        aoi_name

      true ->
        nil
    end
  end

  # Get distance for specific AOI name
  defp get_aoi_distance(regeocode, target_name) do
    case get_in(regeocode, ["aois"]) do
      aois when is_list(aois) ->
        case Enum.find(aois, fn aoi -> aoi["name"] == target_name end) do
          %{"distance" => distance} -> parse_aoi_distance(distance)
          _ -> 999_999.0
        end

      _ ->
        999_999.0
    end
  end

  defp calculate_poi_score(poi) do
    distance = parse_poi_distance(poi["distance"])
    weight = parse_poi_weight(poi["poiweight"])
    {poi["name"], distance, weight}
  end

  defp parse_poi_distance(dist) when is_binary(dist) do
    case Float.parse(dist) do
      {d, _} -> d
      :error -> 999_999.0
    end
  end

  defp parse_poi_distance(dist) when is_number(dist), do: dist
  defp parse_poi_distance(_), do: 999_999.0

  defp parse_poi_weight(w) when is_binary(w) do
    case Float.parse(w) do
      {wt, _} -> wt
      :error -> 0.0
    end
  end

  defp parse_poi_weight(w) when is_number(w), do: w
  defp parse_poi_weight(_), do: 0.0

  defp valid_poi?({name, _distance, _weight}), do: name != nil and name != ""
  defp valid_poi?(_), do: false

  defp extract_poi_name({name, _distance, _weight}) when is_binary(name), do: name
  defp extract_poi_name(_), do: nil

  defp build_address_name(poi_name, address_name, address_component, formatted_address, lat, lon) do
    cond do
      poi_name && address_name ->
        "#{address_name} #{poi_name}"

      poi_name ->
        build_poi_with_street_name(poi_name, address_component)

      address_name ->
        address_name

      true ->
        build_fallback_address_name(address_component, formatted_address, lat, lon)
    end
  end

  defp build_poi_with_street_name(poi_name, address_component) do
    case get_in(address_component, ["streetNumber", "street"]) do
      street when is_binary(street) and street != "" ->
        "#{street} #{poi_name}"

      _ ->
        poi_name
    end
  end

  defp build_fallback_address_name(address_component, formatted_address, lat, lon) do
    if formatted_address && formatted_address != "Unknown" do
      formatted_address
    else
      build_address_from_components(address_component, lat, lon)
    end
  end

  defp build_address_from_components(address_component, lat, lon) do
    parts =
      [
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

  defp extract_city(address_component) do
    case address_component["city"] do
      cities when is_list(cities) -> Enum.join(cities, ", ")
      city when is_binary(city) -> city
      _ -> nil
    end
  end

  defp build_display_name(address_component, formatted_address, lat, lon) do
    if formatted_address && formatted_address != "Unknown" do
      formatted_address
    else
      build_address_from_components(address_component, lat, lon)
    end
  end

  defp extract_house_number(address_component) do
    case get_in(address_component, ["streetNumber", "number"]) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp extract_road(address_component) do
    case get_in(address_component, ["streetNumber", "street"]) do
      nil -> nil
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp validate_address_fields(address) do
    required_fields = [:display_name, :osm_id, :osm_type, :latitude, :longitude, :raw]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        value = Map.get(address, field)
        value == nil || (is_binary(value) && String.trim(value) == "")
      end)

    if length(missing_fields) > 0 do
      Logger.error("Address parsing failed, missing required fields",
        missing_fields: missing_fields
      )

      {:error, {:geocoding_failed, "Missing required fields: #{inspect(missing_fields)}"}}
    else
      {:ok, address}
    end
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
      # gps means input is WGS84 coordinates
      coordsys: "gps"
    ]

    case query("/v3/assistant/coordinate/convert", "zh", opts) do
      {:ok, %{"status" => "1", "locations" => locations}} ->
        parse_converted_coordinates(locations)

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

  defp parse_converted_coordinates(locations) do
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
  end
end
