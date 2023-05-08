#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

#define MAX_LIGHTS          4
#define LIGHT_DIRECTIONAL   0
#define LIGHT_POINT         1

struct Light {
  int enabled;
  int light_type;
  vec3 position;
  vec3 target;
  vec4 color;
  float attenuation;
  float intensity;
};

uniform Light lights[MAX_LIGHTS];
uniform vec3 ambient = vec3(0.0, 0.0, 0.0);
uniform vec3 camera;

uniform sampler2D ALBEDO_TEXTURE;
uniform sampler2D SPECULAR_TEXTURE;
uniform sampler2D NORMAL_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;

uniform vec3 albedo = vec3(1.0, 1.0, 1.0);
uniform vec3 cangiante = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow = vec3(0.0, 0.0, 0.0);
uniform vec3 emission = vec3(0.0, 0.0, 0.0);
uniform vec3 substrate = vec3(1.0, 1.0, 1.0);

uniform float diffuse_factor = 1.0;
uniform float shade_wrap = 1.0;
uniform float dark_edges = 1.0;
uniform float dilute = 1.0;
uniform float dilute_area = 1.0;

uniform float specular_intensity = 0.35;
uniform float specular_diffuse = 0.99;
uniform float specular_transparency = 0.75;
uniform float specular_depth = 100.0;
uniform float high_area = 0.0;

uniform int disable_lighting = 0;

//uniform bool use_normal = false;
uniform float uv_wrap_x = 1.0;
uniform float uv_wrap_y = 1.0;

layout(location = 0) out vec4 finalColor;
layout(location = 1) out vec4 finalNormal;
layout(location = 2) out vec4 finalControl;
//layout(location = 2) out float finalDepth;

struct LightOut {
  vec3 diffuse;
  vec3 specular;
  vec3 diluted;
};

LightOut light_out(
  vec3 light_color,
  float light_intensity,
  vec3 light,
  vec3 normal,
  vec3 view,
  float attenuation
) {
  if (disable_lighting == 1) {
    return LightOut(vec3(0.0), vec3(0.0), vec3(0.0));
  }
  // DIFFUSE
  float n_dot_l = dot(normal, light);
  float n_mask = clamp(n_dot_l, 0.0, 1.0);
  float in_mask = clamp(-n_dot_l, 0.0, 1.0);
  float df = mix(1.0, n_mask, diffuse_factor);
  float sw = mix(0.0, in_mask, shade_wrap);
  float lambert = clamp(df * (1.0 - sw), 0.0, 1.0);
  vec3 diffuse_color = light_color * light_intensity * lambert;

  // SPECULAR
  float r_dot_v = dot(reflect(light, normal), -view);
  float specular_edge = dark_edges * ((clamp((1.0 - specular_intensity) - r_dot_v, 0.0, 1.0) * 200.0 / specular_depth) - 1.0);
  vec3 specular_color = vec3(mix(specular_edge, 0.0, specular_diffuse) + 2.0 * clamp((max(1.0 - specular_intensity, r_dot_v) - (1.0 - specular_intensity)) * pow(2.0 - specular_diffuse, 10.0), 0.0, 1.0)) * (1.0 - specular_transparency);
  specular_color *= clamp(dot(normal, light) * 2.0, 0.0, 1.0);

  // DILUTE
  vec3 diluted = vec3(clamp((n_mask + (dilute_area - 1.0)) / dilute_area, 0.0, 1.0));

  return LightOut(
    diffuse_color * attenuation,
    specular_color * attenuation,
    diluted
  );
}

float luminance(vec3 rgb) {
  const vec3 W = vec3(0.241, 0.691, 0.068);
  return dot(rgb, W);
}

vec3 luma_reinhard_tone_mapping(vec3 rgb)
{
  // luminance reinhard tone mapping  
  float luma = luminance(rgb);
  float toneMappedLuma = luma / (1.0 + luma);
  rgb *= toneMappedLuma / luma;
  // Gamma correction
  rgb = pow(rgb, vec3(1.0 / 2.2));
  return rgb;
}

void main()
{
  vec2 uv = vec2(mod(fragTexCoord.x * uv_wrap_x, 1), mod(fragTexCoord.y * uv_wrap_y, 1));
  vec4 texelColor = texture(ALBEDO_TEXTURE, uv);
  vec4 texelSpecular = texture(SPECULAR_TEXTURE, uv);
  //vec4 texelNormal = texture(NORMAL_TEXTURE, uv);
  vec4 texelControl = texture(CONTROL_TEXTURE, uv);
  vec3 normal = normalize(fragNormal);
  vec3 view = normalize(camera - fragPosition);

  vec3 diffuse = vec3(0.0);
  vec3 specular = vec3(0.0);
  vec3 diluted = vec3(0.0);

  for (int i = 0; i < MAX_LIGHTS; i++)
  {
    if (lights[i].enabled == 1)
    {
      float attenuation = 0.0;
      vec3 light = vec3(0.0);

      if (lights[i].light_type == LIGHT_DIRECTIONAL)
      {
        vec3 d = lights[i].target - lights[i].position;
        attenuation = clamp(1.0 / pow(length(d), lights[i].attenuation), 0.0, 1.0);
        light = -normalize(d);
      }

      if (lights[i].light_type == LIGHT_POINT)
      {
        vec3 d = lights[i].position - fragPosition;
        attenuation = clamp(1.0 / pow(length(d), lights[i].attenuation), 0.0, 1.0);
        light = normalize(d);
      }

      LightOut l = light_out(lights[i].color.rgb, lights[i].intensity, light, normal, view, attenuation);
      diffuse += l.diffuse;
      specular += l.specular;
      diluted += l.diluted;
    }
  }
  diffuse += ambient;
  //diluted += ambient;

  specular *= texelSpecular.rgb;

  diffuse = luma_reinhard_tone_mapping(diffuse);
  //specular = luma_reinhard_tone_mapping(specular);
  diluted = luma_reinhard_tone_mapping(diluted);

  // Soften diluted
  diluted = mix(diluted, pow(diluted, vec3(2.2)), clamp(-1.0 + dilute + cangiante, 0.0, 1.0));

  vec3 color = texelColor.rgb * albedo;
  vec3 highlight = vec3(0.0);

  color += clamp(diluted * cangiante, 0.0, 1.0);
  color = clamp(mix(color, substrate, diluted * dilute), 0.0, 1.0);
  if (high_area > 0.0)
  {
    highlight = (max(1.0 - vec3(high_area), dilute) - (1.0 - vec3(high_area))) * 2.0;
    highlight = clamp(mix(-highlight * dark_edges, highlight, trunc(highlight)), 0.0, 1.0);
  }

  vec3 watercolor = color; //mix(shadow, color, clamp(diffuse, 0.0, 1.0));
  watercolor = mix(vec3(1.0 - diffuse_factor), watercolor, clamp(diffuse, 0.0, 1.0));
  watercolor = watercolor + (specular) + highlight * (1.0 - specular_transparency);
  watercolor = mix(shadow, watercolor, clamp(length(diffuse), 0.0, 1.0));

  vec3 final = watercolor;
  if (dark_edges > 0.0)
  {
    float n_dot_v = dot(normal, -view);
    float edges = clamp(n_dot_v * 3.0, 0.0, 1.0);
    float darkened_edges = mix(1.0, edges, dark_edges);
    final = mix(watercolor * darkened_edges, watercolor, clamp(diluted, 0.0, 1.0) + 0.5);
  }

  //float depth = length(camera - fragPosition);
  //final = mix(final, substrate, clamp((depth - 50.0) / 200.0, 0.0, 1.0));

  final += emission;
  //final = luma_reinhard_tone_mapping(final);
  finalColor = vec4(final, 1.0);
  finalNormal = vec4(normal, 1.0);
  //finalControl = vec4(0.0, 0.0, 0.0, 1.0);
  finalControl = vec4(texelControl.rgb * texelControl.a, 1.0);
}
