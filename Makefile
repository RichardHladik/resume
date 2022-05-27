all: cv.pdf

cv.pdf: cv.tex makra.tex eplain.tex bibliography.bib $(wildcard img/*.pdf)
	yes X | luatex -fmt pdfcsplain cv
	bibtex cv

clean:
	rm -f *.log *.aux
