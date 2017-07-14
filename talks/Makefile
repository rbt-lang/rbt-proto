.PHONY: all clean distclean

TEXFIG := $(wildcard figure-*.tex)
MD := $(wildcard *.md)
RST := $(wildcard *.rst)
HTML := $(MD:md=html) $(RST:rst=html)
PNG := $(TEXFIG:tex=png)
JS = node_modules/reveal.js node_modules/mathjax
PANDOC := \
	pandoc \
	-s \
	-t revealjs \
	-V revealjs-url=./node_modules/reveal.js \
	-V theme=white \
	-V slideNumber="'c/t'" \
	-V history=true \
	-V center=false \
	--mathjax=./node_modules/mathjax/MathJax.js?config=TeX-AMS-MML_HTMLorMML \
	-c override.css

all: node_modules/reveal.js node_modules/mathjax $(HTML) $(PNG)

%.html: %.md
	$(PANDOC) -o $@ $<

%.html: %.rst
	$(PANDOC) -o $@ $<

%.png: %.tex
	pdflatex -shell-escape $<

node_modules/%:
	npm install $*

clean:
	rm -f *.html *.aux *.log *.pdf *.png

distclean: clean
	rm -rf node_modules

