#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

files=(
  01_home.png
  02_gameplay.png
  03_challenges.png
  04_daily.png
  05_ranking.png
  06_results.png
)
validated=0

fail() {
  printf 'Validation failed: %s\n' "$1" >&2
  exit 1
}

check_png() {
  local path="$1"
  local expected_width="$2"
  local expected_height="$3"
  local require_opaque="$4"
  [[ -f "$path" ]] || fail "missing $path"
  local info width height channels
  info="$(identify -quiet -format '%w %h %[channels]' "$path")" || fail "invalid PNG $path"
  read -r width height channels <<<"$info"
  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] ||
    fail "$path is ${width}x${height}, expected ${expected_width}x${expected_height}"
  if [[ "$require_opaque" == true && "$channels" == *a* ]]; then
    fail "$path contains an alpha channel ($channels)"
  fi
  validated=$((validated + 1))
}

check_screenshot_set() {
  local platform="$1"
  local device="$2"
  local width="$3"
  local height="$4"
  local locale file
  for locale in en ar; do
    for file in "${files[@]}"; do
      check_png "store_assets/source_capture/$platform/$locale/$device/$file" "$width" "$height" false
      check_png "store_assets/final/$platform/$locale/$device/$file" "$width" "$height" true
    done
  done
}

check_screenshot_set ios iphone 1320 2868
check_screenshot_set ios ipad 2064 2752
check_screenshot_set android phone 1344 2992
check_screenshot_set android tablet_7 1200 1920
check_screenshot_set android tablet_10 1600 2560

for locale in en ar; do
  check_png "store_assets/final/android/feature_graphic_$locale.png" 1024 500 true
  check_png "store_assets/final/video/poster_$locale.png" 886 1920 true
  check_png "store_assets/final/video/youtube_thumbnail_$locale.png" 1280 720 true
done

check_png ios/Runner/Assets.xcassets/AppIcon.appiconset/Rush-Icon-App-1024x1024@1x.png 1024 1024 false
check_png store_assets/final/contact_sheet_icon_verification.png 2200 540 true

check_video() {
  local path="$1"
  local expected_width="$2"
  local expected_height="$3"
  [[ -f "$path" ]] || fail "missing $path"
  local stream codec width height pix_fmt frame_rate duration audio
  stream="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate -of csv=p=0 "$path")"
  IFS=',' read -r codec width height pix_fmt frame_rate <<<"$stream"
  [[ "$codec" == h264 ]] || fail "$path codec is $codec, expected h264"
  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] ||
    fail "$path is ${width}x${height}, expected ${expected_width}x${expected_height}"
  [[ "$pix_fmt" == yuv420p ]] || fail "$path pixel format is $pix_fmt, expected yuv420p"
  [[ "$frame_rate" == 30/1 ]] || fail "$path frame rate is $frame_rate, expected 30/1"
  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$path")"
  awk -v value="$duration" 'BEGIN { exit !(value >= 20.9 && value <= 21.1) }' ||
    fail "$path duration is $duration seconds, expected 21 seconds"
  audio="$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$path")"
  [[ -z "$audio" ]] || fail "$path contains an audio stream"
  validated=$((validated + 1))
}

for locale in en ar; do
  check_video "store_assets/final/video/brain_rush_preview_$locale.mp4" 1080 2400
  check_video "store_assets/final/video/brain_rush_appstore_preview_$locale.mp4" 886 1920
done

check_source_video() {
  local path="$1"
  local expected_width="$2"
  local expected_height="$3"
  [[ -f "$path" ]] || fail "missing native recording $path"
  local stream codec width height
  stream="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 "$path")"
  IFS=',' read -r codec width height <<<"$stream"
  [[ "$codec" == h264 ]] || fail "$path codec is $codec, expected h264"
  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] ||
    fail "$path is ${width}x${height}, expected native ${expected_width}x${expected_height}"
  validated=$((validated + 1))
}

for locale in en ar; do
  check_source_video "store_assets/source_capture/video/android/$locale/brain_rush_gameplay_raw.mp4" 720 1600
  check_source_video "store_assets/source_capture/video/android/$locale/brain_rush_tail_raw.mp4" 720 1600
  check_source_video "store_assets/source_capture/video/ios/$locale/brain_rush_raw.mov" 1320 2868
done

source_count="$(find store_assets/source_capture -type f -name '0[1-6]_*.png' | wc -l | tr -d ' ')"
final_count="$(find store_assets/final/ios store_assets/final/android -type f -name '0[1-6]_*.png' | wc -l | tr -d ' ')"
metadata_count="$(find store_assets/source_capture -type f -name '0[1-6]_*.metadata.json' | wc -l | tr -d ' ')"
[[ "$source_count" == 60 ]] || fail "native source screenshot count is $source_count, expected 60"
[[ "$final_count" == 60 ]] || fail "final screenshot count is $final_count, expected 60"
[[ "$metadata_count" == 60 ]] || fail "metadata sidecar count is $metadata_count, expected 60"

python3 tool/store_assets/validate_metadata.py
printf 'Validated %s store assets successfully.\n' "$validated"
