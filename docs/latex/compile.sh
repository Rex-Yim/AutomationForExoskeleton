#!/bin/sh
# Build main.pdf (run from docs/latex after BasicTeX is installed)
set -e
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
echo "Done: $(pwd)/main.pdf"
