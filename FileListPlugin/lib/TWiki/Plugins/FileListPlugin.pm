# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# TWiki:Main.VinodKulkarni, Apr 2005
# v0.6
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
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
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
package TWiki::Plugins::FileListPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $doOldInclude $renderingWeb
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'FileListPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $defaultFormat = TWiki::Func::getPluginPreferencesFlag( "FORMAT" ) || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub _handleFileList 
{
  my ($args, $theWeb, $theTopic) = @_;

  use TWiki::Func;
  my %params = TWiki::Func::extractParameters($args);


  my $thisWeb = $theWeb;
  my $thisTopic = $theTopic;
  if ( !($params{"topic"} eq "")) {
      $thisTopic = $params{"topic"};
      if (!($params{"web"} eq "")) {
         $thisWeb = $params{"web"};
      }
  }
  
  my $format = $params{"format"} || $params{"_DEFAULT"} || ('	* [[$fileUrl][$fileName]]: $fileComment'. "\n" ) ;
  # my $flags = $params{"flags"}; # Later use
  my $selection = $params{"selection"}; # "abc, def" syntax. Substring match will be used

  my ($meta, $text) = TWiki::Func::readTopic($thisWeb, $thisTopic); # Third parameter: check permissions.
  my $outtext=""; 

  # Make sure selection string is valid.
  if ( $selection ) {
    # Convert it into regexp to search files against.
    # "abc, bcd" => (abc)|(bcd)
    $selection =~ s/\s*([\w\._\-\+\s]*)\s*,/($1)|/g  ;
    $selection =~ s/\s*([\w\._\-\+\s]*)\s*$/($1)/;
  }

  my @attachments = $meta->find( "FILEATTACHMENT" );
  
  foreach my $attachment ( @attachments ) {
    my $file=$attachment->{name};
    my $attrVersion=$attachment->{Version};
    my $attrDate=TWiki::formatTime($attachment->{"date"});
    my $attrSize=$attachment->{size};
    my $attrUser=$attachment->{user};
    my $attrComment=$attachment->{comment};
    my $attrAttr=$attachment->{attr};

    my $fileIcon = TWiki::Attach::filenameToIcon( $file );

    # I18N: To support attachments via UTF-8 URLs to attachment
    # directories/files that use non-UTF-8 character sets, go through viewfile. 
    # If using %PUBURL%, must URL-encode explicitly to site character set.

    # Go direct to file where possible, for efficiency
    $attrSize = $attrSize.'b' if( $attrSize < 100 );
    $attrSize = sprintf( "%1.1fK", $attrSize / 1024 );
    $attrComment = $attrComment || "&nbsp;";
    my $s = "$format";
    next if ( $selection && ! ($file =~ m/$selection/));
    $s =~ s/\$fileName/$file/g; 
    $s =~ s/\$fileIcon/$fileIcon/g; 
    $s =~ s/\$fileSize/$attrSize/g; 
    $s =~ s/\$fileComment/$attrComment/g; 
    $s =~ s/\$fileDate/$attrDate/g; 
    $s =~ s/\$fileUser/$attrUser/g; 
    $s =~ s/\$n/\n/g; 
    $s =~ s/\$br/\<br\/\>/g; 

    my $fileActionUrl =  TWiki::handleNativeUrlEncode(TWiki::Func::getScriptUrl($thisWeb, $thisTopic, "attach") . "?filename=$file&revInfo=1");
    $s =~ s/\$fileActionUrl/$fileActionUrl/; 

    my $viewfileUrl = TWiki::handleNativeUrlEncode(TWiki::Func::getScriptUrl($thisWeb, $thisTopic, "viewfile") . "?rev=$attrVersion&filename=$file");
    $s =~ s/\$viewfileUrl/$viewfileUrl/; 

    my $fileUrl=TWiki::handleNativeUrlEncode( TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . "/$thisWeb/$thisTopic/$file", 1);
    $s =~ s/\$fileUrl/$fileUrl/; 

    $outtext .= $s;
  }
  return $outtext;
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%FILELIST%/&_handleFileList($defaultFormat, $web, $topic)/ge;
    $_[0] =~ s/%FILELIST{(.*?)}%/&_handleFileList($1, $web, $topic)/ge;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render deprecated *_text_* as "bold italic" text:
    $_[0] =~ s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<strong><em>$2<\/em><\/strong>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&TWiki::Render::internalLink($2,$3,"$2:$3",$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/&TWiki::Render::internalLink($web,$2,$2,$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&TWiki::Render::internalLink($2,$3,$3,$1,1)/geo;

    # Use <link>....</link> links
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/<link>(.*?)<\/link>/&TWiki::internalLink("",$web,$1,$1,"",1)/geo;
}

1;
