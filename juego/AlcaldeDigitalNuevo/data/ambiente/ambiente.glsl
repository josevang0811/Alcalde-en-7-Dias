// Corrección de color del mundo abierto (Ambiente.pde).
// Son las mismas cuentas de herramientas/ambiente_pruebas.py: bajar la
// saturación, teñir sombras y luces, subir el contraste y oscurecer.
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform float saturacion;     // 1 = igual, 0 = blanco y negro
uniform vec3 tonoSombras;     // color que toman las partes oscuras
uniform vec3 tonoLuces;       // color que toman las partes claras
uniform float fuerzaTono;     // cuánto se tiñe (0 a 1)
uniform float contraste;
uniform float centroContraste;
uniform float brillo;         // multiplica todo al final
uniform float vineta;         // qué tanto se oscurecen los bordes

varying vec4 vertColor;
varying vec4 vertTexCoord;

float luminancia(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec4 original = texture2D(texture, vertTexCoord.st);
    vec3 c = original.rgb;
    float l = luminancia(c);
    c = vec3(l) + (c - vec3(l)) * saturacion;
    vec3 tinte = mix(tonoSombras, tonoLuces, clamp(luminancia(c), 0.0, 1.0));
    c = mix(c, c * tinte * 1.6, fuerzaTono);
    c = (c - vec3(centroContraste)) * contraste + vec3(centroContraste);
    c *= brillo;
    vec2 d = (vertTexCoord.st - 0.5) * 2.0;
    c *= 1.0 - vineta * pow(clamp(length(d) - 0.45, 0.0, 1.0), 1.5);
    gl_FragColor = vec4(clamp(c, 0.0, 1.0), original.a) * vertColor;
}
