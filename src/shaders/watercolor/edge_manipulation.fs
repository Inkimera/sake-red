#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D EDGE_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);
uniform float edge_intensity = 1.2;

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec2 texelEdge = texture(EDGE_TEXTURE, fragTexCoord).gr;
  vec4 texelControl = texture(CONTROL_TEXTURE, fragTexCoord);

  // EDGE MODULATION
  float ctrl_intensity = texelControl.r * 2.0;
  float painted_intensity = 1.0 + ctrl_intensity;
  float dark_edge_intensity = texelEdge.x * edge_intensity * painted_intensity;
  // get rid of edges with color similar to substrate
  dark_edge_intensity = mix(0.0, dark_edge_intensity, clamp(length(texelStyle.rgb - substrate) * 5.0, 0.0, 1.0));
  // get rid of edges at bleeded areas
  dark_edge_intensity = mix(0.0, dark_edge_intensity, clamp(texelEdge.y * 3.0, 0.0, 1.0));
  //dark_edge_intensity = mix(0.0, dark_edge_intensity, texelEdge.y);
  // color modification model
  float density = 1.0 + dark_edge_intensity;
  finalStyle = vec4(pow(texelStyle.rgb, vec3(density)), texelStyle.a);
}
