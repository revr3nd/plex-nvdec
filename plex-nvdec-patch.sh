#!/bin/bash

PLEX_PATH="/usr/lib/plexmediaserver"
CODECS=()
ALLOWED_CODECS=("h264" "hevc" "mpeg2video" "mpeg4" "vc1" "vp8" "vp9")
USAGE="Usage: $(basename $0) [OPTIONS]
  -p, --path        Manually define the path to the folder containing the Plex
                      Transcoder
  -c, --codec       Whitelistes codec to enable NVDEC for. When defined, NVDEC
                      will only be enabled for defined codecs. Use -c once per
                      codec
  -u, --uninstall   Remove the NVDEC patch from Plex

Available codec options are:
  h264 (default)       H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10
  hevc (default)       H.265 / HEVC (High Efficiency Video Coding)
  mpeg2video           MPEG-2 video
  mpeg4                MPEG-4 part 2
  vc1                  SMPTE VC-1
  vp8  (default)       On2 VP8
  vp9  (default)       Google VP9"

contains() {
    typeset _x;
    typeset -n _A="$1"
    for _x in "${_A[@]}" ; do
        [ "$_x" = "$2" ] && return 0
    done
    return 1
}

while (( "$#" )); do
  case "$1" in
    -p|--path)
      PLEX_PATH=$2
      shift 2
      ;;
    -c|--codec)
      if contains ALLOWED_CODECS "$2"; then
        CODECS+=$2
      else
        echo "ERROR: Incorrect codec $2, please refer to --help for allowed list" >&2
        exit 1
      fi
      shift 2
      ;;
    -u|--uninstall)
      uninstall=1
      shift 1
      ;;
    -h|--help|*)
      echo "$USAGE"
      exit
      ;;
  esac
done

if [ ${#CODECS[@]} -eq 0 ]; then
  CODECS=("h264" "hevc" "vp8" "vp9")
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

if [ ! -f "$PLEX_PATH/Plex Transcoder" ]; then
  if [ -f "/usr/lib64/plexmediaserver/Plex Transcoder"]; then
    PLEX_PATH="/usr/lib64/plexmediaserver"
  else
    echo "ERROR: Plex transcoder not found. Please ensure plex is installed and use -p to manually define the path to the Plex Transcoder" >&2
    exit 1
  fi
fi

pcheck=$(tail -n 1 "$PLEX_PATH/Plex Transcoder" | tr -d '\0')
if [ "$uninstall" == "1" ]; then
  if [ "$pcheck" == "##patched" ]; then
    if pgrep -x "Plex Transcoder" >/dev/null ; then
      echo "ERROR: Plex Transcoder is currently running. Please stop any open transcodes and run again" >&2
      exit 1
    fi
    mv "$PLEX_PATH/Plex Transcoder2" "$PLEX_PATH/Plex Transcoder"
    echo "Uninstall of patch complete!"
    exit
  else
    echo "ERROR: NVDEC Patch not detected as installed. Cannot uninstall."
    exit 1
  fi
fi

if [ "$pcheck" == "##patched" ]; then
  echo "Patch has already been applied! Reapplying wrapper script"
else
  if pgrep -x "Plex Transcoder" >/dev/null ; then
    echo "ERROR: Plex Transcoder is currently running. Please stop any open transcodes and run again" >&2
    exit 1
  fi
  mv "$PLEX_PATH/Plex Transcoder" "$PLEX_PATH/Plex Transcoder2"
fi

for i in "${CODECS[@]}"; do
  cstring+='"'"$i"'" '
done
cstring="${cstring::-1}"

cat > "$PLEX_PATH/Plex Transcoder" <<< '#!/bin/bash'
cat >> "$PLEX_PATH/Plex Transcoder" <<< 'PLEX_PATH="'"$PLEX_PATH"'"'
cat >> "$PLEX_PATH/Plex Transcoder" <<< 'ALLOWED_CODECS=('"$cstring"')'
cat >> "$PLEX_PATH/Plex Transcoder" <<< '
contains() {
  typeset _x;
  typeset -n _A="$1"
  for _x in "${_A[@]}" ; do
    [ "$_x" = "$2" ] && return 0
  done
  return 1
}

allowed_codec() {
  for i in "$@"; do
    if [ "-i" == "$i" ]; then
      return 1
    elif contains ALLOWED_CODECS "$i"; then
      return 0
    fi
  done
  return 1
}

if allowed_codec $*; then
  exec "$PLEX_PATH/Plex Transcoder2" -hwaccel nvdec "$@"
else
  exec "$PLEX_PATH/Plex Transcoder2" "$@"
fi

##patched'

chmod +x "$PLEX_PATH/Plex Transcoder"

echo "Patch applied successfully!"
