package TWiki::Plugins::RenderFormPlugin;

use strict;

use vars qw( $VERSION $RELEASE $REVISION $debug $pluginName );

$VERSION = '$Rev$';

$RELEASE = 'Dakar';

$REVISION = '1.000'; #dro# initial version

$pluginName = 'RenderFormPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    use TWiki::Plugins::RenderFormPlugin::Core;
    eval {
        $_[0] =~ s/%RENDERFORM{(.*)}%/TWiki::Plugins::RenderFormPlugin::Core::render($1,$_[1],$_[2])/ge;
    };
    TWiki::Func::writeWarning($@) if $@;
}
