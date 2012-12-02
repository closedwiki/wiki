# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2002-2007 TWiki:Main.LingLo
# Copyright (C) 2007-2012 TWiki:TWiki.TWikiContributor
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

# =========================
package TWiki::Plugins::BeautifierPlugin;
use Beautifier::Core;
use Output::HTML;

# =========================

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug %langs
    );

$VERSION = '$Rev$';
$RELEASE = '2012-12-02';

# =========================

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    %langs = ();

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between BeautifierPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "BEAUTIFIERPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::BeautifierPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # &TWiki::Func::writeDebug( "- BeautifierPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Find code tag and beautify
    $_[0] =~ s/%CODE{(.*?)}%(.*?)%ENDCODE%/&handleCode($1, $2)/gseo;
}

# =========================

sub handleCode
{
    my ( $args, $codeFragment ) = @_;

    TWiki::Func::addToHEAD( BEAUTIFIERPLUGIN_CODEFRAGMENT_CSS => '<link rel="stylesheet" href="%PUBURL%/%TWIKIWEB%/BeautifierPlugin/style.css" type="text/css" media="all" />' );

    my $lang = TWiki::Func::extractNameValuePair( $args );
       # || default language (eg, TWiki::Func::getPreferencesValue(uc 'BEAUTIFIERPLUGIN_LANGUAGE' ) 
    unless ($langs->{$lang})
    {
        local $SIG{__DIE__};
        eval "use HFile::HFile_$lang";
        if ($@)
        {
            return qq{<b>BeautifierPlugin Error: Unable to handle "$lang" language.</b>}
		. _formatBeautifierOutput( $codeFragment );
        }
        my $hfile = eval "new HFile::HFile_$lang";
        $langs->{$lang} = new Beautifier::Core($hfile, new Output::HTML);
    }
    return _formatBeautifierOutput( $langs->{$lang}->highlight_text( $codeFragment ) );
}

# =========================

sub _formatBeautifierOutput {
    return '<div class="BeautifierPlugin"><div class="fragment"><pre>' . shift() . '</pre></div></div>';
}

# =========================
1;
