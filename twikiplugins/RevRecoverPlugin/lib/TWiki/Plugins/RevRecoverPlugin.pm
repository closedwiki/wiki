#
# Plugin that recovers revision
# Peter Albiez, 2001

# =========================
package TWiki::Plugins::RevRecoverPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between RevRecoverPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "REVRECOVERPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::RevRecoverPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- RevRecoverPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;



    if ( $_[0] !~ m/(?:\b(\w+)\.)?([A-Z]+[a-z]+[A-Z]\w*)\?rev=(\d+\.\d+)(\"|\&)/o ) {
	$_[0] =~ s/(?:\b(\w+)\.)?([A-Z]+[a-z]+[A-Z]\w*)\?rev=(\d+\.\d+)\b/&handleUrl($1,$2,$3)/ego;
    }
}

sub handleUrl {
    my $web = shift;
    my $topic = shift;
    my $rev = shift;

    if ( defined($1) ) {
	return "<A HREF=\"%SCRIPTURL%\/view\/$web\/$topic\?rev=$rev\">$web\.$topic\?$rev<\/A>";
    } else {
	return "<A HREF=\"%SCRIPTURL%\/view\/%WEB%\/$topic\?rev=$rev\">$topic\?$rev<\/A>";
    }
}

1;
