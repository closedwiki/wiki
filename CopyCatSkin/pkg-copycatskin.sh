#!/usr/bin/bash
skin=CopyCatSkin
data=data
templates=templates
pub=pub
bin=bin
out=$skin-`date +%Y-%b-%d`.zip
localcvs=/cygdrive/d/src/twikiplugins/$skin

list="$data/Plugins/$skin.txt \
	$templates/*.cc-*.tmpl \
	$pub/Plugins/$skin/*.css \
	$pub/Plugins/$skin/*.txt"

# update docs in attach directory
cp $data/Plugins/$skin.txt $pub/Plugins/$skin/$skin.txt

# make archive distribtion 
zip $out $list pkg-copycatskin.sh

# update local CVS
cd $localcvs 
unzip $OLDPWD/$out

