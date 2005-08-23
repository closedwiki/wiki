#!/usr/bin/perl -w
use strict;

use File::Path qw( rmtree );

rmtree( [ qw( cgi-bin/install_twiki.cgi cgi-bin/tmp/ cgi-bin/twiki/ cgi-bin/lib htdocs/twiki/ twiki/ ) ] );
