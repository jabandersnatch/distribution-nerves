INSTRUCCIONES DE EJECUCÍON:

1. Inicie los nodos establecidos para el ejercicio, en cada uno de ellos navegue hasta la ruta de la carpeta del proyecto mix
2. En cada nodo, ejecuté el proyecto mix con un nombre diferente conservando el mismo nombre de cookie (ej. "iex --sname server@localhost --cookie secret_cookie -S mix") --> se debe cambiar el SNAME en cada nodo (ej. "iex --sname client@localhost --cookie secret_cookie -S mix")
3. Conecte cada nodo al nodo principal con el comando "Node.connect(:"server@localhost")"
4. En el nodo principal, ejecute el comando: "{:ok, _pid} = ContadorPalabras.Coordinador.start_link(name: :coordinador)"
5. En el nodo principal, ejecute el comando: "ContadorPalabras.Coordinador.iniciar_contador_desde_archivo("C:/Users/DELL/Elixir/a6_contador/Colombia.txt")". Asegúrese que la ruta del archivo corresponda al archivo .txt de nombre "Colombia", ubicado dentro de la carpeta del proyecto mix