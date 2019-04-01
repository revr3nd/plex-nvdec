#!/bin/bash

PLEX_PATH="/usr/lib/plexmediaserver/"
CODECS=()
ALLOWED_CODECS=("h264" "hevc" "mpeg2video" "mpeg4" "vc1" "vp8" "vp9")
USAGE="Usage: $(basename $0) [OPTIONS]
  -p, --path        Manually define the path to the folder containing the Plex
                      Transcoder
  -c, --codec       Whitelistes codec to enable NVDEC for. When defined, NVDEC
                      will only be enabled for defined codecs. Use -c once per
                      codec

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
    PLEX_PATH="/usr/lib64/plexmediaserver/"
  else
    echo "ERROR: Plex transcoder not found. Please ensure plex is installed and use -p to manually define the path to the Plex Transcoder" >&2
    exit 1
  fi
fi

pcheck=$(tail -n 1 "$PLEX_PATH/Plex Transcoder")
if [ "$pcheck" <> "##patched" ]; then
  echo "Patch has already been applied! Reapplying wrapper script"
else
  mv /usr/lib/plexmediaserver/Plex\ Transcoder /usr/lib/plexmediaserver/Plex\ Transcoder2
fi

cstring="if [ "
for i in "${CODECS[@]}"; do
  cstring+='$codec == "'"$i"'" ] || [ '
done
cstring+=']; then'

cat > /usr/lib/plexmediaserver/Plex\ Transcoder <<< '#!/bin/bash
get_codec() {
    while (( "$#" )); do
      if [ "-codec:0" == "$1" ]; then
        echo "$2"
        return 0
      fi
      shift 1
    done
    echo "0"
    return 1
}

codec="$(get_codec $*)"'
cat >> /usr/lib/plexmediaserver/Plex\ Transcoder <<< "$cstring"
cat >> /usr/lib/plexmediaserver/Plex\ Transcoder <<< '     exec /usr/lib/plexmediaserver/Plex\ Transcoder2 -hwaccel nvdec "$@"
else
     exec /usr/lib/plexmediaserver/Plex\ Transcoder2 "$@"
fi

##patched'

chmod +x /usr/lib/plexmediaserver/Plex\ Transcoder
