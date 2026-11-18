# Convenciones del proyecto

Alcalde en 7 Días: juego en Processing 4 (Java) para Estructura de Datos II, Universidad del Norte.

## Idioma

- Todo en español neutro: textos del juego, comentarios, documentación y mensajes de commit. Sin voseo.
- Comentarios y documentación con redacción natural, sin tono de texto generado.

## Dónde está cada cosa

- `juego/AlcaldeDigitalNuevo/`: el juego. Se abre `AlcaldeDigitalNuevo.pde` en Processing.
- `fuentes-minijuegos/`: los sketches de Infiltrado y del mundo abierto.
- `herramientas/`: scripts de Python (pruebas de color y bocetos del prólogo).
- `docs/`: rediseño, guía de personajes, notas de desarrollo y capturas.

## Reglas

- `Infiltrado.pde` y `MundoAbierto.pde` no se editan a mano: salen de `fuentes-minijuegos/` con `fuentes-minijuegos/MundoAbiertoPrueba/herramientas/fusionar.py`. Un cambio se hace en el sketch de la prueba, y también en el archivo fusionado si no se va a volver a fusionar enseguida.
- `fuentes-minijuegos/MundoAbiertoPrueba/Ambiente.pde` es solo de la prueba (fusionar.py lo salta).
- Nunca subir `data/valeria.txt` (claves), `.env`, la música de `data/musica/` ni archivos `.mp3`.
- Todo el texto en pantalla usa la letra pixel (`LetraGlobal.pde` y `textoPixel` de `Diseno.pde`). Para animar transparencia de texto se usa `tint()`, no el alfa del color: los textos se guardan en caché por color.
- El juego usa `textureSampling(2)` (pixeles nítidos). Un shader que lea otra textura con coordenadas que saltan entre pixeles vecinos puede mezclar colores en los bordes; por eso `ambiente.glsl` hace las cuentas en vez de usar una tabla de color.
- Las cinemáticas se escriben en `data/cinematicas/*.txt` (órdenes al principio de `Cinematica.pde`). Lienzo de 320x180.
- Los retratos van en `data/retratos/` (ver `docs/guia-personajes.md`).

## Compilar y probar sin pantalla

```
Processing cli --sketch=juego/AlcaldeDigitalNuevo --output=/tmp/salida --force --build
xvfb-run -a -s "-screen 0 1920x1080x24" Processing cli --sketch=... --output=... --force --run
```

Para probar una pantalla sin jugar hasta ella, se hace una copia del sketch con un archivo extra que llama a la función que interesa (por ejemplo `empezarCinematica("prologo", "")`) y guarda cuadros con `saveFrame`. Ese archivo de prueba no se sube.
