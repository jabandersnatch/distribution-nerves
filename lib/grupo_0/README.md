### README: Running Distributed Code with Elixir

This document provides instructions on how to execute the distributed Elixir code for processing data using various tasks defined in the modules `Task1` and `Task2`.

#### Prerequisites

- Elixir 1.9 or higher
- Erlang/OTP 22 or higher
- A configured mix project if you plan to use dependencies such as `Nx`

#### Setup

1. **Clone the Repository**:
   Clone the code repository to your local machine or ensure your code is placed in an appropriate directory structure in your existing project.
   Repository url: `https://github.com/jabandersnatch/distribution-nerves`

2. **Install Dependencies** (if any):
   Run `mix deps.get` in the terminal at the root of your project to install any necessary dependencies specified in your `mix.exs` file.

## How to Start the Nodes

### Running on PC

To start a node on your PC, use the following command:

```bash
iex --name {name}@localhost -S mix
```

Replace `{name}` with the desired name of your node. You can start as many nodes as you want, just change the name of each node.

### Running on Nerves (Raspberry Pi)

#### Configuration

1. Open the `config/target.ex` file.
2. Change the host name at line 78 to a unique name. If connecting to another Raspberry Pi, use a common naming convention like `grupo_0`, `grupo_1`, etc.

#### Wi-Fi Setup

If you want to connect via Wi-Fi, add the following configuration to the `config/target.ex` file:

```elixir
config :vintage_net,
  regulatory_domain: "00",
  additional_name_servers: [{127, 0, 0, 53}],
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0", %{
       type: VintageNetEthernet,
       ipv4: %{method: :dhcp}
     }},
    {"wlan0", %{
      type: VintageNetWiFi,
      ipv4: %{method: :dhcp},
      vintage_net_wifi: %{
        key_mgmt: :wpa_psk,
        psk: "{your_password}",
        ssid: "{your_ssid}"
      }
    }}
  ]

config :mdns_lite,
  # Your existing configuration
  dns_bridge_enabled: true,
  dns_bridge_ip: {127, 0, 0, 53},
  dns_bridge_port: 53,
  dns_bridge_recursive: true,
```

Replace `{your_password}` with your Wi-Fi password and `{your_ssid}` with your Wi-Fi network name.

#### Connecting via SSH

To connect to the Raspberry Pi via SSH, use the following command:

```bash
ssh {host_name}.local
```

Replace `{host_name}` with the name set in the `config/target.ex` file.

#### Starting the Node

Once connected to the Raspberry Pi via SSH, start the node with the following commands:

```elixir
System.cmd("epmd", ["-daemon"])
Node.start(:"{name}@{host_name}.local")
Node.set_cookie(:"{your_cookie}")
```

Replace `{name}` with the desired name of the node and `{your_cookie}` with the cookie set in the `config/target.ex` file.

#### Uploading Firmware

1. Export the target device:

```bash
export MIX_TARGET={target}
```

Replace `{target}` with your device, e.g., `rpi4`.

2. If uploading firmware for the first time, use:

```bash
mix firmware.burn
```

3. If the firmware is already on the Raspberry Pi, use:

```bash
mix upload {host_name}.local
```

Replace `{host_name}` with the name set in the `config/target.ex` file.

## Task 1

### Main Node

1. Set the path to the text file:

```elixir
text_path = Grupo0.Utils.Path.get_path('Words/FourWordsRepeatedLarge.txt')
text = Grupo0.Utils.LoadWords.read_file(text_path)
```

2. Spawn the main process:

```elixir
pid = spawn(fn -> Grupo0.Distribute.Distribute.actor(&Grupo0.Task1.Task1.count_para/1, &Grupo0.Task1.Task1.union_fun/2, &Grupo0.Task1.Task1.partition_fun/2, %{}, :some) end)
Process.register(pid, :some)
```

3. Start the task when all nodes are connected:

```elixir
Node.spawn(:"master@solomon", fn -> send(:some, {:start, text}) end)
```

### Other Nodes

1. Spawn the worker process:

```elixir
pid = spawn(fn -> Grupo0.Distribute.Distribute.actor(&Grupo0.Task1.Task1.count_para/1, &Grupo0.Task1.Task1.union_fun/2, &Grupo0.Task1.Task1.partition_fun/2, %{}, :some) end)
Process.register(pid, :some)
```

2. Connect to the main node:

```elixir
Node.connect(:"master@solomon")
```

## Task 2

### Main Node

1. Set the image path and process the image:

```elixir
img_path = Grupo0.Utils.Path.get_path('Images/arrow.png')
image = Grupo0.Utils.Imagineer.read_image(img_path)
flat = Grupo0.Task2.Task2.flatten_pixels(image.pixels)
matrix = Grupo0.Task2.Task2.prepare_tensor_data(flat, image.height, image.width)
angle = Math.pi/2
partition_fun = Grupo0.Task2.Task2.distribute_image(angle)
init_res = Nx.broadcast(0, {360, 360, 3})
union_fun = &Grupo0.Task2.Task2.join_images/2
out_img_path = Grupo0.Utils.Path.get_path('Images/arrow_parallel.png')
save_fun = Grupo0.Task2.Task2.matrix_to_image(image, out_img_path)
fun = Grupo0.Task2.Task2.parallel_rotate_image(2)
pid = spawn(fn -> Grupo0.Distribute.Distribute.actor(fun, union_fun, partition_fun, init_res, :some, save_fun) end)
Process.register(pid, :some)
```

2. Start the task when all nodes are connected:

```elixir
Node.spawn(:"master@solomon", fn -> send(:some, {:start, matrix}) end)
```

### Other Nodes

1. Spawn the worker process:

```elixir
partition_fun = nil
init_res = Nx.broadcast(0, {360, 360, 3})
union_fun = &Grupo0.Task2.Task2.join_images/2
out_img_path = Grupo0.Utils.Path.get_path('Images/arrow_parallel.png')
save_fun = nil
fun = Grupo0.Task2.Task2.parallel_rotate_image(2)
pid = spawn(fn -> Grupo0.Distribute.Distribute.actor(fun, union_fun, partition_fun, init_res, :some, save_fun) end)
Process.register(pid, :some)
```

2. Connect to the main node and start the task:

```elixir
Node.connect(:"master@solomon")
Node.spawn(:"master@solomon", fn -> send(:some, {:start, matrix}) end)
```

#### Monitoring Execution

You can monitor the processing in real-time through IEx sessions. Log statements and process monitoring will show how data is processed and merged back using the specified union function.

#### Troubleshooting

- Ensure all nodes are connected using `Node.list()` which should list all other nodes.
- Check console logs for any error messages or exceptions.
- Make sure Erlang cookies match if you face issues connecting nodes.
