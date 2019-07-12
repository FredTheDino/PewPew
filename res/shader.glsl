#version 130
#define VERT

uniform mat4 view;
uniform vec3 position;
uniform float time;

#ifdef VERT

in vec3 in_position;

void main()
{
	gl_Position = vec4(in_position + position, 1) * view;
}

#else

out vec4 out_color;

void main()
{
	out_color = vec4(1.0, 0.0, sin(time) * 0.5 + 0.5, 1.0) * (1.0 - gl_FragCoord.z);
}

#endif
