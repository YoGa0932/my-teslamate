# The installed location is <repository>/customizations/coordinate/.
source_root =
  System.get_env("COORDINATE_SOURCE_ROOT", Path.expand("../..", __DIR__))
  |> Path.expand()

source_dir =
  Enum.find([Path.join(source_root, "elixir"), source_root], fn candidate ->
    File.regular?(Path.join(candidate, "lib/teslamate/locations/geocoder.ex"))
  end) ||
    raise "COORDINATE_SOURCE_ROOT must contain elixir/lib/teslamate/locations/geocoder.ex or lib/teslamate/locations/geocoder.ex"

dependency_root =
  case System.get_env("COORDINATE_DEPENDENCY_ROOT") do
    nil ->
      Enum.find([source_dir, source_root], fn candidate ->
        File.dir?(Path.join(candidate, "_build/prod/lib"))
      end) || source_dir

    path ->
      Path.expand(path)
  end

%{
  source_dir: source_dir,
  dependency_root: dependency_root,
  ebin_paths: Path.wildcard(Path.join(dependency_root, "_build/prod/lib/*/ebin"))
}
