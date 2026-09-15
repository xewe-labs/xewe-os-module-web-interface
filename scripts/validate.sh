#!/usr/bin/env bash
set -euo pipefail

# validate.sh — assemble and compile this module's validation firmware (optionally upload it).
#
# Usage:
#   scripts/validate.sh                         compile for c3, c6 and s3
#   scripts/validate.sh -b c3 [-b s3]           compile for the given boards
#   scripts/validate.sh -b c3 -p /dev/ttyACM0   compile, then upload to the board on that port
#
# Environment:
#   XEWE_MODULES_DIR    folder with the required xewe-os-module-* repos (default: this repo's parent)
#   XEWE_LIBRARIES_DIR  folder with xewe-library-* clones to build against (default: installed libraries)
#
# The firmware is assembled in build/<repo>/: the .ino, this module's src/<Folder>, and the
# src/<Folder> of every module listed (transitively) in depends_modules of module.properties.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"
MODULES_DIR="${XEWE_MODULES_DIR:-$(dirname "${REPO_ROOT}")}"
BUILD_ROOT="${REPO_ROOT}/build"
SKETCH_DIR="${BUILD_ROOT}/${REPO_NAME}"

# same board options as xewe-os-build-toolchain (the default partition is too small for the firmware)
FQBN_OPTS="CDCOnBoot=cdc,CPUFreq=160,DebugLevel=none,EraseFlash=all,FlashMode=qio,FlashSize=4M,JTAGAdapter=default,PartitionScheme=no_ota,UploadSpeed=921600"

die()   { echo "❌ $*" >&2; exit 1; }
usage() { sed -n '4,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# value of <key> in a key=value file (empty when missing)
prop() {
  local line
  line="$(grep -m1 "^$2=" "$1" 2>/dev/null || true)"
  printf '%s' "${line#*=}"
}

# ---- arguments ----
boards=()
port=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--board)
      case "${2:-}" in c3|c6|s3) boards+=("$2") ;; *) die "board must be c3, c6 or s3 (got '${2:-}')" ;; esac
      shift 2 ;;
    -p|--port) port="${2:?missing port}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done
[[ ${#boards[@]} -gt 0 ]] || boards=(c3 c6 s3)
if [[ -n "${port}" && ${#boards[@]} -ne 1 ]]; then
  die "uploading needs exactly one board, e.g. -b c3 -p ${port}"
fi

command -v arduino-cli >/dev/null 2>&1 || die "arduino-cli not found; install it and the esp32:esp32 core"
[[ -f "${REPO_ROOT}/module.properties" ]] || die "module.properties not found in ${REPO_ROOT}"
[[ -f "${REPO_ROOT}/${REPO_NAME}.ino" ]] || die "${REPO_NAME}.ino not found in ${REPO_ROOT}"

SELF_SLUG="$(prop "${REPO_ROOT}/module.properties" slug)"

# ---- resolve modules: dependencies first ----
ORDER=""
VISITING=""

module_dir() {
  if [[ "$1" == "${SELF_SLUG}" ]]; then
    printf '%s' "${REPO_ROOT}"
  else
    printf '%s' "${MODULES_DIR}/xewe-os-module-$1"
  fi
}

visit() {
  local slug="$1" dir deps dep
  case " ${ORDER} " in *" ${slug} "*) return 0 ;; esac
  case " ${VISITING} " in *" ${slug} "*) die "dependency cycle through module '${slug}'" ;; esac

  dir="$(module_dir "${slug}")"
  if [[ ! -f "${dir}/module.properties" ]]; then
    die "missing required module '${slug}': clone xewe-os-module-${slug} into ${MODULES_DIR} (or set XEWE_MODULES_DIR)"
  fi

  VISITING="${VISITING} ${slug}"
  deps="$(prop "${dir}/module.properties" depends_modules)"
  for dep in ${deps//,/ }; do
    visit "${dep}"
  done
  VISITING="${VISITING/ ${slug}/}"
  ORDER="${ORDER} ${slug}"
}

visit "${SELF_SLUG}"

# ---- assemble the build sketch ----
[[ -n "${REPO_NAME}" && "${SKETCH_DIR}" == "${REPO_ROOT}/build/"* ]] || die "unexpected build path ${SKETCH_DIR}"
rm -rf "${SKETCH_DIR}"
mkdir -p "${SKETCH_DIR}/src"
cp "${REPO_ROOT}/${REPO_NAME}.ino" "${SKETCH_DIR}/${REPO_NAME}.ino"

echo "📦 Assembling ${SKETCH_DIR}"
for slug in ${ORDER}; do
  dir="$(module_dir "${slug}")"
  folder="$(prop "${dir}/module.properties" folder)"
  [[ -n "${folder}" && -d "${dir}/src/${folder}" ]] || die "module '${slug}': src/${folder} not found in ${dir}"
  cp -R "${dir}/src/${folder}" "${SKETCH_DIR}/src/"
  echo "   + src/${folder}  ($(basename "${dir}"))"
done

# ---- libraries ----
lib_args=()
if [[ -n "${XEWE_LIBRARIES_DIR:-}" ]]; then
  [[ -d "${XEWE_LIBRARIES_DIR}" ]] || die "XEWE_LIBRARIES_DIR not found: ${XEWE_LIBRARIES_DIR}"
  for lib in "${XEWE_LIBRARIES_DIR}"/xewe-library-*; do
    [[ -f "${lib}/library.properties" ]] && lib_args+=(--library "${lib}")
  done
  echo "📚 Libraries from ${XEWE_LIBRARIES_DIR}"
else
  echo "📚 Libraries from the arduino-cli installation"
fi

# ---- compile ----
failed=0
summary=""
for board in "${boards[@]}"; do
  fqbn="esp32:esp32:esp32${board}:${FQBN_OPTS}"
  log="${BUILD_ROOT}/compile-${board}.log"
  echo "🔧 Compiling for ${board}"
  if arduino-cli compile --fqbn "${fqbn}" --warnings default \
       --build-path "${BUILD_ROOT}/cache/${board}" \
       ${lib_args[@]+"${lib_args[@]}"} "${SKETCH_DIR}" > "${log}" 2>&1; then
    size="$(grep -m1 'Sketch uses' "${log}" | sed 's/ of program storage space.*//' || true)"
    warnings="$(grep -c 'warning:' "${log}" || true)"
    if [[ "${warnings}" -gt 0 ]]; then
      summary="${summary}⚠️  ${board}  ${size}, ${warnings} warning(s), see ${log}\n"
    else
      summary="${summary}✅ ${board}  ${size}\n"
    fi
  else
    failed=1
    summary="${summary}❌ ${board}  failed, see ${log}\n"
    grep -vE 'Downloading index|Error initializing instance' "${log}" | grep -E 'error' | tail -15 >&2 || true
  fi
done

echo
printf '%b' "${summary}"
[[ ${failed} -eq 0 ]] || exit 1

# ---- optional upload ----
if [[ -n "${port}" ]]; then
  board="${boards[0]}"
  echo "📤 Uploading to ${port}"
  arduino-cli upload --fqbn "esp32:esp32:esp32${board}:${FQBN_OPTS}" --port "${port}" \
    --input-dir "${BUILD_ROOT}/cache/${board}" "${SKETCH_DIR}"
  echo "🖥️  Serial monitor: arduino-cli monitor -p ${port} -c baudrate=115200"
fi
