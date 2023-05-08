#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D BLEED_TEXTURE;

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelBleed = texture(BLEED_TEXTURE, fragTexCoord);
  float blend_ctrl = clamp(texelBleed.a * 5.0, 0.0, 1.0);
  finalStyle = vec4(mix(texelStyle.rgb, texelBleed.rgb, blend_ctrl), texelBleed.a);
}
