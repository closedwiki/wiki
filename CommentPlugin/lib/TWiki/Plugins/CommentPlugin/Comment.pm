use strict;
use integer;

use TWiki::Plugins::CommentPlugin::Attrs;

{ package CommentPlugin::Comment;

  # PRIVATE get the given template and do standard expansions
  sub _getTemplate {
    my ( $name, $topic, $web ) = @_;

    # Get the templates
    my $templateFile =
      TWiki::Func::getPreferencesValue("COMMENTPLUGIN_TEMPLATES") ||
	"comments";
    my $templates = TWiki::Func::readTemplate( $templateFile );
    if (! $templates ) {
      TWiki::Func::writeWarning("No such template file '$templateFile'");
      return;
    }

    my $t =
      TWiki::Func::expandCommonVariables( "%TMPL:P{$name}%", $topic, $web );
    
    return "%RED%No such template def %<nop>TMPL:DEF{$name}%%ENDCOLOR%"
      unless ( defined($t) && $t ne "" );

    return $t;
  }

  # PUBLIC method that generates the prompt for comment entry.
  # Handles the following special variables in the template:
  # %DISABLED%
  # %ACTIONURL%
  # %MESSAGE%
  # %TYPE%
  # %NAME%
  # @return the HTML that implements a comment entry box
  sub prompt {
    #my ( $text, $topic, $web ) = @_;

    # Nasty, tacky, error prone way to find out if we are previewing or not
    my $scriptname = $ENV{'SCRIPT_NAME'} || "";
    my $previewing = ( $scriptname =~ /^.*\/preview/ );

    my $defaultType = 
	TWiki::Func::getPreferencesValue("COMMENTPLUGIN_DEFAULT_TYPE") ||
	  "bottom";

    my $message = TWiki::Func::getPreferencesValue("COMMENTPLUGIN_REFRESH") ||
      "";    

    # Is commenting disabled?
    my $disable = "";
    if ( $previewing ) {
      # We are in Preview mode
      $message  = "(Edit - Preview)";
      $disable = "disabled";
    }

    my $idx = 0;
    $_[0] =~ s/%COMMENT{(.*?)}%/&_handleInput($1,$_[1],$_[2],\$idx,$message,$disable,$defaultType)/ego;
  }

  # PRIVATE generate an input form for a %COMMENT tag
  sub _handleInput {
    my ( $attributes, $topic, $web, $pidx, $message,
	 $disable, $defaultType ) = @_;

    my $attrs = new CommentPlugin::Attrs( $attributes );

    my $type =
      $attrs->remove( "type" ) || $attrs->remove( "mode" ) || $defaultType;

    my $location = $attrs->remove( "location" );

    # clean off whitespace
    $type =~ m/(\S*)/o;
    $type = $1;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = _getTemplate( "PROMPT:$type", $topic, $web );

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/&_expandPromptParams($1, $2, $attrs)/iego;

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = undef;
    my $target = $attrs->remove( "target" );
    if ( $target ) {
      # extract web and anchor
      if ( $target =~ s/^($TWiki::webNameRegex)\.//o ) {
	$web = $1;
      }
      if ( $target =~ s/($TWiki::anchorRegex)$//o ) {
	$anchor = $1;
      }
      $topic = $target;
    }

    my $url = "";
    if ( $disable eq "" ) {
      $url = TWiki::Func::getScriptUrl( $web, $topic, "save" );

      my ( $oopsUrl, $lockUser, $lockTime ) =
	TWiki::Func::checkTopicEditLock( $web, $topic );

      if ( $lockUser ) {
	$message = "Commenting is locked out by $lockUser for at least $lockTime minutes";
	$disable = "disabled";
      }
    }

    if ( $input !~ m/^%RED%/o ) {
      $input =~ s/%DISABLED%/$disable/go;
      $input =~ s/%MESSAGE%/$message/g;
      my $n = $$pidx + 0;
	
      $input = "<form name=\"${disable}$type$n\" " .
	"action=\"$disable$url\" method=\"${disable}post\">\n$input";
      # need to provide text or the save script will reject us; even though we
      # are going to override it in the beforeSaveHandler
      $input .= "<input $disable name=\"${disable}text\" " .
	"type=\"hidden\" value=\"dummy\" />\n";
      # remember to unlock the page
      $input .= "<input $disable name=\"${disable}unlock\" " .
	"type=\"hidden\" value=\"1\" />\n";
      # the presence of these next three urlparams indicates a comment save
      $input .= "<input $disable name=\"${disable}comment_type\" " .
	"type=\"hidden\" value=\"$type\" />\n";
      if ( $location ) {
	$input .= "<input $disable name=\"${disable}comment_location\" " .
	  "type=\"hidden\" value=\"$location\" />\n";
      } elsif ( $anchor ) {
	$input .= "<input $disable name=\"${disable}comment_anchor\" " .
	  "type=\"hidden\" value=\"$anchor\" />\n";
      } else {
	$input .= "<input $disable name=\"${disable}comment_index\" " .
	  "type=\"hidden\" value=\"$$pidx\" />\n";
      }
      $input .= "</form>\n";
    }
    $$pidx++;
    return $input;
  }

  # PRIVATE expand special %param|default% parameters in PROMPT template
  sub _expandPromptParams {
    my ( $name, $default, $attrs ) = @_;

    my $val = $attrs->get( $name );
    return $val if defined( $val );
    return $default;
  }

  # PUBLIC perform save actions
  # Designed to be invoked from the beforeSaveHandler, so extracts most
  # parameters direct from CGI query. Because this is done through the
  # normal save channel, all the access checking should have been done there.
  sub save {
    # my ( $query, $text, $topic, $web ) = @_;

    my $type = $_[0]->param( 'comment_type' );
    my $index = $_[0]->param( 'comment_index' );
    my $anchor = $_[0]->param( 'comment_anchor' );
    my $location = $_[0]->param( 'comment_location' );

    # the presence of these three urlparams indicates it's a comment save
    return unless ( defined( $type ) &&
		   ( defined( $index ) || defined( $anchor ) ||
		     defined( $location )));

    my $output = _getTemplate( "OUTPUT:$type", $_[3], $_[2] );
    if ( $output =~ m/^%RED%/o ) {
      TWiki::Func::writeWarning( $output );
      return;
    }

    # Expand the template
    $output =~ s/%POS:(.*?)%//go;
    my $position = $1 || "BOTTOM";
    TWiki::Func::expandCommonVariables( $output, $_[2], $_[3] );

    # reread the topic, throwing away the dummy text set up in
    # _handleInput
    $_[1] = TWiki::Func::readTopicText( $_[3], $_[2], undef, 1 );

    if ( $position eq "TOP" ) {
      $_[1] = "$output$_[1]";
    } elsif ( $position eq "BOTTOM" ) {
      $_[1] .= "$output";
    } else {
      if ( $location ) {
	if ( $position eq "BEFORE" ) {
	  $_[1] =~ s/($location)/$output\n$1/m;
	} else { # AFTER
	  $_[1] =~ s/($location)/$1\n$output/m;
	}
      } elsif ( $anchor ) {
	# position relative to anchor
	if ( $position eq "BEFORE" ) {
	  $_[1] =~ s/^($anchor)/$output\n$1/m;
	} else { # AFTER
	  $_[1] =~ s/^($anchor)/$1\n$output/m;
	}
      } else {
	# Position relative to index'th comment
	my $idx = 0;
	$_[1] =~ s/(%COMMENT{.*?}%)/&_nth($1,\$idx,$position,$index,$output)/ego;
      }
    }
  }

  # PRIVATE embed output if this comment is the interesting one
  sub _nth {
    my ( $tag, $pidx, $position, $index, $output ) = @_;

    if ( $$pidx == $index) {
      if ( $position eq "BEFORE" ) {
	$tag = "$output$tag";
      } else { # AFTER
	$tag .= "$output";
      }
    }
    $$pidx++;
    return $tag;
  }
}

1;
