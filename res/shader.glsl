#version 130
#define VERT

uniform mat4 view;
uniform mat4 proj;
uniform mat4 model;

uniform float time;

uniform bool use_color;
uniform bool render_shadow_map;
uniform vec3 color;
uniform sampler2D color_texture;
uniform sampler2D shadow_map;

uniform mat4 light_rotation;
uniform mat4 light_projection;

#ifdef VERT

in vec3 in_position;
in vec3 in_normal;
in vec2 in_uv;

out vec3 pass_color;
out vec3 pass_normal;
out vec2 pass_uv;
out vec3 pass_light_coord;

void main()
{
    vec4 world_pos = model * vec4(in_position, 1);
    vec3 light_pos = (light_projection * light_rotation * world_pos).xyz;
    pass_light_coord = light_pos * 0.5 + vec3(0.5, 0.5, 0.5);
    gl_Position = proj * view * world_pos;

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
in vec3 pass_light_coord;

out vec4 out_color;


float dept_blur(sampler2D map, vec2 uv, float toLight) {
    float bias = 0.010;
    float delta = 1.0 / (512.0 * 3);
    float sum = 0.0;
    const int kernel_n = 3;
    for (int x = -kernel_n; x < kernel_n; x++) {
        for (int y = -kernel_n; y < kernel_n; y++) {
            float toShadow = texture(map, uv + vec2(x * delta, y * delta)).z;
            sum += step(toLight, toShadow + bias);
        }
    }
    return sum / pow(kernel_n * 2 + 1, 2);
}

void main()
{
    if (render_shadow_map) {
        out_color = vec4(gl_FragCoord.zzz, 1.0);
        return;
    }

    if (use_color) {
        out_color = vec4(pass_color, 1.0);
        return;
    }

    vec4 shadow_tint = vec4(0.02, 0.01, 0.04, 1.0);
    vec4 light_tint = vec4(1.1, 1.0, 1.0, 1.0);
    vec3 light_dir = vec3(light_rotation[0][2], 
                          light_rotation[1][2],
                          light_rotation[2][2]);
    float light = max(dot(normalize(pass_normal), light_dir), 0.0);
    float shadow = dept_blur(shadow_map, pass_light_coord.xy, pass_light_coord.z); 
    float lightness = min(light, shadow);

    vec4 texture_color = texture(color_texture, pass_uv);
    out_color = texture_color * mix(shadow_tint, light_tint, lightness);
    
}

#endif
