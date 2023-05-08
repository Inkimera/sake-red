#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D EDGE_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);
uniform float edge_intensity = 10.0;

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec2 screen_size = vec2(textureSize(STYLE_TEXTURE, 0));
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelEdge = texture(EDGE_TEXTURE, fragTexCoord);

  //vec2 texelX = vec2(0.5, 0.0) / screen_size;
  //vec2 texelY = vec2(0.0, 0.5) / screen_size;

  //vec4 texelEdgeUp = texture(EDGE_TEXTURE, fragTexCoord + texelX);
  //vec4 texelEdgeRight = texture(EDGE_TEXTURE, fragTexCoord + texelY);
  //vec4 texelEdgeDown = texture(EDGE_TEXTURE, fragTexCoord - texelY);
  //vec4 texelEdgeLeft = texture(EDGE_TEXTURE, fragTexCoord - texelX);

  // EDGE MODULATION
  float edge = clamp((1.0 - (texelEdge.r * 3.0)), 0.0, 1.0);
  //edge = max(edge, clamp((1.0 - (texelEdgeUp.r * 3.0)), 0.0, 1.0));
  //edge = max(edge, clamp((1.0 - (texelEdgeRight.r * 3.0)), 0.0, 1.0));
  //edge = max(edge, clamp((1.0 - (texelEdgeDown.r * 3.0)), 0.0, 1.0));
  //edge = max(edge, clamp((1.0 - (texelEdgeLeft.r * 3.0)), 0.0, 1.0));
  //float dark_edge_intensity = mix(0.0, edge_intensity, edge);
  // color modification model
  //float density = 1.0 + dark_edge_intensity;
  //finalStyle = vec4(pow(texelStyle.rgb, vec3(density)), texelStyle.a);
  finalStyle = vec4(mix(vec3(0.25), texelStyle.rgb, 1.0 - edge), texelStyle.a);
}
