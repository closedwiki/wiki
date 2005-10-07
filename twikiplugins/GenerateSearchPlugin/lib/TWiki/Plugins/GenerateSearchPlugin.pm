# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# =========================
#
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   renderFormFieldForEditHandler( $name, $type, $size, $value, $attributes, $possibleValues)
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, unused handlers are disabled. To
# enable a handler remove the leading DISABLE_ from the function
# name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::GenerateSearchPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'GenerateSearchPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "GENERATESEARCHPLUGIN_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    #$exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%GENERATESEARCH{(.*?)}%/handleGenSearch( $_[2], $_[1], $1 )/ge;
}

# ============================
# Generate a filter-driven search form
=pod

---++ sub handleGenSearch ( $theWeb, $theTopic, $theArgs )

Not yet documented.

=cut

sub handleGenSearch
{
    my( $theWeb, $theTopic, $theArgs ) = @_;

    my %params = TWiki::Func::extractParameters( $theArgs );

    my $topicregex = $params{"_DEFAULT"} || $params{"topic"} || "";
    my $webs   = $params{"web"} || $theWeb;
    my $form   = $params{"form"} || $theTopic;
    my $title  = $params{"title"} || "";
    my $message= $params{"message"} || "";
    my $size   = $params{"size"} || 1;
    my $init   = $params{"initial"} || "";
    my $all    = $params{"all"} || "on";


    return generate_interactive_search( $webs, $topicregex, $theWeb, $form, $title, $message, $size, $init, $all );
}


sub generate_interactive_search {
  my( $searchwebs, $topicregex, $webName, $form, $title, $message, $size, $init, $all ) = @_;

  my @fieldsInfo = TWiki::Form::getFormDef( $webName, $form );

  my $result = "<form method=POST action=\"%SCRIPTURLPATH%/gensearch%SCRIPTSUFFIX%/%WEB%/$topic\">";
  $result .= "<input type=\"hidden\" name=\"topicregex\" value=\"$topicregex\" />";
  $result .= "<input type=\"hidden\" name=\"form\" value=\"$form\" />";
  $result .= "<input type=\"hidden\" name=\"title\" value=\"$title\" />";
  $result .= "<input type=\"hidden\" name=\"message\" value=\"$message\" />";
  $result .= "<input type=\"hidden\" name=\"init\" value=\"$init\" />";
  $result .= "<table border=\"0\">\n";

  $result .= "<tr><td>Field</td><td>Show</td><td>Filter</td></tr>";

  my $ct = 0;
  foreach my $c ( @fieldsInfo ) {
    my @fieldInfo = @$c;
    my $fieldName = shift @fieldInfo;
    my $name = $fieldName;
    my $title = shift @fieldInfo;
    my $type = shift @fieldInfo;
    my $size = shift @fieldInfo;
    my $tooltip = shift @fieldInfo;
    my $attributes = shift @fieldInfo;

    $result .= "<tr><td>$title</td><td><input type=\"checkbox\" name=\"show$name\" value=\"$name\" \></td>";
    $result .= "<td><input type=\"checkbox\" name=\"filter$name\" value=\"$name\"  /></td></tr>";
    
    $ct++;
  }

  $result .= "<tr><td>Select all</td><td><input type=\"checkbox\" name=\"allshow\" value=\"allshow\" \></td><td><input type=\"checkbox\" name=\"allfilter\" value=\"allfilter\" \></td></tr>";
  $result .= "</table>";
  my @webs = split /,/, $searchwebs;

  if ( $all =~ /^on$/i ) {
    $result .= "<input type=\"hidden\" name=\"searchweb\" value=\"";
    my $options = 0;
    foreach my $w (@webs) { 
      $w =~ s/\s*([^\s]*)\s*/$1/geo;
      $result .= "," if $options;
      $result .= $w;
      $options = 1;
    }
    $result .= "\" />";
  } elsif ($#webs > 0) {
    $result .= "<select name=\"searchweb\">
     <option>%INCLUDINGWEB%</option>
     <option value=\"";
    my $options = "";
    foreach my $w (@webs) { 
      $w =~ s/\s*([^\s]*)\s*/$1/geo;
      $result .= "," if $options;
      $result .= $w;
      $options .= "<option value=\"$w\">$w</option>";
    }
    $result .= "\">All</option> $options";
    $result .= "</select>&nbsp;";
  } else {
    $webs = $webs || $webName;
    $result .= "<input type=\"hidden\" name=\"searchweb\" value=\"$webs\" />";
  }
  $result .= "<input type=\"submit\" value=\"Query\"></form>";
  return $result;
}

sub search {
  my ( $searchWeb, $webName, $topic, $query ) = @_;
  my $cgiAppType = $query->param( 'contenttype' ) || $query->param( 'apptype' ) || "text/html";
  my $form = $query->param( 'form' ) || "";
  my $heading = $query->param( 'title' ) || "";
  my $message = $query->param( 'message' ) || "";
  my $topicregex = $query->param( 'topicregex' ) || "";
  my $init = $query->param( 'init' ) || "";
  my $allshow = $query->param( 'allshow' ) || "";
  my $allfilter = $query->param( 'allfilter' ) || "";
  my @fieldsInfo = TWiki::Form::getFormDef( $webName, $form );

  my $header = "|*View, edit:*|";
  my $filter = "|*<input type=\"submit\" value=\"Filter\" />*|";
  my $search = "";
  my $format = "| [[\$web.\$topic][<img src=\\\"%PUBURLPATH%/%TWIKIWEB%/TWikiDocGraphics/viewtopic.gif\\\" border=\\\"0\\\" alt=\\\"View entry\\\" />]] [[%SCRIPTURL%/edit%SCRIPTSUFFIX%/\$web/\$topic?t=%GMTIME{\"\$hour\$min\$sec\"}%][<img src=\\\"%PUBURLPATH%/%TWIKIWEB%/TWikiDocGraphics/edittopic.gif\\\" border=\\\"0\\\" alt=\\\"Edit entry\\\" />]] |";
  my $hidden = "";

  my $textsize = 30;

  foreach my $c ( @fieldsInfo ) {
    my @fieldInfo = @$c;
    my $fieldName = shift @fieldInfo;
    my $name = $fieldName;
    my $title = shift @fieldInfo;
    my $type = shift @fieldInfo;
    my $size = shift @fieldInfo;
    my $tooltip = shift @fieldInfo;
    my $attributes = shift @fieldInfo;
    # now @fieldInfo holds list of possible values

    my $qshow = ($query->param( "show$name" ) || $allshow);
    my $qfilter = ($query->param( "filter$name" ) || $allfilter);
    if ( $qshow || $qfilter ) {
      $header .= "*$title*|";
      $format .= " \$formfield($name) |";
    }

    if ( $qshow eq $name ) {
      $hidden .= "<input type=\"hidden\" name=\"show$name\" value=\"$name\" />";
    }
      
    if ( ! $qfilter ) {
      $filter .= "*&nbsp;*|" if $qshow;
    } else {
      # This will depend on the values possible
      $hidden .= "<input type=\"hidden\" name=\"filter$name\" value=\"$name\" />";
      if ($#fieldInfo == -1) {
	$filter .= "*<input type=\"text\" name=\"q$name\" value=\"" . $query->param( "q$name" ) . "\" size=\"$textsize\" />*|";
      } else {
	if (($type eq "select")||($type =~ "^checkbox")||($type eq "radio")) {
	  $filter .= "*<select name=\"q$name\" size=\"1\"> <option>" .
	    $query->param( "q$name" ) . "</option> <option></option>";
	  foreach my $item ( @fieldInfo ) {
	    $item =~ s/<nop/&lt\;nop/go;
	    $filter .= " <option>$item</option>" if $item;
	  }
	  $filter .= " </select>*|";
	} else {
	  # ($type eq "text")||($type eq "label")||($type eq "date")||($type eq "textarea")
	  $filter .= "*<input type=\"text\" name=\"q$name\" value=\"" . $query->param( "q$name" ) . "\" size=\"$textsize\" />*|";
	}
      }
      if ( my $sparam = $query->param( "q$name" ) ) {
	$search .= "META:FIELD.*?\\\\\"$name.*?" . $sparam . ";";
      }
    }
  }
  if ( $search ) {
    chop $search;
  } else {
    $search = "." if ($init ne "off");
  }

  my $result = "<form method=POST action=\"%SCRIPTURLPATH%/gensearch%SCRIPTSUFFIX%/$webName/%TOPIC%\">\n";
  $result .= "<input type=\"hidden\" name=\"searchweb\" value=\"$searchWeb\" />";
  $result .= "<input type=\"hidden\" name=\"topicregex\" value=\"$topicregex\" />";
  $result .= "<input type=\"hidden\" name=\"form\" value=\"$form\" />";
  $result .= "<input type=\"hidden\" name=\"title\" value=\"$heading\" />";
  $result .= "<input type=\"hidden\" name=\"message\" value=\"$message\" />";
  $result .= $hidden . "\n";
  $result .= $header . "\n" . $filter . "\n%SEARCH{ search=\"" . $search . "\"";
  $result .= " topic=\"$topicregex\"" if $topicregex;
  $result .= " web=\"$searchWeb\" nosearch=\"on\" nototal=\"on\" regex=\"on\" noheader=\"on\" terminator=\"on\" format=\"";
  $result .= $format . "\" }%\n</form>";

  my $tmpl = &TWiki::Func::readTemplate( "oopsgensearch" );
  $tmpl =~ s/%PARAM1%/$heading/go;
  $tmpl =~ s/%PARAM2%/$message/go;
  $tmpl =~ s/%PARAM3%/$result/go;

  $tmpl = &TWiki::Func::expandCommonVariables( $tmpl, "" );
  $tmpl = &TWiki::handleMetaTags( $webName, "", $tmpl );

  TWiki::writeHeader( $query );
  print $tmpl;
}

1;
