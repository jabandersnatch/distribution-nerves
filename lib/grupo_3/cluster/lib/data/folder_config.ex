defmodule Data.FolderConfig do
  use GenServer

  def start_link(:ok) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    target = Application.get_env(:cluster, :target)

    if(target != :host) do
      origin_folder = :code.priv_dir(:cluster)
      target_folder = "/root/priv"
      target_output_folder = "/root/priv/output_images"
      File.rmdir(target_folder)
      File.mkdir(target_folder)
      File.mkdir(target_output_folder)

      case File.ls(origin_folder) do
        {:ok, file_list} -> copy_files(file_list, origin_folder, target_folder)
        {:error, reason} -> IO.inspect("Error to copy files #{reason}")
      end
    end

    {:ok, :any}
  end

  def copy_files(files_list, origin_folder, target_folder) do
    Enum.each(files_list, fn file ->
      file_absolute_path = "#{origin_folder}/#{file}"

      if File.dir?(file_absolute_path) do
        target_folder = "#{target_folder}/#{file}"
        File.rmdir(target_folder)
        File.mkdir(target_folder)

        copy_files(elem(File.ls(file_absolute_path), 1), file_absolute_path, target_folder)
      else
        origin = file_absolute_path
        target = "#{target_folder}/#{file}"
        File.cp(origin, target)
      end
    end)
  end
end
