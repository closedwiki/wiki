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
    my $scriptname = $ENV{'SCRIPT_NAME'};
    my $previewing = ( $scriptname =~ /^.*\/preview/ );

    my $defaultType = 
	TWiki::Func::getPreferencesValue("COMMENTPLUGIN_DEFAULT_TYPE") ||
	  "bottom";
    my $message = TWiki::Func::getPreferencesValue("COMMENTPLUGIN_REFRESH") ||
      "";    

    # Is commenting disabled?
    my $disable = 'disabled';
    my ( $oopsUrl, $lockUser, $lockTime ) =
      TWiki::Func::checkTopicEditLock( $_[2], $_[1] );
    if( $lockUser ) {
      # Topic is locked by another edit
      $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
      $message = "You cannot comment as the topic is locked temporarily\n" .
	"by $lockUser for the next $lockTime minutes.";
    } elsif ( $previewing ) {
      # We are in Preview mode
      $message  = "(Edit - Preview)";
    } else { # view
      # Not disabled
      $disable = '';
    }

    my $url = $disable;
    if ( $disable ne "disabled" ) {
      $url = TWiki::Func::getScriptUrl( $_[2], $_[1], "save" );
    }

    my $idx = 0;
    $_[0] =~ s/%COMMENT{(.*?)}%/&_handleInput($1,$_[1],$_[2],\$idx,$message,$disable,$defaultType,$url)/ego;
  }

  # PRIVATE generate an input form for a %COMMENT tag
  sub _handleInput {
    my ( $attributes, $topic, $web, $pidx, $message,
	 $disable, $defaultType, $url ) = @_;

    my $type =
      TWiki::Func::extractNameValuePair( $attributes, "type" ) ||
	$defaultType;

    # Expand the template in the context of the web where the comment
    # box is
    my $input = _getTemplate( "PROMPT:$type", $topic, $web );

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $target =
      TWiki::Func::extractNameValuePair( $attributes, "target" );
    if ( $target ) {
      if ( $target =~ m/^(.*?)\.(.*?)$/o ) {
	$web = $1;
	$topic = $2;
      } else {
	$topic = $target;
      }

      if ( $url ne "disabled" ) {
	$url = TWiki::Func::getScriptUrl( $web, $topic, "save" );
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
      # the presence of these next two urlparams indicates a comment save
      $input .= "<input name=\"comment_type\" type=\"hidden\" ";
      $input .= "value=\"$type\" />\n";
      $input .= "<input name=\"comment_index\" type=\"hidden\" ";
      $input .= "value=\"$$pidx\" />\n</form>";
    }
    $$pidx++;
    return $input;
  }

  # PUBLIC perform save actions
  # Designed to be invoked from the beforeSaveHandler, so extracts most
  # parameters direct from CGI query. Because this is done through the
  # normal save channel, all the access checking should have been done there.
  sub save {
    # my ( $text, $topic, $web ) = @_;

    my $query = TWiki::Func::getCgiQuery() || return;
    my $type = $query->param( 'comment_type' );
    my $tgt_idx = $query->param( 'comment_index' );

    # the presence of these two urlparams indicates it's a comment save
    return unless ( defined($type) && defined($tgt_idx) );

    my $output = _getTemplate( "OUTPUT:$type", $_[2], $_[1] );
    if ( $output =~ m/^%RED%/o ) {
      TWiki::Func::writeWarning( $output );
      return;
    }

    # Expand the template
    $output =~ s/%POS:(.*?)%//go;
    my $position = $1 || "BOTTOM";
    TWiki::Func::expandCommonVariables( $output, $_[1], $_[2] );

    # reread the topic, throwing away the dummy text set up in
    # _handleInput
    $_[0] = TWiki::Func::readTopicText( $_[2], $_[1], undef, 1 );

    if ( $position eq "TOP" ) {
      $_[0] = "$output$_[0]";
    } elsif ( $position eq "BOTTOM" ) {
      $_[0] .= "$output";
    } else {
      my $idx = 0;
      $_[0] =~ s/(%COMMENT{.*?}%)/&_embed($1,\$idx,$position,$tgt_idx,$output)/ego;
    }
  }

  # PRIVATE embed an output if this comment is the interesting one
  sub _embed {
    my ( $tag, $pidx, $position, $tgt_idx, $output ) = @_;

    if ( $$pidx == $tgt_idx) {
      if ( $position eq "BEFORE" ) {
	$tag = "$output$tag";
      } else {
	$tag .= "$output";
      }
    }
    $$pidx++;
    return $tag;
  }
}

1;
