defmodule LetsEncrypt.Certifier do
  use Parent.GenServer
  require Logger
  alias LetsEncrypt.Certbot

  def https_keys(certbot_config) do
    if Certbot.keys_available?(certbot_config) do
      {:ok,
       [
         keyfile: Certbot.keyfile(certbot_config),
         certfile: Certbot.certfile(certbot_config),
         cacertfile: Certbot.cacertfile(certbot_config)
       ]}
    else
      :error
    end
  end

  def start_link(certbot_config),
    do: Parent.GenServer.start_link(__MODULE__, certbot_config, name: name(certbot_config.domain))

  defp name(domain), do: LetsEncrypt.Registry.via_tuple({__MODULE__, domain})

  @impl GenServer
  def init(certbot_config) do
    Certbot.init(certbot_config)
    if certbot_config.run_client? == true, do: start_fetch(certbot_config)
    {:ok, %{certbot_config: certbot_config}}
  end

  @impl GenServer
  def handle_info(:start_fetch, state) do
    start_fetch(state.certbot_config)
    {:noreply, state}
  end

  def handle_info(other, state), do: super(other, state)

  @impl Parent.GenServer
  def handle_child_terminated(:fetcher, _pid, _reason, state) do
    Process.send_after(self(), :start_fetch, state.certbot_config.renew_interval())
    {:noreply, state}
  end

  defp start_fetch(certbot_config) do
    unless Parent.GenServer.child?(:fetcher) do
      Parent.GenServer.start_child(%{
        id: :fetcher,
        start: {Task, :start_link, [fn -> get_certs(certbot_config) end]}
      })
    end
  end

  defp get_certs(certbot_config) do
    input_sha = keys_sha(certbot_config)

    case get_certificates(certbot_config) do
      {success, 0} ->
        if keys_sha(certbot_config) != input_sha do
          Logger.info("obtained the new certificate")
          Logger.info(success)
          LetsEncrypt.Site.restart_endpoint(certbot_config)
        end

      {failure, _} ->
        Logger.error(failure)
    end
  end

  defp get_certificates(certbot_config) do
    if Certbot.keys_available?(certbot_config),
      do: Certbot.renew(certbot_config),
      else: Certbot.certonly(certbot_config)
  end

  defp keys_sha(certbot_config) do
    :crypto.hash(
      :md5,
      [
        Certbot.keyfile(certbot_config),
        Certbot.certfile(certbot_config),
        Certbot.cacertfile(certbot_config)
      ]
      |> Stream.filter(&File.exists?/1)
      |> Stream.map(&File.read!/1)
      |> Enum.join()
    )
  end
end
