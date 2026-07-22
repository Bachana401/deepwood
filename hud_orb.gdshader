shader_type canvas_item;

// MU Online / Diablo liquid globe, lit as a real 3D sphere (dev ask 2026-07-22:
// "make it 3d"). The glass is treated as a sphere: a surface normal is rebuilt
// per-pixel (z = sqrt(1 - x^2 - y^2)) and lit with diffuse + a specular hotspot
// + a fresnel rim, so it reads as a round glass ball. The liquid surface is
// BOWED into a shallow ellipse (not a flat line) to sell the curvature, ripples
// via `t`, and `fill` (0..1) sets its level. UV-based, renders at any size.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec3 liquid_top : source_color = vec3(0.95, 0.25, 0.22);
uniform vec3 liquid_bottom : source_color = vec3(0.45, 0.03, 0.05);
uniform vec3 frame_col : source_color = vec3(0.60, 0.48, 0.28);
uniform float t = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // -1..1, centre 0
	float r = length(p);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (r <= 1.0) {
		if (r > 0.86) {
			// beveled metal frame ring, lit from the upper-left for depth
			float fb = (r - 0.86) / 0.14;
			float bev = clamp(1.0 - abs(fb - 0.45) * 2.0, 0.0, 1.0);
			vec3 fr = frame_col * (0.42 + 0.72 * bev);
			fr *= 0.62 + 0.6 * clamp(0.5 - (p.x + p.y) * 0.5, 0.0, 1.0);
			col = fr;
			alpha = 1.0;
		} else {
			// --- rebuild the sphere surface normal and light it ---
			vec2 g = p / 0.86;                              // -1..1 inside the glass
			float z = sqrt(max(0.0, 1.0 - dot(g, g)));
			vec3 N = normalize(vec3(g, z));
			vec3 L = normalize(vec3(-0.45, -0.6, 0.66));    // upper-left-front light
			vec3 Vv = vec3(0.0, 0.0, 1.0);
			float diff = 0.36 + 0.64 * clamp(dot(N, L), 0.0, 1.0);
			float spec = pow(clamp(dot(reflect(-L, N), Vv), 0.0, 1.0), 45.0);
			float fres = pow(1.0 - clamp(dot(N, Vv), 0.0, 1.0), 3.0);

			// --- liquid with a bowed (elliptical) 3D surface ---
			float wave = sin(g.x * 7.0 + t * 2.0) * 0.008 + sin(g.x * 13.0 - t * 1.5) * 0.005;
			float bow = (1.0 - g.x * g.x) * 0.05;           // curve the meniscus up at centre
			float surf = (1.0 - fill) - bow + wave;         // surface height in UV.y space
			float alp = 1.0;
			if (UV.y >= surf) {
				float depth = clamp((UV.y - surf) / max(0.001, 1.0 - surf), 0.0, 1.0);
				col = mix(liquid_top, liquid_bottom, depth) * diff;
				col = mix(col, vec3(1.0), smoothstep(0.055, 0.0, abs(UV.y - surf)) * 0.55); // meniscus
				col += (sin(g.x * 10.0 - t * 3.0) * 0.5 + 0.5) * (1.0 - depth) * 0.05;      // caustic
			} else {
				col = vec3(0.05, 0.06, 0.10) * diff;        // empty glass, still shaded round
				alp = 0.70;
			}
			// glass reflections layered over liquid + empty alike
			col += spec * 0.9;                                        // sharp specular hotspot
			col += fres * vec3(0.5, 0.55, 0.7) * 0.35;               // fresnel rim glow
			col += smoothstep(0.6, 0.0, length(p - vec2(-0.32, -0.42))) * 0.14; // soft gloss
			alpha = alp;
		}
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
