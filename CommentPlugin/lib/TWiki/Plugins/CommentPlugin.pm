# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;

use TWiki::Func;

use vars qw( $initialised $VERSION $firstCall $pluginName );

BEGIN {
    $VERSION = 3.009;
    $pluginName = "CommentPlugin";
    $firstCall = 0;
	$initialised = 0;
}

my @dependencies =
  (
   { package => 'TWiki::Plugins', constraint => '>= 1.010' },
   { package => 'TWiki::Contrib::Attrs' }
  );

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.020 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm $TWiki::Plugins::VERSION. Will not work without compatability module." );
    }

    $firstCall = 1;

    return 1;
}

sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;

    unless ($initialised) {
        return unless _lazyInit();
    }

    my $query = TWiki::Func::getCgiQuery();
    return unless( defined( $query ));
    my $action = $query->param( 'comment_action' ) || "";

    if ( defined( $action ) && $action eq "save" ) {
        # $firstCall ensures we only save once, ever.
        if ( $firstCall ) {
            $firstCall = 0;
            TWiki::Plugins::CommentPlugin::Comment::save( $_[2], $_[1], $query );
        }
    } elsif ( $_[0] =~ m/%COMMENT({.*?})?%/o ) {
        # SMELL: Nasty, tacky way to find out where we were invoked from
        my $scriptname = $ENV{'SCRIPT_NAME'} || "";
        # SMELL: unreliable
        my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
        TWiki::Plugins::CommentPlugin::Comment::prompt( $previewing, @_ );
    }
}

sub _lazyInit {
    if ( defined( &TWiki::Func::checkDependencies ) ) {
        my $err = TWiki::Func::checkDependencies($pluginName, \@dependencies);
        if ( $err ) {
            TWiki::Func::writeWarning($err);
            print STDERR $err;
            return 0;
        }
    }

    eval 'use TWiki::Plugins::CommentPlugin::Comment';
    if ($@) {
        print STDERR $@;
        return 0;
    }
    $initialised = 1;
    return 1;
}

1;
