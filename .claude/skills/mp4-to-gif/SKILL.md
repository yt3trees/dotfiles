---
name: mp4-to-gif
description: Convert MP4 video files to high-quality GIF animations using ffmpeg. Use this skill when the user asks to convert mp4 to gif, create animated gifs from videos, or needs video-to-gif conversion.
---

# MP4 to GIF Conversion Skill

Convert MP4 files to high-quality GIF animations using ffmpeg with optimal palette generation.

## Prerequisites

- ffmpeg must be installed and available in PATH
- If not installed, install via: `winget install Gyan.FFmpeg`
- After installation, the PATH may need refreshing: `export PATH="$PATH:/c/Users/$USER/AppData/Local/Microsoft/WinGet/Links"`

## Conversion Command

Use the following ffmpeg command for high-quality GIF output:

```bash
ffmpeg -y -i "INPUT.mp4" \
  -vf "fps=FPS_VALUE,scale=WIDTH:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=floyd_steinberg" \
  "OUTPUT.gif"
```

## Quality Presets

### High Quality (default - recommended)
- Resolution: original (no scaling)
- FPS: 30
- Palette: 256 colors, diff mode
- Dither: Floyd-Steinberg
- Trade-off: large file size but best visual quality

```bash
ffmpeg -y -i "INPUT.mp4" \
  -vf "fps=30,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=floyd_steinberg" \
  "OUTPUT.gif"
```

### Medium Quality (balanced)
- Resolution: 960px width
- FPS: 20
- Palette: 256 colors, diff mode
- Dither: Floyd-Steinberg
- Trade-off: moderate file size with good quality

```bash
ffmpeg -y -i "INPUT.mp4" \
  -vf "fps=20,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=floyd_steinberg" \
  "OUTPUT.gif"
```

### Compact (small file size)
- Resolution: 640px width
- FPS: 15
- Palette: 256 colors, full mode
- Dither: Floyd-Steinberg
- Trade-off: smaller file, lower quality

```bash
ffmpeg -y -i "INPUT.mp4" \
  -vf "fps=15,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=full[p];[s1][p]paletteuse=dither=floyd_steinberg" \
  "OUTPUT.gif"
```

## Workflow

1. Find MP4 files in the target directory using `Glob` with pattern `**/*.mp4`
2. Check if ffmpeg is available; if not, install it
3. Check source video properties (resolution, fps, duration) using ffprobe:
   ```bash
   ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of csv=p=0 "INPUT.mp4"
   ```
4. Ask user for quality preference if not specified (default: high)
5. Convert all MP4 files in parallel (run multiple ffmpeg commands simultaneously)
6. Verify output by listing generated GIF files with sizes using `ls -lh *.gif`

## Parameters Explained

| Parameter | Description |
|---|---|
| fps=N | Output frame rate. Higher = smoother but larger file |
| scale=W:-1 | Width in pixels, height auto-calculated. Omit for original resolution |
| flags=lanczos | High-quality scaling algorithm |
| palettegen | Generates optimal 256-color palette per frame (diff) or globally (full) |
| stats_mode=diff | Optimizes palette for frame differences (better for video with motion) |
| stats_mode=full | Optimizes palette for entire frame (better for static/slide content) |
| paletteuse | Applies the generated palette to produce the final GIF |
| dither=floyd_steinberg | Best general-purpose dithering algorithm for smooth gradients |

## Notes

- GIF format is limited to 256 colors per frame. The palettegen/paletteuse filter chain maximizes quality within this constraint.
- For 1080p source at 30fps, expect output files of 10-35 MB per 20-30 seconds of video.
- If file size is a concern, reduce fps first (has the biggest impact), then resolution.
- Run conversions in parallel when processing multiple files for faster completion.
