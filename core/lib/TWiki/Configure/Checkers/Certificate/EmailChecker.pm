# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

package TWiki::Configure::Checkers::Certificate::EmailChecker;

use base 'TWiki::Configure::Checkers::Certificate';

sub check {
    my $this = shift;

    return $this->checkUsage( shift, 'email' );
}

1;
