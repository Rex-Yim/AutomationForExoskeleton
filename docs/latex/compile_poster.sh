#!/bin/sh
# Build poster.pdf (A0 landscape). Run from docs/latex/; requires results/*.png.
set -e
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode poster.tex
echo "Done: $(pwd)/poster.pdf"
