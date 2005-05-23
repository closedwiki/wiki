# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

# Tests for the plugin component
#
# The tests require TWIKI_LIBS to include a pointer to the lib
# directory of a TWiki installation, so it can pick up the bits
# of TWiki it needs to include.
#
use strict;

package WysiwygPluginTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift(@INC,'../../../..');
}

use TWiki;
use TWiki::Plugins::WysiwygPlugin;

use Carp;
$SIG{__DIE__} = sub { Carp::confess $_[0] };

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_load {
    my $this = shift;
    my $query = new CGI({
                         'skin' => [ 'kupu' ]
                        });
    TWiki::initialize('/Sandbox/WysiwygPluginTest', 'guest',
                      undef, undef, $query );
    my $text = '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]';

    # call the common tags handler. Can't call the twiki function because
    # we are testing the plugin in the checkout area, not the one
    # installed in the TWiki (if any)
    TWiki::Plugins::WysiwygPlugin::commonTagsHandler( $text, "WysiwygPluginTest", "Sandbox" );
    # Can't do this usefully, as the test topic is not on disc and
    # therefore can't be loaded.
    #$this->assert_equals('<a href="'.TWiki::Func::getViewUrl("Sandbox","WikiSyntax").'">syntax</a><a href="http://gnu.org">GNU</a><a href="http://xml.org">XML</a>', $text);
}

sub test_save {
    my $this = shift;
    # call the beforeSaveHandler
    my $query = new CGI({
                         'wysiwyg_edit' => [ 1 ],
                        });

    TWiki::initialize('/Sandbox/WysiwygPluginTest', 'guest',
                      undef, undef, $query );

    my $text = '<a href="'.TWiki::Func::getViewUrl("Sandbox","WikiSyntax").'">syntax</a><a href="http://gnu.org">GNU</a><a href="http://xml.org">XML</a>';

    TWiki::Plugins::WysiwygPlugin::beforeSaveHandler( $text, "WysiwygPluginTest", "Sandbox" );

    $this->assert_equals("[[Sandbox.WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]", $text);
}


1;
