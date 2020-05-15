defmodule Erlangelist.Backup do
  require Logger

  def folder(), do: Erlangelist.priv_path("backup")

  def resync(folder) do
    File.mkdir_p!(folder())

    if File.exists?(folder),
      do: backup(folder),
      else: restore(folder)
  end

  def backup(source_folder) do
    tmp_backup_path = create_tmp_backup(source_folder)
    backup_target = Path.join(folder(), Path.basename(tmp_backup_path))

    File.cp!(tmp_backup_path, backup_target)
    File.rm!(tmp_backup_path)
  end

  defp restore(folder) do
    backup_path = Path.join(folder(), "#{Path.basename(folder)}.tgz")

    if File.exists?(backup_path) do
      Logger.info("restoring #{backup_path}")
      :erl_tar.extract(to_charlist(backup_path), [:compressed, cwd: to_char_list(File.cwd!())])
    end
  end

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
end
