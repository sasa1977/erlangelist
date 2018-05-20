defmodule Erlangelist.Backup do
  def resync() do
    File.mkdir_p!(backup_folder())
    backup_existing()
    restore_missing()
  end

  def backup(source_folder) do
    tmp_backup_path = create_tmp_backup(source_folder)
    backup_target = Path.join(backup_folder(), Path.basename(tmp_backup_path))

    File.cp!(tmp_backup_path, backup_target)
    File.rm!(tmp_backup_path)
  end

  defp backup_existing() do
    [ErlangelistWeb.Site.cert_folder(), Erlangelist.UsageStats.folder()]
    |> Stream.filter(&File.exists?/1)
    |> Enum.each(&backup/1)
  end

  defp restore_missing() do
    backup_folder()
    |> File.ls!()
    |> Stream.filter(&(Path.extname(&1) == ".tgz"))
    |> Stream.reject(&(&1 |> Path.basename(".tgz") |> Erlangelist.db_path() |> File.exists?()))
    |> Enum.each(&restore/1)
  end

  defp restore(backup), do: :erl_tar.extract(to_charlist(Path.join(backup_folder(), backup)), [:compressed])

  defp create_tmp_backup(source_folder) do
    File.mkdir_p!(tmp_folder())
    name = Path.basename(source_folder)
    source = Path.relative_to(source_folder, File.cwd!())
    target = Path.join(tmp_folder(), "#{name}.tgz")
    if File.exists?(target), do: File.rm!(target)
    :erl_tar.create(to_charlist(target), [to_charlist(source)], [:compressed])
    target
  end

  defp tmp_folder(), do: Erlangelist.priv_path("tmp")
  defp backup_folder(), do: Erlangelist.priv_path("backup")
end
