#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_FILE="${REPO_ROOT}/compile_commands.json"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Rscript is required but not found in PATH." >&2
  exit 1
fi

BUILD_EXPR="if (requireNamespace('pkgbuild', quietly = TRUE)) { pkgbuild::clean_dll(); pkgbuild::compile_dll('.') } else { stop('Package \'pkgbuild\' is required. Install with install.packages(\"pkgbuild\")') }"
BUILD_CMD=(Rscript -e "${BUILD_EXPR}")

rm -f "${OUTPUT_FILE}"

cd "${REPO_ROOT}"

run_capture_with() {
  local tool="$1"
  echo "Trying ${tool}..."

  case "${tool}" in
    bear)
      bear --output "${OUTPUT_FILE}" -- "${BUILD_CMD[@]}"
      ;;
    intercept-build)
      intercept-build --cdb "${OUTPUT_FILE}" -- "${BUILD_CMD[@]}"
      ;;
    compiledb)
      compiledb -o "${OUTPUT_FILE}" -- "${BUILD_CMD[@]}"
      ;;
    *)
      echo "Unsupported capture tool: ${tool}" >&2
      return 1
      ;;
  esac
}

choose_tools=()
for candidate in bear intercept-build compiledb; do
  if command -v "${candidate}" >/dev/null 2>&1; then
    choose_tools+=("${candidate}")
  fi
done

if [[ ${#choose_tools[@]} -eq 0 ]]; then
  echo "No supported capture tool found (bear/intercept-build/compiledb)." >&2
  echo "Install one of them, for example: sudo apt install bear" >&2
  exit 1
fi

generated=0
for tool in "${choose_tools[@]}"; do
  rm -f "${OUTPUT_FILE}"
  if run_capture_with "${tool}" && [[ -s "${OUTPUT_FILE}" ]]; then
    generated=1
    break
  fi
  echo "${tool} failed to produce compile_commands.json, trying next fallback..." >&2
done

if [[ ${generated} -ne 1 || ! -s "${OUTPUT_FILE}" ]]; then
  echo "compile_commands.json was not generated or is empty." >&2
  exit 1
fi

echo "Generated ${OUTPUT_FILE}"
