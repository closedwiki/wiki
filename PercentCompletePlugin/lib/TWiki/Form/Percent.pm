# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# This packages subclasses TWiki::Form::FieldDefinition to implement
# the =percent= type

package TWiki::Form::Percent;
use base 'TWiki::Form::FieldDefinition';

use strict;

# ========================================================
sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );
    my $size = $this->{size} || '0';
    $size =~ s/[^\d]//g;
    $size = 8 if( !$size || $size < 1 );
    $this->{size} = $size;
    return $this;
}

# ========================================================
sub renderForDisplay {
    my ( $this, $format, $value ) = @_;

    require TWiki::Plugins::PercentCompletePlugin;
    my $text = TWiki::Plugins::PercentCompletePlugin::renderForDisplay( $value );
    $format =~ s/\$title/$this->{title}/g;
    $format =~ s/\$value/$text/g;

    return $format;
}

# ========================================================
sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    require TWiki::Plugins::PercentCompletePlugin;
#    TWiki::Plugins::PercentCompletePlugin::addHEAD();
    my $text = TWiki::Plugins::PercentCompletePlugin::renderForEdit( $this->{name}, $value );

    my $session = $this->{session};
    $text = $session->renderer->getRenderedVersion(
        $session->handleCommonTags( $text, $web, $topic ));

    return ( '', $text );
}

# ========================================================
1;
