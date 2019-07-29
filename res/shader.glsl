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
in vec3 in_normal;
in vec2 in_uv;

out vec3 pass_color;
out vec3 pass_normal;
out vec2 pass_uv;

void main()
{
	gl_Position = proj * view * model * vec4(in_position, 1);

    pass_uv = in_uv;
    pass_normal = (model * vec4(in_normal, 0)).xyz;
    
    if (use_color) {
        pass_color = color;
    }
}

#else

in vec3 pass_color;
in vec3 pass_normal;
in vec2 pass_uv;


out vec4 out_color;

void main()
{
    vec3 light_dir = normalize(vec3(sin(time), 1, cos(time)));
    float lightness = max(dot(normalize(pass_normal), light_dir), 0);
    if (use_color)
        out_color = vec4(pass_color, 1.0);
    else
        out_color = texture(color_texture, pass_uv) * lightness;
}

#endif
