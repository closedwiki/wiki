#! /bin/sh

rm -rf bin cpan downloads *.cgi pre-twiki.* post-twiki.pl un-twiki.sh cgi-bin/tmp README install_twiki.cgi\?* htdocs/index.php
# just in case cleanup
rm -f TWikiInstallationReport.html
rmdir cgi-bin htdocs
rm uninstall.sh
