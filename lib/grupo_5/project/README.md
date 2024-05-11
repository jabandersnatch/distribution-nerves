
# Proyecto 1 - Paralelismo
## Jonathan Obed Cabanzo Certuche - 201911749 - jo.cabanzo
## Luis Sebastian Bautista Patarroyo - 202010190 - l.bautistap

### Configuración previa para realizar prueba local
    Para probar la ejecución se deben seguir los siguientes pasos:
    
    1. Iniciar las dos consolas necesarias para simular los nodos desde la carpeta del proyecto mix (el test reconocerá unicamente 2 nodos, excluyendo el nodo actual, por lo tanto se tendran 3 consolas: una principal y 2 nodos)
    2. Ejecutar las siguientes lineas de comandos en cada consola:
        Mix.install([:ex_png])
        c "lib/com_nerves.ex"
        Node.start :"node_0@127.0.0.1" # En la segunda consola se debe cambiar el nombre del nodo a "node_1"
    3. En la consola principal ejecutar la siguientes lineas de comandos:
        Mix.install([:ex_png])
        c "lib/com_nerves.ex"
        ComNerves.test # Se debe esperar a que el proceso termine para ver los resultados

    Nota: El test está configurado para ejecutar el ejercicio 1, si se desea probar el ejercicio 2 se debe cambiar la variable data_ex1 por data_ex2 en la función test del modulo ComNerves (Descomentar las lineas 7 y 8, y comentar las lineas 5 y 6) y realizar los pasos anteriores nuevamente.

### Configuración previa para realizar la prueba en un numero n de RPI
    Para probar la ejecución en la Raspberry Pi se deben seguir los siguientes pasos:
    
    1. Cambiar el codigo de la funcion connect_children en el modulo ComNerves, para que se conecte con los nodos hijos especificos de la red local. (Se debe cambiar la lista de nodos hijos en la linea 70)
    2. Crear la imagen del proyecto nerves con el comando mix firmware
    3. En cada RPI se deben seguir los siguientes pasos:
      1. Flashear la imagen del proyecto nerves en la Raspberry Pi
      2. Conectar la Raspberry Pi a la red local, mediante un cable ethernet o wifi
      3. Iniciar la consola de la Raspberry Pi (comando ssh nerves.local)
      4. Ejecutar las siguientes lineas de comandos en la consola de la Raspberry Pi:
          Mix.install([:ex_png])
          Node.start :"nombre_del_nodo@192.168.0.1." # Se debe cambiar el nombre del nodo por uno especifico y unico y la direccion ip por la de la red local
    4. En la consola principal ejecutar la siguientes lineas de comandos:
          ComNerves.test # Se debe esperar a que el proceso termine para ver los resultados


## Módulo ComNerves

Este módulo contiene funciones para configurar y ejecutar un sistema de procesamiento paralelo y distribuido. Utiliza características de Elixir como nodos, procesos y mensajes para distribuir tareas y recopilar resultados. Los datos se dividen entre la cantidad de nodos disponibles y la cantidad de procesos disponibles en cada nodo, es decir, en total se dividen los datos en nodos * procesos, para que cada uno de estos procese una parte de los datos en paralelo.


###  Función test
    Después de configurar el nodo actual (Iniciar el nodo principal) con configure/1, esta función prepara y ejecuta un ejemplo de cómo usar el sistema de procesamiento distribuido. Utiliza dos conjuntos de datos de ejemplo, data_ex1 y data_ex2, aunque sólo data_ex1 es realmente utilizado en este caso (A menos que se cambie). 
    Inicia el clúster de procesamiento distribuido con start_cluster usando el segundo conjunto de datos y funciones específicas pasadas como argumentos. Estas funciones son responsables de dividir los datos (e2_split_function), procesar los datos (e2_function) y fusionar los resultados (e2_merge_function). Note que estas funciones se definen dentro de los modulos de cada ejercicio (Ejercicio 1 y Ejercicio 2), por ello se pasan como parametro al cluster, para que este pueda ejecutarlas.

->  Función configure
    Configura el nodo actual para ser identificado en la red con una dirección específica. Esto es necesario para la comunicación entre nodos en Elixir.

->  Función start_cluster
    Esta función es el corazón del sistema de procesamiento paralelo y distribuido. Conecta a los nodos hijos disponibles, calcula el número de trabajadores paralelos basado en los nodos conectados y la constante de paralelismo(3), divide los datos entre los nodos y finalmente ejecuta la función de procesamiento en cada nodo con su respectivo fragmento de datos.

->  Función start_head
    Inicia el proceso encargado de recopilar los resultados de todos los nodos trabajadores. Este proceso recibe mensajes con los resultados parciales y los almacena en un mapa hasta que todos los resultados han sido recopilados, momento en el cual se ejecuta la función de convergencia.

->  Función loop_head
    Este es el bucle de recepción de mensajes del proceso cabeza. Gestiona los mensajes entrantes que contienen resultados de los nodos trabajadores y ejecuta la función de convergencia una vez que todos los resultados han sido recibidos.

->  Función start_child
    Inicia un proceso en un nodo trabajador. Este proceso es responsable de ejecutar la función de procesamiento en un fragmento de datos y enviar los resultados de vuelta al proceso cabeza.

->  Función loop_child
    Este es el bucle de recepción de mensajes del proceso trabajador. Espera un mensaje para ejecutar la función de procesamiento y enviar el resultado de vuelta al proceso cabeza.

->  Función Privada connect_children
    Intenta conectar con los nodos hijos especificados en la lista. Retorna el número de nodos con los que se ha establecido conexión efectivamente.

## Módulo Exercise1
Este módulo contiene funciones para dividir un texto en fragmentos, contar la frecuencia de cada palabra en cada fragmento y combinar los resultados de todos los fragmentos. 

->  Función e1_function
      - Propósito: Contabiliza la frecuencia de cada palabra en un fragmento de texto dado.
      - Parámetros:
        > data: Una lista de cadenas (strings) donde cada elemento es una palabra del texto.
      - Comportamiento: La función normaliza cada palabra a minúsculas y elimina los caracteres de puntuación. Luego, actualiza un mapa acumulador con el recuento de cada palabra.
      - Retorno: Retorna un mapa donde las llaves son las palabras y los valores son las frecuencias de estas palabras en el fragmento de texto.

->  Función e1_split_function
    - Propósito: Divide el texto completo en fragmentos para su procesamiento paralelo.
    - Parámetros:
      > data: Una cadena de texto (string) que contiene el texto completo.
      > workers: El número de trabajadores o procesos paralelos disponibles para procesar el texto.
    - Comportamiento: Divide el texto en palabras utilizando espacios, saltos de línea y tabulaciones como delimitadores. Luego, divide la lista de palabras en sub-listas de aproximadamente igual tamaño, basado en el número de trabajadores.
    - Retorno: Retorna una lista de listas, donde cada sub-lista contiene un fragmento del texto para ser procesado por un trabajador.
    
->  Función e1_merge_function
    Propósito: Combina los resultados parciales de cada trabajador en un resultado final.
    Parámetros:
    map: Un mapa donde las llaves son índices de nodos trabajadores y los valores son los mapas resultantes de e1_function.
    childs: Una lista de llaves (índices) de los nodos trabajadores que han completado su tarea.
    Comportamiento: Utiliza la función merge para combinar los mapas de frecuencia de palabras de cada trabajador en un solo mapa final. Imprime el resultado final en la consola.
    Retorno: No retorna un valor, pero como efecto secundario, imprime el mapa de frecuencias combinado en la consola.
    
    ->  Función merge (sobrecargada)
        - Propósito: Funciones auxiliares para combinar los mapas de frecuencias de palabras.
        Comportamiento y Parámetros:
        La primera variante toma un mapa general, una lista de llaves (childs), y un mapa acumulador (r) como parámetros. Combina el mapa de un trabajador (identificado por la cabeza de childs) con el mapa acumulador utilizando Map.merge, sumando los valores de frecuencias coincidentes, y recursivamente procesa el resto de trabajadores.
        La segunda variante es un caso base que simplemente retorna el mapa acumulador cuando la lista de childs está vacía.
        Retorno: Retorna un mapa combinado con las frecuencias de palabras de todos los fragmentos.

## Módulo Exercise2
Este módulo realiza el procesamiento de imágenes, específicamente la rotación de imágenes, con un enfoque en el procesamiento paralelo.



->  Función e2_split_function
    - Propósito: Divide la tarea de rotación en partes para ser procesadas en paralelo.
    - Parámetros:
      > {image, angle}: Una tupla conteniendo la imagen a rotar y el ángulo de rotación.
      > workers: Número de trabajadores o procesos paralelos.
    - Retorno: Una lista de tuplas, cada una representando una "tarea" para un trabajador, incluyendo la porción de la imagen a procesar.

->  Función e2_function
    - Propósito: Realiza la rotación de una porción específica de la imagen.
    - Parámetros: Una tupla que contiene:
      > i: Índice del trabajador.
      > package_init y package_end: Inicio y fin de la porción de la imagen a procesar.
      > new_image: Imagen nueva (vacía) donde se dibujará la porción rotada.
      > Otros parámetros necesarios para la rotación.
    - Retorno: Una tupla actualizada con la imagen procesada.

->  Función e2_merge_function
    - Propósito: Combina las imágenes procesadas por cada trabajador en una imagen final.
    - Parámetros:
      > images_map: Mapa con los resultados de cada trabajador.
      > _: Ignorado, permite pasar argumentos adicionales si es necesario.
    - Comportamiento: Combina las porciones de imagen procesadas en una imagen final y guarda el resultado.
    
->  FUNCIONES AUXILIARES

    ->  Función load_image
          - Propósito: Carga una imagen desde un archivo.
          - Parámetros:
            > path: Ruta del archivo de la imagen.
          - Retorno: La imagen cargada como una estructura de datos de ExPng.Image.
    ->  Función grados_a_radianes
          - Propósito: Convierte grados a radianes para la rotación de imágenes.
          - Parámetros:
            > grados: Ángulo en grados.
          - Retorno: El ángulo convertido a radianes.
    ->  Función additional_values
          - Propósito: Calcula valores adicionales necesarios para la rotación de la imagen.
          - Parámetros:
            > width: Ancho original de la imagen.
            > height: Alto original de la imagen.
            > angle: Ángulo de rotación en grados.
          - Retorno: Una tupla con el nuevo ancho, nuevo alto, ancho adicional, y alto adicional de la imagen rotada.
    ->  Función saveImage
            - Propósito: Guarda la imagen resultante en un archivo.
            - Parámetros:
              > image: La imagen a guardar.
            - Comportamiento: Convierte la imagen a datos brutos y los guarda en un archivo PNG.
