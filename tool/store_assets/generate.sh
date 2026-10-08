#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

command -v flutter >/dev/null
command -v ffmpeg >/dev/null
command -v ffprobe >/dev/null
command -v magick >/dev/null
command -v python3 >/dev/null

source_count="$(find store_assets/source_capture -type f -name '0[1-6]_*.png' | wc -l | tr -d ' ')"
[[ "$source_count" == 60 ]] || {
  printf 'Expected 60 native source screenshots, found %s. Capture missing devices before composing.\n' "$source_count" >&2
  exit 1
}

python3 tool/store_assets/write_source_metadata.py
flutter test tool/store_assets/compose_test.dart --update-goldens "$@"

while IFS= read -r image; do
  temporary="$(mktemp "${TMPDIR:-/tmp}/brain-rush-rgb.XXXXXX.png")"
  magick "$image" -alpha off "PNG24:$temporary"
  mv "$temporary" "$image"
done < <(find store_assets/final -type f -name '*.png' | sort)

tool/store_assets/generate_videos.sh

magick montage \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Rush-Icon-App-1024x1024@1x.png \
  store_assets/final/android/feature_graphic_en.png \
  store_assets/final/android/en/phone/01_home.png \
  store_assets/final/video/poster_en.png \
  store_assets/final/video/youtube_thumbnail_en.png \
  -thumbnail '400x500>' -background '#070f20' -geometry '400x500+20+20' \
  -tile 5x1 -alpha off PNG24:store_assets/final/contact_sheet_icon_verification.png

tool/store_assets/validate.sh
