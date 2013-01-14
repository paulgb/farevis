
build :
	npm run-script build

serve :
	npm run-script run

publish : build
	cd out; s3cmd sync ./ s3://farevis.bitaesthetics.com/

buildtest :
	node_modules/browserify/bin/cmd.js -e src/documents/farevis.js.coffee

