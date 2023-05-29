#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D SHADOWMAP_TEXTURE;

layout(location = 0) out vec4 finalColor;

void main()
{
  vec4 texelShadow = texture(SHADOWMAP_TEXTURE, fragTexCoord);
  //float zNear = 0.1; // camera z near
  //float zFar = 1000.0;  // camera z far
  //float depth = (2.0 * zNear) / (zFar + zNear - texelShadow.x * (zFar - zNear));
  float depth = texelShadow.x;
  depth = pow(depth, 1.0 / 2.2);
	finalColor = vec4(vec3(depth), 1.0);
}
