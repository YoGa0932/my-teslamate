Mix.start()
ExUnit.start()

# Exercise the actual patched Geocoder and create_address function, isolating
# network/DB effects. No production credentials or database are needed.
defmodule Decimal do
  defstruct [:value]
  def to_string(%__MODULE__{value: value}, :normal), do: value
  def to_float(%__MODULE__{value: value}), do: String.to_float(value)
end

defmodule Tesla.Env do
  defstruct [:status, :body, :url, :query]
end

defmodule Tesla do
  def client(_middleware, _adapter), do: :audit_client

  def get(:audit_client, url, opts) do
    url = if String.starts_with?(url, "/"), do: "https://nominatim.openstreetmap.org" <> url, else: url
    Process.put(:requests, Process.get(:requests, []) ++ [{url, opts}])
    Process.get(:http).(url, opts)
  end
end

defmodule Ecto.Changeset do
  defstruct [:attrs]
end

defmodule TeslaMate.Locations.Address do
  defstruct [:id, :osm_id, :osm_type, :latitude, :longitude, :display_name, :raw]
  def changeset(_address, attrs), do: %Ecto.Changeset{attrs: attrs}
end

defmodule TeslaMate.Repo do
  def insert(changeset, opts \\ []) do
    Process.put(:insert, {changeset, opts})
    Process.get(:insert_result)
  end

  def get_by(_schema, identity) do
    Process.put(:get_by, identity)
    Process.get(:existing_address)
  end
end

{paths, _} = Code.eval_file(Path.join(__DIR__, "paths.exs"))
Code.require_file("lib/teslamate/locations/geocoder.ex", paths.source_dir)

{:defmodule, _, [_, [do: {:__block__, _, definitions}]]} =
  paths.source_dir |> Path.join("lib/teslamate/locations.ex") |> File.read!() |> Code.string_to_quoted!()

create_address =
  Enum.find(definitions, fn
    {:def, _, [{:create_address, _, _}, _]} -> true
    _ -> false
  end)

Code.eval_quoted(quote do
  defmodule AuditAddressCreation do
    alias TeslaMate.Locations.Address
    alias TeslaMate.Repo
    unquote(create_address)
  end
end)

defmodule CoordinatePatchTest do
  use ExUnit.Case, async: false
  alias TeslaMate.Locations.{Address, Geocoder}

  setup do
    key = System.get_env("AMAP_KEY")
    System.delete_env("AMAP_KEY")
    Process.put(:requests, [])
    Process.put(:http, fn url, _ -> flunk("Unexpected HTTP request: #{url}") end)
    on_exit(fn -> if key, do: System.put_env("AMAP_KEY", key), else: System.delete_env("AMAP_KEY") end)
    :ok
  end

  defp ok(body), do: {:ok, %Tesla.Env{status: 200, body: body}}

  defp osm do
    %{"osm_id" => 111, "osm_type" => "node", "lat" => "46.0", "lon" => "6.0",
      "display_name" => "OSM place", "address" => %{"township" => "Official town", "province" => "Official state"}}
  end

  defp amap do
    %{"status" => "1", "regeocode" => %{
      "formatted_address" => "上海市浦东新区测试路", "aois" => [],
      "pois" => [%{"name" => "较远地点", "distance" => "100"}, %{"name" => "最近地点", "distance" => "5"}],
      "addressComponent" => %{"city" => [], "province" => "上海市", "district" => "浦东新区",
        "country" => [], "adcode" => "310115", "township" => [], "neighborhood" => %{"name" => []},
        "streetNumber" => %{"number" => [], "street" => "测试路"}}
    }}
  end

  test "no AMap key uses official reverse geocoding and current address labels" do
    Process.put(:http, fn url, opts ->
      assert url == "https://nominatim.openstreetmap.org/reverse"
      assert opts[:query][:lat] == 46.0
      assert opts[:headers] == [{"Accept-Language", "zh"}]
      ok(osm())
    end)
    assert {:ok, %{osm_type: "node", city: "Official town", state: "Official state"}} = Geocoder.reverse_lookup(46.0, 6.0, "zh")
  end

  test "blank AMap keys use official fallback without crashing" do
    System.put_env("AMAP_KEY", " , , ")
    Process.put(:http, fn url, _ ->
      assert String.ends_with?(url, "/reverse")
      ok(osm())
    end)
    assert {:ok, %{osm_id: 111}} = Geocoder.reverse_lookup(46.0, 6.0)
  end

  test "Chinese WGS84 Decimal coordinates convert before Chinese reverse lookup" do
    System.put_env("AMAP_KEY", " audit-key ")
    Process.put(:http, fn url, opts ->
      assert opts[:query][:key] == "audit-key"
      case url do
        "https://restapi.amap.com/v3/assistant/coordinate/convert" ->
          assert opts[:query][:locations] == "121.473700,31.230400"
          assert opts[:query][:coordsys] == "gps"
          ok(%{"status" => "1", "locations" => "121.478223,31.228458"})
        "https://restapi.amap.com/v3/geocode/regeo" ->
          assert opts[:query][:location] == "121.478223,31.228458"
          ok(amap())
      end
    end)
    assert {:ok, address} = Geocoder.reverse_lookup(%Decimal{value: "31.230400"}, %Decimal{value: "121.473700"}, "zh")
    assert address.latitude == "31.228458"
    assert address.longitude == "121.478223"
    assert address.osm_type == "amap"
    assert address.city == "上海市"
    assert address.country == "China"
    assert address.name == "最近地点"
    assert address.house_number == nil
    assert length(Process.get(:requests)) == 2
  end

  test "coordinates outside China skip conversion" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn url, opts ->
      assert url == "https://restapi.amap.com/v3/geocode/regeo"
      assert opts[:query][:location] == "6.000000,46.000000"
      ok(amap())
    end)
    assert {:ok, _} = Geocoder.reverse_lookup("46.0", "6.0")
    assert length(Process.get(:requests)) == 1
  end

  test "Float inputs and high precision converted outputs obey six digit API format" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn url, opts ->
      case url do
        "https://restapi.amap.com/v3/assistant/coordinate/convert" ->
          assert opts[:query][:locations] == "116.397470,39.908823"
          ok(%{"status" => "1", "locations" => "116.403712565105,39.910225694445"})
        "https://restapi.amap.com/v3/geocode/regeo" ->
          assert opts[:query][:location] == "116.403713,39.910226"
          ok(amap())
      end
    end)
    assert {:ok, %{latitude: "39.910225694445", longitude: "116.403712565105"}} = Geocoder.reverse_lookup(39.908823, 116.397470, "zh")
    assert length(Process.get(:requests)) == 2
  end

  test "refresh AMap addresses does not apply coordinate conversion again and retains stored id" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn url, opts ->
      assert url == "https://restapi.amap.com/v3/geocode/regeo"
      assert opts[:query][:location] == "121.478223,31.228458"
      ok(amap())
    end)
    stored = %Address{osm_id: 909, osm_type: "amap", latitude: %Decimal{value: "31.2284580"}, longitude: %Decimal{value: "121.4782230"}}
    assert {:ok, [%{osm_id: 909, latitude: "31.2284580"}]} = Geocoder.details([stored], "zh")
    assert length(Process.get(:requests)) == 1
  end

  test "mixed refresh uses official OSM identity lookup and direct AMap lookup" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn url, opts ->
      case url do
        "https://nominatim.openstreetmap.org/lookup" ->
          assert opts[:query][:osm_ids] == "N111"
          ok([osm()])
        "https://restapi.amap.com/v3/geocode/regeo" -> ok(amap())
      end
    end)
    addresses = [%Address{osm_id: 909, osm_type: "amap", latitude: "31.228458", longitude: "121.478223"}, %Address{osm_id: 111, osm_type: "node"}]
    assert {:ok, [%{osm_id: 111, osm_type: "node"}, %{osm_id: 909, osm_type: "amap"}]} = Geocoder.details(addresses, "zh")
    assert length(Process.get(:requests)) == 2
  end

  test "refresh without keys preserves existing AMap addresses without sending GCJ02 to OSM" do
    stored = %Address{osm_id: 909, osm_type: "amap", latitude: "31.228458", longitude: "121.478223", display_name: "既有地址"}
    assert {:ok, [%{osm_id: 909, display_name: "既有地址"}]} = Geocoder.details([stored], "zh")
    assert Process.get(:requests) == []
  end

  test "AMap API errors are returned" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn _, _ -> ok(%{"status" => "0", "info" => "INVALID_USER_KEY"}) end)
    assert {:error, "INVALID_USER_KEY"} = Geocoder.reverse_lookup("46.0", "6.0")
  end

  test "comma separated keys are trimmed and stable for the current day" do
    System.put_env("AMAP_KEY", " first-key, second-key, , ")
    Process.put(:http, fn _, opts ->
      assert opts[:query][:key] in ["first-key", "second-key"]
      ok(amap())
    end)
    assert {:ok, _} = Geocoder.reverse_lookup("46.0", "6.0")
    assert {:ok, _} = Geocoder.reverse_lookup("46.0", "6.0")
    [{_, first}, {_, second}] = Process.get(:requests)
    assert first[:query][:key] == second[:query][:key]
  end

  test "AMap duplicate insert retrieves existing address with matching identity" do
    stored = %Address{id: 88, osm_id: 909, osm_type: "amap"}
    Process.put(:insert_result, {:ok, %Address{id: nil}})
    Process.put(:existing_address, stored)
    assert {:ok, ^stored} = AuditAddressCreation.create_address(%{osm_id: 909, osm_type: "amap"})
    assert {_, [on_conflict: :nothing, conflict_target: [:osm_id, :osm_type]]} = Process.get(:insert)
    assert Process.get(:get_by) == [osm_id: 909, osm_type: "amap"]
  end

  test "AMap insert success and changeset failures preserve return values" do
    stored = %Address{id: 88, osm_id: 909, osm_type: "amap"}
    Process.put(:insert_result, {:ok, stored})
    assert {:ok, ^stored} = AuditAddressCreation.create_address(%{osm_id: 909, osm_type: "amap"})
    error = %Ecto.Changeset{attrs: %{error: true}}
    Process.put(:insert_result, {:error, error})
    assert {:error, ^error} = AuditAddressCreation.create_address(%{osm_id: 909, osm_type: "amap"})
  end

  test "official OSM insert keeps original conflict behavior" do
    Process.put(:insert_result, {:ok, %Address{id: 88}})
    assert {:ok, _} = AuditAddressCreation.create_address(%{osm_id: 111, osm_type: "node"})
    assert {_, []} = Process.get(:insert)
  end
end
