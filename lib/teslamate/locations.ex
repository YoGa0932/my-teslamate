defmodule TeslaMate.Locations do
  @moduledoc """
  The Locations context.
  """

  require Logger

  import Ecto.Query, warn: false
  import TeslaMate.CustomExpressions

  alias __MODULE__.{Address, Geocoder, GeoFence}
  alias TeslaMate.Log.{Drive, ChargingProcess}
  alias TeslaMate.Settings.GlobalSettings
  alias TeslaMate.{Repo, Settings}

  ## Address

  def create_address(attrs \\ %{}) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  def update_address(%Address{} = address, attrs) do
    address
    |> Address.changeset(attrs)
    |> Repo.update()
  end

  @geocoder (case Mix.env() do
               :test -> GeocoderMock
               _ -> Geocoder
             end)

  def find_address(%{latitude: lat, longitude: lng}) do
    %GlobalSettings{language: lang} = Settings.get_global_settings!()

    Logger.debug("Starting address lookup",
      coordinates: {lat, lng},
      language: lang,
      geocoder: if(@geocoder == Geocoder, do: "Amap API", else: "Mock")
    )

    case @geocoder.reverse_lookup(lat, lng, lang) do
      {:ok, %{osm_id: id, osm_type: type} = attrs} ->
        handle_successful_geocoding(id, type, attrs, lat, lng)

      {:error, reason} ->
        Logger.error("Locations.find_address failed", reason: reason)
        {:error, reason}
    end
  end

  defp handle_successful_geocoding(id, type, attrs, lat, lng) do
    Logger.debug("Geocoding successful", osm_id: id, osm_type: type)

    case Repo.get_by(Address, osm_id: id, osm_type: type) do
      %Address{} = address ->
        Logger.debug("Found existing address in database", address_id: address.id)
        {:ok, address}

      nil ->
        handle_new_address(id, type, attrs, lat, lng)
    end
  end

  defp handle_new_address(id, type, attrs, lat, lng) do
    case find_address_by_coordinates(lat, lng) do
      %Address{} = address ->
        log_nearby_address_found(address, lat, lng)
        {:ok, address}

      nil ->
        create_new_address(attrs, id, type)
    end
  end

  defp log_nearby_address_found(address, lat, lng) do
    distance = calculate_distance(lat, lng, address.latitude, address.longitude)

    Logger.info("Found nearby address, reusing existing address",
      address_id: address.id,
      distance_meters: distance
    )
  end

  defp create_new_address(attrs, id, type) do
    case create_address(attrs) do
      {:ok, address} ->
        Logger.info("Created new address",
          address_id: address.id,
          osm_id: id,
          osm_type: type
        )

        {:ok, address}

      {:error, changeset} ->
        Logger.error("Failed to create new address", errors: inspect(changeset.errors))
        {:error, {:database_error, "Failed to create address: #{inspect(changeset.errors)}"}}
    end
  end

  defp find_address_by_coordinates(lat, lng) do
    {lat_decimal, lng_decimal} = convert_coordinates_to_decimal(lat, lng)
    search_range = Decimal.new("0.001")

    Address
    |> where(
      [a],
      a.latitude >= ^Decimal.sub(lat_decimal, search_range) and
        a.latitude <= ^Decimal.add(lat_decimal, search_range) and
        a.longitude >= ^Decimal.sub(lng_decimal, search_range) and
        a.longitude <= ^Decimal.add(lng_decimal, search_range)
    )
    |> order_by([a], desc: a.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp convert_coordinates_to_decimal(lat, lng) do
    {normalize_coordinate_to_decimal(lat), normalize_coordinate_to_decimal(lng)}
  end

  defp normalize_coordinate_to_decimal(coord) do
    case coord do
      %Decimal{} -> coord
      coord when is_float(coord) -> Decimal.new(:erlang.float_to_binary(coord, [:compact]))
      coord when is_number(coord) -> Decimal.new(to_string(coord))
      _ -> Decimal.new("0.0")
    end
  end

  defp calculate_distance(lat1, lng1, lat2, lng2) do
    {lat1_f, lng1_f, lat2_f, lng2_f} = convert_coordinates_to_float(lat1, lng1, lat2, lng2)
    calculate_haversine_distance(lat1_f, lng1_f, lat2_f, lng2_f)
  end

  defp convert_coordinates_to_float(lat1, lng1, lat2, lng2) do
    {
      normalize_coordinate_to_float(lat1),
      normalize_coordinate_to_float(lng1),
      normalize_coordinate_to_float(lat2),
      normalize_coordinate_to_float(lng2)
    }
  end

  defp normalize_coordinate_to_float(coord) do
    case coord do
      %Decimal{} -> Decimal.to_float(coord)
      coord when is_number(coord) -> coord
      _ -> 0.0
    end
  end

  defp calculate_haversine_distance(lat1_f, lng1_f, lat2_f, lng2_f) do
    r = 6_371_000
    lat1_rad = lat1_f * :math.pi() / 180
    lat2_rad = lat2_f * :math.pi() / 180
    delta_lat = (lat2_f - lat1_f) * :math.pi() / 180
    delta_lng = (lng2_f - lng1_f) * :math.pi() / 180

    a =
      :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
          :math.sin(delta_lng / 2) * :math.sin(delta_lng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    round(r * c)
  end

  def refresh_addresses(lang) do
    Address
    |> Repo.all()
    |> process_addresses_in_batches(lang)
  end

  defp process_addresses_in_batches(addresses, lang) do
    addresses
    |> Enum.chunk_every(50)
    |> Enum.with_index()
    |> Enum.each(fn {addresses_batch, i} ->
      process_address_batch(addresses_batch, lang, i)
    end)
  end

  defp process_address_batch(addresses_batch, lang, batch_index) do
    if batch_index > 0, do: Process.sleep(1500)

    case @geocoder.details(addresses_batch, lang) do
      {:ok, attrs} ->
        process_address_attributes(addresses_batch, attrs, lang)

      _ ->
        Logger.warning("Failed to get address details for batch", batch_index: batch_index)
    end
  end

  defp process_address_attributes(addresses, attrs, lang) do
    addresses
    |> merge_addresses(attrs)
    |> Enum.each(fn address_attrs_pair ->
      process_single_address_attributes(address_attrs_pair, lang)
    end)
  end

  defp process_single_address_attributes({%Address{osm_type: "unknown"}, _attrs}, _lang) do
    :ignore
  end

  defp process_single_address_attributes({%Address{} = address, attrs}, _lang)
       when is_map(attrs) do
    attrs = extract_address_update_fields(attrs)
    {:ok, _} = update_address(address, attrs)
  end

  defp process_single_address_attributes(
         {%Address{osm_id: id, osm_type: type} = address, nil},
         _lang
       ) do
    %GlobalSettings{language: lang} = Settings.get_global_settings!()

    case Geocoder.reverse_lookup(address.latitude, address.longitude, lang) do
      {:ok, %{osm_id: ^id, osm_type: ^type} = attrs} ->
        attrs = extract_address_update_fields(attrs)
        {:ok, _} = update_address(address, attrs)

      _ ->
        :ignore
    end
  end

  defp extract_address_update_fields(attrs) do
    Map.take(attrs, [
      :city,
      :country,
      :county,
      :display_name,
      :name,
      :neighbourhood,
      :state,
      :state_district
    ])
  end

  defp merge_addresses(addresses, attrs) do
    addresses =
      Enum.reduce(addresses, %{}, fn %Address{osm_id: id, osm_type: type} = address, acc ->
        Map.put(acc, {type, id}, {address, nil})
      end)

    attrs
    |> Enum.reduce(addresses, fn %{osm_id: id, osm_type: type} = attrs, acc ->
      Map.update!(acc, {type, id}, fn {address, nil} -> {address, attrs} end)
    end)
    |> Map.values()
  end

  defp apply_geofence(%GeoFence{latitude: lat, longitude: lng, radius: r}, opts \\ []) do
    except_id = Keyword.get(opts, :except) || -1
    args = [lat, lng, r, except_id]

    update_query = build_geofence_update_query()

    Drive |> update_query.(:start_geofence_id, :start_position_id) |> Repo.query!(args)
    Drive |> update_query.(:end_geofence_id, :end_position_id) |> Repo.query!(args)
    ChargingProcess |> update_query.(:geofence_id, :position_id) |> Repo.query!(args)

    :ok
  end

  defp build_geofence_update_query do
    fn module, geofence_field, position_field ->
      """
        UPDATE #{module.__schema__(:source)} m
        SET #{geofence_field} = (
          SELECT id
          FROM geofences g
          WHERE
            earth_box(ll_to_earth(g.latitude, g.longitude), g.radius) @> ll_to_earth(p.latitude, p.longitude) AND
            earth_distance(ll_to_earth(g.latitude, g.longitude), ll_to_earth(latitude, p.longitude)) < g.radius AND
            g.id != $4
          ORDER BY
            earth_distance(ll_to_earth(g.latitude, g.longitude), ll_to_earth(latitude, p.longitude)) ASC
          LIMIT 1
        )
        FROM positions p
        WHERE
          m.#{position_field} = p.id AND
          earth_box(ll_to_earth($1::numeric, $2::numeric), $3) @> ll_to_earth(p.latitude, p.longitude) AND
          earth_distance(ll_to_earth($1::numeric, $2::numeric), ll_to_earth(latitude, p.longitude)) < $3
      """
    end
  end

  ## GeoFence

  def list_geofences do
    GeoFence
    |> order_by([g], fragment("? COLLATE \"C\" ASC", g.name))
    |> Repo.all()
  end

  def get_geofence!(id) do
    Repo.get!(GeoFence, id)
  end

  def find_geofence(%{latitude: _, longitude: _} = point) do
    GeoFence
    |> select([:id, :name])
    |> where([geofence], within_geofence?(point, geofence, :left))
    |> order_by([geofence], asc: distance(geofence, point))
    |> limit(1)
    |> Repo.one()
  end

  def create_geofence(attrs) do
    Repo.transaction(fn ->
      with {:ok, geofence} <- %GeoFence{} |> GeoFence.changeset(attrs) |> Repo.insert(),
           :ok <- apply_geofence(geofence) do
        geofence
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_geofence(%GeoFence{id: id} = geofence, attrs) do
    Repo.transaction(fn ->
      with :ok <- apply_geofence(geofence, except: id),
           {:ok, geofence} <- geofence |> GeoFence.changeset(attrs) |> Repo.update(),
           :ok <- apply_geofence(geofence) do
        geofence
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_geofence(%GeoFence{id: id} = geofence) do
    Repo.transaction(fn ->
      with :ok <- apply_geofence(geofence, except: id),
           {:ok, geofence} <- Repo.delete(geofence) do
        geofence
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def change_geofence(%GeoFence{} = geofence, attrs \\ %{}) do
    GeoFence.changeset(geofence, attrs)
  end

  alias TeslaMate.Log.ChargingProcess

  def count_charging_processes_without_costs(%{latitude: _, longitude: _, radius: _} = geofence) do
    Repo.one(
      from c in ChargingProcess,
        select: count(),
        join: p in assoc(c, :position),
        where: is_nil(c.cost) and within_geofence?(p, geofence, :right)
    )
  end

  def calculate_charge_costs(%GeoFence{id: id}) do
    query = build_charge_cost_update_query()

    with {:ok, %Postgrex.Result{num_rows: _}} <- Repo.query(query, [id]) do
      :ok
    end
  end

  defp build_charge_cost_update_query do
    """
    UPDATE charging_processes cp
    SET cost = (
      SELECT
        CASE WHEN g.session_fee IS NULL AND g.cost_per_unit IS NULL THEN
               NULL
             WHEN g.billing_type = 'per_kwh' THEN
               COALESCE(g.session_fee, 0) +
               COALESCE(g.cost_per_unit * GREATEST(c.charge_energy_used, c.charge_energy_added), 0)
             WHEN g.billing_type = 'per_minute' THEN
               COALESCE(g.session_fee, 0) +
               COALESCE(g.cost_per_unit * c.duration_min, 0)
        END
      FROM charging_processes c
      JOIN geofences g ON g.id = c.geofence_id
      WHERE cp.id = c.id
    )
    WHERE cp.geofence_id = $1 AND cp.cost IS NULL;
    """
  end
end
