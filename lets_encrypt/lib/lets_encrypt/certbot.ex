defmodule LetsEncrypt.Certbot do
  def init(config) do
    Enum.each(
      [config_folder(config), work_folder(config), webroot_folder(config)],
      &File.mkdir_p!/1
    )
  end

  def keys_available?(config),
    do: Enum.all?([keyfile(config), certfile(config), cacertfile(config)], &File.exists?/1)

  def keyfile(config), do: Path.join(keys_folder(config), "privkey.pem")
  def certfile(config), do: Path.join(keys_folder(config), "cert.pem")
  def cacertfile(config), do: Path.join(keys_folder(config), "chain.pem")

  def challenge_file(config, challenge),
    do: Path.join([webroot_folder(config), ".well-known", "acme-challenge", challenge])

  def certonly(config) do
    certbot_cmd(
      config,
      ~w(certonly -m #{config.email} --webroot --webroot-path #{webroot_folder(config)} --agree-tos) ++
        domain_params(config)
    )
  end

  def renew(config), do: certbot_cmd(config, ~w(renew --cert-name #{config.domain}))

  defp certbot_cmd(config, options),
    do: System.cmd("certbot", options ++ common_options(config), stderr_to_stdout: true)

  defp common_options(config) do
    ~w(
      --server #{config.ca_url}
      --work-dir #{work_folder(config)}
      --config-dir #{config_folder(config)}
      --logs-dir #{log_folder(config)}
      --no-self-upgrade
      --non-interactive
    )
  end

  defp domain_params(config) do
    Enum.map([config.domain | config.extra_domains], &"-d #{&1}")
  end

  defp keys_folder(config), do: Path.join(~w(#{config_folder(config)} live #{config.domain}))
  defp config_folder(config), do: Path.join(config.base_folder, "config")
  defp log_folder(config), do: Path.join(config.base_folder, "log")
  defp work_folder(config), do: Path.join(config.base_folder, "work")
  defp webroot_folder(config), do: Path.join(config.base_folder, "webroot")
end
