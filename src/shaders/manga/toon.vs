#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;
uniform mat4 matLight;

out vec3 fragPosition;
out vec4 fragLightPosition;
out vec4 fragScreenPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

void main()
{
  fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
  fragLightPosition = matLight * vec4(fragPosition, 1.0);
  fragScreenPosition = mvp*vec4(vertexPosition, 1.0);
  fragTexCoord = vertexTexCoord;
  fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 1.0)));
  //fragNormal = normalize(vec3(transpose(inverse(matModel)) * vec4(vertexNormal, 1.0)));
  fragColor = vertexColor;
  gl_Position = fragScreenPosition;
}
