use strict;
use integer;

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
    my $disable = 'disabled';
    if ( $previewing ) {
      # We are in Preview mode
      $message  = "(Edit - Preview)";
    } else { # view
      # Not disabled
      $disable = '';
    }

    my $idx = 0;
    $_[0] =~ s/%COMMENT{(.*?)}%/&_handleInput($1,$_[1],$_[2],\$idx,$message,$disable,$defaultType)/ego;
  }

  # PRIVATE generate an input form for a %COMMENT tag
  sub _handleInput {
    my ( $attributes, $topic, $web, $pidx, $message,
	 $disable, $defaultType ) = @_;

    my $type =
      TWiki::Func::extractNameValuePair( $attributes, "type" ) ||
	$defaultType;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = _getTemplate( "PROMPT:$type", $topic, $web );

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = "";
    my $target =
      TWiki::Func::extractNameValuePair( $attributes, "target" );
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

    my $url = $disable;
    if ( $url ne "disabled" ) {
      $url = TWiki::Func::getScriptUrl( $web, $topic, "save" );

      my ( $oopsUrl, $lockUser, $lockTime ) =
	TWiki::Func::checkTopicEditLock( $web, $topic );

      if ( $lockUser ) {
	$lockTime = ( $lockTime / 60 ) + 1;
	$message = "Commenting is locked out by $lockUser for at least $lockTime minutes";
	$url = "disabled";
      }
    }

    if ( $input !~ m/^%RED%/o ) {
      $input =~ s/%DISABLED%/$disable/go;
      $input =~ s/%MESSAGE%/$message/g;
	
      $input = "<form name=\"$type$$pidx\" action=\"$url\" method=\"post\">\n" .
	$input;
      # need to provide text or the save script will reject us; even though we
      # are going to override it in the beforeSaveHandler
      $input .= "<input name=\"text\" type=\"hidden\" value=\"dummy\" />\n";
      # remember to unlock the page
      $input .= "<input name=\"unlock\" type=\"hidden\" value=\"1\" />\n";
      # the presence of these next three urlparams indicates a comment save
      $input .= "<input name=\"comment_type\" type=\"hidden\" ";
      $input .= "value=\"$type\" />\n";
      $input .= "<input name=\"comment_anchor\" type=\"hidden\"";
      $input .= "value=\"$anchor\" />\n";
      $input .= "<input name=\"comment_index\" type=\"hidden\" ";
      $input .= "value=\"$$pidx\" />\n</form>\n";
    }
    $$pidx++;
    return $input;
  }

  # PUBLIC perform save actions
  # Designed to be invoked from the beforeSaveHandler, so extracts most
  # parameters direct from CGI query. Because this is done through the
  # normal save channel, all the access checking should have been done there.
  sub save {
    # my ( $query, $text, $topic, $web ) = @_;

    my $type = $_[0]->param( 'comment_type' );
    my $tgt_idx = $_[0]->param( 'comment_index' );
    my $anchor = $_[0]->param( 'comment_anchor' );

    # the presence of these three urlparams indicates it's a comment save
    return unless (defined($type) && defined($tgt_idx) && defined($anchor));

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

    if ($position eq "TOP" ) {
      $_[1] = "$output$_[1]";
    } elsif ( $position eq "BOTTOM" ) {
      $_[1] .= "$output";
    } else {
      if ( $anchor ne "" ) {
	# position relative to anchor
	if ( $position eq "BEFORE" ) {
	  $_[1] =~ s/^($anchor)/$output\n$1/;
	} else { # AFTER
	  $_[1] =~ s/^($anchor)/$1\n$output/;
	}
      } else {
	# Position relative to comment
	my $idx = 0;
	$_[1] =~ s/(%COMMENT{.*?}%)/&_nth($1,\$idx,$position,$tgt_idx,$output)/ego;
      }
    }
  }

  # PRIVATE embed output if this comment is the interesting one
  sub _nth {
    my ( $tag, $pidx, $position, $tgt_idx, $output ) = @_;

    if ( $$pidx == $tgt_idx) {
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
