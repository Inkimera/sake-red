#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;
uniform sampler2D DEPTH_TEXTURE;
uniform sampler2D EDGE_TEXTURE;

uniform float dir_x = 0.0;
uniform float dir_y = 0.0;
uniform float bleeding_threshold = 0.002;
uniform float bleeding_radius = 5.0;
uniform float edge_darkening_kernel = 5.0;
uniform float gaps_overlaps_kernel = 7.0;
uniform float[10] weights;

layout(location = 0) out vec4 finalStyle;
layout(location = 1) out vec4 finalBleed;
layout(location = 2) out vec4 finalEdgeDarkened;

float gaussian(float a, float sigma) {
  return 0.15915 * exp(-0.5 * a * a / (sigma * sigma)) / sigma;
}

// Extends the edges for darkened edges and gaps and overlaps
vec3 edge_blur(
  vec2 screen_uv,
  vec2 dir
) {
  // sample center pixel
  vec3 sedge = texture(EDGE_TEXTURE, screen_uv).rgb;
  // calculate darkening width
  float edge_width_ctrl = texture(CONTROL_TEXTURE, screen_uv).g;
  //float edge_width_ctrl = 1.0;
  float painted_width = mix(0.0, edge_darkening_kernel * 3.0, edge_width_ctrl);  // 3 times wider through local control
  float kernel_radius = max(1.0, (edge_darkening_kernel + painted_width));  // global + local control
  float normalizer = 1.0 / float(kernel_radius);
  float ssigma = kernel_radius / 2.0;
  float weight = gaussian(0.0, ssigma);
  float dark_edge_gradient = sedge.g * weight;
  float norm_divisor = weight;
  vec2 offset_uv;

  //EDGE DARKENING GRADIENT
  for (int o = 1; o < int(kernel_radius); o++) {
    offset_uv = clamp(screen_uv + vec2(float(o) * dir), vec2(0.0), vec2(1.0));
    float offset_color_r = texture(EDGE_TEXTURE, offset_uv).g;
    offset_uv = clamp(screen_uv + vec2(float(-o) * dir), vec2(0.0), vec2(1.0));
    float offset_color_l = texture(EDGE_TEXTURE, offset_uv).g;
    weight = gaussian(float(o), ssigma);

    dark_edge_gradient += weight * (offset_color_r + offset_color_l);
    norm_divisor += weight * 2.0;
  }
  dark_edge_gradient = (dark_edge_gradient / norm_divisor);

  //GAPS AND OVERLAPS GRADIENT
  weight = 1.0;
  float linear_gradient = sedge.b * weight;
  norm_divisor = weight;
  normalizer = 1.0 / gaps_overlaps_kernel;
  for (int l = 1; l < int(gaps_overlaps_kernel); l++) {
    offset_uv = clamp(screen_uv + vec2(float(l) * dir), vec2(0.0), vec2(1.0));
    float offset_color_r = texture(EDGE_TEXTURE, offset_uv).g;
    offset_uv = clamp(screen_uv + vec2(float(-l) * dir), vec2(0.0), vec2(1.0));
    float offset_color_l = texture(EDGE_TEXTURE, offset_uv).g;
    float norm_gradient = (float(l) * normalizer); //normalized gradient | 1...0,5...0...0,5...1
    weight = 1.0 - norm_gradient; // linear
    linear_gradient += weight * (offset_color_r + offset_color_l);
    norm_divisor += weight * 2.0;
  }
  linear_gradient = linear_gradient / norm_divisor;
  return vec3(sedge.r, dark_edge_gradient, linear_gradient);
}

// Blurs certain parts of the image for color bleeding
vec4 color_bleed(
  vec2 screen_uv,
  vec2 dir
) {
  vec4 blur = vec4(0.0);
  vec4 salbedo = texture(STYLE_TEXTURE, screen_uv);
  float zNear = 0.01; // camera z near
  float zFar = 100.0;  // camera z far
  float sdepth = (2.0 * zNear) / (zFar + zNear - texture(DEPTH_TEXTURE, screen_uv).x * (zFar - zNear));
  float sblur_ctrl;
  if (dir.y > 0.0) {
    sblur_ctrl = salbedo.a;
  } else {
    sblur_ctrl = texture(CONTROL_TEXTURE, screen_uv).b;
  }
  vec4 scolor = vec4(salbedo.rgb, sblur_ctrl);
  vec4 talbedo;
  vec2 offset_uv;
  float weight, blur_ctrl, tdepth, ctrl_scope, filter_scope;

  for (int a = -int(bleeding_radius); a < int(bleeding_radius); a++) {
    offset_uv = clamp(screen_uv + vec2(float(a) * dir), 0.0, 1.0);
    talbedo = texture(STYLE_TEXTURE, offset_uv);
    tdepth = (2.0 * zNear) / (zFar + zNear - texture(DEPTH_TEXTURE, offset_uv).x * (zFar - zNear));
    if (dir.y > 0.0) {
      blur_ctrl = talbedo.a;
    } else {
      blur_ctrl = texture(CONTROL_TEXTURE, offset_uv).b;
    }
    ctrl_scope = max(blur_ctrl, sblur_ctrl);
    weight = weights[a + int(bleeding_radius)];
    filter_scope = abs(float(a)) / bleeding_radius;
    if (ctrl_scope >= filter_scope) {
      float bleed = 0.0;
      bool behind = false;
      // check if source pixel is behind
      if ((sdepth - bleeding_threshold) > tdepth) {
        behind = true;
      }
      // check bleeding cases
      if ((sblur_ctrl > 0.0) && (behind == true)) {
        bleed = 1.0;
      }
      // bleed if necessary
      if (bleed > 0.0) {
        blur += talbedo * weight;
      } else {
        blur += scolor * weight;  // get source pixel color
      }
    } else {
      blur += scolor * weight;
    }
  }
  return blur;
}

void main()
{
  vec2 screen_size = vec2(textureSize(STYLE_TEXTURE, 0));
  vec2 dir = vec2(dir_x, dir_y) / screen_size;
  finalBleed = color_bleed(fragTexCoord, dir);
  vec3 edge_darkened = edge_blur(fragTexCoord, dir);
  finalEdgeDarkened = vec4(1.0 - edge_darkened, 0.0);
  if (dir_y > 0.0) {
    finalEdgeDarkened.a = finalBleed.a;
    finalEdgeDarkened.b = pow(finalEdgeDarkened.b, 1.0 / finalEdgeDarkened.b);  // get rid of weak gradients
    finalEdgeDarkened.b = pow(finalEdgeDarkened.b, 2.0 / gaps_overlaps_kernel);  // adjust gamma depending on kernel size
  }
}