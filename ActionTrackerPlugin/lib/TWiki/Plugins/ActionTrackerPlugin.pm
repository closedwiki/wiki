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

use strict;

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
my %prefs;

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  # COVERAGE OFF standard plugin code
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between ActionTrackerPlugin and Plugins.pm $TWiki::Plugins::VERSION" );
    return 0;
  }
  # COVERAGE ON

  # Get plugin debug flag
  $debug = &TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_DEBUG" ) ||
    0;

  _loadPrefsOverrides( $web );

  $useNewWindow = _getPref( "USENEWWINDOW", 0 );

  # Colour for warning of late actions
  $ActionTrackerPlugin::Format::latecol = _getPref( "LATECOL", "yellow" );
  # Colour for an unparseable date
  $ActionTrackerPlugin::Format::badcol = _getPref( "BADDATECOL", "red" );
  # Colour for table header rows
  $ActionTrackerPlugin::Format::hdrcol = _getPref( "HEADERCOL", "#FFCC66" );

  my $hdr      = _getPref( "TABLEHEADER" );
  my $bdy      = _getPref( "TABLEFORMAT" );
  my $textform = _getPref( "TEXTFORMAT" );
  my $orient   = _getPref( "TABLEORIENT" );
  my $changes  = _getPref( "NOTIFYCHANGES" );
  $defaultFormat =
    new ActionTrackerPlugin::Format( $hdr, $bdy, $orient, $textform, $changes );

  my $extras = _getPref( "EXTRAS" );

  if ( $extras ) {
    my $e = ActionTrackerPlugin::Action::extendTypes( $extras );
    # COVERAGE OFF safety net
    if ( defined( $e )) {
      TWiki::Func::writeWarning( "- TWiki::Plugins::ActionTrackerPlugin ERROR $e" );
    }
    # COVERAGE ON
  }

  &TWiki::Func::writeDebug( "- TWiki::Plugins::ActionTrackerPlugin::initPlugin($web.$topic) is OK" ) if $debug;
  $pluginInitialized = 0;
  $javaScriptIncluded = 0;
  return 1;
}

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

  # Format actions in the topic.
  # Done this way so we get tables built up by
  # collapsing successive actions.
  my $actionNumber = 0;
  my $text = "";
  my $actionSet = undef;
  my $javaScriptRequired = 0;
  my $gathering;
  my $pre;
  my $attrs;
  my $descr;
  my $processAction = 0;

  # FORMAT DEPENDANT ACTION SCAN HERE
  foreach my $line ( split( /\r?\n/, $_[0] )) {
    if ( $gathering ) {
      if ( $line =~ m/^$gathering\b.*/ ) {
	$gathering = undef;
	$processAction = 1;
      } else {
	$descr .= "$line\n";
	next;
      }
    } elsif ( $line =~ m/^(.*?)%ACTION{(.*?)}%(.*)/o ) {
      ( $pre, $attrs, $descr ) = ( $1, $2, $3 );
	
      if ( $pre ne "" ) {
	if ( $pre !~ m/^[ \t]*$/o && $actionSet ) {
	  # spit out pending action table if the pre text is more
	  # than just spaces or tabs
	  $text .=
	    $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow ) .
	      "\n";
	  $javaScriptRequired = 1;
	  $actionSet = undef;
	}
	$text .= $pre;
      }
	
      if ( $descr =~ m/\s*<<(\w+)\s*(.*)$/o ) {
	$descr = $2;
	$gathering = $1;
	next;
      }

      $processAction = 1;
    } else {
      if ( $actionSet ) {
	$text .=
	  $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow ) .
	    "\n";
	$javaScriptRequired = 1;
	$actionSet = undef;
      }
      $text .= "$line\n";
    }

    if ( $processAction ) {
      my $action = new ActionTrackerPlugin::Action( $_[2], $_[1], $actionNumber++, $attrs, $descr );
      if ( !defined( $actionSet )) {
	$actionSet = new ActionTrackerPlugin::ActionSet();
      }
      $actionSet->add( $action );
      $processAction = 0;
    }
  }
  if ( $actionSet ) {
    $text .=
      $actionSet->formatAsHTML( $defaultFormat, "name", $useNewWindow );
    $javaScriptRequired = 1;
  }
  if ( $javaScriptRequired ) {
    # do this here rather than as we emit the actions, because it can
    # screw up the other TWiki formatting if it's embedded.
    $text = _embedJS() . $text;
  }
  $_[0] = $text;
  $_[0] =~ s/%ACTIONSEARCH{(.*)?}%/&_handleActionSearch($web, $1)/geo;
  # COVERAGE OFF debug only
  if ( $debug ) {
    $_[0] =~ s/%ACTIONNOTIFICATIONS{(.*?)}%/&_handleActionNotify($web, $1)/geo;
    $_[0] =~ s/%ACTIONTRACKERPREFS%/&_dumpPrefs()/geo;
  }
  # COVERAGE ON
}

# This handler is called by the edit script just before presenting
# the edit text in the edit box.
# New hook in TWiki::Plugins $VERSION = '1.010'
# We use it to populate the actionform.tmpl template, which is then
# inserted in the edit.action.tmpl as the %TEXT%.
# We process the %META fields from the raw text of the topic and
# insert them as hidden fields in the form, so the topic is
# fully populated. This allows us to call either 'save' or 'preview'
# to terminate the edit, as selected by the NOPREVIEW parameter.
sub beforeEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  return unless ( TWiki::Func::getSkin() eq "action" );

  unless( $pluginInitialized ) {
    return unless( _init_defaults() );
  }

  TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

  # If only we had control over meta!!!! But we don't so we have to 
  # read the topic again to extract it and insert the meta fields here.
  # We don't want to show them so they are inserted as type=hidden
  my $topic = $_[1];
  my $web = $_[2];

  my $query = TWiki::Func::getCgiQuery();
  # actionform.tmpl is a sub-template inserted into the parent template
  # as %TEXT%. This is done so we can use the standard template mechanism
  # without screwing up the content of the subtemplate.
  my $tmpl = TWiki::Func::readTemplate( "actionform", "");
  my $date = TWiki::getGmDate();
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

  # Throw away $_[0] and re-read the topic, extracting meta-data.
  # Oh, how I wish the topic reading/writing was smarter! Or even
  # that already extracted meta-data was passed in here!
  my $oldText = TWiki::Func::readTopicText( $_[2], $_[1]);
  my $text = "";
  foreach my $line ( split( /\r?\n/, $oldText ) ) {
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

  # Find the action. This re-reads the topic, but the cost doesn't seem
  # to be too high.
  my $uid = $query->param( "action" );
  my ( $action, $pretext, $posttext ) =
    ActionTrackerPlugin::Action::findActionByUID( $web, $topic, $text, $uid );

  $fields .= $query->hidden( -name=>'pretext', -value=>$pretext );
  $fields .= $query->hidden( -name=>'posttext', -value=>$posttext );

  $tmpl =~ s/%UID%/$uid/go;
  
  my $useNewWindow = ( _getPref( "USENEWWINDOW", 0 ) == 1 );
  
  my $submitCmd = "Preview";
  my $submitScript = "";
  my $cancelScript = "";

  if ( _getPref( "NOPREVIEW", 0 )) {
    $submitCmd = "Save";
    if ( $useNewWindow ) {
      # I'd like close the subwindow here, but not sure how. Like this,
      # the ONCLICK overrides the ACTION and closes the window before
      # the POST is done. All the various solutions I've found on the
      # web do something like "wait x seconds" before closing the
      # subwindow, but this seems very risky.
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
  
  my $hdrs = _getPref( "EDITHEADER" );
  my $body = _getPref( "EDITFORMAT" );
  my $vert = _getPref( "EDITORIENT" );

  my $fmt = new ActionTrackerPlugin::Format( $hdrs, $body, $vert, "", "" );
  my $editable = $action->formatForEdit( $fmt );
  $tmpl =~ s/%EDITFIELDS%/$editable/o;

  my $dfltH = TWiki::Func::getPreferencesValue( 'EDITBOXHEIGHT' );
  my $ebh = _getPref( "EDITBOXHEIGHT", $dfltH );
  $tmpl =~ s/%EBH%/$ebh/go;
  
  my $dfltW = TWiki::Func::getPreferencesValue( 'EDITBOXWIDTH' );
  my $ebw = _getPref( "EDITBOXWIDTH", $dfltW );
  $tmpl =~ s/%EBW%/$ebw/go;

  $text = $action->{text};
  # Process the text so it's nice to edit. This gets undone in Action.pm
  # when the action is saved.
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

  unless( $pluginInitialized ) {
    return unless( _init_defaults() );
  }

  my $pretext = $query->param( 'pretext' ) || "";
  my $posttext = $query->param( 'posttext' ) || "";

  # count the previous actions so we get the right action number
  my $an = 0;
  my $tmp = "$pretext";
  while ( $tmp =~ s/%ACTION{.*?}%//o ) {
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

  unless( $pluginInitialized ) {
    return unless( _init_defaults() );
  }

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
    foreach my $line ( split( /\r?\n/, $_[0] ) ) {
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
  my $text = "";
  my $descr;
  my $attrs;
  my $gathering;
  my $processAction = 0;
  my $an = 0;

  # FORMAT DEPENDANT ACTION SCAN
  foreach my $line ( split( /\r?\n/, $_[0] )) {
    if ( $gathering ) {
      if ( $line =~ m/^$gathering\b.*/ ) {
	$gathering = undef;
	$processAction = 1;
      } else {
	$descr .= "$line\n";
	next;
      }
    } elsif ( $line =~ m/^(.*?)%ACTION{(.*?)}%(.*)$/o ) {
      $text .= $1;
      $attrs = $2;
      $descr = $3;
      if ( $descr =~ m/\s*\<\<(\w+)\s*(.*)$/o ) {
          $descr = $2;
	  $gathering = $1;
	  next;
      }
      $processAction = 1;
    } else {
      $text .= "$line\n";
    }

    if ( $processAction ) {
      my $action = new ActionTrackerPlugin::Action( $web, $topic,
						    $an, $attrs, $descr );
      $action->populateMissingFields();
      $text .= $action->toString() . "\n";
      $an++;
      $processAction = 0;
    }
  }
  $_[0] = $text;
}

# Prefs handling

# PRIVATE Get a prefs value
sub _getPref {
  my ( $vbl, $default ) = @_;
  my $val = $prefs{$vbl};
  if ( !defined( $val )) {
    $val = TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_$vbl" );
    if ( !defined( $val ) || $val eq "" ) {
      $val = $default;
    }
  }
  return $val;
}

# PRIVATE Load prefs from WebPreferences so they override the settings
# in the plugin topic.
sub _loadPrefsOverrides {
  my $web = shift;

  # The remaining prefs are defined in the plugin topic but may be overridden
  # in WebPreferences. Reload ACTIONTRACKERPLUGIN_ prefs from WebPreferences
  # topic. Note: Default load order is:
  # TWiki.TWikiPreferences
  # Main.TWikiPreferences
  # $web.WebPreferences
  # Main.TWikiGuest
  # TWiki.DefaultPlugin
  # All other plugins
  if ( TWiki::Func::topicExists( $web, "WebPreferences" )) {
    my $text = TWiki::Func::readTopicText( $web, "WebPreferences" );
    foreach my $line ( split( /\r?\n/, $text )) {
      if ( $line =~ /^\s+\* Set ACTIONTRACKERPLUGIN_(\w+)\s+=\s+(.*)$/o ) {
	$prefs{$1} = $2;
      }
    }
  }
}

# PRIVATE Generate plugin prefs in HTML for debugging
# COVERAGE OFF debug only
sub _dumpPrefs {
  my $text = "";
  foreach my $key ( "TABLEHEADER","TABLEFORMAT","TABLEORIENT","TEXTFORMAT","LATECOL","BADDATECOL","HEADERCOL","EDITHEADER","EDITFORMAT","EDITORIENT","USENEWWINDOW","NOPREVIEW","EXTRAS","EDITBOXHEIGHT","EDITBOXWIDTH" ) {
    $text .= "\t* $key\n<verbatim>\n";
    if ( defined( _getPref($key))) {
      $text .= _getPref( $key );
    }
    $text .= "\n</verbatim>\n";
  }
  return $text;
}
# COVERAGE ON

# =========================
# Perform filtered search for all actions
sub _handleActionSearch {
  my ( $web, $expr ) = @_;

  my $attrs = new ActionTrackerPlugin::Attrs( $expr );
  # use default format unless overridden
  my $fmt;
  my $fmts = $attrs->remove( "format" );
  my $hdrs = $attrs->remove( "header" );
  my $orient = $attrs->remove( "orient" );
  my $sort = $attrs->remove( "sort" );
  if ( defined( $fmts ) || defined( $hdrs ) || defined( $orient )) {
    $fmts = $defaultFormat->getFields() unless ( defined( $fmts ));
    $hdrs = $defaultFormat->getHeaders() unless ( defined( $hdrs ));
    $orient = $defaultFormat->getOrientation() unless ( defined( $orient ));
    $fmt = new ActionTrackerPlugin::Format( $hdrs, $fmts, $orient, "", "" );
  } else {
    $fmt = $defaultFormat;
  }

  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs( $web, $attrs );
  $actions->sort( $sort );
  return _embedJS() . $actions->formatAsHTML( $fmt, "href", $useNewWindow );
}

# =========================
# Lazy initialize of plugin 'cause of performance
sub _init_defaults
{
  my $libsFound = 0;
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
        require TWiki::Plugins::ActionTrackerPlugin::AttrDef;
      };
      unless( $libsFound ) {
        # Could not find ActionTrackerPlugin utility libs possibly because
        # of relative use of lib dir and chdir after initialization.
        # Try again with absolute TWiki lib dir path
        eval {
          my $libDir = TWiki::getTWikiLibDir();
          $libDir =~ /(.*)/;
          $libDir = $1;       # untaint
          $libsFound = require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Action.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/ActionSet.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Attrs.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/AttrDef.pm";
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

# PRIVATE embed the JavaScript that opens an edit subwindow
sub _embedJS {
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
</script>\n";
}

# PRIVATE return formatted actions that have changed in all webs
# Debugging only
# COVERAGE OFF debug only
sub _handleActionNotify {
  my ( $web, $expr ) = @_;

  eval {
    require TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
  };

  my $text = ActionTrackerPlugin::ActionNotify::doNotifications( $web, $expr, 1 );

  $text =~ s/<html>/<\/pre>/gos;
  $text =~ s/<\/html>/<pre>/gos;
  $text =~ s/<\/?body>//gos;
  return "<!-- from an --> <pre>$text</pre> <!-- end from an -->";
}
# COVERAGE ON

1;
