# Mete el sketch InfiltradoPrueba dentro de Alcalde Digital como una sola
# clase (Infiltrado.pde). Todo lo de la mision queda adentro de la clase, asi
# sus variables y funciones no chocan con las del juego principal.
# Uso: python3 fusionar.py <carpeta del sketch> <carpeta AlcaldeDigitalNuevo>
# Sirve para InfiltradoPrueba (clase Infiltrado) y MundoAbiertoPrueba (clase MundoAbierto).
import os, re, sys, shutil
src, dst = sys.argv[1], sys.argv[2]
SKETCH = os.path.basename(os.path.normpath(src))
CONF = {
    'InfiltradoPrueba': dict(clase='Infiltrado', preparar='prepararMision', cabecera='''
// Infiltrado — la mision de sigilo de la ronda 2, dentro de Alcalde Digital.
//
// Es el sketch InfiltradoPrueba completo metido en una sola clase: asi sus
// variables (estado, escala, mapa...) y sus funciones no chocan con las del
// juego principal, que tiene unas con el mismo nombre. setup() se llama
// prepararMision(), draw() se llama dibujar() y las teclas llegan por
// teclaPresionada() y teclaSoltada(). El juego principal la crea una vez,
// le pasa los datos de la campana con configurarCampana() y, al terminar,
// la mision llama a volverALaCampana() (MisionCampana.pde).
//
// No se edita a mano: se arma con herramientas/fusionar.py a partir de la
// carpeta InfiltradoPrueba (cada parte lleva arriba el nombre de su archivo).
'''),
    'MundoAbiertoPrueba': dict(clase='MundoAbierto', preparar='prepararMundo', cabecera='''
// MundoAbierto — la ciudad y los eventos del parque (rondas 3 y 4), dentro
// de Alcalde Digital.
//
// Es el sketch MundoAbiertoPrueba completo metido en una sola clase, igual
// que Infiltrado. setup() se llama prepararMundo(), draw() se llama
// dibujar() y las teclas llegan por teclaPresionada() y teclaSoltada(). El
// juego empieza cada evento con configurarEvento() y, al terminar, el mundo
// llama a volverALaOficina() (EventoParque.pde).
//
// No se edita a mano: se arma con herramientas/fusionar.py a partir de la
// carpeta MundoAbiertoPrueba (cada parte lleva arriba el nombre de su archivo).
'''),
}[SKETCH]
archivos = [SKETCH + '.pde'] + sorted(f for f in os.listdir(src) if f.endswith('.pde') and f != SKETCH + '.pde')
imports = []
cuerpo = []
for f in archivos:
    t = open(os.path.join(src, f), encoding='utf-8').read()
    t = re.sub(r'// <solo-sketch>.*?// </solo-sketch>\n', '', t, flags=re.S)
    lineas = []
    for l in t.split('\n'):
        if l.startswith('import '):
            if l not in imports:
                imports.append(l)
            continue
        lineas.append(l)
    t = '\n'.join(lineas)
    if f == SKETCH + '.pde':
        t = t.replace('void setup() {', 'void ' + CONF['preparar'] + '() {', 1)
        t = t.replace('void draw() {', 'void dibujar() {', 1)
        t = t.replace('void keyPressed() {', 'void teclaPresionada() {', 1)
        t = t.replace('void keyReleased() {', 'void teclaSoltada() {', 1)
        t = re.sub(r'\n  fullScreen\(P2D\);[^\n]*', '', t, 1)
        t = re.sub(r'\n  noSmooth\(\);[^\n]*', '', t, 1)
        t = re.sub(r'\n  // En OpenGL hay que pedir aparte[^\n]*\n  if \(g instanceof PGraphicsOpenGL\)[^\n]*', '', t, 1)
    cuerpo.append('// ' + '=' * 70 + '\n// ' + f + '\n// ' + '=' * 70 + '\n' + t)
imports = [i for i in imports if 'processing.opengl' not in i]
salida = '\n'.join(imports) + '\n' + CONF['cabecera'] + '''
class ''' + CONF['clase'] + ''' {

''' + '\n\n'.join(cuerpo) + '\n}\n'
open(os.path.join(dst, CONF['clase'] + '.pde'), 'w', encoding='utf-8').write(salida)
# los datos van a la misma carpeta data/ (no hay nombres repetidos)
for raiz, dirs, fs in os.walk(os.path.join(src, 'data')):
    for f in fs:
        if f.endswith('.mp3') or f in ('valeria.txt', 'resultado.txt'):
            continue
        rel = os.path.relpath(os.path.join(raiz, f), os.path.join(src, 'data'))
        destino = os.path.join(dst, 'data', rel)
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copy(os.path.join(raiz, f), destino)
print(len(archivos), 'archivos ->', len(salida.splitlines()), 'lineas')
