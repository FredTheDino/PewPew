#version 130
#define VERT
uniform float time;

uniform bool use_color;
uniform sampler2D color_texture;

uniform vec2 min_pos;
uniform vec2 max_pos;

#ifdef VERT

in vec3 in_position;
in vec3 in_normal;
in vec2 in_uv;

out vec2 pass_uv;

void main()
{
	vec2 normalized = in_position.xy * 0.5 + vec2(0.5, 0.5);
	gl_Position = vec4(min_pos + (normalized * (max_pos - min_pos)), 0.5, 1);
    pass_uv = in_position.xy * 0.5 + vec2(0.5, 0.5);
}

#else

in vec2 pass_uv;


out vec4 out_color;

void main()
{
	out_color = texture(color_texture, pass_uv);
}

#endif
