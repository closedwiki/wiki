# ObjectPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) TWiki:Main.PiersGoodhew & TWikiContributors.

=pod

---+ package ObjectPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::ObjectPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $objectPluginDefHeight
  $objectPluginDefWidth $objectPluginDefUseEMBED $objectPluginDefController
  $objectPluginDefPlay $kMediaFileExtsPattern);

use constant {
    kQTControllerHeight  => 16,
    kWMVControllerHeight => 46,
    kMediaFileExts       => qw (mov mpg m2v swf rm wmv mp4 mp3 avi),
};

# This should always be $Rev: 9813$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'ObjectPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    #TODO: these should be moved into Config.spec for performance.
    $objectPluginDefHeight =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_HEIGHT");
    $objectPluginDefWidth =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_WIDTH");
    $objectPluginDefController =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_CONTROLLER");
    $objectPluginDefPlay =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_PLAY");
    $objectPluginDefUseEMBED =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_USEEMBED");

    $objectPluginDefUseEMBED =
      ( $objectPluginDefUseEMBED eq "TRUE" );  #This one needs to be a perl bool

    # register the OBJECT function to handle %OBJECT{...}%
    TWiki::Func::registerTagHandler( 'OBJECT', \&_OBJECT );

# Some "consts"
#$kQTControllerHeight = 16;
#$kWMVControllerHeight = 46;
#$kMediaFileExts = ("mov", "wmv", "swf", "mpg", "mpeg", "mp3", "rm", "mp4", "3gpp")
    $kMediaFileExtsPattern = join( "|", kMediaFileExts );

    # Plugin correctly initialized
    return 1;
}

# Our actual function
sub _OBJECT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $objectParams = " ";
    my $embedTags    = " ";
    if ($objectPluginDefUseEMBED) {
        $embedTags = "<EMBED "
          ; #you want a trailing space on pretty much everything that isn't an end tag
    }
    my $objectHeader = "<OBJECT ";
    my $objectFooter = "</OBJECT>";
    my $returnValue  = "";
    my ( $key, $value ) = ( 0, 0 );

    #	return $objectPluginDefUseEMBED;

#These three values are passed inside the <OBJECT> tag and not as <PARAM>s later ...
    my $height = $params->{height};
    my $width  = $params->{width};
    $params->{src} ||= $params
      ->{_DEFAULT}; #"src" is optional so we try the default param if "src" is ND

    #fall special values back to default if nd
    $height ||= $objectPluginDefHeight;
    $width  ||= $objectPluginDefWidth;

#copy the params into our own hash, then delete the values (if they're there) which are handled differently
#(if at all)
    my %localParams = %$params;
    delete $localParams{width}    if $localParams{width};
    delete $localParams{height}   if $localParams{height};
    delete $localParams{_DEFAULT} if $localParams{_DEFAULT};
    delete $localParams{_RAW}
      if $localParams{_RAW};  #don't know what it is or does, but it's there ...

    #detect file type ... this should be inside an if (don't be generic) block
    my ( $fileHeader, $fileExt ) = ( $localParams{src} =~ /(.*)\.+(.*$)/ );

    #	if ($fileExt =~ m/$kMediaFileExtsPattern/) {
    if (1) {

#We have a media-y file, fill out our various param synonyms from params/defaults
        $localParams{controller} ||= $objectPluginDefController;
        $localParams{ShowController} =
          ( $localParams{controller} eq "TRUE" ) * 1;
        $localParams{autoplay} ||= $localParams{play} ||= $objectPluginDefPlay;
        $localParams{AutoStart} =
          ( $localParams{play} eq "TRUE" ) *
          1;    #the * 1 is to convert perl bool to number
        $localParams{Movie} = $localParams{FileName} = $localParams{src};
        if ( $fileExt eq "mov" ) {

            #we handle as a QuickTime ...
            $objectHeader .=
"CLASSID=\"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B\" CODEBASE=\"http://www.apple.com/qtactivex/qtplugin.cab\" ";
            if ( $localParams{controller} ) {
                $height += kQTControllerHeight;
            }
            if ($objectPluginDefUseEMBED) {
                $embedTags .=
"TYPE=\"video/quicktime\" PLUGINSPAGE=\"http://www.apple.com/quicktime/download/\" ";
            }
        }
        elsif ( $fileExt eq "wmv" ) {

            #we handle as Windows Media ...
            $objectHeader .=
"ID=\"MediaPlayer\" classid=\"CLSID:22D6F312-B0F6-11D0-94AB-0080C74C7E95\""
              . "codebase=\"http://activex.microsoft.com/activex/controls/mplayer/en/nsmp2inf.cab#Version=6,4,7,1112\""
              . "standby=\"Loading Microsoft Windows Media Player components...\" type=\"application/x-oleobject\" ";
            if ( $localParams{controller} ) {
                $height += kWMVControllerHeight;
            }
            if ($objectPluginDefUseEMBED) {
                $embedTags .=
"type=\"application/x-mplayer2\" pluginspage=\"http://www.microsoft.com/windows/windowsmedia/download/AllDownloads.aspx/\""
                  . "Name=MediaPlayer";
            }

        }
        elsif ( $fileExt eq "swf" ) {

            #we handle as Flash ...
            $objectHeader .=
                "classid=\"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000\""
              . "codebase=\"http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,40,0\""
              . "id=\"myMovieName\"";
            if ( $localParams{controller} ) {
                $height += kWMVControllerHeight;
            }
            if ($objectPluginDefUseEMBED) {
                $embedTags .=
"type=\"application/x-shockwave-flash\" pluginspage=\"http://www.macromedia.com/go/getflashplayer\""
                  . "Name=myMovieName";
            }
        }
        else {

#Generic case - use the OBJECT tag with a "data" value and whatever params were expolicitly passed
            $objectHeader .= "data=\"$localParams{src}\"";
            delete $localParams{src};
        }
    }

 #We can now parse the params out into the OBJECT and (maybe) the EMBED tags ...
    while ( ( $key, $value ) = each %localParams ) {
        $objectParams .=
          ( "<PARAM name=\"" . $key . "\" value=\"" . $value . "\"> " );
        if ($objectPluginDefUseEMBED) {
            $embedTags .= ( $key . "=\"" . $value . "\" " );
        }
    }

    #complete the OBJECT and (maybe) EMBED tags with the size param
    if ($objectPluginDefUseEMBED) {
        $embedTags .= "height=\"$height\" width=\"$width\"></embed>";
    }
    $objectHeader .= "height=\"$height\" width=\"$width\">";

    return $objectHeader . $objectParams . $embedTags . $objectFooter;
}
