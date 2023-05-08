#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D EDGE_TEXTURE;

layout(location = 0) out vec4 finalEdge;

void main()
{
  vec4 texelEdge = texture(EDGE_TEXTURE, fragTexCoord);
  finalEdge = texelEdge;
}
