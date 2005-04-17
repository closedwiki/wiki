#!/usr/bin/perl -w
use strict;

use File::Path qw( rmtree );

rmtree( [ qw( bin/ cpan/ downloads/ config/ cgi-bin/twiki/ cgi-bin/lib/ ) ], 1 );
unlink qw( install_twiki.cgi cgi-bin/install_twiki.cgi pre-twiki.pl post-twiki.pl un-twiki.pl );
unlink qw( README );
unlink qw( TWikiInstallationReport.html );
unlink qw( uninstall.pl );
