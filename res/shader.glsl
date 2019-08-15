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

const vec4 shadow_tint = vec4(0.1, 0.2, 0.1, 1.0);

float dept_blur(sampler2D map, vec2 uv) {
    float delta = 0.001;
    float d0 = texture(shadow_map, uv + vec2( 0 * delta, 0 * delta)).z;
    float d1 = texture(shadow_map, uv + vec2( 1 * delta, 0 * delta)).z;
    float d2 = texture(shadow_map, uv + vec2(-1 * delta, 0 * delta)).z;
    float d3 = texture(shadow_map, uv + vec2( 0 * delta, 1 * delta)).z;
    float d4 = texture(shadow_map, uv + vec2( 0 * delta,-1 * delta)).z;
    return (d0 + d1 + d2 + d3 + d4) / 5.0;
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

    vec3 light_dir = vec3(light_rotation[0][2], 
                          light_rotation[1][2],
                          light_rotation[2][2]);
    float lightness = max(dot(normalize(pass_normal), light_dir), 0.0);

    vec4 color = texture(color_texture, pass_uv) * lightness; 
    float d = pass_light_coord.z - dept_blur(shadow_map, pass_light_coord.xy);
    float in_light = 0.0;
    if (d <= 0.004)
        out_color = color * lightness;
    else
        out_color = color * shadow_tint;;
    
}

#endif
