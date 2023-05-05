#version 330

#define PI 3.1415926538

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D EDGE_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;
uniform sampler2D SUBSTRATE_TEXTURE;
uniform sampler2D DEPTH_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);
uniform float substrate_distortion = 0.2;
uniform float dir = 0.0;
uniform float tilt = 45.0;

layout(location = 0) out vec4 finalStyle;

void main()
{
  vec2 screen_size = textureSize(STYLE_TEXTURE, 0);
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelEdge = texture(EDGE_TEXTURE, fragTexCoord);
  vec4 texelControl = texture(CONTROL_TEXTURE, fragTexCoord);
  vec4 texelSubstrate = texture(SUBSTRATE_TEXTURE, fragTexCoord);
  vec4 texelDepth = texture(DEPTH_TEXTURE, fragTexCoord);

  // to transform float values to -1...1
  vec2 normal = (texelSubstrate.rg * 2.0 - 1.0);
  // control parameters, unpack substrate control target (y)
  float distort_ctrl = clamp(texelControl.r + 0.2, 0.0, 1.0);
  float linear_depth = texelDepth.x;
  // calculate uv offset
  // 0.2 is default
  float controlled_distortion = mix(0.0, substrate_distortion, 5.0 * distort_ctrl);
  vec2 offset_uv = normal * (controlled_distortion * 1.0 / screen_size);
  // check if destination is in front
  float depth_dest = texture(DEPTH_TEXTURE, offset_uv).x;
  if (linear_depth - depth_dest > 0.01) {
    offset_uv = vec2(0.0f, 0.0f);
  }
  vec4 texelStyleDistorted = texture(STYLE_TEXTURE, fragTexCoord + offset_uv);
  // only distort at edges
  texelStyle = mix(texelStyle, texelStyleDistorted, texelEdge);

  // bring normals to [-0.5 - 0.5]
  normal = texelSubstrate.rg - 0.5;

  // get light direction
  float dir_radians = dir * PI / 180.0;
  vec3 light_dir = vec3(sin(dir_radians), cos(dir_radians), (tilt / 89.0));

  // calculate diffuse illumination
  vec3 normals = vec3(-normal, 1.0);
  float diffuse = dot(normals, light_dir);  // basic lambert
  //diffuse = 1.0 - acos(diffuse)/PI;  // angular lambert
  //diffuse = (1 + diffuse)*0.5;  // extended lambert
  // modulate diffuse shading
  // modify curve
  diffuse = 1.0 - (diffuse * 1.0);
  // Gamma correction
  diffuse = pow(diffuse, 1.0/2.2);
  finalStyle = vec4(texelStyle.rgb * diffuse, texelStyle.a);
}
