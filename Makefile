all: resume.pdf cv.pdf

resume.pdf: resume.tex makra.tex eplain.tex $(wildcard img/*.pdf)
	yes X | luatex -fmt pdfcsplain resume

cv.pdf: cv.tex makra-cv.tex makra.tex eplain.tex bibliography.bib $(wildcard img/*.pdf)
	yes X | luatex -fmt pdfcsplain cv
	bibtex cv
	yes X | luatex -fmt pdfcsplain cv

clean:
	rm -f *.log *.aux
