defmodule TeslaMate.Log do
  @moduledoc """
  The Log context.
  """

  require Logger

  import TeslaMate.CustomExpressions
  import Ecto.Query, warn: false

  alias __MODULE__.{Car, Drive, Update, ChargingProcess, Charge, Position, State}
  alias TeslaMate.{Repo, Locations, Settings}
  alias TeslaMate.Locations.GeoFence
  alias TeslaMate.Settings.{CarSettings, GlobalSettings}

  ## Car

  def list_cars do
    Repo.all(Car)
  end

  def get_car!(id) do
    Repo.get!(Car, id)
  end

  def get_car_by([{_key, nil}]), do: nil
  def get_car_by([{_key, _val}] = opts), do: Repo.get_by(Car, opts)

  def create_car(attrs) do
    %Car{settings: %CarSettings{}}
    |> Car.changeset(attrs)
    |> Repo.insert()
  end

  def create_or_update_car(%Ecto.Changeset{} = changeset) do
    with {:ok, car} <- Repo.insert_or_update(changeset) do
      {:ok, Repo.preload(car, [:settings])}
    end
  end

  def update_car(%Car{} = car, attrs, opts \\ []) do
    with {:ok, car} <- car |> Car.changeset(attrs) |> Repo.update() do
      preloads = Keyword.get(opts, :preload, [])
      {:ok, Repo.preload(car, preloads, force: true)}
    end
  end

  def recalculate_efficiencies(%GlobalSettings{} = settings) do
    for car <- list_cars() do
      {:ok, _car} = recalculate_efficiency(car, settings)
    end

    :ok
  end

  ## State

  def start_state(%Car{} = car, state, opts \\ []) when not is_nil(state) do
    now = Keyword.get(opts, :date) || DateTime.utc_now()

    case get_current_state(car) do
      %State{state: ^state} = s ->
        {:ok, s}

      %State{} = s ->
        Repo.transaction(fn ->
          with {:ok, _} <- s |> State.changeset(%{end_date: now}) |> Repo.update(),
               {:ok, new_state} <- create_state(car, %{state: state, start_date: now}) do
            new_state
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)

      nil ->
        create_state(car, %{state: state, start_date: now})
    end
  end

  def get_current_state(%Car{id: id}) do
    State
    |> where([s], ^id == s.car_id and is_nil(s.end_date))
    |> Repo.one()
  end

  def create_current_state(%Car{id: id} = car) do
    query =
      from s in State,
        where: s.car_id == ^id,
        order_by: [desc: s.start_date],
        limit: 1

    with nil <- get_current_state(car),
         %State{} = state <- Repo.one(query),
         {:ok, _} <- state |> State.changeset(%{end_date: nil}) |> Repo.update() do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  def complete_current_state(%Car{id: id} = car) do
    case get_current_state(car) do
      %State{start_date: date} = state ->
        query =
          from s in State,
            where: s.car_id == ^id and s.start_date > ^date,
            order_by: [asc: s.start_date],
            limit: 1

        end_date =
          case Repo.one(query) do
            %State{start_date: d} -> d
            nil -> DateTime.add(date, 1, :second)
          end

        with {:ok, _} <-
               state
               |> State.changeset(%{end_date: end_date})
               |> Repo.update() do
          :ok
        end

      nil ->
        :ok
    end
  end

  def get_earliest_state(%Car{id: id}) do
    State
    |> where(car_id: ^id)
    |> order_by(asc: :start_date)
    |> limit(1)
    |> Repo.one()
  end

  defp create_state(%Car{id: id}, attrs) do
    %State{car_id: id}
    |> State.changeset(attrs)
    |> Repo.insert()
  end

  ## Position

  def insert_position(%Drive{id: id, car_id: car_id}, attrs) do
    %Position{car_id: car_id, drive_id: id}
    |> Position.changeset(attrs)
    |> Repo.insert()
  end

  def insert_position(%Car{id: id}, attrs) do
    %Position{car_id: id}
    |> Position.changeset(attrs)
    |> Repo.insert()
  end

  def get_latest_position do
    Position
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  def get_latest_position(%Car{id: id}) do
    Position
    |> where(car_id: ^id)
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  def get_positions_without_elevation(min_id \\ 0, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    date_earliest =
      cond do
        min_id == 0 ->
          DateTime.add(DateTime.utc_now(), -10, :day)

        true ->
          {:ok, default_date_earliest, _} = DateTime.from_iso8601("2003-07-01T00:00:00Z")
          default_date_earliest
      end

    naive_date_earliest = DateTime.to_naive(date_earliest)

    non_streamed_drives =
      Repo.all(
        from p in Position,
          select: p.drive_id,
          inner_join: d in assoc(p, :drive),
          where: d.start_date > ^naive_date_earliest and p.id > ^min_id,
          having:
            count()
            |> filter(not is_nil(p.odometer) and is_nil(p.ideal_battery_range_km)) == 0,
          group_by: p.drive_id
      )

    Position
    |> where(
      [p],
      p.id > ^min_id and is_nil(p.elevation) and p.drive_id in ^non_streamed_drives and
        p.date > ^naive_date_earliest
    )
    |> order_by(asc: :id)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
    |> case do
      [%Position{id: next} | _] = positions ->
        {Enum.reverse(positions), next}

      [] ->
        {[], nil}
    end
  end

  def update_position(%Position{} = position, attrs) do
    position
    |> Position.changeset(attrs)
    |> Repo.update()
  end

  ## Drive

  def start_drive(%Car{id: id}) do
    %Drive{car_id: id}
    |> Drive.changeset(%{start_date: DateTime.utc_now()})
    |> Repo.insert()
  end

  def close_drive(%Drive{id: id} = drive, opts \\ []) do
    drive = Repo.preload(drive, [:car])

    drive_data =
      from p in Position,
        select: %{
          count: count() |> over(:w),
          start_position_id: first_value(p.id) |> over(:w),
          end_position_id: last_value(p.id) |> over(:w),
          outside_temp_avg: avg(p.outside_temp) |> over(:w),
          inside_temp_avg: avg(p.inside_temp) |> over(:w),
          speed_max: max(p.speed) |> over(:w),
          power_max: max(p.power) |> over(:w),
          power_min: min(p.power) |> over(:w),
          start_date: first_value(p.date) |> over(:w),
          end_date: last_value(p.date) |> over(:w),
          start_km: first_value(p.odometer) |> over(:w),
          end_km: last_value(p.odometer) |> over(:w),
          distance: (last_value(p.odometer) |> over(:w)) - (first_value(p.odometer) |> over(:w)),
          duration_min:
            fragment(
              "round(extract(epoch from (? - ?)) / 60)::integer",
              last_value(p.date) |> over(:w),
              first_value(p.date) |> over(:w)
            ),
          start_ideal_range_km: -1,
          end_ideal_range_km: -1,
          start_rated_range_km: -1,
          end_rated_range_km: -1,
          ascent: 0,
          descent: 0
        },
        windows: [
          w: [
            order_by:
              fragment("? RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING", p.date)
          ]
        ],
        where: p.drive_id == ^id,
        limit: 1

    non_streamed_drive_data =
      from p in Position,
        select: %{
          start_ideal_range_km: first_value(p.ideal_battery_range_km) |> over(:w),
          end_ideal_range_km: last_value(p.ideal_battery_range_km) |> over(:w),
          start_rated_range_km: first_value(p.rated_battery_range_km) |> over(:w),
          end_rated_range_km: last_value(p.rated_battery_range_km) |> over(:w)
        },
        windows: [
          w: [
            order_by:
              fragment("? RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING", p.date)
          ]
        ],
        where:
          p.drive_id == ^id and
            not is_nil(p.ideal_battery_range_km) and
            not is_nil(p.odometer),
        limit: 1

    elevation_data =
      from p1 in subquery(
             from p in Position,
               where: p.drive_id == ^id and not is_nil(p.elevation),
               select: %{
                 elevation_diff: p.elevation - (lag(p.elevation) |> over(order_by: [asc: p.date]))
               }
           ),
           select: %{
             elevation_gains:
               sum(
                 fragment(
                   "CASE WHEN ? > 0 THEN ? ELSE 0 END",
                   p1.elevation_diff,
                   p1.elevation_diff
                 )
               ),
             elevation_losses:
               sum(
                 fragment(
                   "CASE WHEN ? < 0 THEN ABS(?) ELSE 0 END",
                   p1.elevation_diff,
                   p1.elevation_diff
                 )
               )
           }

    query =
      from d0 in subquery(drive_data),
        join: d1 in subquery(non_streamed_drive_data),
        on: true,
        join: e in subquery(elevation_data),
        on: true,
        select: %{
          d0
          | start_ideal_range_km: d1.start_ideal_range_km,
            end_ideal_range_km: d1.end_ideal_range_km,
            start_rated_range_km: d1.start_rated_range_km,
            end_rated_range_km: d1.end_rated_range_km,
            ascent: e.elevation_gains,
            descent: e.elevation_losses
        }

    case Repo.one(query) do
      %{count: count, distance: distance} = attrs when count >= 2 and distance >= 0.01 ->
        lookup_address = Keyword.get(opts, :lookup_address, true)

        start_pos = Repo.get!(Position, attrs.start_position_id)
        end_pos = Repo.get!(Position, attrs.end_position_id)

        attrs =
          if lookup_address do
            attrs
            |> put_address(:start_address_id, start_pos)
            |> put_address(:end_address_id, end_pos)
          else
            attrs
          end

        attrs =
          attrs
          |> put_geofence(:start_geofence_id, start_pos)
          |> put_geofence(:end_geofence_id, end_pos)

        case drive
             |> Drive.changeset(attrs)
             |> Repo.update() do
          {:ok, updated_drive} ->
            # Send drive record email with trajectory (if available)
            Task.start(fn -> TeslaMate.Email.send_drive_notification(updated_drive) end)
            
            {:ok, updated_drive}
          error -> error
        end

      _ ->
        drive
        |> Drive.changeset(%{distance: 0, duration_min: 0})
        |> Repo.delete()
    end
  end

  defp put_address(attrs, key, position) do
    case Locations.find_address(position) do
      {:ok, %Locations.Address{id: id}} ->
        Map.put(attrs, key, id)

      {:error, reason} ->
        Logger.warning("Address not found: #{inspect(reason)}")
        attrs
    end
  end

  defp put_geofence(attrs, key, position) do
    case Locations.find_geofence(position) do
      %GeoFence{id: id} -> Map.put(attrs, key, id)
      nil -> attrs
    end
  end

  ## ChargingProcess

  def get_charging_process!(id) do
    ChargingProcess
    |> where(id: ^id)
    |> preload([:address, :geofence, :car, :position])
    |> Repo.one!()
  end

  def update_charging_process(%ChargingProcess{} = charge, attrs) do
    charge
    |> ChargingProcess.changeset(attrs)
    |> Repo.update()
  end

  def start_charging_process(%Car{id: id}, %{latitude: _, longitude: _} = attrs, opts \\ []) do
    lookup_address = Keyword.get(opts, :lookup_address, true)
    position = Map.put(attrs, :car_id, id)

    address_id =
      if lookup_address do
        case Locations.find_address(position) do
          {:ok, %Locations.Address{id: id}} ->
            id

          {:error, reason} ->
            Logger.warning("Address not found: #{inspect(reason)}")
            nil
        end
      end

    geofence_id =
      with %GeoFence{id: id} <- Locations.find_geofence(position) do
        id
      end

    with {:ok, cproc} <-
           %ChargingProcess{car_id: id, address_id: address_id, geofence_id: geofence_id}
           |> ChargingProcess.changeset(%{start_date: DateTime.utc_now(), position: position})
           |> Repo.insert() do
      {:ok, Repo.preload(cproc, [:address, :geofence])}
    end
  end

  def insert_charge(%ChargingProcess{id: id}, attrs) do
    %Charge{charging_process_id: id}
    |> Charge.changeset(attrs)
    |> Repo.insert()
  end

  def complete_charging_process(%ChargingProcess{} = charging_process) do
    charging_process = Repo.preload(charging_process, [{:car, :settings}, :geofence])
    settings = Settings.get_global_settings!()

    type =
      from(c in Charge,
        select: %{
          fast_charger_type: fragment("mode() WITHIN GROUP (ORDER BY ?)", c.fast_charger_type)
        },
        where: c.charging_process_id == ^charging_process.id and c.charger_power > 0
      )

    stats =
      from(c in Charge,
        join: t in subquery(type),
        on: true,
        select: %{
          start_date: first_value(c.date) |> over(:w),
          end_date: last_value(c.date) |> over(:w),
          start_ideal_range_km: first_value(c.ideal_battery_range_km) |> over(:w),
          end_ideal_range_km: last_value(c.ideal_battery_range_km) |> over(:w),
          start_rated_range_km: first_value(c.rated_battery_range_km) |> over(:w),
          end_rated_range_km: last_value(c.rated_battery_range_km) |> over(:w),
          start_battery_level: first_value(c.battery_level) |> over(:w),
          end_battery_level: last_value(c.battery_level) |> over(:w),
          outside_temp_avg: avg(c.outside_temp) |> over(:w),
          charge_energy_added:
            coalesce(
              nullif(last_value(c.charge_energy_added) |> over(:w), 0),
              max(c.charge_energy_added) |> over(:w)
            ) -
              (first_value(c.charge_energy_added) |> over(:w)),
          duration_min:
            duration_min(last_value(c.date) |> over(:w), first_value(c.date) |> over(:w)),
          fast_charger_type: t.fast_charger_type
        },
        windows: [
          w: [
            order_by:
              fragment("? RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING", c.date)
          ]
        ],
        where: [charging_process_id: ^charging_process.id],
        limit: 1
      )
      |> Repo.one() || %{end_date: DateTime.utc_now(), charge_energy_added: nil}

    charge_energy_used = calculate_energy_used(charging_process)
    charge_energy_added = stats.charge_energy_added

    attrs =
      stats
      |> Map.put(:charge_energy_used, charge_energy_used)
      |> Map.update(:charge_energy_added, nil, fn kwh ->
        cond do
          kwh == nil or Decimal.negative?(kwh) -> nil
          true -> kwh
        end
      end)
      |> Map.put(:cost, calculate_charging_cost(charging_process, charge_energy_added))

    with {:ok, cproc} <- charging_process |> ChargingProcess.changeset(attrs) |> Repo.update(),
         {:ok, _car} <- recalculate_efficiency(charging_process.car, settings) do
      # Preload all associations needed for email
      charging_process_with_associations = Repo.preload(cproc, [
        :car, 
        :address, 
        :geofence
      ])
      # Send charging completion email notification
      Task.start(fn -> TeslaMate.Email.send_charging_notification(charging_process_with_associations) end)
      {:ok, cproc}
    end
  end

  def update_energy_used(%ChargingProcess{} = charging_process) do
    charging_process
    |> ChargingProcess.changeset(%{charge_energy_used: calculate_energy_used(charging_process)})
    |> Repo.update()
  end

  defp calculate_energy_used(%ChargingProcess{id: id} = charging_process) do
    phases = determine_phases(charging_process)

    query =
      from c in Charge,
        select: %{
          energy_used:
            c_if is_nil(c.charger_phases) do
              c.charger_power
            else
              c.charger_actual_current * c.charger_voltage * type(^phases, :float) / 1000.0
            end *
              fragment(
                "EXTRACT(epoch FROM (?))",
                c.date - (lag(c.date) |> over(order_by: c.date))
              ) / 3600
        },
        where: c.charging_process_id == ^id and c.charger_power > 0

    case Repo.all(query) do
      [] -> nil
      energy_used_list ->
        energy_used_list
        |> Enum.map(& &1.energy_used)
        |> Enum.reject(&is_nil/1)
        |> Enum.sum()
        |> Decimal.new()
    end
  end

  def determine_charging_type(%ChargingProcess{id: id}) do
    query =
      from c in Charge,
        select: %{
          charge_type: fragment("""
            CASE 
              WHEN fast_charger_present = true THEN 'DC'
              WHEN NULLIF(mode() WITHIN GROUP (ORDER BY charger_phases),0) is null THEN 'DC'
              ELSE 'AC'
            END
          """)
        },
        group_by: c.fast_charger_present,
        where: c.charging_process_id == ^id and c.charger_power > 0

    case Repo.one(query) do
      %{charge_type: charge_type} -> charge_type
      _ -> "Unknown"
    end
  end

  defp calculate_charging_cost(%ChargingProcess{} = charging_process, charge_energy_added) do
    if is_nil(charge_energy_added) or Decimal.equal?(charge_energy_added, Decimal.new("0")) do
      nil
    else
      # Price priority: Geofence fixed price > No price
      price_per_kwh = case charging_process.geofence do
        %{id: geofence_id} when not is_nil(geofence_id) ->
          # Use geofence fixed price
          case charging_process.geofence do
            %{cost_per_unit: cost} when not is_nil(cost) ->
              if Decimal.equal?(cost, Decimal.new("0")), do: nil, else: cost
            _ ->
              nil
          end
        _ ->
          nil
      end
      

      
      if Decimal.equal?(price_per_kwh, Decimal.new("0")) do
        nil
      else
        Decimal.mult(charge_energy_added, price_per_kwh)
      end
    end
  end

  defp determine_phases(%ChargingProcess{id: id, car_id: car_id}) do
    from(c in Charge,
      select: {
        avg(c.charger_power * 1000.0 / nullif(c.charger_actual_current * c.charger_voltage, 0))
        |> type(:float),
        avg(c.charger_phases) |> type(:integer),
        avg(c.charger_voltage) |> type(:float),
        count()
      },
      group_by: c.charging_process_id,
      where: c.charging_process_id == ^id
    )
    |> Repo.one()
    |> case do
      {p, r, v, n} when not is_nil(p) and p > 0 and n > 15 ->
        cond do
          r == round(p) ->
            r

          r == 3 and abs(p / :math.sqrt(r) - 1) <= 0.1 ->
            Logger.info("Voltage correction: #{round(v)}V -> #{round(v / :math.sqrt(r))}V",
              car_id: car_id
            )

            :math.sqrt(r)

          abs(round(p) - p) <= 0.3 ->
            Logger.info("Phase correction: #{r} -> #{round(p)}", car_id: car_id)
            round(p)

          true ->
            nil
        end

      _ ->
        nil
    end
  end



  defp recalculate_efficiency(car, settings, opts \\ [{5, 8}, {4, 5}, {3, 3}, {2, 2}])
  defp recalculate_efficiency(car, _settings, []), do: {:ok, car}

  defp recalculate_efficiency(%Car{id: id} = car, settings, [{precision, threshold} | opts]) do
    {start_range, end_range} =
      case settings do
        %GlobalSettings{preferred_range: :ideal} ->
          {:start_ideal_range_km, :end_ideal_range_km}

        %GlobalSettings{preferred_range: :rated} ->
          {:start_rated_range_km, :end_rated_range_km}
      end

    query =
      from c in ChargingProcess,
        select: {
          round(
            c.charge_energy_added / nullif(field(c, ^end_range) - field(c, ^start_range), 0),
            ^precision
          ),
          count()
        },
        where:
          c.car_id == ^id and c.duration_min > 10 and c.end_battery_level <= 95 and
            not is_nil(field(c, ^end_range)) and not is_nil(field(c, ^start_range)) and
            c.charge_energy_added > 0.0,
        group_by: 1,
        order_by: [desc: 2],
        limit: 1

    case Repo.one(query) do
      {factor, n} when n >= threshold and not is_nil(factor) and factor > 0 ->
        Logger.info("Derived efficiency factor: #{factor * 1000} Wh/km (#{n}x confirmed)",
          car_id: id
        )

        car
        |> Car.changeset(%{efficiency: factor})
        |> Repo.update()

      _ ->
        recalculate_efficiency(car, settings, opts)
    end
  end

  ## Update

  def start_update(%Car{id: id}, opts \\ []) do
    start_date = Keyword.get(opts, :date) || DateTime.utc_now()

    %Update{car_id: id}
    |> Update.changeset(%{start_date: start_date})
    |> Repo.insert()
  end

  def cancel_update(%Update{} = update) do
    Repo.delete(update)
  end

  def finish_update(%Update{} = update, version, opts \\ []) do
    end_date = Keyword.get(opts, :date) || DateTime.utc_now()

    update
    |> Update.changeset(%{end_date: end_date, version: version})
    |> Repo.update()
  end

  def get_latest_update(%Car{id: id}) do
    from(u in Update, where: [car_id: ^id], order_by: [desc: :start_date], limit: 1)
    |> Repo.one()
  end

  def insert_missed_update(%Car{id: id}, version, opts \\ []) do
    date = Keyword.get(opts, :date) || DateTime.utc_now()

    %Update{car_id: id}
    |> Update.changeset(%{start_date: date, end_date: date, version: version})
    |> Repo.insert()
  end

  def calculate_drive_cost(%Drive{} = drive) do
    # Get efficiency from drive.car.efficiency
    efficiency = case drive do
      %{car: %{efficiency: eff}} -> eff
      _ -> nil
    end

    # Calculate energy used for driving (from range change)
    energy_used_kwh = case {drive.start_rated_range_km, drive.end_rated_range_km, efficiency} do
      {start_range, end_range, eff} when not is_nil(start_range) and not is_nil(end_range) and not is_nil(eff) ->
        range_diff = (if is_struct(start_range, Decimal), do: Decimal.to_float(start_range), else: start_range) - 
                     (if is_struct(end_range, Decimal), do: Decimal.to_float(end_range), else: end_range)
        range_diff * eff
      _ ->
        nil
    end
    
    if is_nil(energy_used_kwh) do
      nil
    else
      # Get last charging price information
      last_charging_cost_per_kwh = get_last_charging_cost_per_kwh(drive.car_id)
      
      if is_nil(last_charging_cost_per_kwh) do
        # If no charging price info, use default value 1 yuan/kWh
        Decimal.mult(Decimal.new(Float.to_string(energy_used_kwh)), Decimal.new("1.0"))
        |> Decimal.to_float()
        |> Float.round(3)
      else
        Decimal.mult(Decimal.new(Float.to_string(energy_used_kwh)), last_charging_cost_per_kwh)
        |> Decimal.to_float()
        |> Float.round(3)
      end
    end
  end

  defp get_last_charging_cost_per_kwh(car_id) do
    # Get last charging price information
    query = """
    SELECT 
      cp.cost,
      cp.charge_energy_added,
      CASE WHEN NULLIF(mode() WITHIN GROUP (ORDER BY c.charger_phases),0) is null THEN 'DC' ELSE 'AC' END AS charge_type
    FROM charging_processes cp
    LEFT JOIN charges c ON cp.id = c.charging_process_id
    WHERE cp.car_id = $1 
      AND cp.cost IS NOT NULL 
      AND cp.charge_energy_added IS NOT NULL 
      AND cp.charge_energy_added > 0
    GROUP BY cp.id, cp.cost, cp.charge_energy_added
    ORDER BY cp.end_date DESC
    LIMIT 1
    """
    
    case Repo.query(query, [car_id]) do
      {:ok, %{rows: [[cost, charge_energy_added, _charge_type] | _]}} ->
        if Decimal.equal?(charge_energy_added, Decimal.new("0")) do
          nil
        else
          Decimal.div(cost, charge_energy_added)
        end
      _ ->
        nil
    end
  end
end
