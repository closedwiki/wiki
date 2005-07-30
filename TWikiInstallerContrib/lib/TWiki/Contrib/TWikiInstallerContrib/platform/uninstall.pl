#!/usr/bin/perl -w
use strict;

use File::Path qw( rmtree );

print `chmod -f -R a+rwx cgi-bin/lib/CPAN`;
rmtree( [ qw( bin/ cpan/ downloads/ config/ cgi-bin/twiki/ cgi-bin/lib/ cgi-bin/tmp/ htdocs/twiki/ ) ] );
unlink qw( install_twiki.cgi cgi-bin/install_twiki.cgi pre-twiki.pl post-twiki.pl un-twiki.pl );
unlink qw( pre-twiki.log );
unlink qw( README );
unlink qw( TWikiInstallationReport.html );
unlink qw( uninstall.pl );
