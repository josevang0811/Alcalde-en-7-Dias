// Ambiente — la corrección de color del mundo abierto (versión de prueba).
// En el juego completo esto lo hace Ambiente.pde de AlcaldeEn7Dias,
// que además permite cambiarlo con F8 y lo guarda en data/ajustes.txt.
// Aquí está apagado; con ambienteEnPrueba = true se usa el de noche.

boolean ambienteEnPrueba = false;

PShader shaderPrueba;
boolean ambientePruebaFallo = false;

void aplicarAmbiente() {
  if (ambientePruebaFallo || !ambienteEnPrueba) return;
  try {
    if (shaderPrueba == null) {
      shaderPrueba = loadShader("ambiente/ambiente.glsl");
      shaderPrueba.set("saturacion", 0.35);
      shaderPrueba.set("tonoSombras", 0.26, 0.34, 0.62);
      shaderPrueba.set("tonoLuces", 0.62, 0.72, 0.95);
      shaderPrueba.set("fuerzaTono", 0.85);
      shaderPrueba.set("contraste", 1.25);
      shaderPrueba.set("centroContraste", 0.45);
      shaderPrueba.set("brillo", 0.55);
      shaderPrueba.set("vineta", 0.6);
    }
    filter(shaderPrueba);
  } catch (Exception e) {
    ambientePruebaFallo = true;
  }
}
