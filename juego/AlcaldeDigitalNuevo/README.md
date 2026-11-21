# Alcalde Digital — Rediseño gráfico (AlcaldeDigitalNuevo)

Esta carpeta es una copia de `AlcaldeDigitalRediseno` con el **rediseño gráfico del equipo** (el prototipo `Oficina.html`). La lógica del juego no cambia: solo cambia cómo se ve.

- **Menú:** el cajón del escritorio con el periódico «Alcalde en 7 días» (Solo, Multijugador, Opciones, Salir). Con «Solo» la cámara baja del cajón a la oficina; con un clic en el cajón del escritorio se vuelve al menú. Multijugador y Opciones avisan que llegan después.
- **Oficina:** una sola imagen. Encima se dibujan el turno en el calendario, los titulares corriendo en la TV y el teléfono, que vibra cuando suena.
- **Al abrir un objeto,** la oficina cambia por su versión oscura (sin ese objeto) y el objeto sube desde abajo balanceándose; al cerrar, baja.
  - **Teléfono:** el auricular del dibujo sube a la derecha y el globo de la periodista queda a su lado.
  - **Celular:** el chat de Civitas va dentro del celular del dibujo. El mapa de papel tiene un post-it por barrio; las calles del grafo son hilos rojos entre los post-its, con sus minutos al pasar el mouse.
  - **Libro:** cada habilidad tiene su círculo en el árbol dibujado. En la hoja derecha están los puntos, la ficha y el costo, que es el botón para comprar. Un clic fuera del libro lo cierra.
  - **Televisor:** está siempre encendido en la oficina, con el noticiero en pequeño. El globo del presentador cambia cada 5 s entre el impacto del último turno, la gráfica de apoyo de los candidatos y el mapa de la partida. Con un clic la cámara se acerca hasta que el noticiero llena la pantalla (`Televisor.pde`). A la derecha va el reel del barrio jugado en el turno; abajo, la cinta con el @ de quien publicó la noticia. Los dibujos están en `data/tv/` y los prepara `herramientas/gen_tv.py`.
- **Rondas intercaladas (`Minijuegos.pde`):** las rondas 1, 3, 5 y 7 son de llamada y las 2, 4 y 6 de minijuego. Al empezar la campaña se barajan los minijuegos (Infiltrado, Volantes, Convencer a la gente y Lives) y se toman tres, sin repetir. En red, el anfitrión baraja y manda el orden.
- **Cómo termina un día (`Ronda.pde` y `Encargo.pde`):** cada día empieza con el encargo por teléfono: hay 10 s para decidir dónde va la noticia, y si no se alcanza el celular se autodestruye y se pierde apoyo. Cuando ya se jugó, aparece abajo a la derecha el botón rojo TERMINAR EL DÍA. Al tocarlo, una pantalla negra anuncia el día siguiente; al terminar la campaña salen los créditos. Para la exposición, F9 salta al final desde cualquier parte.
- **Las llamadas:** la noticia ya no viene de un periódico. La periodista la vio en una publicación de Civitas y cuenta quién la hizo (reportero verificado, usuario común o cuenta anónima, con su @), qué dicen los comentarios y si genera odio. Las tarjetas y el celular siguen igual (`Noticia.java`, `Noticiero.java`).
- **La misión Infiltrado (cuando le toca):** en vez de la periodista llama Valeria (la estratega de la campaña) y cuenta el bulo de Titulares Ya sobre el agua de El Puerto. Al colgar, la pantalla se oscurece y empieza la misión en el mismo programa (`Infiltrado.pde`). Ya no se elige habilidad: en el plano de la sede Valeria marca la ruta (servidor, copiar la información y salir por la camioneta) y el HUD solo muestra esos pasos. Las habilidades del árbol se vuelven herramientas de la misión. Al terminar (Enter en su pantalla final) se vuelve a la oficina: el apoyo en El Puerto cambia (+25 + botín + 5 por oportunidad, o −15), la ronda cuenta como la jugada del turno y la TV pasa la noticia. En esa ronda no se publica con el celular. Todo eso está en `MisionCampana.pde`.
- **Los minijuegos del mundo abierto (Volantes, Gente y Lives):** llama Valeria (etiqueta EVENTO). Valeria presenta el que tocó; Lives es por toda la ciudad, con cúmulos de gente al azar. Al colgar, el candidato aparece en el parqueadero de su sede, en la ciudad del mundo abierto (`MundoAbierto.pde`), camina al parque y juega 60 segundos contra Morales, Rincón y Pérez. Con Enter en la pantalla final vuelve caminando (o en carro) a su sede y, al entrar por el parqueadero, llega a la oficina. El puesto da apoyo: +20, +10, 0 o −5. Los empatados comparten puesto, y con 0 puntos no se gana nada.
  - **Si ganó apoyo:** vibra el celular, Nico escribe con la lista final del evento y el jugador escoge en el mapa el barrio, solo entre los que alcanza, igual que al publicar. El apoyo viaja por las calles como una publicación.
  - **Si quedó solo de último:** el −5 se resta en su barrio con más apoyo.
  - **El turno:** la ronda cuenta como la jugada, así que no se publica y el día se termina con el botón rojo. La TV pasa la noticia del evento.
  - **Dónde está el código:** todo esto está en `EventoParque.pde`.
- **Multijugador en red (opción «Multijugador» del cajón):** cada candidato juega en su PC. Hay que estar en la misma red; si no, se puede usar Radmin VPN o Tailscale.
  - **La sala:** uno escribe su nombre y crea la partida. Ese es el anfitrión, y la sala le muestra su IP. Los demás escriben su nombre y esa IP y se unen. Son 4 puestos, y los libres los juegan los bots. El anfitrión empieza la campaña y a todos les baja la cámara a la oficina en el turno 1.
  - **Los turnos:** cada uno juega su oficina. Al terminar el día queda esperando («1 de 2 listos») y el turno avanza cuando todos están listos. Con cada turno se manda el apoyo de cada barrio, y la TV pasa el sondeo.
  - **Los minijuegos del mundo abierto:** todos entran a la misma ciudad. El anfitrión simula todo (bots, gente, carros, botellas) y manda una foto del estado unas 15 veces por segundo. Los invitados mandan sus teclas y ven los efectos y avisos que les tocan. Si un invitado sigue en su oficina, no se le espera. Si alguien no llega a la plaza, se empieza a los 45 s. Si un invitado se queda sin fotos, puede volver con Enter.
  - **Las votaciones:** al terminar la campaña, los votos de cada uno son la suma de su apoyo. Cada barrio lo gana quien tenga más apoyo ahí (si hay empate, nadie). El que tiene más votos es el alcalde.
  - **El código:** está en `Red.pde`, con la librería `processing.net` de Processing y el puerto 5204. Del lado del parque, en `EnLinea.pde` de `MundoAbiertoPrueba`. Cada mensaje es una línea de texto, por ejemplo `HOLA nombre`, `LISTO turno apoyo`, `TABLA ...`, `TURNO n`, `IN teclas` o `ES foto`.
  - **Si alguien se desconecta:** su puesto queda libre y no se le espera. Si el que se va es el anfitrión, el invitado sigue solo.
- **`MundoAbierto.pde` tampoco se edita a mano:** es `MundoAbiertoPrueba` metido en una clase con `herramientas/fusionar.py`, el mismo script de Infiltrado.
- **`Infiltrado.pde` no se edita a mano:** es el sketch `InfiltradoPrueba` metido en una sola clase con `herramientas/fusionar.py` (para que sus variables no choquen con las del juego). Los cambios se hacen en `InfiltradoPrueba` y se vuelve a fusionar.
- **Archivos nuevos:** `Diseno.pde`, `MisionCampana.pde`, `Infiltrado.pde`, `EventoParque.pde`, `MundoAbierto.pde`, `Red.pde`, `Minijuegos.pde`, `Televisor.pde` (imágenes, letra pixel 5×7, menú, animaciones) y la carpeta `data/` con los dibujos del equipo.

---

# Alcalde Digital — Rediseño

Especificación de desarrollo para Claude Code.
Estructura de Datos II, Universidad del Norte.

Esta carpeta es una copia de la entrega 1 (la carpeta `AlcaldeDigital`, que queda intacta) donde se rediseña el juego a partir del guion gráfico del equipo. La oficina es el centro y cada ronda sigue el mismo orden: suena el teléfono con una noticia, se usa el celular, el televisor muestra el fin de la ronda, llega un evento al azar y al final se mejora el árbol de habilidades. Se construye un paso a la vez.

**Hecho hasta ahora:**

1. Lo de la entrega 1: la oficina como menú y el árbol de habilidades.
2. La llamada del periodista: al empezar cada turno suena el teléfono, la periodista cuenta una noticia de última hora y después se corta la llamada (ver «La llamada del periodista»).
3. El televisor muestra el grafo de la ciudad: solo vértices (las 8 zonas) y aristas (las 12 calles). La sede del candidato, La Colina, va en rojo con un círculo blanco; las demás zonas en gris. Por ahora hay un solo candidato. El grafo está en `GrafoCiudad.java` con una matriz de adyacencia de minutos (0 = no hay calle) y lo dibuja `dibujarGrafoTV()`: primero las calles, recorriendo solo la mitad de arriba de la matriz para no dibujar cada una dos veces, y encima las zonas. Con un clic en el televisor se abre en grande (`Mapa.pde`, estado `MAPA`): las zonas con su nombre, cada calle con sus minutos (el peso guardado en la matriz) y, al pasar el mouse por una zona, sus calles en amarillo y la lista de sus vecinas (la fila de esa zona en la matriz). Mientras suena el teléfono, el televisor también espera. Se vuelve con «← Oficina» o Esc.
4. El celular (Civitas) y el mapa para publicar: después de la llamada, el influencer Nico Viral escribe por el celular con la noticia y ofrece seis tarjetas. El jugador elige una y el barrio donde se publica; solo puede publicar en sus barrios y en los que tienen calle con ellos. La publicación viaja por el camino más corto (Dijkstra) y suma o resta apoyo en el barrio; con 50 de apoyo el barrio es suyo y la frontera crece (ver «El celular y el mapa»). La campaña ahora dura 7 turnos, como dice el periódico del menú del equipo.
5. La noticia hay que recordarla: la llamada ya no se puede adelantar ni colgar (se cierra sola) y Nico no repite la noticia en el chat; solo se vuelve a oír con la habilidad «Libreta de notas». Después de publicar, el chat sí muestra la noticia completa y qué era.
6. El árbol nuevo, con el dibujo del equipo como guía (ver «El árbol de habilidades» y «Cuaderno.pde»): tres ramas (Alcance, Credibilidad e IA), habilidades con efecto real al publicar, la tarjeta de IA funcionando, habilidades que solo se compran desde cierta ronda y puntos para el árbol según cómo le fue al candidato (2, 3 o 4).

**Lo que sigue, según el guion:** los rivales (tres candidatos máquina) con el bloqueo de tarjetas, el televisor con el fin de ronda (noticiero) y los puntos del árbol repartidos por ranking entre los candidatos.

---

## REGLAS DURAS — LEER ANTES DE ESCRIBIR CÓDIGO

### Regla 1: estos archivos y ninguno más

```
AlcaldeDigitalRediseno/
  AlcaldeDigitalRediseno.pde  sketch principal, máquina de estados, colores, fuentes y layout
  Interfaz.pde                Boton, ObjetoOficina, la oficina (menú), el cuaderno con el árbol y la ayuda
  Llamada.pde                 el teléfono que suena y la llamada del periodista
  Mapa.pde                    el televisor en grande: el grafo de la ciudad
  Celular.pde                 el celular: chat con el influencer, tarjetas, mapa y envío animado
  Cuaderno.pde                el cuaderno abierto: el árbol dibujado y la hoja con los puntos y la habilidad elegida
  Nodo.java                   nodo del árbol n-ario de habilidades
  ArbolHabilidades.java       el árbol y sus operaciones
  Partida.java                estado del juego: candidato, turno, puntos, noticia, tarjetas, apoyo por barrio y efectos al publicar
  Noticia.java                una noticia: titular, fuente y tipo (verdadera, falsa u opinión)
  Noticiero.java              el mazo de noticias, una por turno
  Influencer.java             las reglas de las tarjetas: textos, cuánto vale cada una y cómo se arman las seis
  Tarjeta.java                una tarjeta: texto, acción y categoría
  Publicacion.java            lo que pasó al publicar: cambio de apoyo, bonos y habilidades que se activaron
  GrafoCiudad.java            el grafo de la ciudad: 8 barrios y 12 calles (matriz de adyacencia), BFS y Dijkstra
  Sonidos.java                los sonidos del teléfono y del celular, generados con javax.sound
```

Cada archivo nuevo necesita una razón clara. Si algo cabe en uno de los que ya existen, va ahí.

Nota de Processing: la carpeta y el `.pde` principal deben llamarse igual (`AlcaldeDigitalRediseno`), por eso el archivo principal cambió de nombre en esta copia.

Nota de Java: la clase `public` de un archivo debe llamarse igual que el archivo. `Nodo.java` lleva `public class Nodo`, `Noticia.java` lleva `public class Noticia`, y así con todos. Todo vive en el paquete por defecto, sin declaración de `package`.

### Regla 2: el código tiene que poder explicarse

Es un trabajo universitario y en la sustentación cualquier integrante puede ser interrogado sobre cualquier línea.

- Nada de patrones de diseño, interfaces, genéricos, clases abstractas ni herencia.
- Nada de getters y setters que no se usen.
- Métodos cortos, de una sola responsabilidad.
- Nombres en español.
- Estilo de referencia: el código de clase del estudiante — clases planas, campos privados con getters simples, recursión directa, `ArrayList` y nada más exótico.

### Regla 3: un paso del guion a la vez

Solo se construye el paso en el que se está trabajando. Sigue prohibido implementar, esbozar o dejar preparado lo que viene después: rivales, bots o IA de oponentes · bloqueo de tarjetas · noticiero de fin de ronda · sockets, red, multijugador funcional · accesibilidad · guardado en archivos.

Sonido: solo los del teléfono y el celular, generados con `javax.sound` (viene con Java). Nada de librerías de sonido ni archivos de audio.

Nada de clases vacías, `TODO` ni métodos sin cuerpo. Si algo de esa lista parece imprescindible, el diseño se desvió: detenerse y preguntar.

Excepción acordada: la oficina (el menú) muestra los objetos que llegan después (hoy, la estantería) porque son parte del dibujo. Se ven, reaccionan al mouse y avisan «Próximamente», pero no tienen ninguna lógica detrás.

### Regla 4: el modelo no toca Processing

Las clases `.java` se compilan como Java independiente y **no pueden llamar** a `random`, `millis`, `println`, `fill`, `line` ni ninguna función de Processing. Si hacen falta, usar `java.util.Random` y `System.currentTimeMillis()`.

---

## El juego (contexto completo)

Alcalde Digital es un juego por turnos donde varios candidatos compiten por la alcaldía de Ciudad Nova publicando en la red social Civitas. Publicar información verificada gana influencia; publicar mentiras o atacar a otros candidatos da un empujón rápido pero cuesta credibilidad. Con la influencia se domina territorio en un mapa de la ciudad.

Cada candidato tiene un **árbol de habilidades** que va desbloqueando con los puntos que gana cada turno. Las habilidades mejoran su alcance, su credibilidad, o le permiten presionar a los rivales.

**De todo eso, por ahora están el menú, el árbol de habilidades, la llamada del periodista y la publicación con el celular sobre el mapa (un solo candidato).** Los rivales, el noticiero y la IA llegan en los pasos siguientes. Se documentan aquí solo para que se entienda qué papel cumple cada parte dentro del juego completo.

---

## El árbol de habilidades

### Qué problema resuelve

Las habilidades de un candidato no son una lista plana: unas dependen de otras. No puedes tener «Golpe de suerte» sin antes tener «Fuente confiable», ni mejorar la IA sin antes tener el «Asistente de IA». Esa dependencia es jerárquica por naturaleza y es exactamente lo que un árbol representa.

### Por qué n-ario y no binario

Un nodo puede abrir más de dos caminos. La raíz se ramifica en tres líneas de desarrollo y un árbol binario obligaría a inventar nodos intermedios sin significado dentro del juego. El árbol n-ario permite que cada nodo tenga los hijos que el diseño necesite, ni más ni menos.

Esta es la respuesta literal a la pregunta "¿qué variante de árbol se utiliza?" de la rúbrica.

### Cómo se juega

El candidato empieza con 3 puntos y, al pasar cada turno, recibe más según cómo le fue con su publicación: **2 si sumó, 3 si quedó igual (o no publicó) y 4 si restó**. Así siempre se puede remontar (es la idea del director para cuando haya rivales: el que va perdiendo recibe más). Una habilidad solo se desbloquea si:

1. Su nodo padre ya está desbloqueado (la raíz siempre lo está).
2. Ya es su ronda (`rondaMinima`): el Asistente de IA desde la ronda 2; Transmisión en vivo e IA perfecta desde la ronda 6.
3. El candidato tiene puntos suficientes para pagar su costo.

Con puntos limitados y tres ramas compitiendo, el jugador tiene que elegir en qué especializarse. Esa es la decisión del juego.

### Estructura del árbol

Raíz: **Campaña** (costo 0, desbloqueada desde el inicio). De ella salen tres ramas.

**Rama Alcance** — llegar a más barrios (usa el grafo)

| Habilidad | Padre | Costo | Ronda | Efecto |
|---|---|---|---|---|
| Volantes | Campaña | 2 | 1 | Si la publicación suma, los barrios a 1 calle del elegido reciben +5 |
| Megáfono | Volantes | 3 | 1 | Si suma, los barrios a 2 calles del elegido reciben +3 |
| Perfil verificado | Volantes | 3 | 1 | Se puede publicar hasta a 2 calles del territorio |
| Transmisión en vivo | Perfil verificado | 5 | 6 | Una vez por partida, la publicación cuenta como la mejor (100%) |

**Rama Credibilidad** — jugar limpio

| Habilidad | Padre | Costo | Ronda | Efecto |
|---|---|---|---|---|
| Libreta de notas | Campaña | 2 | 1 | Volver a oír la noticia una vez por turno |
| Fuente confiable | Libreta de notas | 3 | 1 | Al acertar (mayor o menor), 50% de +10 extra |
| Golpe de suerte | Fuente confiable | 5 | 1 | 20% de que la tarjeta elegida se cambie por la mejor |
| Rueda de prensa | Libreta de notas | 4 | 1 | Si la publicación resta, resta la mitad |

**Rama IA** — el atajo

| Habilidad | Padre | Costo | Ronda | Efecto |
|---|---|---|---|---|
| Asistente de IA | Campaña | 3 | 2 | Desbloquea la tarjeta «inventar una noticia»: 20% de que no la descubran (+30); si la descubren, -10 |
| Modelo mejorado | Asistente de IA | 4 | 1 | 40% de que no la descubran |
| Bots de difusión | Modelo mejorado | 5 | 1 | Si no la descubren, +10 extra |
| IA perfecta | Modelo mejorado | 6 | 6 | En la última ronda, si en la anterior la publicación restó, la IA no falla (100%) |

Doce habilidades más la raíz: trece nodos, con la misma forma n-aria de la entrega 1 (la raíz con tres hijos y los demás con uno o dos). Completar todo cuesta 45 puntos y en siete turnos se reciben entre 15 y 27, así que nadie completa el árbol.

### Orden en que actúan las habilidades al publicar

Todas se aplican después de que el jugador eligió tarjeta y barrio, siempre en el mismo orden (`Partida.publicar()`), y Nico las cuenta en el chat:

1. **Transmisión en vivo** (si se activó con el botón «EN VIVO» del chat): la tarjeta cuenta como la mejor.
2. Si es la **tarjeta de IA**: se sortea si la descubren (20%, 40% con Modelo mejorado o 100% con IA perfecta en su caso). Si no la descubren vale +30 (+10 con Bots de difusión); si la descubren, -10. Si no es de IA: **Golpe de suerte** puede cambiarla por la mejor y **Fuente confiable** puede sumar +10 si se acertó.
3. **Rueda de prensa**: si resta, resta la mitad.
4. Se aplica al barrio, sin pasarse de 0 ni de 100.
5. **Volantes y Megáfono**: si sumó, bonos a los barrios a 1 y 2 calles (niveles del BFS desde el barrio elegido).

---

## La llamada del periodista## La llamada del periodista

### Cómo se juega

Cada turno empieza en la oficina con el teléfono rojo sonando. Mientras suena, vibra (el auricular salta sobre la horquilla), salen las rayitas amarillas del dibujo del equipo y un «¡RIIING!» por cada timbrazo, y una burbuja dice «¡Contesta!». Es lo único de la oficina que responde: el cuaderno y los demás objetos avisan «Primero contesta el teléfono». La ayuda y la puerta sí funcionan, y el timbre se calla mientras se lee la ayuda.

Con un clic en el teléfono (o con Enter o la barra espaciadora) se contesta. El auricular sube al frente de la pantalla, a la derecha, con su cable en espiral, y la oficina se oscurece un poco. Aparece un globo con la etiqueta roja «ÚLTIMA HORA» y el nombre de quien llama: Marta Ríos, del Noticiero Ciudad Nova. Lo que dice sale letra por letra, con un murmullo de voz, en cuatro partes: un saludo, el titular (más grande), de dónde salió la noticia y una despedida. El saludo y la despedida cambian de un turno a otro.

La fuente es la pista: no es lo mismo «la página oficial de la Alcaldía» que «un audio que está rotando en los grupos de vecinos». La periodista nunca dice si la noticia es verdadera, falsa u opinión.

Cuando termina de hablar, y después de un momento para leer, la periodista cuelga: suena el «tu, tu, tu» (a 425 Hz, el tono de ocupado que se usa en Colombia), el globo lo muestra escrito y el auricular vuelve a su base. **La llamada no se puede adelantar ni colgar**: los clics, Enter y Esc no hacen nada mientras dura, para que el jugador preste atención. Abajo del globo dice «Escucha bien: la noticia no se repite».

Después, el teléfono dice «Ya colgaron»: la noticia no se vuelve a oír, salvo con la habilidad **Libreta de notas**, que permite oírla otra vez una vez por turno (`puedeRepetirLlamada()`, `repeticionUsada`).

Al pasar turno se vuelve a la oficina y el teléfono suena otra vez, con una noticia nueva.

### Noticia.java y Noticiero.java

`Noticia` guarda el titular, la fuente y el tipo (`VERDADERA`, `FALSA` u `OPINION`). La fuente está escrita para leerse después de «Me llegó de…».

`Noticiero` funciona como un mazo de cartas: tiene 18 noticias (seis de cada tipo), las baraja con `Collections.shuffle` al empezar la partida y `siguiente()` saca la de arriba. Así ninguna se repite en los 7 turnos y cada partida llegan en otro orden. Las verdaderas vienen casi siempre de fuentes oficiales y las falsas de cadenas, audios y cuentas sin nombre, como pasa en la vida real; las opiniones son gustos o juicios, no datos.

`Partida` crea su `Noticiero` en `iniciar()` y saca una noticia nueva en cada `siguienteTurno()`. La interfaz la pide con `getNoticiaDelTurno()`.

### Llamada.pde

La llamada es una secuencia de fases guardada en `faseLlamada`:

| Fase | Qué pasa | Cuándo termina |
|---|---|---|
| `LLAMADA_POR_SONAR` | empezó el turno | 1,2 s después, con la oficina a la vista |
| `LLAMADA_SONANDO` | vibra y timbra | con el clic en el teléfono |
| `LLAMADA_CONTESTANDO` | el auricular sube al frente | 0,65 s |
| `LLAMADA_HABLANDO` | la periodista habla, letra por letra | cuando termina de hablar y pasa el tiempo para leer, o con un clic |
| `LLAMADA_CORTADA` | «tu, tu, tu» | 1,4 s o con un clic |
| `LLAMADA_COLGANDO` | el auricular vuelve a su base | 0,55 s |
| `LLAMADA_ATENDIDA` | ya se oyó la noticia del turno | al pasar turno |

Como el resto de las animaciones, cada fase guarda el momento en que empezó (`millis()`), y `actualizarLlamada()`, que se llama al principio de cada `draw()`, la hace avanzar cuando toca. El momento en que aparece cada letra se calcula una sola vez al contestar (`calcularMomentosLetras()`), con pausas después de los puntos y las comas. Por eso adelantar la llamada es solo correr hacia atrás el momento en que empezó la fase.

Cada parte del texto se parte en líneas con su texto completo antes de escribirla, y el alto del globo se mide con todo el texto: así ninguna palabra salta de línea mientras aparece y el globo no crece mientras la periodista habla.

El teléfono ya no está en la foto de la oficina: se dibuja en cada cuadro, porque vibra y porque durante la llamada se queda sin auricular.

### Sonidos.java

Los sonidos (timbre, descolgar, la voz, el tono de ocupado y colgar) se calculan muestra por muestra con senos y un poco de ruido al abrir el juego, y se guardan en objetos `Clip` de `javax.sound`. No hay que instalar nada ni cargar archivos. El timbre imita el de un teléfono antiguo: un martillito golpea dos campanas unas cuarenta veces por segundo, en dos ráfagas («ring, ring»). La voz no dice palabras: son sílabas cortas con el sonido de una vocal, una cada dos letras. Si el computador no tiene salida de audio, el juego sigue en silencio.

---

## El celular y el mapa

### Cómo se juega

Después de oír la noticia, el celular de la oficina muestra un círculo rojo con un «1» y una burbuja «¡Publica aquí!». Al abrirlo, la pantalla se divide en dos:

- **Izquierda, el celular:** el chat con Nico Viral, el influencer de la campaña. Primero aparece «escribiendo...» y después pregunta qué hacer con la noticia que contó la periodista, **sin repetirla**: hay que acordarse de ella y, sobre todo, de su fuente. Si el candidato tiene Transmisión en vivo sin usar, en la cabecera aparece un botón «EN VIVO» para activarla. Debajo, una barra que dice qué falta por elegir, el botón redondo de enviar y las seis tarjetas en dos columnas.
- **Derecha, el mapa:** el grafo de Ciudad Nova. Los barrios propios van en rojo (la sede con un círculo blanco), los que están al alcance en gris con un anillo amarillo que late y los que no, en gris oscuro. Debajo de cada nombre hay una barrita con su apoyo de 0 a 100 y una rayita blanca en 50. Al pasar el mouse por un barrio, la franja de abajo del mapa (donde está la leyenda) muestra su apoyo y, si está al alcance, por dónde llegaría la publicación y en cuántos minutos; ese camino se pinta de amarillo con sus minutos. Así la información nunca tapa las calles.

El botón de enviar solo se pone verde con tarjeta **y** barrio elegidos. Al enviar, el mensaje del jugador sale en una burbuja blanca y un punto de luz viaja por las calles del camino más corto, desde el barrio propio más cercano; cada calle tarda según sus minutos. Al llegar salen ondas del barrio y el cambio de apoyo («+30», «-10»), y si el barrio llegó a 50, «¡CONQUISTADO!». Nico responde cómo le fue, cuenta las habilidades que se activaron, muestra la noticia completa y qué era en realidad («Era falsa: lo mejor era desmentirla»), y cada tarjeta muestra abajo lo que valía. Si se usó la tarjeta de IA, Nico muestra la noticia que «escribió» la IA y si la descubrieron. Los bonos de Volantes y Megáfono salen como «+5» y «+3» sobre los barrios de alrededor. Se publica una vez por turno; después aparece «Ir al cuaderno →».

Teclado en el celular: del 1 al 6 eligen tarjeta, Enter envía, Esc vuelve a la oficina.

### Las tarjetas (Influencer.java y Tarjeta.java)

Cada tarjeta es una **acción** y cada acción tiene cinco formas de decirse, que se sortean en cada turno (así el texto no delata la respuesta). Lo que vale una acción depende de qué era la noticia:

| Acción | Verdadera | Falsa | Opinión |
|---|---|---|---|
| Compartirla tal cual, con su fuente | mayor (+30) | negativa (-10) | negativa (-10) |
| Desmentirla | negativa | mayor (+30) | negativa |
| Presentarla como opinión | negativa | negativa | mayor (+30) |
| Mencionarla con cautela | menor (+15) | menor (+15) | menor (+15) |
| No publicar nada | neutra (0) | neutra (0) | neutra (0) |
| Exagerarla | negativa | negativa | negativa |

Las seis tarjetas del turno son: una mayor, una menor, una neutra, una negativa, una sexta que repite cualquiera de esas cuatro (la mayor sale solo el 10% de las veces, la negativa el 40%) y la de IA, que se puede usar con el Asistente de IA del árbol (`Partida.estaBloqueada()`); mientras no, sale con candado. Ningún texto se repite y al final se barajan. La pista para acertar sigue siendo la fuente que dijo la periodista.

### Apoyo, alcance y conquista (Partida.java)

Cada barrio guarda el apoyo del candidato, de 0 a `TOPE_APOYO = 100`. La sede empieza en 50 y los demás en 0. Un barrio es propio con `UMBRAL_CONQUISTA = 50` o más (la sede siempre). `publicar(tarjeta, barrio, usarTransmision)` aplica las habilidades en el orden de arriba, una sola vez por turno, y devuelve una `Publicacion` con lo que pasó: la categoría final, lo que valía, cuánto cambió de verdad el apoyo, los bonos a los demás barrios y los textos de las habilidades que se activaron.

### El grafo (GrafoCiudad.java)

- `vecinos(z)`: recorre la fila de `z` en la matriz y devuelve las casillas con calle.
- `niveles(origenes)` y `nivelesDesde(z)`: **BFS**, recorrido por niveles con una cola. Arranca desde todos los barrios de origen a la vez (nivel 0) y avanza por capas: a 1 calle, a 2... Un barrio al que no se llega queda en -1.
- `alcanzables(propios, calles)`: los barrios a `calles` calles o menos de algún barrio propio (1, o 2 con Perfil verificado). Es la regla de a dónde se puede publicar; cuando se conquista un barrio, los que lo rodean quedan al alcance y la frontera crece. Los bonos de Volantes y Megáfono usan `nivelesDesde()` el barrio elegido.
- `dijkstra(origen, fijo, temporal, anterior)`: el algoritmo como en clase. En cada paso se fija el barrio no fijo de menor temporal y se relajan sus calles. Llena los tres arreglos para poder leer la tabla completa.
- `caminoMasCorto(origen, destino)` y `minutosMasCorto(origen, destino)`: el camino se arma leyendo `anterior` desde el destino hacia atrás.
- `propioMasCercano(propios, destino)`: desde qué barrio propio sale la publicación (el de menos minutos al destino).

La tecla **P** imprime además la matriz de adyacencia, los niveles del BFS desde los barrios propios, los barrios propios con su apoyo, a dónde se puede publicar y la tabla final de Dijkstra desde la sede (Final y Anterior por barrio), para la sustentación.

### Celular.pde

La publicación tiene tres fases en `faseCelular`: `CEL_ELIGIENDO`, `CEL_VIAJANDO` y `CEL_LISTO`. El modelo cambia en el momento de enviar (`enviarPublicacion()`), pero mientras el punto viaja el barrio de destino sigue mostrando el apoyo y el color de antes (`apoyoVisible()`, `propioVisible()`); el cambio se ve al llegar. `actualizarCelular()` se llama al principio de cada `draw()`, así la publicación llega aunque el jugador se devuelva a la oficina durante el viaje. El chat se arma cada cuadro con `mensajesDelChat()` según la fase y se apila desde abajo, recortado con `clip()`. Al pasar turno, `reiniciarCelular()` lo deja como nuevo.

Sonidos nuevos en `Sonidos.java`: «tin-tin» de mensaje, «fiuuu» de envío, tres notas que suben si sumó y dos que bajan si restó.

---

## Nodo.java

```java
public class Nodo {
    private String nombre;
    private String descripcion;
    private int costo;
    private int rondaMinima;
    private boolean desbloqueada;
    private ArrayList<Nodo> hijos;
}
```

Constructor que recibe nombre, descripción, costo y ronda mínima, pone `desbloqueada` en false y crea la lista de hijos vacía.

Métodos: getters de los seis campos, `setDesbloqueada(boolean)`, `agregarHijo(Nodo h)` y `esHoja()` que devuelve true si la lista de hijos está vacía.

Nada más. Es la clase más simple del proyecto y así debe quedar.

---

## ArbolHabilidades.java

Contiene la raíz y todas las operaciones sobre el árbol.

### Construcción

`construirArbol()` arma los trece nodos de la tabla de arriba con `agregarHijo`, y se llama desde el constructor. La raíz Campaña queda desbloqueada de entrada.

### Operaciones requeridas

```java
Nodo getRaiz()
Nodo buscar(String nombre)                  // recursivo desde la raíz
Nodo buscarPadre(Nodo actual, String nombre)
boolean estaDisponible(Nodo n)              // su padre está desbloqueado y él no
boolean desbloquear(String nombre, Partida p)
ArrayList<Nodo> preorden()
ArrayList<Nodo> disponibles()               // los que se pueden desbloquear ahora
int contarDesbloqueadas()
int altura(Nodo n)
int peso(Nodo n)
```

Dos operaciones más, que usa la interfaz:

```java
int contarDesbloqueadasEn(Nodo n)           // recursivo: desbloqueadas dentro del subárbol de n
int indiceRama(Nodo n)                      // 0, 1 o 2 según la rama; -1 si es la raíz
```

`desbloquear` es el método central del juego. Busca el nodo, verifica que su padre esté desbloqueado, verifica que la partida tenga puntos suficientes, descuenta el costo, marca el nodo y devuelve true. Si algo falla devuelve false sin cambiar nada.

`estaDisponible` es lo que la interfaz usa para pintar un nodo resaltado en vez de gris. Un nodo está disponible si él no está desbloqueado pero su padre sí.

Los recorridos en un árbol n-ario se hacen con un `for` sobre la lista de hijos, no con llamadas a izquierdo y derecho:

```java
public void preordenRec(Nodo n, ArrayList<Nodo> lista) {
    if (n == null) return;
    lista.add(n);
    for (Nodo hijo : n.getHijos()) {
        preordenRec(hijo, lista);
    }
}
```

`altura` y `peso` siguen la misma forma: `altura` es 1 más el máximo de las alturas de los hijos, `peso` es 1 más la suma de los pesos de los hijos.

---

## Partida.java

Estado mínimo del juego. No sabe nada de gráficos.

```java
public class Partida {
    private String nombreCandidato;
    private int turno;
    private int puntos;
    private Noticiero noticiero;
    private Noticia noticiaDelTurno;
    private GrafoCiudad ciudad;
    private Influencer influencer;
    private ArrayList<Tarjeta> tarjetasDelTurno;
    private int[] apoyo;
    private boolean publicoEsteTurno;
    private ArbolHabilidades arbol;
    // ...y lo que necesitan las habilidades (resultado del turno, Transmisión usada)
}
```

Métodos: `iniciar(String nombre, ArbolHabilidades arbol)` que pone turno en 1 y puntos en 3, crea el mazo de noticias, el influencer y la ciudad, guarda el árbol del candidato y prepara el primer turno (noticia y tarjetas); `siguienteTurno()` que suma 1 al turno, da 2, 3 o 4 puntos según el resultado y prepara el turno nuevo; `puedePagar(int costo)`; `gastar(int costo)`; `seAcabaronLosTurnos()` que dice si el turno ya pasó de 7; los de barrios (`esPropio`, `barriosPropios`, `contarBarriosPropios`, `puedePublicarEn`, `publicar`, `yaPublicoEsteTurno`, `getApoyo`) y los getters.

Constantes: `PUNTOS_INICIALES = 3`, `PUNTOS_SI_GANO = 2`, `PUNTOS_SI_QUEDO_IGUAL = 3`, `PUNTOS_SI_PERDIO = 4`, los valores de las habilidades (`BONO_VOLANTES`, `PROB_IA`...), `TURNOS_TOTALES = 7`, `ZONA_SEDE = 2`, `TOPE_APOYO = 100`, `UMBRAL_CONQUISTA = 50`. La partida termina al pasar del turno 7 o cuando se desbloquean las doce habilidades.

---

## AlcaldeDigitalRediseno.pde

Pantalla completa con `fullScreen(P2D)`. Todo el layout sale de `width` y `height`, así que para probar en ventana basta cambiar esa línea por `size(1280, 720, P2D)`.

Máquina de estados con cinco valores: `MENU` (la oficina), `ARBOL` (el cuaderno), `AYUDA` (el manual), `MAPA` (el televisor en grande) y `CELULAR` (publicar en Civitas). Se cambia de pantalla con `irA(estado)`, que además descarta la foto de la oficina al volver a ella (ver «Rendimiento» más abajo).

Bloque de constantes de color al inicio. Ningún valor de color suelto en el resto del código. La paleta sale del dibujo de la oficina (colores de Paint):

| Uso | Color |
|---|---|
| Pared | `#EFE4B0` crema |
| Piso | `#FFC90E` amarillo |
| Madera (escritorio, estantería, puerta) | `#B97A57` café |
| Teléfono, acentos | `#ED1C24` rojo |
| Pantalla de la TV | `#00A2E8` azul |
| Marco de la TV, portada del cuaderno | `#7F7F7F` gris |
| Trofeo | `#FFF200` amarillo |
| Mapa de la pared | `#7092BE` azul grisáceo con `#B5E61D` verde lima |
| Contornos | `#1A1A1A` casi negro, trazo grueso |

Las tres ramas tienen un color de «resaltador» (azul claro, verde lima y rosado) para las habilidades desbloqueadas y uno fuerte (azul, verde y rojo) para líneas, barras y etiquetas.

Fuentes: cuatro tipos de letra (`LETRA_TITULO`, `LETRA_NEGRITA`, `LETRA_TEXTO`, `LETRA_MANO`), cada uno con una lista de preferencia (Impact, Segoe UI Bold, Segoe UI y Segoe Print Bold en Windows, con alternativas para Mac y Linux). En P2D el texto solo se ve nítido si se dibuja al mismo tamaño con que se creó la fuente, así que `usarLetra(tipo, tamaño)` crea una `PFont` por cada tamaño la primera vez que se pide y la guarda en `fuentes[tipo][tamaño]`.

`setup()` crea la partida, el árbol y los sonidos. `draw()` primero deja avanzar la llamada (`actualizarLlamada()`) y después despacha según el estado. `mousePressed()` despacha los clics. `keyPressed()`:

- **P**: imprime en consola el preorden del árbol marcando cuáles están desbloqueadas, más la altura, el peso, cuántas van desbloqueadas, cuáles están disponibles y la noticia del turno con su tipo; y del grafo, la matriz de adyacencia, los barrios propios, a dónde se puede publicar y la tabla de Dijkstra desde la sede. Sirve para mostrar los recorridos corriendo durante la sustentación.
- **1 a 6 y Enter** (en el celular): eligen tarjeta y envían.
- **Enter o espacio**: contestan el teléfono y adelantan la llamada, igual que un clic.
- **Esc**: vuelve a la oficina desde el cuaderno o la ayuda (en la oficina no cierra el juego; para salir está la puerta). Durante la llamada, la adelanta.

---

## Interfaz.pde

### class Boton

`x`, `y`, `ancho`, `alto`, `texto`, `dibujar()` con cambio de color al pasar el mouse, y `contiene(mx, my)`. Se dibuja como una etiqueta de papel con contorno negro que se pone amarilla y se levanta con el mouse encima.

### class ObjetoOficina

Un objeto clicable de la oficina: `nombre`, `funcion`, `accion` (el texto de la etiqueta), `habilitado` y su caja (`x`, `y`, `ancho`, `alto`) en coordenadas del lienzo de la oficina. Métodos: `contiene(ex, ey)`, `centroX()` y `centroY()`. No sabe dibujarse: cada objeto tiene su propia función de dibujo porque cada uno tiene una forma distinta.

### pantallaMenu(): la oficina

El menú principal es la oficina del candidato, dibujada con figuras de Processing a partir del dibujo original del equipo (arte propio, sin imágenes externas). Se dibuja sobre un lienzo de referencia de 1200 x 675 (16:9) y se escala entero con `scale()`; las paredes, el piso y las patas se dibujan más grandes que el lienzo para que en monitores 16:10 o 4:3 el espacio sobrante muestre más habitación en vez de franjas vacías. La perspectiva usa un punto de fuga (`FUGA_X`, `FUGA_Y`).

Cada objeto clicable, al pasar el mouse, se agranda un poco, se ilumina y muestra una etiqueta con su nombre, para qué sirve y qué pasa al hacer clic:

| Objeto | Función en el juego | Por ahora |
|---|---|---|
| Cuaderno (sobre el escritorio) | Árbol de habilidades | **Funciona**: abre la pantalla del árbol |
| Post-it «¿Cómo jugar?» (pared) | Reglas y controles | **Funciona**: abre la ayuda |
| Puerta (pared derecha) | Salir del juego | **Funciona**: la puerta se abre, la pantalla se oscurece y el juego se cierra |
| Teléfono rojo | Noticias de última hora | **Funciona**: suena al empezar cada turno (ver «La llamada del periodista») |
| Televisor | Mapa de Ciudad Nova | **Funciona**: muestra el grafo de la ciudad y con un clic lo abre en grande |
| Celular | Publicar en Civitas | **Funciona**: después de la llamada, abre el chat con el influencer y el mapa (ver «El celular y el mapa») |
| Estantería con el trofeo | Quién va ganando | Próximamente |

Un clic en un objeto «próximamente» muestra un candado sobre el objeto y un aviso abajo. Además:

- **Portada**: al abrir el juego, la oficina aparece oscurecida con el título **Alcalde Digital** en una cinta de campaña roja, el subtítulo **Ciudad Nova** y «Haz clic para empezar».
- **Calendario** en la pared: muestra el turno actual de la campaña (no es clicable).
- **Televisor**: noticiero animado (globo que gira y titulares de «última hora» sobre verificar antes de compartir).
- **Celular**: después de la llamada muestra un círculo rojo con un «1» hasta que se abre el chat, y una burbuja «¡Publica aquí!» hasta que se publica.
- **Cuaderno**: después de publicar, la primera vez tiene una burbuja «¡Sigue aquí!»; mientras queden puntos sin gastar muestra una burbuja naranja con cuántos.
- **Televisor** y mapa en grande: los barrios conquistados se pintan de rojo.
- Abajo, un cartel recuerda que se puede pasar el mouse por los objetos; mientras suena el teléfono, dice que hay que contestarlo.

### El cuaderno (Cuaderno.pde)

Sigue el dibujo del equipo: un cuaderno abierto sobre el escritorio.

**Hoja izquierda, el árbol dibujado:** la raíz (Campaña) abajo, en el tronco, sobre el pasto, y las tres ramas creciendo hacia arriba entre el follaje. Las ramas de madera son más gruesas cuanto más habilidades cuelgan de ellas (`peso()` del subárbol del hijo). Cada habilidad es un círculo con candado y su nombre debajo:

- **Desbloqueada:** dorada, con el candado abierto. La rama que lleva a ella se marca con una línea dorada (se ve el camino recorrido).
- **Disponible:** blanca con el candado cerrado; si alcanzan los puntos y ya es su ronda, un anillo amarillo que late.
- **Bloqueada:** gris con el candado cerrado.
- **Elegida con clic:** anillo naranja. Las que piden ronda llevan una insignia roja «R2» o «R6».

El anillo delgado de cada círculo es del color de su rama (azul Alcance, verde Credibilidad, rojo IA), con la leyenda arriba de la hoja.

**Hoja derecha:** «Puntos: N» con un brochazo rojo detrás, cómo se ganan, y la ficha de la habilidad bajo el mouse (o la elegida): nombre, rama, qué hace, si se puede comprar o por qué no («primero desbloquea…», «desde la ronda 6», «te faltan 2 puntos») y el botón «Desbloquear por N». Abajo, el costo en grande sobre la marca de agua «COSTO». Enter también compra la elegida.

**Al comprar:** se llama a `desbloquear`, sale una onda dorada, la rama se marca y los hijos pasan a disponibles. Si no se puede, el nodo se sacude.

**Barra superior:** nombre del candidato, turno actual de 7, puntos y el botón «Pasar turno».

Las posiciones salen de la misma fórmula recursiva de la entrega 1, pero hacia arriba: cada nodo reparte su ancho en partes iguales entre sus hijos (`xHijo()`, `anchoHijo()`) y los hijos van un nivel más arriba. Todas las funciones que recorren el árbol (follaje, ramas, camino dorado, nodos y `nodoEnPosicion()` para el clic) son recursivas y usan esa misma cuenta, así lo que se ve y donde se hace clic coinciden. El libro, el pasto, el follaje, el tronco, las ramas y la marca de agua van en la foto (`fotoCuaderno`); los nodos y la hoja derecha se dibujan cada cuadro.

**Fin de la partida:** al pasar del turno 7 (en el turno 7 el botón dice «Terminar campaña») o si se desbloquean las doce habilidades, aparece una tarjeta con el resumen: turnos jugados, barrios conquistados, habilidades desbloqueadas, el progreso por rama y el «estilo de campaña» según la rama más desarrollada (Comunicador, Candidato confiable o Candidato de la IA). Tiene los botones «Nueva campaña» y «Volver a la oficina».

### pantallaAyuda()

Un manual en una hoja sobre el escritorio, en dos columnas: el objetivo del juego, qué hace cada objeto de la oficina (cuáles ya funcionan y cuáles llegan después), cómo funcionan los turnos y los puntos, la regla de que un nodo necesita su padre desbloqueado, qué hace cada rama y los atajos de teclado. Botón para volver a la oficina.

### Rendimiento

La oficina ya no se dibuja con figuras: es una imagen, así que no hace falta tomarle fotos. Lo que sí se guarda es el texto: cada frase en letra pixel se arma una vez y se reutiliza (`textosPixel` en `Diseno.pde` y `textosBlancos` en `LetraGlobal.pde`, con un tope de 3000 para que los contadores no llenen la memoria). Los fundidos de texto se hacen con `tint()`, para no crear una imagen por cada transparencia. En la ciudad del mundo abierto, los personajes y carros se ordenan una sola vez por cuadro antes de dibujarse entre los objetos.

---

## Hitos

**Hito 1 — El árbol.** `Nodo.java` y `ArbolHabilidades.java` con los trece nodos y todas las operaciones.
*Verificación por consola:* imprimir el preorden completo, la altura y el peso. Intentar desbloquear una habilidad cuyo padre está bloqueado (debe fallar). Desbloquear el padre y volver a intentar (debe funcionar). Intentar desbloquear algo sin puntos suficientes (debe fallar). Imprimir la lista de disponibles después de cada cambio y verificar que crece correctamente.

**Hito 2 — Menú.** `AlcaldeDigitalRediseno.pde` (en la entrega 1 se llamaba `AlcaldeDigital.pde`) con la máquina de estados, `Boton`, la pantalla de menú y la de ayuda.
*Verificación:* se abre la ventana, se ve el menú, los botones responden, Multijugador se ve deshabilitado y Ayuda muestra su contenido.

**Hito 3 — Pantalla del árbol.** El dibujo recursivo, los tres estados visuales, el panel lateral y el clic para desbloquear.
*Verificación:* se entra desde el menú, se desbloquea una habilidad con clic, sus hijos pasan a disponibles, los puntos bajan, y pasar turno devuelve puntos. Los trece nodos se ven sin solaparse.

**Hito 4 — La oficina como menú.** La oficina dibujada con la paleta del juego, los objetos con etiqueta al pasar el mouse y la portada.
*Verificación:* el cuaderno abre el árbol, el post-it abre la ayuda, la puerta cierra el juego, los objetos «próximamente» muestran el candado y el aviso, y el calendario muestra el turno actual al volver del cuaderno. Probado en 1920x1080, 1536x864, 1366x768, 1280x800 y 1024x768.

**Hito 5 — La llamada del periodista.** `Noticia.java`, `Noticiero.java`, `Sonidos.java` y `Llamada.pde`.
*Verificación:* al cerrar la portada el teléfono suena; mientras suena, el cuaderno avisa que primero hay que contestar y la ayuda calla el timbre; al contestar, el auricular sube, la periodista cuenta la noticia letra por letra y cuelga sola; un clic adelanta la llamada; después se puede volver a oír la noticia; al pasar turno se vuelve a la oficina con una noticia distinta; en el turno 10 la campaña termina y el teléfono ya no suena; «Nueva campaña» empieza otra vez con la llamada. Probado en 2560x1080, 1920x1080, 1366x768, 1280x800 y 1024x768.

**Hito 6 — El celular y el mapa.** `Celular.pde`, `Influencer.java`, `Tarjeta.java` y lo nuevo de `GrafoCiudad.java` y `Partida.java`.
*Verificación:* el celular solo se abre después de la llamada; el botón de enviar solo se activa con tarjeta y barrio; la tarjeta de IA avisa que se desbloquea con el árbol; un barrio fuera de alcance avisa por qué no se puede; el punto viaja por el camino de Dijkstra; el apoyo cambia al llegar; con 50 el barrio se vuelve rojo, en el mapa y en el televisor, y sus vecinos quedan al alcance; al pasar turno hay tarjetas y noticia nuevas; la tecla P imprime la matriz y la tabla de Dijkstra. Probado en 1280x720 y 1920x1080.

**Hito 7 — Memoria, árbol nuevo e IA.** `Cuaderno.pde`, `Publicacion.java`, el árbol nuevo en `ArbolHabilidades.java`, `rondaMinima` en `Nodo.java`, BFS en `GrafoCiudad.java` y los efectos en `Partida.java`.
*Verificación:* la llamada no se adelanta con clic, Enter ni Esc y se cierra sola; después el teléfono dice «Ya colgaron» y solo con la Libreta se vuelve a oír, una vez; Nico no repite la noticia y al final la muestra completa; la ficha del barrio va en la franja de abajo; el Asistente de IA no se compra en la ronda 1; con él, la tarjeta de IA se puede usar y muestra su probabilidad; Perfil verificado deja publicar a 2 calles; Volantes y Megáfono dan sus bonos; los puntos del árbol llegan según el resultado. Probado en 1280x720 y 1920x1080.

---

## Antes de dar por terminado

1. Confirmar que existen **exactamente los dieciséis archivos de la Regla 1** (más este README).
2. Verificar que no hay nada sobre red, rivales ni bloqueo de tarjetas, y que los únicos sonidos son los del teléfono y el celular.
3. Confirmar que ningún `.java` llama a funciones de Processing.
4. Escribir `JUSTIFICACION.md` respondiendo las cinco preguntas de la rúbrica: qué problema resuelve el árbol, por qué se escogió esa estructura, qué variante es y por qué n-ario en vez de binario, cómo se insertan y eliminan elementos, y cómo se realiza su recorrido. Redacción natural y directa, máximo dos páginas.

El criterio de éxito: que alguien mire la pantalla del árbol y entienda sin explicación que las habilidades dependen unas de otras, y que desbloquear una abre las siguientes.
