#!/usr/bin/env bash
#
# Typst Extras - Typst library tests
# Compiles every tests/typst/*.typ file and stops at the first failure.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/../.." && pwd)"

shopt -s nullglob
for file in "${here}"/*.typ; do
  echo "compiling ${file#"${root}"/}"
  quarto typst compile --root "${root}" "${file}" "${file%.typ}.pdf"
done

quarto pandoc lua "${root}/tests/lua/modules.lua"
