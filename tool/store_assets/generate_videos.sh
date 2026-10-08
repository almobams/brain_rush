#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
mkdir -p store_assets/final/video

encode_android() {
  local locale="$1"
  local gameplay="$2"
  local tail="$3"
  local game_end="$4"
  local game_rate="$5"
  local tail_hold="$6"
  local output="store_assets/final/video/brain_rush_preview_${locale}.mp4"

  # Both inputs are native Android Emulator screenrecord files. The long idle
  # part of the 60-second round is accelerated; the recorded Results -> Daily
  # transition is retained and its last genuine frame is held for readability.
  ffmpeg -hide_banner -loglevel error -y \
    -i "$gameplay" -i "$tail" \
    -filter_complex \
      "[0:v]scale=1080:2400:flags=lanczos,trim=start=0:end=4,setpts=0.75*(PTS-STARTPTS),fps=30,format=yuv420p[home];\
       [0:v]scale=1080:2400:flags=lanczos,trim=start=4:end=${game_end},setpts=${game_rate}*(PTS-STARTPTS),fps=30,format=yuv420p[game];\
       [1:v]scale=1080:2400:flags=lanczos,setpts=PTS-STARTPTS,fps=30,tpad=stop_mode=clone:stop_duration=${tail_hold},trim=duration=5,format=yuv420p[tail];\
       [home][game][tail]concat=n=3:v=1:a=0[out]" \
    -map '[out]' -t 21 -an -r 30 \
    -c:v libx264 -preset medium -crf 18 -profile:v high -level 5.1 \
    -pix_fmt yuv420p -movflags +faststart "$output"
}

encode_ios() {
  local locale="$1"
  local input="$2"
  local start="$3"
  local live_duration="$4"
  local hold="$5"
  local output="store_assets/final/video/brain_rush_appstore_preview_${locale}.mp4"

  # The selected interval is the real app run inside the Simulator recording.
  # Build/install lead-in and the Simulator home screen after the test are cut.
  ffmpeg -hide_banner -loglevel error -y \
    -i "$input" \
    -vf "trim=start=${start}:duration=${live_duration},setpts=PTS-STARTPTS,scale=886:1920:force_original_aspect_ratio=increase:flags=lanczos,crop=886:1920,fps=30,tpad=stop_mode=clone:stop_duration=${hold},trim=duration=21,format=yuv420p" \
    -t 21 -an -r 30 \
    -c:v libx264 -preset medium -crf 18 -profile:v high -level 4.2 \
    -pix_fmt yuv420p -movflags +faststart "$output"
}

encode_android \
  en \
  store_assets/source_capture/video/android/en/brain_rush_gameplay_raw.mp4 \
  store_assets/source_capture/video/android/en/brain_rush_tail_raw.mp4 \
  65 \
  '13/61' \
  4

encode_android \
  ar \
  store_assets/source_capture/video/android/ar/brain_rush_gameplay_raw.mp4 \
  store_assets/source_capture/video/android/ar/brain_rush_tail_raw.mp4 \
  23 \
  '13/19' \
  4

encode_ios \
  en \
  store_assets/source_capture/video/ios/en/brain_rush_raw.mov \
  178 \
  19 \
  2

encode_ios \
  ar \
  store_assets/source_capture/video/ios/ar/brain_rush_raw.mov \
  191 \
  14 \
  7
