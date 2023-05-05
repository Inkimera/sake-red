#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D SCREEN_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec4 texelColor = texture(SCREEN_TEXTURE, fragTexCoord);
  vec4 texelControl = texture(CONTROL_TEXTURE, fragTexCoord);

  float density = 1.0 + texelControl.b;
  vec3 color_output = pow(abs(texelColor.rgb), vec3(density));
  finalStyle = vec4(mix(substrate, color_output, clamp(density, 0.0, 1.0)), texelColor.a);
}
