# Grupo 6

Diego Higera
Andrés Florián
Nicolás Londoño

## Entrega Proyecto 1

Instrucciones de ejecución.

1. Flashear la imagen de este repositorio a los RasPi y conectarse
2. En cada instancia de IEx correr:
```
cmd("epmd", ["-daemon"])

Node.start(:"user@targetX.local")

Node.set_cookie(:cookie)
```
3. Conectar los nodos entre sí usando las direcciones con el comando
```
Node.connect(:"user@targetX.local")
```
4. Correr las funciones en cualquier nodo con la función ```Node.spawn()```

Para el conteo de palabras, los archivos deben estar flasheados mediante ponerlos en el directorio /priv