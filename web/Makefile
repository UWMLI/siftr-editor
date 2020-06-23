.PHONY: default deploy

default:
	yarn
	gulp

deploy:
	rsync -vrc * .htaccess mli-sft@mli.doit.wisc.edu:/httpdocs --exclude-from rsync-exclude
	rsync -vrc ../../SiftrNative/web/* mli-sft@mli.doit.wisc.edu:/httpdocs/beta
