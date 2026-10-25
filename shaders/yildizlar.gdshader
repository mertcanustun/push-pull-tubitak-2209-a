// Yıldız küresi (Gokyuzu). Kameranın etrafında büyük, içten görünen bir küre.
// Yıldızlar yönün 3B hücre ızgarasında rastgele seçilen noktalarıdır; doku yok.
// "yogunluk" 0 iken küre zaten gizlenir (bkz. scripts/gokyuzu.gd).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled, blend_mix;

uniform float yogunluk : hint_range(0.0, 1.0) = 0.0;
uniform float olcek = 220.0;     // büyük = daha küçük ve sık yıldız
uniform float esik : hint_range(0.9, 1.0) = 0.982;  // büyük = daha az yıldız
uniform float boyut : hint_range(0.05, 0.5) = 0.30;
uniform vec3 renk : source_color = vec3(0.92, 0.95, 1.0);

varying vec3 yon;

void vertex() {
	yon = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 g = normalize(yon) * olcek;
	vec3 hucre = floor(g);
	float r = length(fract(g) - 0.5);
	float h = hash(hucre);
	float parlak = hash(hucre + 7.31);
	float nokta = step(esik, h) * smoothstep(boyut * (0.5 + parlak), 0.0, r);
	ALBEDO = renk * (0.55 + 0.9 * parlak);
	ALPHA = clamp(nokta * yogunluk, 0.0, 1.0);
}
