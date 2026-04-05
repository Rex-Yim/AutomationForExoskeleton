#!/bin/sh
# Build poster.pdf here, then copy to docs/poster.pdf. Requires results/figures/*/*.png.
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode poster.tex
if [ ! -f poster.pdf ]; then
  echo "compile failed: poster.pdf not produced" >&2
  exit 1
fi
cp -f poster.pdf ../poster.pdf
echo "Done: $(cd .. && pwd)/poster.pdf"
