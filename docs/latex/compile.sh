#!/bin/sh
# Build in this folder, then copy main.pdf → docs/reports/final_report.pdf (no PDFs left in latex/).
# (pdflatex may exit non-zero on missing figures while still producing main.pdf.)
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
mkdir -p ../reports
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
if [ ! -f main.pdf ]; then
  echo "compile failed: main.pdf not produced" >&2
  exit 1
fi
cp -f main.pdf ../reports/final_report.pdf
rm -f main.pdf
echo "Done: $(cd ../reports && pwd)/final_report.pdf"