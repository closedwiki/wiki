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
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $doOldInclude $renderingWeb
    );

$VERSION = '1.021';
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
    $selection =~ s/\s*([\w\._\-\+\s]*)\s*,/(\1)|/g  ;
    $selection =~ s/\s*([\w\._\-\+\s]*)\s*$/(\1)/;
  }

  my @attachments = $meta->find( "FILEATTACHMENT" );
  
  foreach my $attachment ( @attachments ) {
    my $file=$attachment->{name};
    my $attrVersion=$attachment->{Version};
    my $attrDate=TWiki::formatTime($attachment->{"date"});
    my $attrSize=$attachment->{size};
    my $attrUser=$attachment->{user};
    my $attrComment=$attachment->{comment};
    my $attrAttr=attachment->{attr};

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
sub DISABLE_earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}


# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the beginning of TWiki::handleCommonTags (for cache Plugins use only)
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
sub DISABLE_afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the end of TWiki::handleCommonTags (for cache Plugins use only)
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

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}

# =========================
sub DISABLE_beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_renderFormFieldForEditHandler
{
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::renderFormFieldForEditHandler( $web.$topic )" ) if $debug;

    # This handler is called by Form.renderForEdit, before built in types are considered
    
    my $ret = "";
    # Set ret to html, leave empty if plugin doesn't want to render this field
    return $ret;
}

# =========================

1;
