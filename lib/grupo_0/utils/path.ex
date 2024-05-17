defmodule Grupo0.Utils.Path do
  def get_path(relative_path) do
    Path.join(Application.app_dir(:distribution_nerves, "priv"), relative_path)
  end
end
