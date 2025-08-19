defmodule TeslaMate.EmailService do
  @moduledoc """
  Email service module
  
  Integrates external capability service for automatic email sending after driving and charging completion
  """

  use Tesla
  require Logger

  # Tesla configuration
  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  @doc """
  Send driving completion email
  """
  def send_driving_email(trip_id) do
    try do
      Logger.info("Sending driving completion email: #{trip_id}")

      case send_driving_email_request(trip_id) do
        {:ok, response} ->
          Logger.info("Driving email sent successfully: #{trip_id}")
          {:ok, response}

        {:error, reason} ->
          Logger.error("Driving email sending failed: #{trip_id}, reason: #{reason}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Driving email sending exception: #{trip_id}, error: #{inspect(e)}")
        {:error, "Email sending exception: #{inspect(e)}"}
    end
  end

  @doc """
  Send charging completion email
  """
  def send_charging_email(charging_id) do
    try do
      Logger.info("Sending charging completion email: #{charging_id}")

      case send_charging_email_request(charging_id) do
        {:ok, response} ->
          Logger.info("Charging email sent successfully: #{charging_id}")
          {:ok, response}

        {:error, reason} ->
          Logger.error("Charging email sending failed: #{charging_id}, reason: #{reason}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Charging email sending exception: #{charging_id}, error: #{inspect(e)}")
        {:error, "Email sending exception: #{inspect(e)}"}
    end
  end

  # Private functions

  defp send_driving_email_request(trip_id) do
    hub_url = get_hub_url()
    url = "#{hub_url}/api/v1/driving-email/send/#{trip_id}"

    case get(url) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{reason}"}
    end
  end

  defp send_charging_email_request(charging_id) do
    hub_url = get_hub_url()
    url = "#{hub_url}/api/v1/charging-email/send/#{charging_id}"

    case get(url) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{reason}"}
    end
  end

  defp get_hub_url do
    System.get_env("TESLAMATE_HUB_URL") || "http://localhost:8000"
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :debug
end
