#!/bin/sh
# Build pipeline_gallery_full.pdf (all 36 pipeline replay PNGs). Requires results/figures/pipeline/**/replay_*.png.
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
mkdir -p ../reports
pdflatex -interaction=nonstopmode pipeline_gallery_full.tex
pdflatex -interaction=nonstopmode pipeline_gallery_full.tex
if [ ! -f pipeline_gallery_full.pdf ]; then
  echo "compile failed: pipeline_gallery_full.pdf not produced" >&2
  exit 1
fi
cp -f pipeline_gallery_full.pdf ../reports/pipeline_gallery_full.pdf
rm -f pipeline_gallery_full.pdf
echo "Done: $(cd ../reports && pwd)/pipeline_gallery_full.pdf"
