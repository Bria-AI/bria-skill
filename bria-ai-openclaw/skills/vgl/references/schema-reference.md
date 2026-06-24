# VGL Output Schema Reference

Complete JSON schema for VGL prompt output. Use this when validating or generating VGL JSON.

> **Main Skill**: See **[VGL SKILL.md](../SKILL.md)** for usage guide and examples.
> **API Integration**: See **[bria-ai](../../bria-ai/SKILL.md)** for executing VGL prompts.

## Full Schema (JSON Schema Format)

```json
{
  "type": "OBJECT",
  "properties": {
    "short_description": { "type": "STRING" },
    "objects": {
      "type": "ARRAY",
      "items": {
        "type": "OBJECT",
        "properties": {
          "description": { "type": "STRING" },
          "location": { "type": "STRING" },
          "relationship": { "type": "STRING" },
          "relative_size": { "type": "STRING" },
          "shape_and_color": { "type": "STRING" },
          "texture": { "type": "STRING", "nullable": true },
          "appearance_details": { "type": "STRING", "nullable": true },
          "number_of_objects": { "type": "INTEGER", "nullable": true },
          "pose": { "type": "STRING", "nullable": true },
          "expression": { "type": "STRING", "nullable": true },
          "clothing": { "type": "STRING", "nullable": true },
          "action": { "type": "STRING", "nullable": true },
          "gender": { "type": "STRING", "nullable": true },
          "skin_tone_and_texture": { "type": "STRING", "nullable": true },
          "orientation": { "type": "STRING", "nullable": true }
        },
        "required": [
          "description", "location", "relationship", "relative_size",
          "shape_and_color", "texture", "appearance_details", "number_of_objects",
          "pose", "expression", "clothing", "action", "gender",
          "skin_tone_and_texture", "orientation"
        ]
      }
    },
    "background_setting": { "type": "STRING" },
    "lighting": {
      "type": "OBJECT",
      "properties": {
        "conditions": { "type": "STRING" },
        "direction": { "type": "STRING" },
        "shadows": { "type": "STRING", "nullable": true }
      },
      "required": ["conditions", "direction", "shadows"]
    },
    "aesthetics": {
      "type": "OBJECT",
      "properties": {
        "composition": { "type": "STRING" },
        "color_scheme": { "type": "STRING" },
        "mood_atmosphere": { "type": "STRING" }
      },
      "required": ["composition", "color_scheme", "mood_atmosphere"]
    },
    "photographic_characteristics": {
      "type": "OBJECT",
      "nullable": true,
      "properties": {
        "depth_of_field": { "type": "STRING" },
        "focus": { "type": "STRING" },
        "camera_angle": { "type": "STRING" },
        "lens_focal_length": { "type": "STRING" }
      },
      "required": ["depth_of_field", "focus", "camera_angle", "lens_focal_length"]
    },
    "style_medium": { "type": "STRING" },
    "artistic_style": { "type": "STRING" },
    "context": { "type": "STRING" },
    "text_render": {
      "type": "ARRAY",
      "items": {
        "type": "OBJECT",
        "properties": {
          "text": { "type": "STRING" },
          "location": { "type": "STRING" },
          "size": { "type": "STRING" },
          "color": { "type": "STRING" },
          "font": { "type": "STRING" },
          "appearance_details": { "type": "STRING", "nullable": true }
        },
        "required": ["text", "location", "size", "color", "font", "appearance_details"]
      }
    },
    "edit_instruction": { "type": "STRING" }
  },
  "required": [
    "short_description",
    "objects",
    "background_setting",
    "lighting",
    "aesthetics",
    "photographic_characteristics",
    "style_medium",
    "artistic_style",
    "context",
    "text_render",
    "edit_instruction"
  ]
}
```

## Parameter Value Reference

### Lighting Conditions
- `"Golden hour"` - Warm, directional sunlight near sunrise/sunset
- `"Blue hour light"` - Cool, pre-dawn/post-sunset
- `"Overcast light"` - Soft, diffused illumination
- `"Starlight nighttime"` - Low-light scenarios
- `"Midday"` - Harsh overhead sun
- `"Sunrise light"` - Early morning warmth
- `"Spotlight on subject"` - Dramatic single source
- `"Soft bokeh lighting"` - Diffused with background blur
- `"Harsh studio lighting"` - High contrast professional
- `"Studio lighting"` - Controlled indoor setup
- `"Bright daylight"` - Strong natural light
- `"Dim indoor"` - Low ambient interior

### Lighting Direction
- `"Front"` / `"front-lit"` - Light facing subject
- `"Side"` / `"side-lit from left"` / `"side-lit from right"`
- `"Bottom"` - Upward lighting (dramatic)
- `"Top-down"` - Overhead lighting
- `"Backlit"` - Light behind subject (silhouette effect)

### Camera Angles
- `"Eye-level"` - Natural human perspective
- `"High angle"` / `"Bird's-eye view"` - Looking down
- `"Low angle"` / `"Worm's-eye view"` - Looking up
- `"Dutch angle"` - Tilted frame

### Lens Focal Lengths
- `"35mm"` / `"wide-angle"` - Expansive view, more distortion
- `"50mm"` / `"standard lens"` - Natural human-eye perspective
- `"85mm"` / `"portrait lens"` - Flattering for people, background compression
- `"100mm"` / `"telephoto"` - Strong background compression
- `"macro"` - Extreme close-up detail
- `"fisheye"` - Ultra-wide with distortion

### Depth of Field
- `"Shallow"` - Subject sharp, background blurred (bokeh)
- `"Deep"` - Everything in focus
- `"Bokeh background"` - Emphasized background blur

### Composition Types
- `"Rule of thirds"` - Subject off-center at intersection points
- `"Centered"` - Subject in middle
- `"Symmetrical"` - Mirror balance
- `"Leading lines"` - Lines draw eye to subject
- `"Wide shot"` - Full body/environment visible
- `"Medium shot"` - Waist up
- `"Close-up"` - Face/detail focus
- `"Portrait composition"` - Standard portrait framing

### Mood/Atmosphere Values
- `"Peaceful"` / `"Serene"` / `"Calm"`
- `"Dramatic"` / `"Cinematic"`
- `"Joyful"` / `"Festive"` / `"Celebratory"`
- `"Energetic"` / `"Dynamic"`
- `"Mysterious"` / `"Moody"`
- `"Nostalgic"` / `"Warm"`
- `"Professional"` / `"Corporate"`
- `"Playful"` / `"Whimsical"`

### Style/Medium Values
- `"photograph"` - Default for realistic images
- `"oil painting"`
- `"watercolor"`
- `"3D render"` / `"3D CGI render"`
- `"digital illustration"`
- `"pencil sketch"`
- `"cartoon"` / `"anime"`
- `"Pixar-style 3D"`

### Object Textures
- `"Smooth"` / `"Polished"`
- `"Rough"` / `"Textured"`
- `"Metallic"` / `"Chrome"` / `"Brushed aluminum"`
- `"Furry"` / `"Plush"`
- `"Fabric"` / `"Silk"` / `"Cotton"` / `"Leather"`
- `"Glass"` / `"Transparent"`
- `"Wooden"` / `"Oak"` / `"Walnut"`
- `"Matte"` / `"Glossy"`
- `"Organic"` / `"Natural"`

### Location Values
- `"center"` - Middle of frame
- `"top-left"` / `"top-right"` / `"top-center"`
- `"bottom-left"` / `"bottom-right"` / `"bottom-center"`
- `"left"` / `"right"`
- `"foreground"` / `"background"` / `"midground"`
- Combined: `"bottom-right foreground"`, `"center-left midground"`

### Orientation Values
- `"upright"` - Standard vertical position
- `"horizontal"` / `"lying flat"`
- `"vertical"`
- `"tilted 45 degrees"` / `"tilted left"` / `"tilted right"`
- `"facing left"` / `"facing right"` / `"facing camera"`
- `"upside down"`
- `"lying on its side"`
- `"three-quarter view"` - Angled between front and profile

### Expression Values (Humans)
- `"calm"` / `"neutral"` / `"serene"`
- `"joyful"` / `"smiling"` / `"laughing"`
- `"serious"` / `"focused"` / `"determined"`
- `"surprised"` / `"shocked"`
- `"winking"` / `"playful"`
- `"confident"` / `"proud"`
- `"thoughtful"` / `"contemplative"`
- `"sad"` / `"melancholic"`
