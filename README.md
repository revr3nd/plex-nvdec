# Plex-NVDEC

This patch is designed to enable NVDEC functions on Linux installations of Plex Media Server version 1.15.1.791 and later. This is a stopgap patch to enable the feature until Plex officially supports the feature natively.

## Requirements

- Plex Media Server must be a least version 1.15.1.791
- You must have a NVIDIA card and drivers installed with support for NVDEC (see https://developer.nvidia.com/video-encode-decode-gpu-support-matrix for a list of supported cards)

## Installation

To install this patch perform the following:
1. Copy the plex-nvdec-patch.sh to your Plex server in any convenient to use directory.
1. Enable execution of the script by running: chmod +x ./plex-nvdec-patch.sh
1. Execute the script with sudo: sudo bash -c ./plex-nvdec-patch.sh

Note that you must rerun this patch every time PMS is updated.
If you need to remove the script, you can either manually reinstall PMS or run the script with the --uninstall parameter.
