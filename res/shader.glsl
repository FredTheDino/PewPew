#version 130
#define VERT

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

uniform float time;

uniform bool use_color;
uniform vec3 color;
uniform sampler2D color_texture;

#ifdef VERT

in vec3 in_position;
in vec2 in_uv;

out vec3 pass_color;
out vec2 pass_uv;

void main()
{
	gl_Position = proj * view * model * vec4(in_position, 1);

    pass_uv = in_uv;
    
    if (use_color) {
        pass_color = color;
    }
}

#else

in vec3 pass_color;
in vec2 pass_uv;

out vec4 out_color;

void main()
{
    if (use_color)
        out_color = vec4(pass_color, 1.0);
    else
        out_color = texture(color_texture, pass_uv);
}

#endif
