#!/bin/sh
# Build system_design.pdf → docs/reports/System_Design.pdf
export PATH="/Library/TeX/texbin:$PATH"
cd "$(dirname "$0")"
mkdir -p ../reports
pdflatex -interaction=nonstopmode system_design.tex
if [ ! -f system_design.pdf ]; then
  echo "compile failed: system_design.pdf not produced" >&2
  exit 1
fi
cp -f system_design.pdf ../reports/System_Design.pdf
rm -f system_design.pdf
echo "Done: $(cd ../reports && pwd)/System_Design.pdf"
