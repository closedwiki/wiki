#!/usr/bin/bash
data=data
templates=templates
pub=pub
bin=bin
out=SeeSkinToo-`date +%Y-%b-%d`.zip
localcvs=/cygdrive/d/src/twikiplugins/SeeSkin

list="$data/Plugins/SeeSkinToo.txt \
	$templates/*.seetoo.tmpl \
	$pub/Plugins/SeeSkinToo/*.css \
	$pub/Plugins/SeeSkinToo/*.txt \
	$bin/savemulti"

# update docs in attach directory
cp $data/Plugins/SeeSkinToo.txt $pub/Plugins/SeeSkinToo/SeeSkinToo.txt

# make archive distribtion 
zip $out $list pkg-seeskintoo.sh

# update local CVS
cd $localcvs 
unzip $OLDPWD/$out

