#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

void main()
{
  // Send vertex attributes to fragment shader
  //float bleed = clamp(vertexColor.a - 0.7, 0.0, 1.0);
  fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
  fragTexCoord = vertexTexCoord;
  fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 1.0)));
  fragColor = vertexColor;

  // Calculate final vertex position
  gl_Position = mvp*vec4(vertexPosition, 1.0);
}
