#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D SCREEN_TEXTURE;
//uniform sampler2D NORMAL_TEXTURE;
uniform sampler2D DEPTH_TEXTURE;

layout(location = 0) out vec4 finalEdge;

vec4 rgbd(vec2 screen_uv)
{
  vec3 texelColor = texture(SCREEN_TEXTURE, screen_uv).rgb;
  vec4 texelDepth = texture(DEPTH_TEXTURE, screen_uv);
  //float zNear = 0.01; // camera z near
  //float zFar = 10.0;  // camera z far
  //float depth = (2.0 * zNear) / (zFar + zNear - texelDepth.x * (zFar - zNear));
  //return vec4(texelColor.rgb, depth);
  return vec4(texelColor.rgb, texelDepth.x);
}

// Performs a sobel edge detection on RGBD channels
// -> Based on the sobel image processing operator by Sobel and Feldman 1968 
//    [1968] A 3x3 Isotropic Gradient Operator for Image Processing
vec3 edge(vec2 screen_size)
{
  float px = 1.0 / screen_size.x;
  float py = 1.0 / screen_size.y;

  vec4 topLeft = rgbd(fragTexCoord + vec2(-px, -py));
  vec4 topMiddle = rgbd(fragTexCoord + vec2(0, -py));
  vec4 topRight = rgbd(fragTexCoord + vec2(px, -py));
  vec4 midLeft = rgbd(fragTexCoord + vec2(-px, 0));
  //vec4 middle = rgbd(fragTexCoord);
  vec4 midRight = rgbd(fragTexCoord + vec2(px, 0));
  vec4 bottomLeft = rgbd(fragTexCoord + vec2(-px, py));
  vec4 bottomMiddle = rgbd(fragTexCoord + vec2(0, py));
  vec4 bottomRight = rgbd(fragTexCoord + vec2(px, py));

  vec4 hKernelMul = (1.0 * topLeft) + (2.0 * topMiddle) + (1.0 * topRight) + (-1.0 * bottomLeft) + (-2.0 * bottomMiddle) + (-1.0 * bottomRight);
  vec4 vKernelMul = (1.0 * topLeft) + (-1.0 * topRight) + (2.0 * midLeft) + (-2.0 * midRight) + (1.0 * bottomLeft) + (-1.0 * bottomRight);

  hKernelMul.a *= 5.0;  // modulate depth
  float rgbdHorizontal = length(hKernelMul);
  //float rgbdHorizontal = max(max(hKernelMul.r, hKernelMul.b), hKernelMul.g);
  vKernelMul.a *= 5.0;  // modulate depth
  float rgbdVertical = length(vKernelMul);
  //float rgbdVertical = max(max(vKernelMul.r, vKernelMul.b), vKernelMul.g);
  float edgeMagnitude = length(vec2(rgbdHorizontal, rgbdVertical));
  return vec3(edgeMagnitude);
}

void main()
{
  vec4 texelColor = texture(SCREEN_TEXTURE, fragTexCoord);
  vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));
  finalEdge = vec4(edge(screen_size), 1.0);
}
