# Run with elixir inside the official builder; no app startup or DB is needed.
# Only the isolated HTTP adapter is replaced; Tesla middleware, Decimal,
# Ecto Address schema, and the patched Geocoder are the real dependencies.
Mix.start()
{paths, _} = Code.eval_file(Path.join(__DIR__, "paths.exs"))

if paths.ebin_paths == [] do
  raise "No compiled production dependencies found under #{paths.dependency_root}/_build/prod/lib; compile the app or set COORDINATE_DEPENDENCY_ROOT"
end

Code.append_paths(paths.ebin_paths)
Code.compiler_options(ignore_module_conflict: true)
ExUnit.start()
Logger.configure(level: :warning)

defmodule Tesla.Adapter.Finch do
  def call(%Tesla.Env{} = env, _opts) do
    Process.put(:requests, Process.get(:requests, []) ++ [env])
    Process.get(:http).(env)
  end
end

Code.require_file("lib/teslamate/locations/geocoder.ex", paths.source_dir)

defmodule RealDependencyCoordinateTest do
  use ExUnit.Case, async: false
  alias TeslaMate.Locations.{Address, Geocoder}

  setup do
    System.delete_env("AMAP_KEY")
    Process.put(:requests, [])
    Process.put(:http, fn env -> flunk("Unexpected HTTP: #{env.url}") end)
    :ok
  end

  defp ok(env, body), do: {:ok, %{env | status: 200, body: body}}

  defp amap do
    %{"status" => "1", "regeocode" => %{"formatted_address" => "上海市测试地址", "addressComponent" => %{"city" => [], "province" => "上海市"}}}
  end

  test "real Tesla middleware keeps official no-key reverse lookup" do
    Process.put(:http, fn env ->
      assert env.url == "https://nominatim.openstreetmap.org/reverse"
      assert env.query[:lat] == Decimal.new("46.0")
      assert {"Accept-Language", "zh"} in env.headers
      ok(env, %{"osm_id" => 111, "osm_type" => "node", "lat" => "46.0", "lon" => "6.0", "address" => %{"township" => "Town"}})
    end)
    assert {:ok, %{osm_id: 111, city: "Town"}} = Geocoder.reverse_lookup(Decimal.new("46.0"), Decimal.new("6.0"), "zh")
  end

  test "real Decimal values convert once before AMap reverse lookup" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn env ->
      case env.url do
        "https://restapi.amap.com/v3/assistant/coordinate/convert" ->
          assert env.query[:locations] == "121.473700,31.230400"
          assert env.query[:coordsys] == "gps"
          ok(env, %{"status" => "1", "locations" => "121.478223,31.228458"})
        "https://restapi.amap.com/v3/geocode/regeo" ->
          assert env.query[:location] == "121.478223,31.228458"
          ok(env, amap())
      end
    end)
    assert {:ok, %{osm_type: "amap", latitude: "31.228458", city: "上海市"}} = Geocoder.reverse_lookup(Decimal.new("31.230400"), Decimal.new("121.473700"))
    assert length(Process.get(:requests)) == 2
  end

  test "real Ecto Address refresh uses stored GCJ02 and retains legacy identity" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn env ->
      assert env.url == "https://restapi.amap.com/v3/geocode/regeo"
      assert env.query[:location] == "121.478223,31.228458"
      ok(env, amap())
    end)
    address = %Address{osm_id: 909, osm_type: "amap", latitude: Decimal.new("31.2284580"), longitude: Decimal.new("121.4782230")}
    assert {:ok, [%{osm_id: 909, latitude: "31.2284580"}]} = Geocoder.details([address], "zh")
    assert length(Process.get(:requests)) == 1
  end

  test "real Float requests use six decimals and converted response precision preserves stored identity" do
    System.put_env("AMAP_KEY", "audit-key")
    Process.put(:http, fn env ->
      case env.url do
        "https://restapi.amap.com/v3/assistant/coordinate/convert" ->
          assert env.query[:locations] == "116.397470,39.908823"
          ok(env, %{"status" => "1", "locations" => "116.403712565105,39.910225694445"})
        "https://restapi.amap.com/v3/geocode/regeo" ->
          assert env.query[:location] == "116.403713,39.910226"
          ok(env, amap())
      end
    end)
    assert {:ok, %{latitude: "39.910225694445", longitude: "116.403712565105"}} = Geocoder.reverse_lookup(39.908823, 116.397470, "zh")
    assert length(Process.get(:requests)) == 2
  end

  test "real Ecto Address stays unchanged without AMap credentials" do
    address = %Address{osm_id: 909, osm_type: "amap", latitude: Decimal.new("31.228458"), longitude: Decimal.new("121.478223"), display_name: "既有地址"}
    assert {:ok, [%{osm_id: 909, display_name: "既有地址"}]} = Geocoder.details([address], "zh")
    assert Process.get(:requests) == []
  end
end
