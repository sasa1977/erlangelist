defmodule SiteEncrypt.Phoenix do
  def child_spec(opts) do
    %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link({endpoint, callback_mod}) do
    config = callback_mod.config()

    Supervisor.start_link(
      [
        Supervisor.child_spec(endpoint, id: :endpoint),
        {SiteEncrypt.Certifier, {callback_mod, config}}
      ],
      name: name(config),
      strategy: :rest_for_one
    )
  end

  def restart_endpoint(config) do
    Supervisor.terminate_child(name(config), :endpoint)
    Supervisor.restart_child(name(config), :endpoint)
  end

  defp name(config), do: SiteEncrypt.Registry.via_tuple({__MODULE__, config.domain})
end
