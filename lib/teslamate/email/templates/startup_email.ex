defmodule TeslaMate.Email.Templates.StartupEmail do
  @moduledoc """
  Startup notification email templates
  """

  def generate_html(info) do
    TeslaMate.Email.Templates.StartupEmail.HtmlRenderer.render(info)
  end
end 