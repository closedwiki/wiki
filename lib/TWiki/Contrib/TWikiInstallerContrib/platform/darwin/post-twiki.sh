#!/bin/sh
# post-twiki.sh
mkdir htdocs/twiki
mv cgi-bin/tmp/twiki/pub/* htdocs/twiki/
mkdir twiki/templates
cp cgi-bin/tmp/twiki/templates/* twiki/templates/
cat >htdocs/index.php <<'EOF'
<?php 
Header( "Location: http://" . $_SERVER[HTTP_HOST] . "/cgi-bin/twiki/view/" );
?>
EOF
rm -fr cgi-bin/TWiki20040901.tar.gz cgi-bin/install_twiki.cgi cgi-bin/tmp

