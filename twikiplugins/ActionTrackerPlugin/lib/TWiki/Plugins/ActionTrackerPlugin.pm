#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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
#
# Based on EmptyPlugin
#

# =========================
package TWiki::Plugins::ActionTrackerPlugin;

use TWiki::Func;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
require TWiki::Plugins::ActionTrackerPlugin::ActionNotify;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION
	    $allActions $useNewWindow $debug $javaScriptIncluded
	    $pluginInitialized $perlTimeParseDateFound $pluginName
	    $defaultFormat
	   );

$VERSION = '1.000';
$pluginInitialized = 0;
$perlTimeParseDateFound = 0;
$pluginName = "ActionTrackerPlugin";

my $actionNumber = 0;

# =========================
sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between ActionTrackerPlugin and Plugins.pm $TWiki::Plugins::VERSION" );
    return 0;
  }

  # Get plugin debug flag
  $debug = &TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_DEBUG" ) ||
    0;
  $useNewWindow = &TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_USENEWWINDOW" ) || 0;

  # Colour for warning of late actions
  $ActionTrackerPlugin::Format::latecol = 
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_LATECOL" ) ||
      "yellow";
  # Colour for an unparseable date
  $ActionTrackerPlugin::Format::badcol =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_BADDATECOL" ) ||
      "red";
  # Colour for table header rows
  $ActionTrackerPlugin::Format::hdrcol =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_HEADERCOL" ) ||
      "FFCC66";

  my $hdr =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TABLEHEADER" );
  my $bdy =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TABLEFORMAT" );
  my $textform =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TEXTFORMAT" );
  my $orient =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TABLEORIENT" );
  my $changes =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_NOTIFYCHANGES" );
  $defaultFormat =
    new ActionTrackerPlugin::Format( $hdr, $bdy, $textform, $changes, $orient );

  my $extras =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EXTRAS" );

  $types = ActionTrackerPlugin::Action::extendTypes( $extras ) if ( $extras );

  &TWiki::Func::writeDebug( "- TWiki::Plugins::ActionTrackerPlugin::initPlugin($web.$topic) is OK" ) if $debug;
  $pluginInitialized = 0;
  $javaScriptIncluded = 0;
  return 1;
}

# =========================
sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  
  # This is the place to define customized tags and variables
  # Called by sub handleCommonTags, after %INCLUDE:"..."%
  
  # do custom extension rule, like for example:
  # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
  # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;

  return unless ( $_[0] =~ m/%ACTION.*{.*}%/o );

  unless( $pluginInitialized ) {
    return unless( _init_defaults() );
  }

  my $javaScriptIncluded = 0;

  # Format actions in the topic.
  # Done this way so we get tables built up by
  # collapsing successive actions.
  my $actionNumber = 0;
  my $text = "";
  my $actionSet = undef;
  foreach my $line ( split( /\r?\n/, $_[0] )) {
    if ( $line =~ /^(.*)%ACTION{(.*)?}%(.*)/o ) {
      my ( $pre, $attrs, $descr ) = ( $1, $2, $3 );

      if ( $pre =~ /\S/o ) {
	if ( $actionSet ) {
	  $text .= embedJS() .
	    $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow ) . "\n";
	  $actionSet = undef;
	}
	$text .= $pre;
      }

      $descr =~ s/%ACTION{(.*)}%/%<nop>ACTION{$1}%/go;
      my $action = new ActionTrackerPlugin::Action( $_[2], $_[1], $actionNumber++, $attrs, $descr );
      $actionSet = new ActionTrackerPlugin::ActionSet() unless ( $actionSet );
      $actionSet->add( $action );

    } else {
      if ( $actionSet ) {
	$text .= embedJS() .
	  $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow ) . "\n";
	$actionSet = undef;
      }
      $text .= "$line\n";
    }
  }
  if ( $actionSet ) {
    $text .= embedJS() .
      $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow );
  }
  $_[0] = $text;
  $_[0] =~ s/%ACTIONSEARCH{(.*)?}%/&handleActionSearch($web, $1)/geo;
  $_[0] =~ s/%ACTIONNOTIFICATIONS{(.*?)}%/&handleActionNotify($web, $1)/geo;
}

# This handler is called by the edit script just before presenting
# the edit text in the edit box.
# New hook in TWiki::Plugins $VERSION = '1.010'
# We use it to populate the editaction.tmpl template, which is then
# inserted in the edit.action.tmpl as the %TEXT%.
# We process the %META fields from the raw text of the topic and
# insert them as hidden fields in the form, so the topic is
# fully populated. This allows us to call either 'save' or 'preview'
# to terminate the edit, as selected by the NOPREVIEW parameter.
sub beforeEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  return unless ( TWiki::Func::getSkin() eq "action" );

  TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

  # If only we had control over meta!!!! But we don't so we have to 
  # read the topic again to extract it and insert the meta fields here.
  # We don't want to show them so they are inserted as type=hidden
  my $topic = $_[1];
  my $web = $_[2];

  my $query = TWiki::Func::getCgiQuery();
  my $tmpl = TWiki::Func::readTemplate( "editaction", "");
  my $date = &TWiki::getGmDate();
  $tmpl =~ s/%DATE%/$date/go;
  my $user = TWiki::Func::getWikiUserName();
  $tmpl =~ s/%WIKIUSERNAME%/$user/go;
  $tmpl = TWiki::Func::expandCommonVariables( $tmpl, $topic, $web );
  $tmpl = TWiki::Func::renderText( $tmpl, $web );

  # The 'command' parameter is used to signal to the afterEditHandler and
  # the beforeSaveHandler that they have to handle the fields of the
  # edit differently
  my $fields = $query->hidden( -name=>'closeactioneditor', -value=>1 );
  $fields .= $query->hidden( -name=>'cmd', -value=>"" );

  # Throw away $_[0] and re-read the topic, extracting meta-data
  my $oldText = TWiki::Func::readTopicText( $_[2], $_[1]);
  my $text = "";
  foreach my $line ( split( /\n/, $oldText ) ) {
    if( $line =~ /^%META:([^{]+){([^}]*)}%/ ) {
      my $type = $1;
      my $args = $2;
      if ( $type eq "FIELD" ) {
	my $name = "UNKNOWN";
	my $value = "";
	if ( $args =~ m/\s*name=\"([^\"]*)\"/io ) {
	  $name = $1;
	}
	if ( $args =~ m/\s*value=\"([^\"]*)\"/io ) {
	  $value = $1;
	}
	$fields .= $query->hidden( -name=>$name, -value=>$value );
      }
    } else {
      $text .= "$line\n";
    }
  }

  # Find the action
  my $uid = $query->param( "action" );
  my ( $action, $pretext, $posttext ) =
    ActionTrackerPlugin::Action::findActionByUID( $webName, $topic, $text, $uid );

  $fields .= $query->hidden( -name=>'pretext', -value=>$pretext );
  $fields .= $query->hidden( -name=>'posttext', -value=>$posttext );

  $tmpl =~ s/%UID%/$uid/go;
  
  my $useNewWindow =
    &TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_USENEWWINDOW" );
  
  my $submitCmd = "Preview";
  my $submitScript = "";
  my $cancelScript = "";

  if ( TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_NOPREVIEW" )) {
    $submitCmd = "Save";
    if ( $useNewWindow ) {
      # I'd like to do this, but not sure how. Like this, the ONSUBMIT
      # overrides the ACTION and closes the window before the POST
      # is done. There's probably something like window.submit().
      #$submitScript = "ONCLICK=\"document.form.submit();window.close();return true\"";
    }
  }
  if ( $useNewWindow ) {
    $cancelScript = "ONCLICK=\"window.close();\"";
  }

  $tmpl =~ s/%CANCELSCRIPT%/$cancelScript/go;
  $tmpl =~ s/%SUBMITSCRIPT%/$submitScript/go;
  $tmpl =~ s/%SUBMITCMDNAME%/$submitCmd/go;
  $submitCmd = lcfirst( $submitCmd );
  $tmpl =~ s/%SUBMITCOMMAND%/$submitCmd/go;
  
  my $hdrs =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EDITHEADER" );
  my $body =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EDITFORMAT" );
  my $vert =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EDITORIENT" );

  my $fmt = new ActionTrackerPlugin::Format( $hdrs, $body, "", "", $vert );
  my $editable = $fmt->formatForEdit( $action );
  $tmpl =~ s/%EDITFIELDS%/$editable/o;

  my $ebh =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EDITBOXHEIGHT" ) ||
      TWiki::Func::getPreferencesValue( 'EDITBOXHEIGHT' );
  $tmpl =~ s/%EBH%/$ebh/go;
  
  my $ebw =
    TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_EDITBOXWIDTH" ) ||
      TWiki::Func::getPreferencesValue( 'EDITBOXWIDTH' );
  $tmpl =~ s/%EBW%/$ebw/go;
  $text = $action->{text};
  $text =~ s/^\t/   /gos;
  $text =~ s/<br( \/)?>/\n/gios;
  $text =~ s/<p( \/)?>/\n\n/gios;
  $tmpl =~ s/%TEXT%/$text/go;
  $tmpl =~ s/%HIDDENFIELDS%/$fields/go;

  $_[0] = $tmpl;
}

# This handler is called by the preview script just before
# presenting the text.
# New hook in TWiki::Plugins $VERSION = '1.010'
# The skin name is passed over from the original invocation of
# edit so if the skin is "action" we know we have been editing
# an action and have to recombine fields to create the
# actual text.
# Metadata is handled by the preview script itself.
sub afterEditHandler {
### my ( $text, $topic, $web ) = @_;

  my $query = TWiki::Func::getCgiQuery();
  return unless ( $query->param( 'closeactioneditor' ));

  my $pretext = $query->param( 'pretext' ) || "";
  my $posttext = $query->param( 'posttext' ) || "";

  # count the previous actions so we get the right action number
  my $an = 0;
  my $tmp = "$pretext";
  while ( $tmp =~ s/%ACTION{[^%]*}%//o ) {
    $an++;
  }

  my $action =
    ActionTrackerPlugin::Action::createFromQuery( $_[2], $_[1], $an, $query );

  $action->populateMissingFields();

  my $text = $action->toString();
  $text = "$pretext$text\n$posttext"; 

  # take the opportunity to fill in the missing fields in actions
  _addMissingAttributes( $text, $_[1], $_[2] );

  $_[0] = $text;
}

# This handler is called by TWiki::Store::saveTopic just before
# the save action. The text passed is the raw text of the topic, so it
# contains meta-data.
# New hook in TWiki::Plugins $VERSION = '1.010'
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;

  my $query = TWiki::Func::getCgiQuery();
  if ( $query->param( 'closeactioneditor' )) {
    # this is a save from the action editor
    # Strip pre and post metadata from the text
    my $topic = $_[1];
    my $web = $_[2];
    my $premeta = "";
    my $postmeta = "";
    my $inpost = 0;
    my $text = "";
    foreach my $line ( split( /\n/, $_[0] ) ) {
      if( $line =~ /^(%META:[^{]+{[^}]*}%)/ ) {
	if ( $inpost) {
	  $postmeta .= "$1\n";
	} else {
	  $premeta .= "$1\n";
	}
      } else {
	$text .= "$line\n";
	$inpost = 1;
      }
    }
    # compose the text
    afterEditHandler( $text, $topic, $web );
    # reattach the metadata
    $_[0] = $premeta . $text . $postmeta;
  } else {
    # take the opportunity to fill in the missing fields in actions
    _addMissingAttributes( $_[0], $_[1], $_[2] );
  }
}

# PRIVATE Add missing attributes to all actions that don't have them
sub _addMissingAttributes {
  #my ( $text, $topic, $web ) = @_;
  # Note: correct action numbers depend on the substitute working
  # sequentially through the topic.
  $_[0] =~ s/%ACTION{([^%]*)}%([^\n\r]*)/&_populateFields( $_[2], $_[1], $1, $2 )/geos;
}

# PRIVATE populate missing fields on an action
sub _populateFields {
  my ( $web, $topic, $attrs, $text ) = @_;
  my $action = new ActionTrackerPlugin::Action( $web, $topic, $actionNumber++, $attrs, $text );
  $action->populateMissingFields();
  return $action->toString();
}

# =========================
# Perform filtered search for all actions
sub handleActionSearch {
  my ( $web, $expr ) = @_;

  my $attrs = new ActionTrackerPlugin::Attrs( $expr );
  # use default format unless overridden
  my $fmt;
  my $fmts = $attrs->remove( "format" );
  my $hdrs = $attrs->remove( "header" );
  my $orient = $attrs->remove( "orient" );
  if ( defined( $fmts ) || defined( $hdrs ) || defined( $orient )) {
    if ( !defined( $fmts ) ) {
      # header not defined; use default
      $fmts = $defaultFormat->getFields();
    }
    if ( !defined( $hdrs ) ) {
      # header not defined; use default
      $hdrs = $defaultFormat->getHeaders();
    }
    if ( !defined( $orient )) {
      $orient = $defaultFormat->getOrientation();
    }
    $fmt = new ActionTrackerPlugin::Format( $hdrs, $fmts, $fmts, $orient );
  } else {
    $fmt = $defaultFormat;
  }

  my $sort = $attrs->remove( "sort" );

  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs( $web, $attrs );

  # by default actions will be sorted by due date
  $actions->sort( $sort );

  return embedJS() . $actions->formatAsHTML( $fmt, "href", $useNewWindow );
}

# =========================
# Lazy initialize of plugin 'cause of performance
sub _init_defaults
{
  $libsFound = 0;
  eval {
    require Exporter;
    $perlTimeParseDateFound = require Time::ParseDate;
    # If the Time::ParseDate module is not found, then there is no use in
    # including any of the following.
    if( $perlTimeParseDateFound ) {
      eval {
        $libsFound = require TWiki::Plugins::ActionTrackerPlugin::Action;
        require TWiki::Plugins::ActionTrackerPlugin::ActionSet;
        require TWiki::Plugins::ActionTrackerPlugin::Attrs;
      };
      unless( $libsFound ) {
        # Could not find ActionTrackerPlugin utility libs possibly because
        # of relative use lib dir and chdir after initialization.
        # Try again with absolute TWiki lib dir path
        eval {
          my $libDir = TWiki::getTWikiLibDir();
          $libDir =~ /(.*)/;
          $libDir = $1;       # untaint
          $libsFound = require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Action.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/ActionSet.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Attrs.pm";
        };
      }
#      @TWiki::Plugins::ISA = qw(
#          TWiki::Plugins::ActionTrackerPlugin::Action;
#          TWiki::Plugins::ActionTrackerPlugin::ActionSet;
#          TWiki::Plugins::ActionTrackerPlugin::Attrs;
#        );
    }
  };
  $pluginInitialized = 1;
  return $libsFound;
}

sub embedJS {
    return "" unless ($useNewWindow && !$javaScriptIncluded);
    $javaScriptIncluded = 1;
    return "
<script language=\"JavaScript\"><!--
function editWindow(url) {
  win=open(url,\"none\",\"titlebar=0,width=700,height=400,resizable,scrollbars\");
  if(win){win.focus();}
  return false;
}
// -->
</script>
";
}

########################################

# handle actions that have changed in all webs
sub handleActionNotify {
  my ( $web, $expr ) = @_;

  use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
  my $text = ActionTrackerPlugin::ActionNotify::doNotifications( $web, $expr, 1 );

  $text =~ s/<html>/<\/pre>/gos;
  $text =~ s/<\/html>/<pre>/gos;
  $text =~ s/<\/?body>//gos;
  return "<!-- from an --> <pre>$text</pre> <!-- end from an -->";
}


1;
