#!/bin/sh
# Build in this folder, then copy main.pdf → docs/final_report.pdf (no aux clutter in docs/).
# (pdflatex may exit non-zero on missing figures while still producing main.pdf.)
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
if [ ! -f main.pdf ]; then
  echo "compile failed: main.pdf not produced" >&2
  exit 1
fi
cp -f main.pdf ../final_report.pdf
echo "Done: $(cd .. && pwd)/final_report.pdf"