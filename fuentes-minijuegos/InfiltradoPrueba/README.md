# Infiltrado (prueba)

Modo de sigilo de Alcalde Digital. El candidato se mete de noche a la sede de
"Titulares Ya", la agencia que fabrica los bulos, copia su servidor y sale sin
que lo atrapen. Se juega solo o en cooperativo en el mismo PC.

Es un sketch aparte de Processing 4 (modo Java). Para correrlo: abrir
`InfiltradoPrueba.pde` y darle Play. La carpeta `data/` con los PNG tiene que
ir junto al sketch.

## Archivos

| Archivo | Qué tiene |
|---|---|
| `InfiltradoPrueba.pde` | Estados de la partida, preparar la misión, usar, ductos, luces, botellas, salida, teclado |
| `Mapa.pde` | Carga del mapa desde `data/mapa/`, choques, línea de vista, luz, grafo de cuartos, BFS, Dijkstra de ductos |
| `Jugador.pde` | Movimiento, posturas, ruido de los pasos; clase `Ruido` |
| `Vigilante.pde` | Vista, sospecha, estados (patrulla, sospecha, búsqueda, alerta), movimiento por BFS |
| `CamaraSeguridad.pde` | Cámaras que giran y dan la alarma |
| `Sprites.pde` | Carga de los PNG y cómo se dibujan agrandados sin suavizar |
| `Dibujo.pde` | Mundo isométrico: pisos, conos, capa ordenada, personas, plano del reconocimiento |
| `Hud.pde` | Interfaz, pantalla de inicio, reconocimiento y ventanas |
| `HudPixel.pde` | HUD en pixel art: se dibuja a la resolución del arte y se agranda sin suavizar |
| `Persona.pde` | Lo que comparten vigilantes y civiles: noquear, arrastrar, esconder y encontrar cuerpos |
| `Radio.pde` | La central llama al vigilante noqueado: minijuego para contestar |
| `Civil.pde` | Empleados de la sede: si te ven, corren a avisar al vigilante más cercano (Dijkstra) |
| `Disfraz.pde` | Disfraz de conserje: cuándo sirve y cuándo no; el jefe de seguridad te reconoce de cerca |
| `Seguridad.pde` | Consola del cuarto de seguridad: apagar cámaras, borrar grabaciones, buscar en las pantallas |
| `Alarma.pde` | Nivel de alarma 0 a 3 (qué cambia en cada uno) y reloj de 2:00 a 5:00 a. m. |
| `Mochila.pde` | Botín con valor y peso: documento (1 kg), disco duro (2 kg), portátil (3 kg); mochila de 6 kg |
| `Charlas.pde` | Conversaciones que se pueden escuchar y dan pistas |
| `Teclado.pde` | Código de 4 dígitos de la puerta del servidor y su teclado |
| `Roles.pde` | Roles Hacker y Fantasma con su habilidad (F / M) y la pantalla para elegir |
| `Campana.pde` | Conexión con Alcalde Digital y herramientas del árbol de habilidades |
| `Rescate.pde` | Cooperativo: el atrapado queda esposado y el otro tiene 20 s para soltarlo |
| `Equipo.pde` | Acciones a dos: puerta pesada que se empuja entre los dos |
| `Oportunidades.pde` | Tres objetivos opcionales que se descubren en la oficina del rival |
| `Salidas.pde` | Tres salidas con distinto riesgo: camioneta, moto y ducto |
| `Calificacion.pde` | Rango final (Fantasma, Silencioso, Ruidoso), puntos, pantalla final y variación de rondas |
| `Audio.pde` | Música dinámica con fundido (4 momentos) y efectos de sonido, con javax.sound |
| `Jugo.pde` | Temblor de pantalla, texto flotante y chispas |
| `Creditos.pde` | Pantalla de créditos con la música acreditada |
| `MapaGrande.pde` | Mapa grande con G (pausa) y cuartos que parpadean cuando una charla da una pista |
| `Valeria.pde` | Ayudante con IA: eventos en cola de prioridad, resumen de la misión, frase de Claude, voz de Azure con filtro de radio, subtítulo |
| `Llamada.pde` | Llamada del inicio: Valeria cuenta el bulo y la misión antes del reconocimiento |
| `Interaccion.pde` | Marcas de lo que se puede usar: borde, brillo, tecla y acción encima del objeto |
| `data/` | Sprites en pixel art (baldosa de 32x16 px) |
| `data/mapa/` | El mapa: `terreno.csv`, `zonas.csv`, `objetos.csv`, `entidades.txt` y `sede.tmx` para Tiled |

## El mapa (data/mapa)

La sede mide 44 x 32 baldosas. Tiene callejón y parqueadero, recepción, pasillo,
redacción de bulos, seguridad, archivo, aseo, descanso, estudio de TV, cuarto del
servidor y la oficina del rival.

- `terreno.csv`: 1 pared, 2 piso, 3 puerta, 4 roja, 5 azul, 6 amarilla, 7 con código.
- `zonas.csv`: 16 + número de zona (0 exterior ... 10 descanso, en el orden de `NOMBRES_ZONA`).
- `objetos.csv`: 32 + posición de la letra en `CODIGOS_OBJETO` (armario, escritorio, etc.); -1 vacío.
- `entidades.txt`: rondas de los vigilantes, puestos de los empleados, cámaras, ductos y tableros eléctricos.

Para editarlo en Tiled se abre `sede.tmx` y se exporta cada capa como CSV
(Archivo > Exportar como > CSV). Tiled nombra los archivos `sede_terreno.csv`,
etc.: hay que renombrarlos a `terreno.csv`, `zonas.csv` y `objetos.csv`.
Si al cargarlo los números salen corridos en 1, es porque esa versión de Tiled
escribió el número global de la baldosa: basta con restarle 1 a cada valor.

## Conexión con Alcalde Digital

El juego principal no se modifica. Se comunican con dos archivos de texto en `data/`:

- `campana.txt` (lo escribe Alcalde Digital antes de entrar): barrio, apoyo, el bulo del
  rival y las habilidades desbloqueadas en el árbol. Ver `campana_ejemplo.txt`.
  Si no existe, Infiltrado usa valores de prueba.
- `resultado.txt` (lo escribe Infiltrado al terminar): éxito, salida, rango, botín,
  oportunidades, alarma máxima, cuánto cambia el apoyo y la noticia del día siguiente.

Cada habilidad del árbol se vuelve una herramienta en la misión (ver `Campana.pde`):
Volantes, Megáfono, Perfil verificado, Libreta de notas, Fuente confiable, Rueda de
prensa, Asistente de IA y Bots de difusión.

Para entrar desde la oficina, en Alcalde Digital bastaría un objeto nuevo que guarde
`campana.txt` con `saveStrings`, abra el sketch de Infiltrado y, al volver, lea
`resultado.txt` con `loadStrings` y sume `apoyo_cambio` al barrio.

## Controles

- Jugador 1: WASD mover, Shift correr, C agacharse, E usar (mantener para copiar; noquear y arrastrar), Q lanzar botella, X soltar lo último de la mochila.
- Jugador 2: flechas mover, `-` correr, `.` agacharse, Enter usar, `,` lanzar botella.
- F (jugador 1) y M (jugador 2): habilidad del rol.
- G: mapa grande de la sede (pausa la partida).
- V: ver las rutas BFS de los vigilantes. R: reiniciar. Esc: salir.

## Estructuras de datos

El detalle por mecánica está en `MECANICAS.md` (pensado para la sustentación).
En corto: matrices para el mapa, la luz y el ruido; BFS en la cuadrícula para los
vigilantes y el ruido; BFS en el grafo de cuartos para las tarjetas; Dijkstra en
los ductos y para los empleados que buscan al vigilante más cercano; listas para
todo lo que se mueve; herencia `Persona` → `Vigilante` y `Civil`.

## Cómo probarlo en el PC

1. Abrir `InfiltradoPrueba.pde` y darle Play (usa `fullScreen(P2D)`).
2. Probar solo (1) y cooperativo (2), con los dos roles.
3. Revisar que se oiga la música y los efectos (si no hay sonido, la consola
   de Processing dice por qué).
4. Recorrer la sede completa: tarjetas, código, servidor, oportunidades y las
   tres salidas.
5. Si va lento, mirar los cuadros por segundo con `println(frameRate)` en `draw()`.

## Registro de cambios

- 2026-10-21: prototipo inicial con mapa isométrico, vigilantes con cono y BFS,
  cámaras, ruido, armarios, servidor, pruebas y cooperativo.
- 2026-10-22: todo visible y fase de reconocimiento con las rondas dibujadas.
- 2026-10-22: pixel art "neón nocturno" con sprites en `data/` e iluminación de colores.
- 2026-10-22: inicio del plan de 4 hitos (H0 a H4). Respaldo en
  `InfiltradoPrueba_respaldo_2026-10-22`.
- 2026-10-22 (H1): mapa de 44 x 32 leído desde CSV, oficina del rival (celular,
  tablero de conspiración, cuaderno, TV), puertas con tarjeta y código, ductos,
  botellas para distraer, tableros eléctricos, ruido por BFS, 5 vigilantes y 5 cámaras.
- 2026-10-22 (T39): lo que se puede usar se marca al acercarse: borde que palpita,
  tecla y acción encima del objeto. Cian se usa, verde se recoge, ámbar falta algo.
  A 4 baldosas o menos lo usable tiene un brillo suave.
- 2026-10-22 (T14-T15): noquear por la espalda (E de cerca y fuera de su vista) y
  arrastrar el cuerpo hasta un armario o el contenedor. Si un vigilante o una cámara
  ve un cuerpo, sube la alarma y van a despertarlo. Los pasos agachado ya no se oyen.
- 2026-10-22 (T16): la radio del vigilante noqueado suena a los 4 s. Hay 12 s para
  contestar repitiendo 4 direcciones (WASD o flechas). Si fallas o no contestas, sube la
  alarma. La central acepta 3 respuestas por misión.
- 2026-10-22 (T17): dos empleados nocturnos (redacción y descanso). Si te ven o ven un
  cuerpo, corren al vigilante más cercano por Dijkstra y le avisan. Se pueden noquear.
- 2026-10-22 (T18): uniforme de conserje en el casillero del aseo. Con él los vigilantes
  casi no sospechan y los empleados no se fijan, salvo si corres, te agachas, arrastras un
  cuerpo o entras a seguridad, servidor u oficina del rival. Nuevo jefe de seguridad (gorra
  blanca) que te reconoce a menos de 3 baldosas. Si te descubren, el disfraz se quema.
- 2026-10-22 (T19): consola del cuarto de seguridad. Apaga las cámaras 30 s (luego
  45 s de espera), borra las grabaciones (la alarma baja un nivel, una vez) o marca 30 s
  dónde están las tarjetas y el botín.
- 2026-10-22 (T20): nivel de alarma de 0 a 3. Sube si te descubren, te ve una cámara,
  encuentran un cuerpo, falla una radio o avisa un empleado. 1: vigilantes más rápidos y
  cámaras que giran más. 2: ven más lejos, se prenden las luces, bloquean los tableros y
  cierran la entrada principal. 3: la policía llega en 90 s. Reloj de 2:00 a 5:00 a. m.
  (un minuto = 2 s); a las 5:00 se pierde.
- 2026-10-22 (T21): botín con valor y peso (documento 1, disco duro 2, portátil 3) y
  mochila de 6 kg. Cada kilo hace caminar un 5 % más lento y los pasos se oyen más lejos.
  Agachado no se oye. Al final cuenta el valor extraído.
- 2026-10-22 (T22-T23): conversaciones entre vigilantes y empleados que se cruzan con
  un jugador cerca (a 6 baldosas o menos se entienden). Dan pistas: los dos últimos
  dígitos del código, dónde están las tarjetas amarilla y roja. La puerta del servidor
  tiene un teclado con un código nuevo en cada misión (los dos primeros dígitos están en
  la nota del archivo). Tres códigos malos suben la alarma y bloquean el teclado 20 s.
- 2026-10-25 (T40): las charlas ya no salen en "...": se leen siempre y empiezan solo
  con un jugador a 6 baldosas o menos. Menos ruido al moverse: agachado no se oye nada,
  caminando 1,4 baldosas, corriendo 3,2 y arrastrando 1 (antes 2,5, 5,5 y 1,8).
- 2026-10-25 (T24): roles. Hacker: apaga 12 s la cámara más cercana (cada 25 s) y
  contesta la radio con 3 flechas. Fantasma: Sombra, 6 s en que casi nadie lo nota (cada
  30 s), y agachado se mueve más rápido. En cooperativo el jugador 2 queda con el otro rol.
- 2026-10-25 (T25-T26): en cooperativo, si atrapan a uno queda esposado y el otro tiene
  20 s para soltarlo (mantener usar 2 s). Acciones a dos: la puerta de carga se abre sin
  tarjeta si la empujan los dos a la vez, y en la consola de seguridad uno puede quedarse
  vigilando con las cámaras en bucle mientras el otro avanza.
- 2026-10-25 (T27-T30): tres oportunidades opcionales; salidas por camioneta, moto o
  ducto (cada una con su riesgo); conexión con Alcalde Digital por `campana.txt` y
  `resultado.txt`; las habilidades del árbol aparecen como herramientas en la misión.
- 2026-10-25 (T31-T33): música dinámica de 4 momentos (calma, tensión, alerta, escape)
  que cambia con fundido de 1,5 s. Usa los archivos de `data/musica/` si están y, si no, la
  música generada de `data/musica_respaldo/`. 30 efectos de sonido generados en `data/sfx/`.
  Temblor de pantalla, textos flotantes y chispas en las acciones importantes.
- 2026-10-25 (T34, T36): pantalla final con rango, puntos y resultado en Alcalde Digital;
  cada misión cambia el punto de partida y el sentido de las rondas. Pantalla de créditos
  (C), con los compositores de ARC Raiders y Cyberpunk 2077 cuando se usa su música.
- 2026-10-25 (T37-T38): luces y conos fuera de pantalla ya no se dibujan; pruebas
  automáticas largas sin errores a 720p y 1080p; `MECANICAS.md` para la sustentación.
- 2026-10-25 (T41): disfrazado, los vigilantes no te notan salvo que estés a menos de
  1,2 baldosas; el jefe te reconoce a 3. El límite de las 5:00 a. m. queda apagado
  (`LIMITE_DE_TIEMPO` en `Alarma.pde`).
- 2026-10-25 (T42): HUD en pixel art (opción 2 de los bocetos): marcos con bisel y
  remaches, letra pixelada, íconos de tarjetas, mochila, ruido, sirena y retrato del
  jugador. Las ventanas y menús usan el mismo marco. La letra es DejaVu Sans Mono
  (incluida en `data/`) para que se vea igual en cualquier PC.
- 2026-10-25 (T43): copiar el servidor es lo último. Después ya no se recoge ni se
  revisa nada; el panel de objetivos cambia a "ESCAPA" con las tres salidas y solo quedan
  marcadas las salidas.
- 2026-10-25 (T44): mapa grande con G, como el del reconocimiento, con la posición de
  cada jugador. La partida se pausa mientras está abierto. Las pistas de las charlas hacen
  parpadear el cuarto del que hablan ("PISTA AQUÍ").
- 2026-10-25: la botella rota se oye a 9 baldosas (12 con Megáfono) y los vigilantes que
  la oyen van derecho y apurados a ese punto, y revisan 5 s.
- 2026-10-25: la botella distrae aunque el vigilante esté sospechando de ti: mientras va
  hacia el ruido no te ve (salvo que estés pegado a él). Los que ya te persiguen no caen.
- 2026-10-25 (T45-T47): Valeria, la ayudante con IA. Cuando pasa algo importante (te ven,
  sube la alarma, encuentras una tarjeta o una pista, te quedas quieto) el juego le manda
  a Claude un resumen de la misión y ella escribe una frase nueva; Azure la dice con voz
  colombiana y filtro de radio, con subtítulo. Antes del reconocimiento suena el teléfono
  y ella explica el bulo y la misión. Claves en `data/valeria.txt` (no se comparte); sin
  claves o sin internet usa frases de respaldo.
- 2026-10-25: botín como problema de la mochila 0/1. Documento 1 kg = 2 pts, disco duro
  2 kg = 5, portátil 3 kg = 6; en 6 kg no cabe todo. Al empezar, programación dinámica
  calcula el mejor botín posible (con dos jugadores, sobre las dos mochilas) y ese es el
  objetivo del HUD. La mochila es una pila: X (J1) o K (J2) deja en el piso lo último que
  se guardó. Valeria habla menos y, al coger una tarjeta, dice qué abre y el cuarto
  parpadea en el mapa.
- 2026-10-25: cuando sale la pantalla final (ganaste o perdiste) Valeria se calla y ya
  no habla. La botella llega más lejos (7 baldosas) y se
  oye a 13 (17 con Megáfono); el vigilante que la oye va siempre, aunque esté sospechando,
  ningún otro ruido lo desvía y al llegar olvida lo que había visto. El uniforme de conserje
  sirve en todos los cuartos y Valeria avisa cuando pasas junto al casillero. Valeria usa
  frases programadas según lo que pasa; la IA y la voz quedan con `usar_ia=si`.
- 2026-10-29: arreglos después de probar en el juego principal.
  - **Uniforme:** caminando con el uniforme nadie se fija en ti en ningún cuarto. Los pasos ya no hacen que los vigilantes vayan a revisar y las cámaras tampoco te notan. Solo te descubren si estás pegado a un vigilante (a menos de 1 baldosa), si corres, te agachas o arrastras a alguien, o si el jefe te ve de cerca.
  - **Voz de Valeria sin esperas:** si internet falla, durante 40 s no se vuelve a intentar y Valeria habla en texto con sus frases de respaldo (las que ya tienen voz guardada suenan). Cada pedido espera a lo sumo 5 s. Una frase que llega tarde y ya no viene al caso no se dice, y la pausa entre frases bajó a 9 s.
  - **Voces guardadas:** al abrir, se graban en `data/voz/` las frases de respaldo que falten. Solo pasa una vez y necesita internet; después suenan sin conexión.
  - **Letra nítida:** el HUD en pixel se dibujaba con suavizado, porque `noSmooth()` estaba después de `beginDraw()` y Processing lo ignora. Por eso al agrandarlo se veía borroso. Ahora se llama al crear la capa.

