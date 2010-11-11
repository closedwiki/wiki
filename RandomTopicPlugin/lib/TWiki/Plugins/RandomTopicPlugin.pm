# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Micahel Sparks
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

package TWiki::Plugins::RandomTopicPlugin;

use strict;

use vars qw(
            $VERSION $RELEASE @topicList $defaultIncludes $defaultExcludes
    );

$VERSION = '$Rev$';
$RELEASE = '2010-11-10';


sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $defaultIncludes = TWiki::Func::getPreferencesValue( "RANDOMTOPICPLUGIN_INCLUDE" );
    $defaultExcludes = TWiki::Func::getPreferencesValue( "RANDOMTOPICPLUGIN_EXCLUDE" );

    @topicList = TWiki::Func::getTopicList( $web );

    return 1;
}

sub handleRandomPage {
    my $attr = shift;

    my $format;
    my $topics = 1;
    my $includes;
    my $excludes;

    $format =
      TWiki::Func::extractNameValuePair( $attr, "format" ) ||
          "\$t* \$topic\$n";
    $topics =
      TWiki::Func::extractNameValuePair( $attr, "topics" ) || 1;

    $includes =
      TWiki::Func::extractNameValuePair( $attr, "include" ) ||
          $defaultIncludes || "^.+\$";

    $excludes =
      TWiki::Func::extractNameValuePair( $attr, "exclude" ) ||
          $defaultExcludes || "^\$";

    my @pickFrom = grep { /$includes/ && !/$excludes/ } @topicList;

    my $result = "";
    my %chosen = ();
    my $pickable = scalar( @pickFrom );
    while ( $topics && $pickable ) {
        my $i = int( rand( scalar @pickFrom ));
        unless ( $chosen{$i} ) {
            my $line = $format;
            $line =~ s/\$topic/$pickFrom[$i]/g;
            $line =~ s/\$t/\t/g;
            $line =~ s/\$n/\n/g;
            $result .= $line;
            $topics--;
            $pickable--;
            $chosen{$i} = 1;
        }
    }
    return $result;
}

sub commonTagsHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    $_[0] =~ s/%RANDOMTOPIC%/&handleRandomPage()/ge;
    $_[0] =~ s/%RANDOMTOPIC{(.*?)}%/&handleRandomPage($1)/ge;
}

1;
