#!/usr/bin/env bash
# Install H.264 video playback codecs and FFmpeg on Linux Mint / Ubuntu

set -e

echo "Installing H.264 video playback codecs and FFmpeg..."
sudo apt update && sudo apt install -y libavcodec-extra60 ffmpeg

echo "Done! H.264 codecs and FFmpeg installed successfully."
