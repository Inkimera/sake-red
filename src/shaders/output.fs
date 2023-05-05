#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;

layout(location = 0) out vec4 finalColor;

void main()
{
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  finalColor = texelStyle;
}
