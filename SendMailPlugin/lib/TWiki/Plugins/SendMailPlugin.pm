# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2012 TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the AUTHORS
# file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::SendMailPlugin;
use strict;
our $pluginName = 'SendMailPlugin';

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '2012-02-14';

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Send mail from TWiki topics, useful for workflow automation';

our $NO_PREFS_IN_TOPIC = 1;
our $debug;

#=====================================================================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{SendMailPlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'SENDMAIL', \&_SENDMAIL );

    # Plugin correctly initialized
    return 1;
}

#=====================================================================
sub _SENDMAIL {
    my($session, $params, $theTopic, $theWeb, $meta, $textRef) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # $meta     - topic meta-data to use while expanding, can be undef (Since TWiki::Plugins::VERSION 1.4)
    # $textRef  - reference to unexpanded topic text, can be undef (Since TWiki::Plugins::VERSION 1.4)

    # Return: the result of processing the variable

    # For example, %EXAMPLEVAR{'existence' proof="thinking"}%
    # $params->{_DEFAULT} will be 'existence'
    # $params->{proof} will be 'thinking'

    return 'To be coded.';
}

#=====================================================================
1;
