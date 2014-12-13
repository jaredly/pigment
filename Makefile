.PHONY: build debug clean server docs

build:
	cd src; hastec Main.lhs --with-js=js/react-stubs.js; say done; cd -

debug:
	cd src; hastec Main.lhs --with-js=js/react-stubs.js --ddisable-js-opts --debug; say done; cd -

clean:
	git clean -xf
	cd src; rm -rf main; cd -

server:
	python -m SimpleHTTPServer 8765

# docs:
# 	rm -rf docs
# 	cd src; rsync -R $(wildcard **.lhs) ../docs; cd -
# 	cd docs; find . -name "*.lhs" -exec rename -v 's/\.lhs$$/\.md/i' "{}" ";"; cd -
# 	mkdocs