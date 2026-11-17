# Infiltrado: mecánicas y estructuras de datos

Guía para la sustentación. Para cada mecánica: qué hace en el juego, en qué
archivo está y qué estructura de datos la sostiene.

## 1. El mapa como grafo

La sede es una cuadrícula de 44 x 32 baldosas que se lee de tres CSV (`data/mapa/`).
Por dentro cada baldosa es una letra en la matriz `Mapa.celdas` (`#` pared,
`.` piso, `D` puerta abierta, `1`-`4` puertas cerradas, letras de muebles).

Sobre esa matriz hay dos grafos:

- **Grafo de baldosas.** Cada baldosa libre es un vértice unido a sus cuatro
  vecinas. No se guarda una lista de adyacencia: los vecinos se calculan al vuelo
  sumando (±1, 0) y (0, ±1). Así el grafo cambia solo cuando se abre una puerta.
- **Grafo de cuartos.** Cada zona (recepción, archivo, servidor...) es un vértice
  y cada puerta es una arista que guarda la tarjeta que pide
  (`Mapa.armarGrafoCuartos`).

## 2. Vigilantes que se mueven por BFS

`Vigilante.pde`, `Mapa.caminoBFS`.

La ronda de cada vigilante es una lista de puntos. Para ir de uno al siguiente se
usa BFS sobre el grafo de baldosas: como todas las aristas pesan lo mismo, BFS ya
da el camino más corto. La cola es un `ArrayList` con un índice `frente` (en vez
de borrar el primer elemento se avanza el índice) y un arreglo `anterior` guarda
de dónde se llegó a cada baldosa, para reconstruir el camino al final.

El mismo BFS sirve cuando un vigilante va a revisar un ruido, a prender un
tablero o a despertar a un compañero noqueado.

Los estados del vigilante (patrulla, sospecha, búsqueda, alerta) son una máquina
de estados con una barra de sospecha de 0 a 100.

## 3. Ruido que no atraviesa paredes

`Mapa.pasosRuido`, `hacerRuido`.

Cuando algo suena (pasos, una botella, la radio) se hace un BFS desde ese punto
con un máximo de pasos. El resultado es una matriz con cuántos pasos recorrió el
sonido hasta cada baldosa, o -1 si no llegó. Las paredes y las puertas cerradas
cortan el BFS, por eso un ruido al otro lado de una pared no se oye aunque esté
cerca en línea recta. Un vigilante oye el ruido si la matriz en su baldosa no es -1.

## 4. A qué cuartos se llega con las tarjetas

`Mapa.zonasAlcanzables`.

BFS sobre el grafo de cuartos: desde el exterior, se avanza por una arista solo
si su puerta está abierta o si se tiene la tarjeta que pide. El HUD muestra
"Alcanzas n de 11 cuartos" con este resultado, y el plano marca los cuartos
cerrados.

## 5. Ductos con Dijkstra

`Mapa.distanciasDucto`, `entrarDucto`.

Las rejillas son vértices y los ductos son aristas con su largo como peso. Al
meterse en un ducto se corre Dijkstra desde esa rejilla y el tiempo de gateo
hasta cada salida es la distancia por 0,22 s. Se hace igual que en clase: arreglo
de temporales, arreglo de fijos y en cada vuelta se fija el de menor temporal y
se relajan sus aristas.

## 6. Empleados que buscan al vigilante más cercano (Dijkstra)

`Civil.pde`, `Mapa.dijkstraCivil`.

Si un empleado ve al jugador o un cuerpo, corre a avisarle al vigilante más
cercano. "Más cercano" no es en línea recta ni en número de baldosas: cruzar una
puerta cuesta 3 y pasar por una zona a oscuras también cuesta 3. Con pesos
distintos BFS ya no sirve y se usa Dijkstra sobre la cuadrícula. Una sola corrida
desde el empleado da la distancia a todas las baldosas, así que se compara la de
cada vigilante y se elige la menor; el camino se arma hacia atrás con el arreglo
`anteriorCivil`. Como el vigilante se mueve, se recalcula cada 0,8 s.

## 7. Luz, vista y conos

`Mapa.calcularLuz`, `Mapa.hayLinea`, `dibujarCono`.

La luz de cada baldosa se guarda en matrices (`luzR`, `luzG`, `luzB` y `luz`).
Cada fuente de luz suma color a las baldosas a su alcance si hay línea de vista.
Cortar la luz de un tablero apaga zonas enteras y se recalculan las matrices.

La línea de vista avanza en pasos cortos desde el vigilante hasta el jugador y se
corta en la primera baldosa que tapa la vista. El cono que se dibuja son rayos
que se detienen en la primera pared.

## 8. Noquear, arrastrar y esconder

`Persona.pde`.

Vigilantes y empleados heredan de `Persona`, que guarda si está inconsciente, si
el cuerpo está escondido y quién lo arrastra. Para buscar cuerpos se recorre una
sola lista con todas las personas. Los armarios ocupados se guardan en una
`IntList` con la clave `columna * 1000 + fila`.

## 9. Radio, teclado y consola

`Radio.pde`, `Teclado.pde`, `Seguridad.pde`.

- **Radio:** la secuencia que hay que repetir es un arreglo de direcciones al
  azar; se compara posición por posición con lo que se presiona.
- **Teclado:** el código cambia en cada misión. Un arreglo de booleanos dice qué
  dígitos ya se conocen (la nota da los dos primeros y una conversación los dos
  últimos).
- **Consola:** un menú de opciones con su tiempo de espera.

## 10. Conversaciones

`Charlas.pde`.

Las charlas pendientes están en una lista y salen en orden: cada una se dice una
vez. Empiezan cuando dos personas tranquilas quedan cerca y hay un jugador a 6
baldosas o menos. Si el jugador está cerca cuando se dice la línea útil, se queda
con la pista.

## 11. Alarma, reloj, mochila y salidas

- `Alarma.pde`: un entero de 0 a 3. Cada nivel cambia reglas: velocidad, alcance
  de la vista, luces, tableros, la entrada principal y la policía.
- `Mochila.pde`: cada botín tiene valor y peso en arreglos paralelos; el peso
  baja la velocidad y sube el ruido. El valor no es proporcional al peso
  (documento 1 kg = 2, disco 2 kg = 5, portátil 3 kg = 6) y en la mochila caben
  6 kg, así que elegir el botín es el problema de la mochila 0/1. Al empezar se
  resuelve con programación dinámica: un arreglo `mejor[c]` con el mayor valor
  que cabe en c kilos, recorrido de atrás hacia adelante para usar cada objeto
  una sola vez. Con dos jugadores el estado son los kilos libres de cada
  mochila, `mejor[a][b]`. Ese óptimo es la meta que muestra el HUD.
- La mochila de cada jugador es una pila (`ArrayDeque`): X o K saca lo último
  que se guardó y lo deja en el piso, para poder cambiarlo por otra cosa.
- `Salidas.pde`: tres salidas, cada una con su condición (alarma, peso, que estén
  los dos jugadores).

## 12. Cooperativo y roles

`Rescate.pde`, `Equipo.pde`, `Roles.pde`.

Los dos jugadores comparten tarjetas y código. Si atrapan a uno, el otro tiene
20 s para soltarlo. La puerta de carga se puede empujar entre los dos y la
consola deja a uno vigilando con las cámaras en bucle. Cada rol (Hacker,
Fantasma) tiene una habilidad con su tiempo de recarga.

## 13. Conexión con Alcalde Digital

`Campana.pde`.

Se comunican con dos archivos de texto `clave=valor` en `data/`. `campana.txt`
trae las habilidades del árbol del candidato (el árbol n-ario de Alcalde
Digital) y cada una se vuelve una herramienta en la misión. `resultado.txt`
devuelve el rango, el botín, las oportunidades, el cambio de apoyo y la noticia
del día siguiente.

## 14. Sonido y dibujo

- `Audio.pde`: cuatro pistas de música que se mezclan en un hilo aparte con
  fundido; los efectos se cargan una vez en `Clip` de javax.sound.
- `Dibujo.pde`: la cuadrícula se pasa a isométrico solo al dibujar. Se dibuja por
  diagonales (`i + j`) para que lo que está más cerca tape lo de atrás.
- `Interaccion.pde`: las marcas de lo que se puede usar se guardan en matrices
  del tamaño del mapa (fuerza y color de cada baldosa) que se recalculan en cada
  cuadro.

## Resumen

| Estructura | Dónde se usa |
|---|---|
| Matriz | Mapa, zonas, luz, cortes de paredes, ruido, marcas |
| Grafo implícito (cuadrícula) | Movimiento de vigilantes y empleados, ruido |
| Grafo de cuartos | Puertas y tarjetas |
| Grafo con pesos | Ductos, caminos de los empleados |
| BFS | Rondas, ruido, cuartos alcanzables |
| Dijkstra | Ductos, empleado que busca al vigilante |
| Listas (`ArrayList`) | Jugadores, vigilantes, empleados, cámaras, ruidos, partículas, charlas |
| Herencia | `Persona` → `Vigilante`, `Civil` |
| Árbol n-ario (Alcalde Digital) | Habilidades que llegan como herramientas |
