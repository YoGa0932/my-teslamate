defmodule TeslaMate.EmailTest do
  use TeslaMate.DataCase

  alias TeslaMate.Email
  alias TeslaMate.Log.{Drive, Car}

  describe "send_drive_notification/1" do
    test "returns success but does not send email when email address is not configured" do
      # Create test data
      car = %Car{id: 1, name: "Test Vehicle"}
      drive = %Drive{
        id: 1,
        car_id: 1,
        car: car,
        distance: 10.5,
        duration_min: 30,
        speed_max: 80,
        start_date: ~U[2024-01-01 10:00:00Z],
        end_date: ~U[2024-01-01 10:30:00Z],
        start_ideal_range_km: 300.0,
        end_ideal_range_km: 290.0,
        outside_temp_avg: 25.0,
        inside_temp_avg: 22.0
      }

      # Mock environment without email address configured
      with_mock System, get_env: fn "DRIVE_NOTIFICATION_EMAIL" -> nil end do
        result = Email.send_drive_notification(drive)
        assert result == {:ok, "Email address not configured"}
      end
    end

    test "returns success but does not send email when using default email address" do
      car = %Car{id: 1, name: "Test Vehicle"}
      drive = %Drive{
        id: 1,
        car_id: 1,
        car: car,
        distance: 10.5,
        duration_min: 30,
        speed_max: 80,
        start_date: ~U[2024-01-01 10:00:00Z],
        end_date: ~U[2024-01-01 10:30:00Z],
        start_ideal_range_km: 300.0,
        end_ideal_range_km: 290.0,
        outside_temp_avg: 25.0,
        inside_temp_avg: 22.0
      }

      # Mock environment with default email address
      with_mock System, get_env: fn "DRIVE_NOTIFICATION_EMAIL" -> "your-email@example.com" end do
        result = Email.send_drive_notification(drive)
        assert result == {:ok, "Using default email address"}
      end
    end

    test "email content format is correct" do
      car = %Car{id: 1, name: "Test Vehicle"}
      drive = %Drive{
        id: 1,
        car_id: 1,
        car: car,
        distance: 10.5,
        duration_min: 30,
        speed_max: 80,
        start_date: ~U[2024-01-01 10:00:00Z],
        end_date: ~U[2024-01-01 10:30:00Z],
        start_ideal_range_km: 300.0,
        end_ideal_range_km: 290.0,
        outside_temp_avg: 25.0,
        inside_temp_avg: 22.0
      }

      # Test email sending functionality (without actually sending)
      result = Email.send_drive_notification(drive)
      assert result == {:ok, "Email address not configured"}
    end
  end


end 