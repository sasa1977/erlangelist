defmodule Erlangelist.Core do
  use Boundary, exports: [Article]
  use Parent.Supervisor

  alias Erlangelist.Core.{Backup, UsageStats}

  def start_link(_) do
    Parent.Supervisor.start_link(
      [
        UsageStats,
        {Phoenix.PubSub, name: Erlangelist.Core.PubSub}
      ],
      name: __MODULE__
    )
  end

  def clean do
    Enum.each(
      [
        backup_folder(),
        Path.join(Application.app_dir(:erlangelist, "priv"), "db")
      ],
      &File.rm_rf/1
    )
  end

  def backup_folder, do: Backup.folder()
end
