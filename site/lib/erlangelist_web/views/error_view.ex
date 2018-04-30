defmodule ErlangelistWeb.ErrorView do
  use ErlangelistWeb, :view

  def render("404.html", _assigns) do
    {:safe, "<div style='margin-top:20px;'>Page not found</div>"}
  end

  def render("500.html", _assigns) do
    {:safe, "<div style='margin-top:20px;'>Server internal error</div>"}
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
