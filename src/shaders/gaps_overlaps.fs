#version 330

in vec3 fragPosition;
in vec2 fragTexCoord;

uniform sampler2D STYLE_TEXTURE;
uniform sampler2D EDGE_TEXTURE;
uniform sampler2D BLEED_TEXTURE;
uniform sampler2D CONTROL_TEXTURE;

uniform vec3 substrate = vec3(1.0, 1.0, 1.0);
uniform float go_radius = 5.0;

layout(location = 0) out vec4 finalStyle;

float luminance(vec3 rgb) {
  const vec3 W = vec3(0.241, 0.691, 0.068);
  return dot(rgb, W);
}

//  Convert between RGB (red, green, blue) to RYB (red, yellow, blue)
vec3 rgb2ryb(vec3 rgb_color) {
  // Remove the white from the color
  float white = min(min(rgb_color.r, rgb_color.g), rgb_color.b);
  rgb_color -= vec3(white);
  float max_green = max(max(rgb_color.r, rgb_color.g), rgb_color.b);
  // Get the yellow out of the red & green
  float yellow = min(rgb_color.r, rgb_color.g);
  rgb_color.r -= yellow;
  rgb_color.g -= yellow;
  // If this unfortunate conversion combines blue and green, then cut each in half to preserve the value's maximum range.
  if (rgb_color.b > 0.0 && rgb_color.g > 0.) {
    rgb_color.b /= 2.0;
    rgb_color.g /= 2.0;
  }
  // Redistribute the remaining green.
  yellow += rgb_color.g;
  rgb_color.b += rgb_color.g;
  // Normalize to values.
  float max_yellow = max(max(rgb_color.r, yellow), rgb_color.b);
  if (max_yellow > 0.) {
    float n = max_green / max_yellow;
    rgb_color.r *= n;
    yellow *= n;
    rgb_color.b *= n;
  }
  // Add the white back in.
  rgb_color.r += white;
  yellow += white;
  rgb_color.b += white;
  return vec3(rgb_color.r, yellow, rgb_color.b);
}

vec3 ryb2rgb(vec3 ryb_color) {
  // Remove the white from the color
  float white = min(min(ryb_color.r, ryb_color.g), ryb_color.b);
  ryb_color -= vec3(white);
  float max_yellow = max(max(ryb_color.r, ryb_color.g), ryb_color.b);
  // Get the green out of the yellow & blue
  float green = min(ryb_color.g, ryb_color.b);
  ryb_color.g -= green;
  ryb_color.b -= green;
  if (ryb_color.b > 0. && green > 0.) {
    ryb_color.b *= 2.0;
    green *= 2.0;
  }
  // Redistribute the remaining yellow.
  ryb_color.r += ryb_color.g;
  green += ryb_color.g;
  // Normalize to values.
  float max_green = max(max(ryb_color.r, green), ryb_color.b);
  if (max_green > 0.0) {
    float n = max_yellow / max_green;
    ryb_color.r *= n;
    green *= n;
    ryb_color.b *= n;
  }
  // Add the white back in.
  ryb_color.r += white;
  green += white;
  ryb_color.b += white;
  return vec3(ryb_color.r, green, ryb_color.b);
}

// rgb (red, green, blue) to ryb (red, yellow, blue) color space transformation
// -> Based on color mixing model by Chen et al. 2015
//    [2015] Wetbrush: GPU-based 3D Painting Simulation at the Bristle Level
vec3 mixRYB2(vec3 color1, vec3 color2) {
  //mat3 M = mat3(0.241, 0, 0, 0, 0.691, 0, 0, 0, 0.068); //luminance matrix
  //measure RGB brightness of colors
  float b1 = luminance(color1);
  float b2 = luminance(color2);
  //float b1 = pow(dot(color1, mul(M, color1)), 0.5);
  //float b2 = pow(dot(color2, mul(M, color2)), 0.5);
  float bAvg = 0.5*(b1 + b2);
  //convert colors to RYB
  vec3 ryb1 = rgb2ryb(color1);
  vec3 ryb2 = rgb2ryb(color2);
  //mix colors in RYB space
  vec3 rybOut = 0.5*(ryb1 + ryb2);
  //bring back to RGB to measure brightness
  vec3 rgbOut = ryb2rgb(rybOut);
  //measure brightness of result
  //float b3 = pow(dot(rgbOut, mul(M, rgbOut)),0.5);
  float b3 = luminance(rgbOut);
  //modify ryb with brightness difference
  rybOut *= (bAvg / b3) * 0.9;
  //convert and send back
  return ryb2rgb(rybOut);
}

void main()
{
  vec2 screen_size = vec2(textureSize(STYLE_TEXTURE, 0));
  vec2 texel_size = 1.0 / screen_size;
  vec4 texelStyle = texture(STYLE_TEXTURE, fragTexCoord);
  vec4 texelBleed = texture(BLEED_TEXTURE, fragTexCoord);
  vec4 texelEdge = texture(EDGE_TEXTURE, fragTexCoord);
  vec4 texelControl = texture(CONTROL_TEXTURE, fragTexCoord);

  // edge control target fidelity (b)
  float gaps_overlaps = texelControl.b * go_radius;
  // contains the blending mask
  float bleeding = texelBleed.a;

  finalStyle = texelStyle;
  float mask = finalStyle.a;
  float go_threshold = 1.0 / go_radius;

  // make sure we are not considering emptiness or blending
  if (mask > 0.1 && bleeding < 0.01) {
    // make sure we are at an edge
    if (texelEdge.b > 0.1) {
      // OVERLAPS
      if (gaps_overlaps > 0.1f) {
        // get gradients
        float right = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, 0.0)).b;
        float left = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, 0.0)).b;
        float down = texture(EDGE_TEXTURE, fragTexCoord + vec2(0.0, texel_size.y)).b;
        float up = texture(EDGE_TEXTURE, fragTexCoord + vec2(0.0, -texel_size.y)).b;

        float topRight = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, -texel_size.y)).b;
        float topLeft = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, -texel_size.y)).b;
        float downRight = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, texel_size.y)).b;
        float downLeft = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, texel_size.y)).b;

        // could be optimized for lower end devices by using bilinear filtering
        float uGradient = (right + 0.5*(topRight + downRight)) - (left + 0.5 * (topLeft + downLeft));
        float vGradient = (down + 0.5*(downRight + downLeft)) - (up + 0.5*(topRight + topLeft));
        vec2 gradient = vec2(uGradient, vGradient);
        vec4 destColor = finalStyle;
        gradient = normalize(gradient);

        int o = 1;
        // find vector of gradient (to get neighboring color)
        for (o = 1; o < go_radius; o++) {
          if (gaps_overlaps < o) {
            break;
          }
          destColor = texture(STYLE_TEXTURE, fragTexCoord + float(o) * (gradient * texel_size));
          // check with destination color
          if (length(destColor - finalStyle) > 0.33) {
            // no overlap with substrateColor
            if (length(destColor.rgb - substrate) < 0.1) {
              break;
            }
            finalStyle.rgb = mixRYB2(finalStyle.rgb, destColor.rgb);
            break;
          }
        }
        // check if loop reached the max
        if (o == go_radius) {
          // means that gradient was reversed
          destColor = texture(STYLE_TEXTURE, fragTexCoord + (-gradient * texel_size));
          finalStyle.rgb = mixRYB2(finalStyle.rgb, destColor.rgb);
        }
      }

      // GAPS
      if (gaps_overlaps < -0.1f) {
        // check if it is at an edge
        if (texelEdge.b > go_threshold * 2) {
          finalStyle = vec4(substrate, finalStyle.a);
        } else {
          // get gradients
          float right = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, 0.0)).b;
          float left = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, 0.0)).b;
          float down = texture(EDGE_TEXTURE, fragTexCoord + vec2(0.0, texel_size.y)).b;
          float up = texture(EDGE_TEXTURE, fragTexCoord + vec2(0.0, -texel_size.y)).b;

          float topRight = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, -texel_size.y)).b;
          float topLeft = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, -texel_size.y)).b;
          float downRight = texture(EDGE_TEXTURE, fragTexCoord + vec2(texel_size.x, texel_size.y)).b;
          float downLeft = texture(EDGE_TEXTURE, fragTexCoord + vec2(-texel_size.x, texel_size.y)).b;

          float uGradient = (right + 0.5*(topRight + downRight)) - (left + 0.5 * (topLeft + downLeft));
          float vGradient = (down + 0.5*(downRight + downLeft)) - (up + 0.5*(topRight + topLeft));
          vec2 gradient = vec2(uGradient, vGradient);

          // normalize gradient to check neighboring pixels
          gradient = normalize(gradient);
          for (int o = 1; o < go_radius; o++) {
            if (abs(gaps_overlaps) < float(o) / go_radius) {
              //outColor.rgb = float3(gapsOverlaps, 0, 0);
              break;
            }
            float destEdges = texture(EDGE_TEXTURE, fragTexCoord + float(o) * (gradient * texel_size)).b;
            // check destionation edge
            if (destEdges > go_threshold) {
              finalStyle.rgb = substrate;
              break;
            }
          }
        }
      }
    }
  }
}
