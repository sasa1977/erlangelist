defmodule Erlangelist.Web.Dashboard.Endpoint do
  use Phoenix.Endpoint, otp_app: :erlangelist

  socket "/live", Phoenix.LiveView.Socket

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Erlangelist.Web.Dashboard.Router

  def init(_key, phoenix_defaults) do
    {:ok,
     Keyword.merge(
       phoenix_defaults,
       pubsub_server: Erlangelist.PubSub,
       http: [compress: true, port: 20082, transport_options: [num_acceptors: 5]],
       live_view: [signing_salt: "dmsgVNOMhYDl66PB65qHd2HOMc2sV1K4"],
       secret_key_base: "tOczp1KVeoPHOXj8CyYoinE/2xr3dps53AGzpx9AuJR7pft8LK4YkhMj55O+lP6o"
     )}
  end
end
