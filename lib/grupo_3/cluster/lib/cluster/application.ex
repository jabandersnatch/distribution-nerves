defmodule Cluster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cluster.Supervisor]

    children =
      [
        {Cluster.NodeCluster, :ok},
        {Data.FolderConfig, :ok},
        {Cluster.LoadBalancer, 0},
        {Cluster.Variable, []},
        {Mutex, name: MyMutexConnect, meta: "some_data"},
        # Children for all targets
        # Starts a worker by calling: Cluster.Worker.start_link(arg)
        # {Cluster.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Cluster.Worker.start_link(arg)
      # {Cluster.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Cluster.Worker.start_link(arg)
      # {Cluster.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:cluster, :target)
  end
end
