#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D SUBSTRATE_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);
uniform float substrate_scale = 1.0;
uniform float strength = 1.0;
uniform float density = 1.0;
uniform float intensity = 1.0;

layout(location = 0) out vec4 finalStyle;

float luminance(vec3 rgb) {
  const vec3 W = vec3(0.241, 0.691, 0.068);
  return dot(rgb, W);
}

void main()
{
  vec2 screen_size = textureSize(STYLE_TEXTURE, 0);
  vec2 substrate_size = textureSize(SUBSTRATE_TEXTURE, 0);
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelSubstrate = texture(SUBSTRATE_TEXTURE, vec2(mod(fragTexCoord.x * screen_size.x / substrate_size.x * substrate_scale, 1), mod(fragTexCoord.y * screen_size.y / substrate_size.y * substrate_scale, 1)));
  vec4 texelControl = texture(CONTROL_TEXTURE, fragTexCoord);

  // PIGMENT APPLICATION
  float application = strength + ((1.0 - texelControl.g) * 0.5 - 0.5) * 2.0;
  float height = texelSubstrate.b * intensity;
  float dry_diff = application + height;
  if (dry_diff < 1.0) {
    finalStyle = vec4(mix(texelStyle.rgb, substrate, clamp(abs(dry_diff), 0.0, 1.0)), texelStyle.a);
  } else {
    // default is granulated (// 1.2 granulate, 0.2 default)
    application = (abs(application) + 0.2);
    // more accumulation on brighter areas
    application = mix(application, application * 5.0, luminance(texelStyle.rgb));
    // modulate heightmap to be between 0.8 - 1.0 (for montesdeoca et al. 2016)
    height = (height * 0.2) + 0.8;  // deprecated
    float accumulation = 1.0 + (density * application * (1.0 - (height)));
    // calculate denser color output
    vec3 accumulation_output = pow(abs(texelStyle.rgb), vec3(accumulation));
    // don't granulate if the render_texture is similar to substrate color
    float color_diff = clamp(length(texelStyle.rgb - substrate) * 5.0, 0.0, 1.0);
    finalStyle = vec4(mix(texelStyle.rgb, accumulation_output, vec3(color_diff)), texelStyle.a);
  }
}
