#version 330

in vec3 fragPosition;
in vec4 fragLightPosition;
in vec4 fragScreenPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

#define MAX_LIGHTS          4
#define LIGHT_DIRECTIONAL   0
#define LIGHT_POINT         1

struct Light {
  int enabled;
  int cast_shadow;
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
//uniform sampler2D NORMAL_TEXTURE;
uniform sampler2D SHADOWMAP_TEXTURE;

uniform vec3 albedo = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow = vec3(0.0, 0.0, 0.0);
uniform vec3 emission = vec3(0.0, 0.0, 0.0);

uniform float shadow_wrap = 0.5;
uniform float shadow_blur = 0.1;
uniform float shadow_scale = 10.0;
uniform float underpaint_wrap = 0.5;
uniform float underpaint_blur = 0.01;

uniform float underpaint_bands = 1.0;

uniform float specular_intensity = 0.35;

uniform int disable_lighting = 0;

uniform float uv_wrap_x = 1.0;
uniform float uv_wrap_y = 1.0;

layout(location = 0) out vec4 finalColor;
layout(location = 1) out vec4 finalNormal;
layout(location = 2) out vec4 finalControl;
//layout(location = 2) out float finalDepth;

struct LightOut {
  vec3 diffuse;
  vec3 specular;
  float underpaint;
  float pattern;
  float shaded;
};

float shadow_calculation(float n_dot_l)
{
  float bias = 0.00001;
  vec3 projCoords = fragLightPosition.xyz / fragLightPosition.w;
  projCoords = projCoords * 0.5 + 0.5;

  //float currentDepth = projCoords.z - bias;
  //float closestDepth = texture(SHADOWMAP_TEXTURE, projCoords.xy).r; 
  //float in_shadow = currentDepth - closestDepth;
  //in_shadow = in_shadow >= 0.0 ? 1.0 : 0.0;
  //in_shadow = in_shadow + ceil(-n_dot_l);
  //return in_shadow;
  float shadows = 0.0;

  vec2 texelSize = 0.5 / textureSize(SHADOWMAP_TEXTURE, 0);
  float currentDepth = projCoords.z - bias;

  for(int x = -1; x <= 1; ++x)
  {
    for(int y = -1; y <= 1; ++y)
    {
      float closestDepth = texture(SHADOWMAP_TEXTURE, projCoords.xy + vec2(x, y) * texelSize).r; 
      float in_shadow = currentDepth - closestDepth;
      in_shadow = in_shadow >= 0.0 ? 1.0 : 0.0;
      in_shadow = in_shadow + ceil(-n_dot_l);
      shadows += in_shadow;
    }
  }

  return shadows / 9.0;
}  

LightOut light_out(
  vec3 light_color,
  float light_intensity,
  int shadow_enabled,
  vec3 light_pos,
  vec3 light,
  vec3 normal,
  vec3 view,
  float attenuation
) {
  if (disable_lighting == 1) {
    return LightOut(vec3(0.0), vec3(0.0), 1.0, 1.0, 0.0);
  }
  float n_dot_l = max(dot(normal, light), 0.0);
  float atten = attenuation;

  // DIFFUSE
  float underpaint_lambert = 0.0;
  if (n_dot_l < underpaint_wrap - underpaint_blur / 2.0) {
    underpaint_lambert = 0.0;
  } else if (n_dot_l > underpaint_wrap + underpaint_blur / 2.0) {
    underpaint_lambert = 1.0;
  } else {
    underpaint_lambert = 1.0 - ((underpaint_wrap + underpaint_blur / 2.0 - n_dot_l) / underpaint_blur);
  }
  //underpaint_lambert *= atten;
  
  float pattern_lambert = 0.0;
  if (n_dot_l < shadow_wrap - shadow_blur / 2.0) {
    pattern_lambert = 0.0;
  } else if (n_dot_l > shadow_wrap + shadow_blur / 2.0) {
    pattern_lambert = 1.0;
  } else {
    pattern_lambert = 1.0 - ((shadow_wrap + shadow_blur / 2.0 - n_dot_l) / shadow_blur);
  }

  vec3 diffuse_color = light_color * light_intensity;

  // SPECULAR
  float n_dot_h = dot(normal, normalize(light_pos + view));
  float specular = smoothstep(0.005, 0.01, pow(n_dot_h * n_dot_l, 32.0));
  vec3 specular_color = vec3(0.9) * specular * specular_intensity * light_intensity;

	float shaded = 0.0;
	if (shadow_enabled == 1)
	{
		shaded = shadow_calculation(n_dot_l);
	}

  return LightOut(
    diffuse_color,
    specular_color,
    underpaint_lambert,
    pattern_lambert,
		shaded
  );
}

float luminance(vec3 rgb)
{
  const vec3 W = vec3(0.241, 0.691, 0.068);
  return dot(rgb, W);
}

vec3 greyscale(vec3 color)
{
  float g = dot(color, vec3(0.299, 0.587, 0.114));
  return vec3(g);
}

float ndot(vec2 a, vec2 b )
{
  return a.x*b.x - a.y*b.y;
}

vec3 diamond(vec2 uv, float size, vec3 fg, vec3 bg)
{
  vec2 p = uv * 2.0 - 1.0;
  //float d = abs(p.x) + abs(p.y);
  //vec3 s = bg;
  //if (d < size) {
  //  s = fg;
  //}
  //return s;
  vec2 b = vec2(size, size * 0.5);
  p = abs(p);
  float h = clamp(ndot(b - 2.0 * p, b) / dot(b, b), -1.0, 1.0);
  float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
  d = d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
  return mix(fg, bg, step(0.0, d));
}

vec3 heart(vec2 uv, float size, vec3 fg, vec3 bg)
{
  float x = uv.x - (size * 8);// 0.32;
  float y = uv.y - (size * 5);// 0.20;
  float xx = x * x;
  float yy = y * y;
  float yyy = yy * y;
  float h = xx + yy - size;
  float d = h * h * h - xx * yyy;
  return mix(fg, bg, step(0.0, d));
}

vec3 luma_reinhard_tone_mapping(vec3 rgb)
{
  // luminance reinhard tone mapping  
  float luma = luminance(rgb);
  float toneMappedLuma = luma / (1.0 + luma);
  rgb *= toneMappedLuma / luma;
  // Gamma correction
  float gamma = 2.2;
  rgb = pow(rgb, vec3(1.0 / gamma));
  return rgb;
}

vec3 unreal_tone_mapping(vec3 rgb) {
  // Unreal 3, Documentation: "Color Grading"
  // Adapted to be close to Tonemap_ACES, with similar range
  // Gamma 2.2 correction is baked in, don't use with sRGB conversion!
  return rgb / (rgb + 0.155) * 1.019;
}

void main()
{
  vec2 uv = vec2(mod(fragTexCoord.x * uv_wrap_x, 1), mod(fragTexCoord.y * uv_wrap_y, 1));
  vec4 texelColor = texture(ALBEDO_TEXTURE, uv);
  vec4 texelSpecular = texture(SPECULAR_TEXTURE, uv);
  //vec4 texelNormal = texture(NORMAL_TEXTURE, uv);
  vec3 normal = normalize(fragNormal);
  float depth = length(camera - fragPosition);
  vec3 view = normalize(camera - fragPosition);

  vec3 diffuse = vec3(0.0);
  float underpaint_lambert = 0.0;
  float pattern_lambert = 0.0;
  vec3 specular = vec3(0.0);
  float shaded = underpaint_bands;

  for (int i = 0; i < MAX_LIGHTS; i++)
  {
    if (lights[i].enabled == 1)
    {
      float attenuation = 0.0;
      vec3 light = vec3(0.0);

      if (lights[i].light_type == LIGHT_DIRECTIONAL)
      {
        vec3 d = lights[i].target - lights[i].position;
        attenuation = lights[i].attenuation;
        light = -normalize(d);
      } else if (lights[i].light_type == LIGHT_POINT)
      {
        vec3 d = lights[i].position - fragPosition;
        attenuation = clamp(1.0 - length(d) / lights[i].attenuation, 0.0, 1.0);
        light = normalize(d);
      }

      LightOut l = light_out(
          lights[i].color.rgb,
          lights[i].intensity,
          lights[i].cast_shadow,
          lights[i].position,
          light,
          normal,
          view,
          attenuation
      );
      float min_shaded = min(shaded, l.shaded);
      float max_shaded = max(shaded, l.shaded);
      shaded = mix(min_shaded, max_shaded, 1.0 - underpaint_bands);
      diffuse += l.diffuse;
      specular += l.specular;
      underpaint_lambert = max(underpaint_lambert, l.underpaint);
      pattern_lambert = max(pattern_lambert, l.pattern);
    }
  }
  specular *= texelSpecular.rgb;

  //float dep = 1.0 / fragScreenPosition.w;
  //vec2 uvss = fragScreenPosition.xy / fragScreenPosition.w;
  float dep = 1.0;
  vec2 uvss = fragTexCoord;
  vec2 pattern_uv = vec2(mod(uvss.x * shadow_scale / dep, 1), mod(uvss.y * shadow_scale / dep, 1));

	underpaint_lambert = underpaint_lambert * (1.0 - shaded);
	pattern_lambert = pattern_lambert * (1.0 - shaded);

  vec3 albedo_color = albedo * texelColor.rgb;
  vec3 color = (diffuse + specular) + albedo_color;
  vec3 solid_diffuse_color = mix(shadow, color, underpaint_lambert);
  //vec3 pattern = diamond(pattern_uv, 0.8, shadow, solid_diffuse_color);
  vec3 pattern = heart(pattern_uv, 0.04, shadow, solid_diffuse_color);
  vec3 pattern_diffuse_color = mix(pattern, solid_diffuse_color, pattern_lambert);
  pattern_diffuse_color += emission;
  pattern_diffuse_color = mix(pattern_diffuse_color, albedo_color, ambient);
  vec3 final = pattern_diffuse_color;
  //final = luma_reinhard_tone_mapping(final);
  final = unreal_tone_mapping(final);
  //final = clamp(final, 0.0, 1.0);
  final = mix(final, greyscale(final), 0.15);
  finalColor = vec4(final, 1.0);
  finalNormal = vec4(normal, 1.0);
  finalControl = vec4(greyscale(albedo).r, underpaint_lambert, shaded, 1.0);
}
