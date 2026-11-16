#!/usr/bin/env bash
#
# Typst Extras - Example images
# Renders each example of this folder to PDF with the extension of the repository,
# then converts its first page to the PNG image next to this folder.
# Run it from anywhere: docs/assets/examples/_src/build.sh
# It needs Quarto and pdftoppm (poppler).
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/../../../.." && pwd)"
images="$(dirname "${here}")"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# The examples render outside docs/, so the website project does not apply to them.
mkdir -p "${work}/_extensions"
cp -R "${root}/_extensions/typst-extras" "${work}/_extensions/"
cp "${here}"/*.qmd "${work}/"

for source in "${work}"/*.qmd; do
  name="$(basename "${source}" .qmd)"
  echo "rendering ${name}"
  (cd "${work}" && quarto render "${name}.qmd" --to typst)
  pdftoppm -png -r 110 -singlefile "${work}/${name}.pdf" "${images}/${name}"
done
