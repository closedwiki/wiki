#!/usr/bin/bash
data=data
templates=templates
pub=pub
bin=bin
out=../SeeSkin-`date +%Y-%b-%d`.zip

list="$data/Plugins/SeeSkin.txt \
	$templates/*.see.tmpl \
	$pub/Plugins/SeeSkin/*.css \
	$pub/Plugins/SeeSkin/*.txt \
	$bin/savemulti"

zip $out $list pkg-seeskin.sh

