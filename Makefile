
build :
	npm run-script build

serve :
	npm run-script run

buildtest :
	node_modules/browserify/bin/cmd.js -e src/documents/farevis.js.coffee

