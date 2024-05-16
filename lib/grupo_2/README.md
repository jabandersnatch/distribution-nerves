# Grupo 2

Esteban Gonzalez Ruales: 202021225

Juan Diego Yepes: 202022391

Felipe Nuñez: 202021673

For our parallelism project we had to connect multiple RaspberryPis so that we can execute a variety of tasks in parallel taking advantage of the amount nodes and cores that each RaspberryPi adds to the system. First we will explain the installation process and then we will explain the cluster creation process.

# Installation Process

First we will execute all the necessary commands to install everything needed to flash the MicroSD cards that go on the devices.

With the following commands Nerves and dependencies are installed.

```zsh
brew install fwup squashfs coreutils xz pkg-config
mix archive.install hex nerves_bootstrap
# replace yes
```

Since it is necessary to flash the MicroSD cards an ssh key is created and added to the current terminal session.

```zsh
ssh-keygen -b 4096 -t rsa
# default dir
# overwrite yes
# no pass
ssh-add
```

Having done the previous steps we can go ahead and create the nerves project where all the code we write will go. This step is done for illustration purposes since we already have the project created with all the code.

```zsh
# don't install dependencies
mix nerves.new parallelism

cd parallelism
```

Once you have created the project and placed all the code inside it you need to installed it inside of the Raspberry Pi. You can do that by running the following commands inside of the project directory and having a MicroSD card connected to your computer.

```zsh
export MIX_TARGET=rpi4

mix deps.get

# mix firmware.gen.script
# ./upload.sh
# mix upload nerves.local

mix firmware

mix burn
```

Having burned the project to the MicroSD card you are ready to start a node in a Raspberry Pi.

# Execution

You first need to place the MicroSD into the Raspberry Pi and connect to it from a terminal on which you can run commands. Following that, run the following commands.

```zsh
ssh nerves.local
# follow the instructions of the terminal so that you can connect successfully

System.cmd("epmd", ["-daemon"])

# connect to wifi
VintageNetWiFi.quick_configure("<username>", "<password>")

# wait for connection until an address appears in wlan0
:inet.getifaddrs

# start node with a username and the ip from previous step on wlan0
Node.start(:"<username>@<ip>")

# set cookie, needs to be the same for all devices to connect
Node.set_cookie(:<cookie_name>)

# Connect to main node with its user and ip
Node.connect(:"<main_node_name>@<ip_of_main_node>")
```

If you don't already have a main node running you can do it with the following instructions

```zsh
System.cmd("epmd", ["-daemon"])

# wait for connection until an address appears in en0
:inet.getifaddrs

# start the node
Node.start(:"<main_node_name>@<ip_where_main_node_is>")

# set cookie, needs to be the same for all devices to connect
Node.set_cookie(:<cookie_name>)
```

With these instructions, you can now create as many nodes as you like and connect them to the main node. From the main node, the tasks are executed and parallelized towards the worker nodes (Raspberry Pis). The instructions on how to run the tasks can be found inside of our project's explanation PDF on the "ejercicios parallelismo" assignement on Bloque Neon.

Other functions

```zsh
# can view node list
Node.list

# can look cookie with coomand
Node.get_cookie

# can stop node with command
Node.stop
```

```zsh
System.cmd("epmd", ["-daemon"])
:inet.getifaddrs
Node.start(:"main@172.20.10.2")
Node.set_cookie(:esteban)
Node.connect(:"local@157.253.120.69")
Node.connect(:"raspi@157.253.120.69")

System.cmd("epmd", ["-daemon"])
:inet.getifaddrs
Node.start(:"local@157.253.120.69")
Node.set_cookie(:esteban)
Node.connect(:"main@172.20.10.2")

System.cmd("epmd", ["-daemon"])
:inet.getifaddrs
Node.start(:"other@157.253.120.69")
Node.set_cookie(:esteban)
Node.connect(:"main@172.20.10.2")

System.cmd("epmd", ["-daemon"])
VintageNetWiFi.quick_configure("user", "pass")
:inet.getifaddrs
Node.start(:"raspi@172.20.10.7")
Node.set_cookie(:esteban)
Node.connect(:"main@172.20.10.2")
```
