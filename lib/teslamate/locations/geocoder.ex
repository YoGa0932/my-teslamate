defmodule TeslaMate.Locations.Geocoder do
  use Tesla, only: [:get]

  @version Mix.Project.config()[:version]

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.BaseUrl, "https://nominatim.openstreetmap.org"
  plug Tesla.Middleware.Headers, [{"user-agent", "TeslaMate/#{@version}"}]
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  alias TeslaMate.Locations.Address

  def reverse_lookup(lat, lon, lang \\ "en") do
    case amap_keys() do
      [] -> reverse_lookup_nominatim(lat, lon, lang)
      keys -> reverse_lookup_amap(lat, lon, lang, keys)
    end
  end

  def details(addresses, lang) when is_list(addresses) do
    case amap_keys() do
      [] -> details_nominatim(addresses, lang)
      _keys -> details_amap(addresses, lang)
    end
  end

  defp reverse_lookup_nominatim(lat, lon, lang) do
    opts = [
      format: :jsonv2,
      addressdetails: 1,
      extratags: 1,
      namedetails: 1,
      zoom: 19,
      lat: lat,
      lon: lon
    ]

    with {:ok, address_raw} <- query("/reverse", lang, opts),
         {:ok, address} <- into_address(address_raw) do
      {:ok, address}
    end
  end

  defp details_nominatim(addresses, lang) do
    osm_ids =
      addresses
      |> Enum.reject(fn %Address{} = a -> a.osm_id == nil or a.osm_type in [nil, "unknown"] end)
      |> Enum.map(fn %Address{} = a ->
        "#{String.upcase(String.at(a.osm_type, 0))}#{a.osm_id}"
      end)
      |> Enum.join(",")

    params = [
      osm_ids: osm_ids,
      format: :jsonv2,
      addressdetails: 1,
      extratags: 1,
      namedetails: 1,
      zoom: 19
    ]

    with {:ok, raw_addresses} <- query("/lookup", lang, params) do
      addresses =
        Enum.map(raw_addresses, fn attrs ->
          case into_address(attrs) do
            {:ok, address} -> address
            {:error, reason} -> throw({:invalid_address, reason})
          end
        end)

      {:ok, addresses}
    end
  catch
    {:invalid_address, reason} ->
      {:error, reason}
  end

  defp reverse_lookup_amap(lat, lon, _lang, keys) do
    key = select_daily_key(keys)
    {lat, lon} = maybe_convert_to_gcj02(lat, lon, key)
    location = "#{lon},#{lat}"

    params = [
      key: key,
      location: location,
      extensions: "all",
      radius: 1000,
      output: "JSON"
    ]

    with {:ok, address_raw} <- query_amap("/v3/geocode/regeo", params),
         {:ok, address} <- into_address_amap(address_raw, lat, lon) do
      {:ok, address}
    end
  end

  defp details_amap(addresses, lang) do
    addresses =
      Enum.map(addresses, fn
        %Address{latitude: lat, longitude: lon} ->
          case reverse_lookup(lat, lon, lang) do
            {:ok, address} -> address
            {:error, reason} -> throw({:invalid_address, reason})
          end
      end)

    {:ok, addresses}
  catch
    {:invalid_address, reason} ->
      {:error, reason}
  end

  defp query(url, lang, params) do
    case get(url, query: params, headers: [{"Accept-Language", lang}]) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{body: %{"error" => reason}}} -> {:error, reason}
      {:ok, %Tesla.Env{} = env} -> {:error, reason: "Unexpected response", env: env}
      {:error, reason} -> {:error, reason}
    end
  end

  defp query_amap(url, params) do
    case get("https://restapi.amap.com#{url}", query: params) do
      {:ok, %Tesla.Env{status: 200, body: %{"status" => "1"} = body}} -> {:ok, body}
      {:ok, %Tesla.Env{status: 200, body: %{"status" => "0", "info" => reason}}} ->
        {:error, reason}

      {:ok, %Tesla.Env{} = env} ->
        {:error, reason: "Unexpected response", env: env}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp amap_keys do
    System.get_env("AMAP_KEY")
    |> case do
      nil -> []
      val -> val
    end
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp select_daily_key([key]), do: key

  defp select_daily_key(keys) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)
    len = length(keys)

    today_idx = :erlang.phash2({:amap_key, today}, len)
    yesterday_idx = :erlang.phash2({:amap_key, yesterday}, len)

    idx =
      if today_idx == yesterday_idx do
        rem(today_idx + 1, len)
      else
        today_idx
      end

    Enum.at(keys, idx)
  end

  defp maybe_convert_to_gcj02(lat, lon, key) do
    if in_china_mainland?(lat, lon) do
      locations = "#{coord_to_string(lon)},#{coord_to_string(lat)}"

      params = [
        key: key,
        locations: locations,
        coordsys: "gps",
        output: "JSON"
      ]

      case query_amap("/v3/assistant/coordinate/convert", params) do
        {:ok, %{"locations" => converted}} ->
          case String.split(converted, ";") |> List.first() |> String.split(",") do
            [lon_c, lat_c] -> {lat_c, lon_c}
            _ -> {coord_to_string(lat), coord_to_string(lon)}
          end

        {:error, _reason} ->
          {coord_to_string(lat), coord_to_string(lon)}
      end
    else
      {coord_to_string(lat), coord_to_string(lon)}
    end
  end

  defp in_china_mainland?(lat, lon) do
    lat_f = coord_to_float(lat)
    lon_f = coord_to_float(lon)

    lat_f >= 3.86 and lat_f <= 53.55 and lon_f >= 73.66 and lon_f <= 135.05
  end

  defp coord_to_string(%Decimal{} = val), do: Decimal.to_string(val, :normal)
  defp coord_to_string(val) when is_binary(val), do: val
  defp coord_to_string(val) when is_integer(val), do: Integer.to_string(val)
  defp coord_to_string(val) when is_float(val), do: :erlang.float_to_binary(val, [:compact])

  defp coord_to_float(%Decimal{} = val), do: Decimal.to_float(val)
  defp coord_to_float(val) when is_integer(val), do: val * 1.0
  defp coord_to_float(val) when is_float(val), do: val
  defp coord_to_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  # Address Formatting
  # Source: https://github.com/OpenCageData/address-formatting/blob/master/conf/components.yaml

  @road_aliases [
    "road",
    "footway",
    "street",
    "street_name",
    "residential",
    "path",
    "pedestrian",
    "road_reference",
    "road_reference_intl",
    "square",
    "place"
  ]

  @neighbourhood_aliases [
    "neighbourhood",
    "suburb",
    "city_district",
    "district",
    "quarter",
    "borough",
    "city_block",
    "residential",
    "commercial",
    "houses",
    "subdistrict",
    "subdivision",
    "ward"
  ]

  @municipality_aliases [
    "municipality",
    "local_administrative_area",
    "subcounty"
  ]

  @village_aliases [
    "village",
    "municipality",
    "hamlet",
    "locality",
    "croft"
  ]

  @city_aliases [
                  "city",
                  "town",
                  "township"
                ] ++ @village_aliases ++ @municipality_aliases

  @county_aliases [
    "county",
    "county_code",
    "department"
  ]

  defp into_address(%{"error" => "Unable to geocode"} = raw) do
    unknown_address = %{
      display_name: "Unknown",
      osm_type: "unknown",
      osm_id: 0,
      latitude: 0.0,
      longitude: 0.0,
      raw: raw
    }

    {:ok, unknown_address}
  end

  defp into_address(%{"error" => reason}) do
    {:error, {:geocoding_failed, reason}}
  end

  defp into_address(raw) do
    address = %{
      display_name: Map.get(raw, "display_name"),
      osm_id: Map.get(raw, "osm_id"),
      osm_type: Map.get(raw, "osm_type"),
      latitude: Map.get(raw, "lat"),
      longitude: Map.get(raw, "lon"),
      name:
        Map.get(raw, "name") || get_in(raw, ["namedetails", "name"]) ||
          get_in(raw, ["namedetails", "alt_name"]),
      house_number: raw["address"] |> get_first(["house_number", "street_number"]),
      road: raw["address"] |> get_first(@road_aliases),
      neighbourhood: raw["address"] |> get_first(@neighbourhood_aliases),
      city: raw["address"] |> get_first(@city_aliases),
      county: raw["address"] |> get_first(@county_aliases),
      postcode: get_in(raw, ["address", "postcode"]),
      state: raw["address"] |> get_first(["state", "province", "state_code"]),
      state_district: get_in(raw, ["address", "state_district"]),
      country: raw["address"] |> get_first(["country", "country_name"]),
      raw: raw
    }

    {:ok, address}
  end

  defp into_address_amap(%{"status" => "0", "info" => reason}, _lat, _lon) do
    {:error, {:geocoding_failed, reason}}
  end

  defp into_address_amap(%{"regeocode" => regeocode} = raw, lat, lon) do
    address_component = Map.get(regeocode, "addressComponent", %{})
    street_number = Map.get(address_component, "streetNumber", %{})

    name =
      address_component
      |> Map.get("building", %{})
      |> Map.get("name") ||
        address_component
        |> Map.get("neighborhood", %{})
        |> Map.get("name")

    city =
      case Map.get(address_component, "city") do
        [] -> Map.get(address_component, "province")
        "" -> Map.get(address_component, "province")
        nil -> Map.get(address_component, "province")
        val -> val
      end

    address = %{
      display_name: Map.get(regeocode, "formatted_address") || "Unknown",
      osm_id: osm_hash_id(lat, lon),
      osm_type: "amap",
      latitude: to_string(lat),
      longitude: to_string(lon),
      name: name,
      house_number: Map.get(street_number, "number"),
      road: Map.get(street_number, "street"),
      neighbourhood:
        Map.get(address_component, "neighborhood", %{})
        |> Map.get("name") ||
          Map.get(address_component, "township"),
      city: city,
      county: Map.get(address_component, "district"),
      postcode: Map.get(address_component, "adcode"),
      state: Map.get(address_component, "province"),
      state_district: Map.get(address_component, "city"),
      country: Map.get(address_component, "country") || "China",
      raw: raw
    }

    {:ok, address}
  end

  defp osm_hash_id(lat, lon) do
    :erlang.phash2({lat, lon}, 2_147_483_647)
  end

  defp get_first(nil, _aliases), do: nil
  defp get_first(_address, []), do: nil

  defp get_first(address, [key | aliases]) do
    with nil <- Map.get(address, key), do: get_first(address, aliases)
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info
end
