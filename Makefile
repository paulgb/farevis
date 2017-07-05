
out/farevis.js : src/farevis.coffee
	mkdir -p out
	node_modules/.bin/browserify -t coffeeify $< > $@

