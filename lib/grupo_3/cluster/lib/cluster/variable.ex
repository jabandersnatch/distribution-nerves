defmodule Cluster.Variable do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> {:crypto.hash(:sha, initial_value), initial_value} end,
      name: __MODULE__
    )
  end

  def get_sha do
    manage_value({:get_sha, []})
  end

  def get_value do
    Agent.get(__MODULE__, fn {_, value} -> value end)
  end

  def save_new_value(value) do
    manage_value({:save, value})
  end

  defp manage_value({action, value}) when is_list(value) do
    resource_id = {User, {:id, 2}}
    lock = Mutex.await(MyMutexConnect, resource_id)

    result =
      case {action, value} do
        {:save, value} ->
          Agent.update(__MODULE__, fn _ -> {:crypto.hash(:sha, value), value} end)

        {:get_sha, _} ->
          Agent.get(__MODULE__, fn {sha, _} -> sha end)
      end

    Mutex.release(MyMutexConnect, lock)
    result
  end
end
