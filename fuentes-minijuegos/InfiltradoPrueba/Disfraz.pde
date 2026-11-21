// Disfraz de conserje. En el casillero del aseo hay uniformes (uno por
// jugador). Con el uniforme puesto, caminando, nadie se fija en ti en ningún
// cuarto de la sede: ni los vigilantes (salvo que estés pegado a ellos), ni
// los empleados, ni las cámaras, y tus pasos no los hacen ir a revisar. Se
// nota solo si:
//   - corras, te agaches o arrastres un cuerpo (un conserje no hace eso),
//   - el jefe de seguridad te vea de cerca: el si conoce a su gente.
// Si un vigilante te descubre, el disfraz queda quemado.

final float DISTANCIA_JEFE = 3;
final float DISTANCIA_PEGADO = 1.0;   // a menos de esto cualquier vigilante ve que no eres el conserje

// Cuanto se multiplica la sospecha de quien mira a este jugador.
// esJefe: si quien mira es el jefe de seguridad. d: distancia.
float factorDisfraz(Jugador j, boolean esJefe, float d) {
  if (!j.disfrazado) return 1;
  if (j.corriendo || j.agachado || j.arrastrando != null) return 1;
  if (esJefe && d < distanciaJefe()) return 1.6;   // el jefe te reconoce
  if (d < DISTANCIA_PEGADO) return 1;                // pegado a un vigilante, se nota
  return 0;
}

// Los empleados no se fijan en un conserje que hace lo suyo
float factorDisfrazCivil(Jugador j) {
  if (!j.disfrazado) return 1;
  if (j.corriendo || j.agachado || j.arrastrando != null) return 1;
  return 0;
}

boolean puedeTomarUniforme(Jugador j) {
  return !j.disfrazado && mapa.cercano(j.x, j.y, 'Z', 1.5) != null;
}

void ponerseUniforme(Jugador j) {
  j.disfrazado = true;
  sonar("recoger");
  j.agachado = false;
  avisar("Uniforme puesto: no te reconocen salvo que te les pegues. Camina normal y evita al jefe (gorra blanca)");
}

// Te descubrieron: el disfraz ya no sirve
void quemarDisfraz(Jugador j) {
  if (j == null || !j.disfrazado) return;
  j.disfrazado = false;
  j.disfrazQuemado = true;
}

// Avisa una vez al entrar disfrazado a un cuarto donde un conserje no entra
void revisarZonaDisfraz(Jugador j) {
  // el uniforme ya sirve en todos los cuartos; solo avisa una vez cuando
  // pasas cerca del casillero sin tenerlo puesto
  boolean cerca = puedeTomarUniforme(j);
  if (cerca && !j.avisoZona) eventoValeria("uniforme", 2, "", "En ese casillero hay uniformes de conserje. Póntelo con E: así casi nadie te reconoce.");
  if (cerca) j.avisoZona = true;
}
