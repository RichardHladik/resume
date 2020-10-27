resume.pdf: resume.tex makra.tex eplain.tex $(wildcard img/*.pdf)
	luatex -fmt pdfcsplain resume

clean:
	rm -f *.log *.aux
