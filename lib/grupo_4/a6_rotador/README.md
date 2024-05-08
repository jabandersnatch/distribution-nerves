# A6

## Image Rotator

Para correr el rotador de imagenes, corremos la funcion `ImageRotator.rotate_image/4`, donde:

- el primer parametro es la ruta de la imagen a rotar (debe ser png con 3 bandas de color, como ejemplo esta el archivo "./cat.png"),
- el segundo parametro es la ruta de la imagen de salida,
- el tercer parametro es el angulo de rotacion (en radianes),
- y el cuarto parametro es cuantas divisiones queremos hacerle a la imagen, donde cada division se corre en paralelo.

Tambien se puede correr `ImageRotatore.test_all/0` para correr una prueba que rota la imagen "./cat.png" con diferentes cantidades de divisiones.

## Installation

Instalar dependencias con `mix deps.get`. Luego, correr `iex -S mix` para abrir la consola de Elixir con el proyecto cargado.
