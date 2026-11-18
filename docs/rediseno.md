# Rediseño: historia y jugabilidad

Después de presentar, la profesora pidió dos cosas: más jugabilidad (elegir una tarjeta se siente como un examen) y una introducción que dé contexto. Esto es el plan y lo que ya está hecho.

## La historia

Andrés tiene 16 años y lo acosan en redes: publican fotos editadas de él, lo etiquetan, se burlan. Un día, en el balcón, su hermano menor Mateo llega a buscarlo para jugar. Andrés le dice que no viva la vida que él vivió. Veinticinco años después, Mateo es candidato y quiere hacer campaña de otra forma: que la gente mida el impacto de lo que publica.

El prólogo sugiere lo que pasa, pero no lo muestra: hay un corte a negro y se oye un golpe. Al empezar hay un aviso de contenido con la Línea 192, opción 4 (hay que confirmar que siga vigente antes de entregar).

## El problema de jugabilidad

Hoy casi siempre se nota cuál es la tarjeta "correcta", así que la decisión no pesa. El tema (las redes) está en los textos, pero no en lo que hace el jugador. La idea es que el jugador **investigue, contenga y convenza**, y que cada actividad le sirva para la siguiente.

## Un día de campaña

| Momento | Ritmo | Qué se hace | Qué se gana |
|---|---|---|---|
| Mañana | Calma | Llega un bulo. Se investiga la publicación: quién la subió, cuándo, qué dicen los comentarios, si la imagen está editada. | Cartas de evidencia |
| Tarde | Acción | Contener la propagación en el grafo de Civitas, o un minijuego (Infiltrado en la granja de bots, mitin en el parque). | Más evidencia o menos daño |
| Noche | Tensión | Debate o entrevista: el rival ataca y se responde con las cartas de evidencia. Luego, una escena corta con las consecuencias. | Apoyo, credibilidad, avance de la historia |

## Mecánicas nuevas

- **Investigar (como el braindance de Cyberpunk 2077):** la publicación se recorre en el tiempo y por capas (imagen, comentarios, cuenta, fecha). Cada pista encontrada es una carta.
- **Contener (problema del bombero en grafos):** el bulo avanza por el grafo de cuentas de Civitas turno a turno. Cada turno se pueden "verificar" k cuentas para cortar el contagio. Variante: recorrer el grafo hacia atrás (BFS inverso) para encontrar quién lo publicó primero.
- **Debatir (como las objeciones de Ace Attorney):** el rival afirma algo y se responde con la carta de evidencia correcta. Sin investigación no hay argumentos. Reemplaza las seis tarjetas de hoy.
- **Integridad y popularidad (como el honor de Red Dead Redemption 2):** jugar sucio sube la popularidad rápido; jugar limpio, la integridad. Morales gana jugando sucio y Valeria presiona para hacer lo mismo. El final depende de las dos barras.
- **Personas que vuelven:** tres o cuatro personajes fijos (por ejemplo Sofía, de 15 años) que aparecen días después según lo que se publicó sobre ellos.
- **Diagrama de decisiones (como Detroit: Become Human):** al final de cada día, el árbol de lo que se eligió y lo que quedó bloqueado.

## Estructuras de datos

| Estructura | Dónde |
|---|---|
| Grafo con listas de adyacencia | Red de cuentas de Civitas, propagación del bulo |
| BFS y BFS inverso | Contagio por niveles, rastreo del origen |
| Árbol n-ario | Árbol de habilidades, diagrama de decisiones del día |
| Cola | Planos de las cinemáticas (`Cinematica.pde`) |
| Cola de prioridad | Eventos de Valeria en Infiltrado |
| Dijkstra | Recorrido de la publicación, rutas de la gira |

## Orden de trabajo

1. **Prólogo y motor de cinemáticas.** Hecho, con bocetos (ver `guia-personajes.md`).
2. **Color del mundo abierto.** Hecho: cuatro ambientes, se cambian con F8.
3. **Retratos de alta resolución.** El código ya está listo para Valeria; falta el dibujo.
4. Contener el bulo en el grafo.
5. Debate con cartas de evidencia.
6. Investigación y diagrama de decisiones, si alcanza el tiempo.
