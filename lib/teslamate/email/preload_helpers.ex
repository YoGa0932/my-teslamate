defmodule TeslaMate.Email.PreloadHelpers do
  @moduledoc """
  Common preload helpers for email templates
  """

  alias TeslaMate.Repo

  @doc """
  Preload drive with all necessary associations for email rendering
  """
  def preload_drive_for_email(drive) do
    Repo.preload(drive, [
      :car, 
      :start_address, 
      :end_address, 
      :start_geofence, 
      :end_geofence, 
      :end_position
    ])
  end

  @doc """
  Preload charging process with all necessary associations for email rendering
  """
  def preload_charging_for_email(charging_process) do
    Repo.preload(charging_process, [
      :car, 
      :address, 
      :geofence
    ])
  end

  @doc """
  Preload car with settings
  """
  def preload_car_with_settings(car) do
    Repo.preload(car, [:settings])
  end

  @doc """
  Preload drive with car only
  """
  def preload_drive_with_car(drive) do
    Repo.preload(drive, [:car])
  end

  @doc """
  Preload charging process with car settings and geofence
  """
  def preload_charging_with_car_settings(charging_process) do
    Repo.preload(charging_process, [{:car, :settings}, :geofence])
  end
end 