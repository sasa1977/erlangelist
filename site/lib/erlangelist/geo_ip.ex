defmodule Erlangelist.GeoIP do
  use Parent.GenServer

  def start_link(_), do: Parent.GenServer.start_link(__MODULE__, nil)

  def data(ip_address) do
    case Geolix.lookup(ip_address) do
      %{country: %{country: %{iso_code: country_code, name: country_name}}}
      when not is_nil(country_code) and not is_nil(country_name) ->
        %{country_code: country_code, country_name: country_name}

      _ ->
        %{country_code: nil, country_name: nil}
    end
  end

  @impl GenServer
  def init(_) do
    init_server()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:start_loader_job, state) do
    if Parent.GenServer.child?(:fetch_job), do: Parent.GenServer.shutdown_child(:fetch_job)
    start_loader_job()
    enqueue_loader_job()
    {:noreply, state}
  end

  def handle_info(unknown_message, state), do: super(unknown_message, state)

  if Mix.env() == :prod do
    def init_server() do
      File.mkdir_p(db_path())

      if File.exists?(db_file("country.mmdb")) do
        load_db()
        enqueue_loader_job()
      else
        start_loader_job()
      end

      Process.send_after(self(), :start_loader_job, :timer.hours(12))
    end
  else
    def init_server(), do: :ok
  end

  defp start_loader_job(), do: Parent.GenServer.start_child(%{id: :fetch_job, start: {Task, :start_link, [&job/0]}})

  defp enqueue_loader_job(), do: Process.send_after(self(), :start_loader_job, :timer.hours(1))

  defp job() do
    File.write!(
      db_file("country.mmdb"),
      "http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz"
      |> HTTPoison.get!()
      |> Map.fetch!(:body)
      |> mmdb!()
    )

    load_db()
  end

  defp load_db() do
    Geolix.load_database(%{
      id: :country,
      adapter: Geolix.Adapter.MMDB2,
      source: db_file("country.mmdb")
    })
  end

  defp mmdb!(tarball_data) do
    {:ok, files} = :erl_tar.extract({:binary, tarball_data}, [:compressed, :memory])

    files
    |> Stream.filter(fn {name, _content} -> name |> to_string() |> String.ends_with?(".mmdb") end)
    |> Stream.map(fn {_name, content} -> content end)
    |> Enum.take(1)
    |> hd()
  end

  defp db_path(), do: Path.join(Application.app_dir(:erlangelist, "priv"), "geo_db")

  defp db_file(name), do: Path.join(db_path(), name)
end
