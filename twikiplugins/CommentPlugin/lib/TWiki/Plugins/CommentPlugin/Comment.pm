# Comment TWiki plugin
# Original author David Weller, reimplemented by Peter Masiar
# and again by Crawford Currie
#
# This version Copyright (C) 2004 Crawford Currie
#
use strict;
use integer;

use TWiki::Plugins::CommentPlugin::Attrs;
use TWiki::Plugins::CommentPlugin::Templates;

{ package CommentPlugin::Comment;

  # PUBLIC method that handles the presense of %COMMENT in a topic. Operates
  # in three modes, view, preview and viewauth
  sub save {
    my ( $web, $topic, $type, $index, $anchor, $location ) = @_;
    my $query = TWiki::Func::getCgiQuery();

    my $wikiUserName = &TWiki::Func::getWikiUserName();
    if( ! TWiki::Func::checkAccessPermission( "change", $wikiUserName, "",
					       $topic, $web ) ) {
      # user has no permission to change the topic
      my $url = TWiki::Func::getOopsUrl( $web, $topic, "oopsaccesschange" );
      TWiki::Func::redirectCgiQuery( $query, $url );
      return 0;
    }

    my( $oopsUrl, $lockUser ) = TWiki::Func::checkTopicEditLock( $web, $topic );
    if( $lockUser ) {
      # warn user that other person is editing this topic
      TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
      return 0;
    }
    TWiki::Func::setTopicEditLock( $web, $topic, 1 );

    my $text = _buildNewTopic( $web, $topic, $type, $index, $anchor, $location );

    my $error = TWiki::Func::saveTopicText( $web, $topic, $text, "", 0 );
    TWiki::Func::setTopicEditLock( $web, $topic, 0 );
    my $url;
    if( $error ) {
      $url = TWiki::Func::getOopsUrl( $web, $topic, "oopssaveerr", $error );
    } else {
      $url = TWiki::Func::getViewUrl( $web, $topic );
    }
    TWiki::Func::redirectCgiQuery( $query, $url );
  }

  # PUBLIC STATIC convert COMMENT statements to form prompts
  sub prompt {
    #my ( $text, $topic, $web ) = @_;

    my $defaultType = 
      TWiki::Func::getPreferencesValue("COMMENTPLUGIN_DEFAULT_TYPE") ||
	  "bottom";

    my $message = TWiki::Func::getPreferencesValue("COMMENTPLUGIN_REFRESH") ||
      "";

    # Is commenting disabled?
    my $disable = "";
    # Nasty, tacky, error prone way to find out if we are previewing or not
    my $scriptname = $ENV{'SCRIPT_NAME'} || "";
    if ( $scriptname =~ /^.*\/preview/ ||
	 $scriptname =~ /^.*\/gnusave/ ) {
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

    return $input if $input =~ m/^%RED%/so;

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/&_expandPromptParams($1, $2, $attrs)/iego;

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = undef;
    my $target = $attrs->remove( "target" );
    if ( $target ) {
      # extract web and anchor
      if ( $target =~ s/^(\w+)\.//o ) {
	$web = $1;
      }
      if ( $target =~ s/(#\w+)$//o ) {
	$anchor = $1;
      }
      if ( $target ne "" ) {
	$topic = $target;
      }
    }

    my $url = "";
    if ( $disable eq "" ) {
      $url = TWiki::Func::getScriptUrl( "%INTURLENCODE{$web}%",
					"%INTURLENCODE{$topic}%",
					"viewauth" );

      my ( $oopsUrl, $lockUser, $lockTime ) =
	TWiki::Func::checkTopicEditLock( $web, $topic );

      if ( $lockUser ) {
	$message = "Commenting is locked out by <nop>$lockUser for at least $lockTime more minutes";
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

  # PRIVATE get the given template and do standard expansions
  sub _getTemplate {
    my ( $name, $topic, $web ) = @_;

    # Get the templates
    my $templateFile =
      TWiki::Func::getPreferencesValue("COMMENTPLUGIN_TEMPLATES") ||
	"comments";

    my $templates = CommentPlugin::Templates::readTemplate( $templateFile );
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

  # PRIVATE expand special %param|default% parameters in PROMPT template
  sub _expandPromptParams {
    my ( $name, $default, $attrs ) = @_;

    my $val = $attrs->get( $name );
    return $val if defined( $val );
    return $default;
  }

  # PRIVATE STATIC Performs comment insertion in the topic.
  sub _buildNewTopic {
    my ( $web, $topic, $type, $index, $anchor, $location ) = @_;

    my $output = _getTemplate( "OUTPUT:$type", $topic, $web );
    if ( $output =~ m/^%RED%/o ) {
      return $output;
    }

    # Expand the template
    $output =~ s/%POS:(.*?)%//go;
    my $position = $1 || "BOTTOM";

    # Expand common variables in the template, but don't expand other
    # tags. KEEP IN SYNC WITH edit and register SCRIPTS. NOTE: A patch
    # has been submitted to add this function to TWiki, for Cairo and beyond.
    my $wikiName = TWiki::Func::getWikiName();
    my $wikiUserName = TWiki::Func::getWikiUserName();
    my $userName = TWiki::Func::wikiToUserName( $wikiName );

    my $today = TWiki::Func::formatGmTime(time());
    $output =~ s/%DATE%/$today/go;
    $output =~ s/%USERNAME%/$userName/go;
    $output =~ s/%WIKINAME%/$wikiName/go;
    $output =~ s/%WIKIUSERNAME%/$wikiUserName/go;
    $output =~ s/%URLPARAM{(.*?)}%/TWiki::handleUrlParam($1)/geo;
    $output =~ s/%NOP{.*?}%//gos;
    $output =~ s/%NOP%//go;

    my $text = TWiki::Func::readTopicText( $web, $topic, undef, 1 );

    if ( $position eq "TOP" ) {
      $text = "$output$text";
    } elsif ( $position eq "BOTTOM" ) {
      $text .= "$output";
    } else {
      if ( $location ) {
	if ( $position eq "BEFORE" ) {
	  $text =~ s/($location)/$output\n$1/m;
	} else { # AFTER
	  $text =~ s/($location)/$1\n$output/m;
	}
      } elsif ( $anchor ) {
	# position relative to anchor
	if ( $position eq "BEFORE" ) {
	  $text =~ s/^($anchor)/$output\n$1/m;
	} else { # AFTER
	  $text =~ s/^($anchor)/$1\n$output/m;
	}
      } else {
	# Position relative to index'th comment
	my $idx = 0;
	$text =~ s/(%COMMENT{.*?}%)/&_nth($1,\$idx,$position,$index,$output)/ego;
      }
    }

    return $text;
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
