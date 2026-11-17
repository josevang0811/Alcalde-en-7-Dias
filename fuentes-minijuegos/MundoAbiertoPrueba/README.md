# MundoAbiertoPrueba

La ciudad del mundo abierto de Alcalde Digital y sus dos eventos en el parque: la **ronda de volantes** y la **ronda de convencer a la gente**. En la prueba se escoge cuál jugar con **1** (volantes) o **2** (gente) antes de la ronda o en la pantalla final.

**Teclas:** WASD o flechas para caminar, Shift para correr, E para subirte o bajarte de un carro (en el paseo) y para pegar o convencer rápido (en la ronda), F para asegurar, Q para lanzar una botella, M para el mapa, C para ver por dónde no se puede pasar.

## La ronda de volantes

1. **Ir al parque.** El candidato sale de su sede de campaña. Arriba sale el objetivo y una flecha con los metros que faltan apunta al centro del parque. Los otros tres candidatos (Morales, Rincón y Pérez, manejados por el computador) salen de Titulares Ya, el mercado y el colegio y también caminan hasta allá.
2. **Reunión.** Cuando están los cuatro en la plaza de la fuente hay una cuenta de 3 segundos.
3. **Ronda de 60 segundos.** Nadie puede salir del parque y sus calles (línea punteada amarilla). Hay 16 carteleras: 6 en el parque y 10 en los andenes de enfrente, cada una con su anillo en el piso. Se pega con E: si el volante es de otro, se tapa y el punto pasa a ser tuyo. La lista de la esquina se reordena en vivo.
4. **Botellas.** Cada uno tiene 3 y las lanza cuando quiere (Q, hacia donde mira; si hay un rival más o menos en esa dirección, la botella se le apunta). Al que le pegan se queda quieto 2 segundos y pierde lo que llevaba pegando.
5. **Final.** Sale la lista con el apoyo de cada puesto: +20, +10, 0, −5. R repite solo la ronda.
6. **Vuelta.** Con Enter el candidato vuelve a su sede, a pie o en carro, siguiendo la flecha hasta el círculo del parqueadero. Al llegar entra a la oficina (en la prueba, todo empieza otra vez). En red no hay vuelta: Enter lleva directo a la oficina.

## La ronda de convencer a la gente

Igual que la de volantes (se sale de la sede, reunión en la plaza, cuenta, 60 segundos, botellas y premios), pero en vez de carteleras hay **20 ciudadanos** paseando por el parque y sus calles. Cada uno lleva un anillo: punteado si nadie lo tiene, claro si es de alguien por la vía rápida, fuerte y con candado si está asegurado.

- **Rápida:** E a su lado. Queda tuyo, pero cualquiera te lo puede quitar igual.
- **Segura:** F a su lado (no hay que mantenerla). Arriba salen 4 flechas que hay que marcar en orden (flechas o WASD); mientras tanto el candidato no camina. Si se completan, queda asegurado y nadie lo cambia. Un error vuelve a empezar la secuencia con flechas nuevas; F otra vez la deja y un botellazo la corta.
- **El ciudadano** se queda quieto mientras alguien le hace la secuencia, y nadie más puede convencerlo en ese momento.
- **Bots:** si están solos usan la forma segura (marcan las flechas a su ritmo y a veces se equivocan); si hay rivales cerca van por la rápida. Les gusta quitarle al que va ganando los que no tiene asegurados, y le lanzan botellas sobre todo al que está haciendo una secuencia.

**Estructuras usadas:** la secuencia de flechas es una cola (`ArrayDeque`), que se va sacando en orden; dos HashMap guardan la secuencia de cada candidato y con quién la está haciendo. Los ciudadanos pasean con rutas BFS.

## Los bots

- **Cómo llegan:** antes de la ronda caminan hasta su puesto alrededor de la fuente con una ruta BFS por toda la ciudad.
- **Qué punto escogen:** el que les cueste menos. El costo es lo que hay que caminar, más barato si el punto está libre o si es del que va ganando, y más caro si otro bot ya va para allá. Lo vuelven a pensar cada 3 a 5 segundos.
- **Pegar:** tienen una pequeña reacción antes de pegar.
- **Botellas:** cada medio segundo miran si alguien les queda a tiro y con línea libre, y a veces lanzan. Lanzan más si el otro está pegando. Apuntan a donde va a estar el blanco, con un error según la dificultad (`dificultad` en `Bots.pde`: FACIL o NORMAL).
- **Si se traban:** recalculan la ruta.

**Estructuras usadas:** un HashMap de punto a dueño, BFS con cola (`ArrayDeque`) y un arreglo de "de dónde vengo" para reconstruir el camino, y ordenamiento por inserción para la lista en vivo y para el orden de dibujo de lo que se mueve.

## Carros y tráfico

- **Manejar:** cualquier carro se puede manejar, sea el azul de la campaña, uno estacionado o uno que va pasando. En el paseo, E al lado de un carro para subirte. W acelera, S frena (o va en reversa) y A y D giran. E otra vez para bajarte: el carro se queda donde lo dejes. El carro choca con edificios y otros carros, y no entra al parque, al malecón ni al río. Durante un evento no se puede subir a carros.
- **Tráfico:** 14 carros andan solos por un **grafo de carriles**.
  - Cada vía tiene un carril por sentido.
  - Un tramo es una recta entre dos cruces o una curva dentro de un cruce: de frente, a la derecha o a la izquierda.
  - Al terminar un tramo, el carro escoge al azar uno de los siguientes.
  - En los bordes de la ciudad dan la vuelta en U.
- **Semáforos:** cada cruce tiene el suyo. Hay 6,5 s de verde para un eje, 1,5 s de amarillo y luego el otro eje; cada cruce va desfasado y la luz que toca se prende en el dibujo del semáforo.
- **Frenar:** los carros paran en rojo y frenan si hay otro carro o una persona adelante. Si llevan más de 5 s trabados por otro carro, se destraban.
- **Personas:** chocan con los carros, pero si alguien se queda trabado más de un segundo, pasa.
- **Los dibujos de los carros:** 8 colores (uno es el taxi) en 8 direcciones. Salen de `herramientas/gen_carros.py`, que se llama solo al generar la ciudad.

## La ciudad

El candidato puede caminar por toda la ciudad. La cámara lo sigue, y choca con edificios, árboles, bancas, postes, carros y el río. Cuando entra a otra zona aparece su nombre.

108 × 104 baldosas en vista isométrica (una baldosa es un rombo de 32 × 16 pixeles, igual que en Infiltrado). Nueve manzanas con el parque en el centro:

| | | |
|---|---|---|
| Titulares Ya | Barrio residencial | Mercado |
| Zona comercial | Parque central | Colegio |
| Sede de campaña | Lote en obra (libre) | Gasolinera |

A un lado va el río con el malecón. Todas las vías tienen dos carriles, con cebras y semáforos. El lote en obra queda libre para lo que se agregue después.

## Cómo está hecha

- `Ciudad.pde`: carga la ciudad, la dibuja y dice dónde se puede caminar.
  - El piso viene en trozos de 512 px y solo se dibujan los que se ven.
  - Cada objeto (edificio, árbol, banca...) es su propio dibujo con su "huella" en el piso. Con la huella se sabe si el candidato está delante o detrás del objeto, y lo alto que lo tapa se vuelve transparente.
  - Los choques son una cuadrícula de un cuarto de baldosa (`choques.png`, blanco = no se pasa).
  - Las zonas son una imagen de una baldosa por pixel, donde el valor del pixel es el número de la zona (`zonas.png` y `zonas.txt`).
- `Candidato.pde`: los cuatro candidatos (el jugador y los bots caminan y chocan igual) y el teclado.
- `Ronda.pde`: los pasos del evento (paseo, reunión, cuenta, ronda, final).
- `Volantes.pde`: las carteleras, de quién es cada una, el puntaje de cada evento y la lista en vivo.
- `Gente.pde`: los ciudadanos, las dos formas de convencer y la secuencia de flechas.
- `Botellas.pde`: las botellas, los papelitos y los textos que suben.
- `Bots.pde`: cómo piensan los rivales en cada evento.
- `Carros.pde`: el grafo de carriles, los semáforos, el tráfico y manejar.
- `Hud.pde`: objetivo, flecha, reloj, lista, avisos, pantalla final y mapa.
- `Lives.pde`: la ronda de los lives.
  - Salen 6 cúmulos al azar por toda la ciudad, fuera del parque y lejos unos de otros. Cada uno tiene a alguien transmitiendo en vivo (letrero rojo LIVE) y 4 personas mirando.
  - Se reclama con F o E junto al que transmite, marcando 6 flechas. Cada live es un punto y ya nadie lo cambia.
  - Termina cuando no queda ninguno libre o a los 120 s. Se puede manejar durante la ronda, y la flecha apunta al live libre más cercano.
  - Los bots caminan hasta el live que más les conviene y marcan las flechas con su ritmo.
  - Reutiliza la cola de flechas y los ciudadanos de `Gente.pde`. En la prueba se escoge con la tecla 3.
- `SonidosMundo.pde`: los efectos de sonido. Son WAV de 8 bits en `data/sfx_mundo/`, hechos con `herramientas/gen_sonidos.py`: pasos, lanzar, vidrio, golpe, volante, convencer, asegurado, flechas, cuenta, salida, silbato y puerta. Lo que pasa lejos del candidato suena más bajo.
- `EnLinea.pde`: los eventos en red.
  - El anfitrión simula y arma la foto del estado (`estadoRed`).
  - El invitado la copia y acerca todo suavemente (`aplicarEstado` y `seguirFoto`).
  - Cada asiento tiene sus teclas.
  - Quien manda los mensajes es el juego principal (`Red.pde`). En esta prueba la red está apagada.

## Cambiar la ciudad

Todo lo que está en `data/mundo/` lo arma `herramientas/gen_ciudad.py` (Python 3 con numpy y Pillow). Ahí está el trazado de calles y manzanas, qué va en cada manzana y cómo se dibuja cada objeto. Para volver a generarla:

```
DATOS_MUNDO=data/mundo python3 herramientas/gen_ciudad.py ../InfiltradoPrueba/data . ../AlcaldeDigitalNuevo/Diseno.pde
```

El primer dato es la carpeta con los dibujos de las personas, el segundo dónde guardar las imágenes de muestra y el tercero de dónde sacar la fuente de letras del juego.

Los colores de los ciudadanos salen de `herramientas/gen_ciudadanos.py`, que toma los dibujos de las personas de Infiltrado y les cambia la camisa, la piel, el pelo y el pantalón (8 variantes).
