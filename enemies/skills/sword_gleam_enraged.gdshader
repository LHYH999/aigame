shader_type canvas_item;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float energy = max(source.r, max(source.g, source.b));
	vec3 shadow_purple = vec3(0.28, 0.08, 0.48);
	vec3 core_purple = vec3(0.90, 0.58, 1.0);
	vec3 enraged_color = mix(
		shadow_purple,
		core_purple,
		smoothstep(0.12, 0.88, energy)
	);
	COLOR = vec4(enraged_color, source.a);
}
