# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;

use TWiki::Func;

use vars qw( $initialised $VERSION $firstCall $pluginName $testing );

BEGIN {
    $VERSION = '3.003';
    $pluginName = "CommentPlugin";
    $firstCall = 0;
	$testing = 0;
	$initialised = 0;
}

my @dependencies =
  (
   { package => 'TWiki::Plugins', constraint => '>= 1.010' },
   { package => 'TWiki::Plugins::SharedCode::Attrs' }
  );

sub initPlugin {
  #my ( $topic, $web, $user, $installWeb ) = @_;

  if( $TWiki::Plugins::VERSION < 1.020 ) {
    TWiki::Func::writeWarning( "Version mismatch between ActionTrackerPlugin and Plugins.pm $TWiki::Plugins::VERSION. Will not work without compatability module." );
  }
  my $depsOK = 1;
  foreach my $dep ( @dependencies ) {
    my ( $ok, $ver ) = ( 0, 0 );
    eval "use $dep->{package}";
    unless ( $@ ) {
	  if ( defined( $dep->{constraint} )) {
		eval "\$ver = \$$dep->{package}::VERSION;\$ok = ( \$ver $dep->{constraint})";
	  } else {
		$ok = 1;
	  }
	}
	unless ( $ok ) {
	  my $mess = "$dep->{package} ";
	  $mess .= "version $dep->{constraint} " if ( $dep->{constraint} );
	  $mess .= "is required for $pluginName version $VERSION. ";
	  $mess .= "$dep->{package} $ver is currently installed. " if ( $ver );
	  $mess .= "Please check the plugin installation documentation. ";
	  TWiki::Func::writeWarning( $mess );
	  print STDERR "$mess\n";
	  $depsOK = 0;
	}
  }
  return 0 unless $depsOK;
  
  $firstCall = 1;
  
  return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;

  my $query = TWiki::Func::getCgiQuery();
  return unless( defined( $query ));
  my $action = $query->param( 'comment_action' ) || "";
  if ( defined( $action ) && $action eq "save"
	   && ( $testing || $query->path_info() eq "/$_[2]/$_[1]" )
	 ) {
    # $firstCall ensures we only save once, ever.
    if ( $firstCall ) {
      $firstCall = 0;
      CommentPlugin::Comment::save( $_[2], $_[1], $query );
    }
  } elsif ( $_[0] =~ m/%COMMENT({.*?})?%/o ) {
    # Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || "";
    my $previewing = ($scriptname =~ /\/preview/ ||
		      $scriptname =~ /\/gnusave/);
    CommentPlugin::Comment::prompt( $previewing, @_ );
  }
}

sub _lazyInit {
  eval {
	use TWiki::Plugins::CommentPlugin::Comment;
  };

  $initialised = 1;
}

1;
