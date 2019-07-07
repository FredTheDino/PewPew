#version 130
#define VERT

uniform mat4 view;
uniform float time;

#ifdef VERT

in vec3 in_position;

vec3 rotateX(vec3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return vec3(
            p.x,
            p.y * c - p.z * s,
            p.y * s + p.z * c);
}

vec3 rotateZ(vec3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return vec3(
            p.x * c - p.y * s,
            p.x * s + p.y * c,
            p.z);
}
void main()
{
	gl_Position = vec4(rotateZ(rotateX(in_position, time), time * 0.45653), 1);
}

#else

out vec4 out_color;

void main()
{
	out_color = vec4(1.0, 0.0, sin(time) * 0.5 + 0.5, 1.0) * gl_FragCoord.z;
}

#endif
