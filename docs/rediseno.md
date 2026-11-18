# Rediseño: historia y jugabilidad

Después de presentar, la profesora pidió dos cosas: más jugabilidad (elegir una tarjeta se siente como un examen) y una introducción que dé contexto. Este documento es el plan.

## La historia

Andrés tiene 16 años y lo acosan en redes: publican fotos editadas de él, lo etiquetan, se burlan. Un día, en el balcón, su hermano menor Mateo llega a buscarlo para jugar. Andrés le dice que no viva la vida que él vivió. Veinticinco años después, Mateo es candidato y quiere hacer campaña de otra forma: que la gente mida el impacto de lo que publica.

El prólogo sugiere lo que pasa, pero no lo muestra: hay un corte a negro y se oye un golpe. Al empezar hay un aviso de contenido con la Línea 192, opción 4 (hay que confirmar que siga vigente antes de entregar).

## La idea central

Hoy el jugador decide en la oficina y el resultado es un número. En el rediseño, **cada día es un caso**: un bulo que se hace viral en Civitas. El caso se juega en tres actos, y cada acto deja algo que se usa en el siguiente:

```
INVESTIGAR  ──pistas──▶  CONTENER  ──cuánto se regó──▶  DEBATIR  ──▶  consecuencias
(la publicación)          (el grafo de Civitas)            (en vivo, contra Morales)
```

**La tensión que une todo:** mientras más tiempo se investiga, más turnos de ventaja le saca el bulo en el grafo. Investigar bien da mejores herramientas, pero se paga con tiempo.

## La oficina pierde peso

La oficina deja de ser donde se juega. Queda como transición entre días:

- **Mañana (unos 20 s):** suena el teléfono y Marta Ríos cuenta el caso del día. Es la entrada al acto 1.
- **Noche (unos 30 s):** el noticiero cuenta qué pasó, se ve el diagrama de decisiones del día y se gastan puntos en el libro de habilidades.

El mapa de barrios de la oficina se reemplaza por la red de Civitas del acto 2. Los minijuegos que ya existen pasan a ser parte de los casos (ver más abajo).

## Acto 1 — Investigar (como el braindance de Cyberpunk 2077)

La publicación viral se abre como un video corto de 15 a 20 segundos que se puede adelantar y retroceder.

- **Línea de tiempo:** se recorre con A/D o con el mouse.
- **Tres capas:** `IMAGEN` (lo que se ve), `COMENTARIOS` (quién reacciona y cuándo) y `CUENTA` (quién publicó, desde cuándo existe, a quién sigue). Cada pista solo aparece en una capa y en un momento.
- **Pistas:** al encontrar una (clic sobre ella en el momento y la capa correctos) se guarda como **carta de evidencia**. Ejemplos: "el video está cortado justo antes del empujón", "la cuenta se creó ayer", "40 comentarios con la misma frase".
- **Pistas falsas:** cosas que parecen sospechosas pero no prueban nada. Si se usan en el debate, restan.
- **El reloj:** cada 15 segundos investigando, el bulo avanza un turno en el acto 2. Se puede cerrar la investigación cuando uno quiera.

*Estructuras:* la línea de tiempo es un arreglo de cuadros; las pistas, una lista ordenada por tiempo; las cartas ganadas, una lista que pasa a los actos 2 y 3.

## Acto 2 — Contener (problema del bombero en grafos)

La red de Civitas se ve en grande: 25 a 40 cuentas (personas, grupos, medios, influencers y bots) unidas por quién sigue a quién.

- **El contagio:** cada turno, el bulo pasa de las cuentas que lo tienen a sus vecinas, nivel por nivel (BFS). Las cuentas crédulas se contagian siempre; las escépticas, con probabilidad.
- **Las acciones del jugador** (3 puntos por turno):
  - **Verificar** una cuenta (1 punto): ya no se contagia.
  - **Hablar con un influencer** (2 puntos): lo protege a él y a parte de sus seguidores.
  - **Desmentir con prueba** (2 puntos): solo con una carta del acto 1. Protege una cuenta y a todas sus vecinas.
  - **Reportar un bot** (1 punto): saca del grafo una cuenta marcada como bot. Solo se sabe cuál es bot si en el acto 1 se encontró la pista.
  - **Rastrear** (1 punto): muestra de quién le llegó el bulo a una cuenta. Siguiendo esas flechas hacia atrás (BFS inverso, el árbol de padres) se llega a quien lo publicó primero. Encontrarlo y reportarlo detiene el contagio.
- **Final del acto:** cuando el bulo ya no puede avanzar. El porcentaje de la red contagiada pasa al acto 3.

*Estructuras:* grafo con listas de adyacencia, cola para el BFS de cada turno, conjunto de contagiados, arreglo de padres (el árbol BFS) para rastrear el origen.

## Acto 3 — Debatir (como los juicios de Ace Attorney)

En la noche hay un debate en vivo: Marta modera y Morales defiende el bulo.

- **El testimonio:** Morales dice entre 4 y 6 afirmaciones que se repiten en ciclo. Se avanza y se retrocede entre ellas.
- **Presionar:** pedir que explique una afirmación. A veces revela una nueva o una pista.
- **Objetar:** mostrar una carta de evidencia contra una afirmación. Si la contradice, el público sube y aparece la siguiente parte del testimonio. Si no, baja la credibilidad.
- **Afirmaciones verdaderas:** no todo lo que dice el rival es falso. Objetar algo cierto resta, para enseñar a no desmentir por desmentir.
- **El público:** una barra de apoyo en vivo con los comentarios de Civitas pasando al lado. Empieza más baja si en el acto 2 se contagió mucha gente.

*Estructuras:* el testimonio es una lista circular doblemente enlazada (siguiente y anterior, y del último se vuelve al primero).

## Integridad y popularidad (como el honor de Red Dead Redemption 2)

En cada acto hay un atajo sucio que funciona:

| Acto | Atajo | Gana | Pierde |
|---|---|---|---|
| Investigar | Pedirle a la IA que fabrique una prueba | Una carta fuerte al instante | Integridad; si Marta lo descubre, mucho más |
| Contener | Lanzar un bulo contra Morales | El bulo propio corre más rápido que el de él | Integridad |
| Debatir | Ataque personal en vez de argumento | Público en el momento | Integridad, y Valeria lo celebra |

Morales va ganando porque juega sucio, y Valeria presiona para hacer lo mismo. El final depende de las dos barras:

| Cómo se jugó | Final |
|---|---|
| Ganar sucio | El último plano es un niño mirando su celular en un balcón. |
| Perder limpio | Final digno y agridulce. |
| Ganar limpio | El final difícil, el que vale la pena. |

## Los minijuegos que ya existen

| Hoy | En el rediseño |
|---|---|
| Infiltrado | Caso del día 4: entrar a la granja de bots de Morales. Si sale bien, en el acto 2 se ven todos los bots marcados. |
| Mitin en el parque | Caso del día 3: un agitador riega el rumor en la plaza. Se encuentra por pistas (como el modo escucha de The Last of Us) antes de que lo cuente a todos. |
| Lives con trolls | Se queda como evento corto entre días. |

## Personas que vuelven

Tres o cuatro personajes fijos aparecen en varios casos. Por ejemplo, Sofía (15 años) es el tema del bulo del día 2. Si ese día se contuvo mal, en el día 5 aparece en el noticiero. Así la consecuencia es una persona y no un número.

## Diagrama de decisiones (como Detroit: Become Human)

Al cerrar cada día se muestra el árbol de lo que se eligió en ese caso: las ramas tomadas y las que quedaron con candado. Es un árbol n-ario y da ganas de volver a jugar.

## Estructuras de datos del juego completo

| Estructura | Dónde |
|---|---|
| Grafo con listas de adyacencia | Red de Civitas (acto 2) |
| BFS y árbol de padres | Contagio por niveles y rastreo del origen |
| Lista circular doble | Testimonio del debate (acto 3) |
| Lista ordenada | Pistas de la investigación (acto 1) |
| Árbol n-ario | Habilidades y diagrama de decisiones |
| Cola | Planos de las cinemáticas |
| Grafo con pesos y Dijkstra | Ciudad del mundo abierto (ya existe) |

## Cómo se arma sin perderse

1. **Un día completo primero.** El día 1 entero (llamada, los tres actos y el cierre) antes de hacer los otros seis. Si el día 1 no es divertido, se corrige ahí y no en siete lugares.
2. **Los casos son datos, no código.** Cada caso es un archivo (`data/casos/dia1.txt`) con la publicación, las pistas, el grafo y el testimonio. Escribir los siete días es trabajo de guion, no de programación.
3. **Orden de programación:** primero el acto 2 (el grafo; es lo más jugable y lo que más muestra el curso), después el acto 3, después el acto 1. Mientras el acto 1 no exista, el acto 2 arranca con pistas de prueba.
4. **Arte por partes:** retratos de Marta, Morales y Mateo para el debate; la red de Civitas puede ser de nodos y líneas en pixel art; la publicación del acto 1 necesita un video corto por caso, que puede hacerse con capas de imágenes (como las cinemáticas).

## Estado

| Parte | Estado |
|---|---|
| Prólogo y motor de cinemáticas | Hecho, con bocetos |
| Paleta profunda del mundo abierto | Hecho (nivel 1.4) |
| Retrato grande de Valeria | El código está listo; falta el dibujo |
| Acto 2 (contener en el grafo) | Siguiente |
| Acto 3 (debate) | Pendiente |
| Acto 1 (investigar) | Pendiente |
| Integridad y popularidad, finales | Pendiente |
