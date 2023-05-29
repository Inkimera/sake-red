#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D EDGE_TEXTURE;

uniform vec3 edge_color = vec3(1.0, 0.7, 0.2);
uniform vec2 edge_thickness = vec2(1.0, 1.0);
uniform float edge_intensity = 0.75;

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec2 screen_size = vec2(textureSize(STYLE_TEXTURE, 0));
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelEdge = texture(EDGE_TEXTURE, fragTexCoord);

  vec2 texelX = vec2(edge_thickness.x, 0.0) / screen_size;
  vec2 texelY = vec2(0.0, edge_thickness.y) / screen_size;

  vec4 texelEdgeUp = texture(EDGE_TEXTURE, fragTexCoord + texelX);
  vec4 texelEdgeRight = texture(EDGE_TEXTURE, fragTexCoord + texelY);
  vec4 texelEdgeDown = texture(EDGE_TEXTURE, fragTexCoord - texelY);
  vec4 texelEdgeLeft = texture(EDGE_TEXTURE, fragTexCoord - texelX);

  //// EDGE MODULATION
  float edge = texelEdge.r;
  edge = min(edge, texelEdgeUp.r);
  edge = min(edge, texelEdgeRight.r);
  edge = min(edge, texelEdgeDown.r);
  edge = min(edge, texelEdgeLeft.r);

  float lit_mask = texelEdge.g;
  lit_mask = max(lit_mask, texelEdgeUp.g);
  lit_mask = max(lit_mask, texelEdgeRight.g);
  lit_mask = max(lit_mask, texelEdgeDown.g);
  lit_mask = max(lit_mask, texelEdgeLeft.g);

  //vec3 edgeStyle = mix(edge_color, texelStyle.rgb, edge);
  //vec3 edgeStyle = mix(pow(texelStyle.rgb, vec3(edge_intensity)), texelStyle.rgb, edge);
  vec3 edgeStyle = mix(texelStyle.rgb * 1.2, texelStyle.rgb, edge);
  finalStyle = vec4(mix(texelStyle.rgb, edgeStyle, lit_mask), texelStyle.a);
  //finalStyle = texelStyle;
  //float brush_size = 0.5 + 0.5 * edge;
  //vec2 uv = fragTexCoord.xy;
  //vec2 brush_uv = vec2(dFdx(uv.x), dFdy(uv.y)) * brush_size;

  //vec4 texelBrush = texture(BRUSH_TEXTURE, brush_uv);
  //finalStyle = vec4(mix(edge_color, texelStyle.rgb, pow(1.0 - edge, 2.0)), texelStyle.a);
}
