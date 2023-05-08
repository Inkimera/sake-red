#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;

layout(location = 0) out vec4 finalColor;

void main()
{
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  //finalColor = vec4(vec3(texelStyle.b), texelStyle.a);
  finalColor = texelStyle;
  //float zNear = 0.01; // camera z near
  //float zFar = 10.0;  // camera z far
  //float depth = (2.0 * zNear) / (zFar + zNear - texelStyle.x * (zFar - zNear));
  //depth = pow(depth, 1.0 / 2.2);
	//finalColor = vec4(vec3(depth), 1.0);
	//finalColor = vec4(vec3(texelStyle.x), 1.0);
}
