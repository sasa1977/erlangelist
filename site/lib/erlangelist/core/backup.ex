defmodule Erlangelist.Core.Backup do
  use Boundary
  require Logger

  def resync(folder) do
    File.mkdir_p!(backup_folder())

    if File.exists?(folder),
      do: backup(folder),
      else: restore(folder)
  end

  def backup(source_folder) do
    tmp_backup_path = create_tmp_backup(source_folder)
    backup_target = Path.join(backup_folder(), Path.basename(tmp_backup_path))

    File.cp!(tmp_backup_path, backup_target)
    File.rm!(tmp_backup_path)
  end

  defp restore(folder) do
    backup_path = Path.join(backup_folder(), "#{Path.basename(folder)}.tgz")

    if File.exists?(backup_path) do
      Logger.info("restoring #{backup_path}")
      :erl_tar.extract(to_charlist(backup_path), [:compressed, cwd: to_char_list(File.cwd!())])
    end
  end

  defp create_tmp_backup(source_folder) do
    File.mkdir_p!(tmp_backup_folder())
    name = Path.basename(source_folder)
    source = Path.relative_to(source_folder, File.cwd!())
    target = Path.join(tmp_backup_folder(), "#{name}.tgz")
    if File.exists?(target), do: File.rm!(target)
    :erl_tar.create(to_charlist(target), [to_charlist(source)], [:compressed])
    target
  end

  def backup_folder, do: Erlangelist.Config.backup_folder()
  defp tmp_backup_folder(), do: backup_folder() |> Path.dirname() |> Path.join("tmp")
end
