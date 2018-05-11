defmodule SiteEncrypt.Certifier do
  use Parent.GenServer
  require Logger
  alias SiteEncrypt.Certbot

  def start_link({site, certbot_config}),
    do:
      Parent.GenServer.start_link(
        __MODULE__,
        {site, certbot_config},
        name: name(certbot_config.domain)
      )

  defp name(domain), do: SiteEncrypt.Registry.via_tuple({__MODULE__, domain})

  @impl GenServer
  def init({site, certbot_config}) do
    Certbot.init(certbot_config)
    if certbot_config.run_client? == true, do: start_fetch(site, certbot_config)
    {:ok, %{site: site, certbot_config: certbot_config}}
  end

  @impl GenServer
  def handle_info(:start_fetch, state) do
    start_fetch(state.site, state.certbot_config)
    {:noreply, state}
  end

  def handle_info(other, state), do: super(other, state)

  @impl Parent.GenServer
  def handle_child_terminated(:fetcher, _pid, _reason, state) do
    Process.send_after(self(), :start_fetch, state.certbot_config.renew_interval())
    {:noreply, state}
  end

  defp start_fetch(site, certbot_config) do
    unless Parent.GenServer.child?(:fetcher) do
      Parent.GenServer.start_child(%{
        id: :fetcher,
        start: {Task, :start_link, [fn -> get_certs(site, certbot_config) end]}
      })
    end
  end

  defp get_certs(site, certbot_config) do
    case Certbot.ensure_cert(certbot_config) do
      {:error, output} ->
        Logger.error("error obtaining certificate:\n#{output}")

      {:new_cert, output} ->
        Logger.info(output)
        Logger.info("obtained new certificate, restarting endpoint")
        site.handle_new_cert(certbot_config)

      :no_change ->
        :ok
    end
  end
end
