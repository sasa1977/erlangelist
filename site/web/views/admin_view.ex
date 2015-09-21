defmodule Erlangelist.AdminView do
  use Erlangelist.Web, :view

  defp model_display(model) do
    model
    |> to_string
    |> String.replace(~r/Elixir\.Erlangelist\.Model\.(.+)Visit/, "\\1")
  end

  defp drilldown_format_date(datetime, period) do
    Timex.DateFormat.format!(datetime, drilldown_date_formats[period], :strftime)
  end

  defp drilldown_date_formats do
    %{
      "recent" => "%H:%M",
      "day" => "%d.%m. %H:%M",
      "month" => "%d.%m.",
      "all" => "%b %Y"
    }
  end
end
