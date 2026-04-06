#!/bin/sh
# Build poster.pdf here, then copy to docs/reports/poster.pdf. Requires results/figures/*/*.png.
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
mkdir -p ../reports
pdflatex -interaction=nonstopmode poster.tex
if [ ! -f poster.pdf ]; then
  echo "compile failed: poster.pdf not produced" >&2
  exit 1
fi
cp -f poster.pdf ../reports/poster.pdf
rm -f poster.pdf
echo "Done: $(cd ../reports && pwd)/poster.pdf"
