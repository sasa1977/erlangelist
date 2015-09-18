defmodule Erlangelist.Repo do
  use Ecto.Repo, otp_app: :erlangelist

  defoverridable start_link: 0, start_link: 1
  def start_link(opts \\ []) do
    result = super(opts)

    Ecto.Migrator.run(
      __MODULE__,
      Application.app_dir(:erlangelist, "priv/repo/migrations"),
      :up,
      all: true
    )

    result
  end
end
