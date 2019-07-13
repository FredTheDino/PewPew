#version 130
#define VERT

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

uniform float time;

#ifdef VERT

in vec3 in_position;
out vec3 pass_color;

void main()
{
	gl_Position = proj * view * model * vec4(in_position, 1);

    float color = mod(gl_VertexID, 3);
    if (color < 1)
        pass_color = vec3(1, 0, 0);
    else if (color < 2)
        pass_color = vec3(0, 1, 0);
    else
        pass_color = vec3(0, 0, 1);
}

#else

in vec3 pass_color;
out vec4 out_color;

void main()
{
	out_color = vec4(pass_color, 1.0);
}

#endif
