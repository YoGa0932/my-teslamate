defmodule TeslaMate.Email.Templates.ChargingEmail do
  @moduledoc """
  Charging notification email templates
  """

  def generate_html(charging) do
    TeslaMate.Email.Templates.ChargingEmail.HtmlRenderer.render(charging)
  end
end 