defmodule TeslaMate.Email.Templates.DriveEmail do
  @moduledoc """
  Drive notification email templates
  """

  def generate_html(drive) do
    TeslaMate.Email.Templates.DriveEmail.HtmlRenderer.render(drive)
  end
end 