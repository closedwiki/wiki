# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package ImgPlugin

This is a pretty winky-dink plugin that allows people to use %IMG{"foo.gif"}% instead
of <img src="%ATTACHURL%/foo.gif" />. It allows specification of the standard attributes 

as well as an optional web=<web> and/or topic=<topic>.

Another small step in the eradication of html in TWiki!

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::ImgPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'ImgPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle tags that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

    use vars qw(
		$ConvertProg
		$IdentifyProg
		$Default_Thumb
		$MAGNIFY_FORMAT
		$SIMPLE_FORMAT
		$NO_CAPTION_FORMAT
		$CAPTION_FORMAT
		$ImgPlugin_Style
		$Debug
		);

    # href, caption, img, caption, width, height, href
    $SIMPLE_FORMAT = qq[<a href="%s" class="image" title="%s"><img border="0" align="absmiddle" src="%s" alt="%s" width="%d" height="%d" longdesc="%s" /></a>];

    # href
    $MAGNIFY_FORMAT = qq[<div class="magnify" style="float:right"><a href="%s" class="internal" title="Enlarge"><img border="0" align="absmiddle" src="/tw/templates/magnify-clip.png" width="15" height="11" alt="Enlarge" /></a></div>];

    $NO_CAPTION_FORMAT = qq[<div class="float%s"><div class="floatnone"><span><a href="%s" class="image" title=""><img border="0" align="absmiddle" src="%s" width="%d" height="%d" longdesc="%s" /></a></span></div></div>];

    $CAPTION_FORMAT = qq[<div class="thumb t%s"><div style="width:%dpx;"><a href="%s" class="internal" title="%s"><img border="0" align="absmiddle" src="%s" alt="%s" width="%d" height="%d" longdesc="%s" /></a><div class="thumbcaption">%s</div></div></div>];



sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
    my($error);

    $error = 0;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
      TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
      return( 0 );
    }

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
    #my $exampleCfgVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );
    # There is also an equivalent:
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( 'EXAMPLE' );
    # that may _only_ be called from the main plugin package.

    #$exampleCfgVar ||= 'default'; # make sure it has a value

    $Debug = TWiki::Func::getPluginPreferencesValue( 'DEBUG' ) || 0;

    $ConvertProg  = TWiki::Func::getPluginPreferencesValue( 'CONVERT_PROG' ) ||
	'/usr/local/bin/convert';

    if( ! (-e $ConvertProg || -x $ConvertProg) ){
        TWiki::Func::writeWarning( qq[ImgPlugin: CONVERT_PROG does not exist!] );
	$error++;
    }

    $IdentifyProg = TWiki::Func::getPluginPreferencesValue( 'IDENTIFY_PROG' ) ||
	'/usr/local/bin/identify';

    if( ! (-e $IdentifyProg || -x $ConvertProg) ){
        TWiki::Func::writeWarning( qq[ImgPlugin: IDENTITY_PROG does not exist!] );
	$error++;
    }

    $Default_Thumb   = TWiki::Func::getPluginPreferencesValue( 'THUMBNAIL_SIZE' ) || 180;

    $ImgPlugin_Style = TWiki::Func::getPluginPreferencesValue( 'IMGPLUGIN_STYLE' ) ||
      join('/', TWiki::Func::getPubUrlPath(), 'TWiki', 'ImgPlugin', 'ImgPlugin.css');

    TWiki::Func::writeWarning( "Initialize (ImgPlugin) error=($error): [$ConvertProg][$IdentifyProg][$Default_Thumb][$ImgPlugin_Style]" );

    if( $error > 0 ){
	return( 0 );
    }
    # register the _IMGfunction to handle %IMG{...}%
    TWiki::Func::registerTagHandler( 'IMG', \&_IMG);
    TWiki::Func::registerTagHandler( 'IMAGE', \&_IMAGE);

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('example', \&restExample);

    # Plugin correctly initialized
    return(1);

} # initPlugin



sub get_size {
    my($dir_path, $file) = @_;
    my($result, @info);

    $result = `$IdentifyProg '$dir_path/$file'`;
    chomp($result);

    (@info) = split(/\s+/, $result);
    TWiki::Func::writeDebug("get_size($file): ", join(' | ', @info), "\n") if( $Debug > 0 );

    if( defined($info[2]) && $info[2] =~ m/(\d+)x(\d+)/ ){
	return( {
	    DIR  => $dir_path,
	    FILE => $file,
	    X => $1,
	    Y => $2, } );
    } else {
	return( {
	    DIR  => $dir_path,
	    FILE => $file,
	    X => '',
	    Y => '', } );
    }
} # get_size


sub resize {
    my($src_path, $dst_path, $file, $size) = @_;
    my($result, $cmd, $new);

    if( $size ne '' ){
	$new = join('px-', $size, $file);
	if( ! -f "$dst_path/$new" ){
	    $cmd = qq[$ConvertProg -resize $size '$src_path/$file' '$dst_path/$new'];
	    TWiki::Func::writeDebug( "resize($file): [$cmd]\n" ) if( $Debug > 0 );
	    $result = `$cmd`;
	}
	return( get_size($dst_path, $new) );
    } else {
	return( get_size($src_path, $file) );
    }
} # resize


sub _CLEAR {
    my($session, $params, $theTopic, $theWeb) = @_;

    return( qq[<br clear="all" />] );
} # _CLEAR


sub _IMAGE {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    # For example, %IMG{'foo.gif' topic="SomeTopic"}%
    # $params->{_DEFAULT} will be 'foo.gif'
    # $params->{topic} will be 'SomeTopic'

    my($str, @args, $file, $align, $size, $frame, $caption, $thumb,
       $result, $link_only, $tmp, $height);

    $str = $params->{_DEFAULT};
    if( $str =~ m/clr|clear/i ){
	return( qq[<br clear="all" />] );
    }

    
    foreach ( qw(type align caption) ){
	$tmp = $params->{$_};
	if( defined($tmp) ){
	    $str = join('|', $str, $params->{$_});
	}
    }

    $tmp = $params->{size};
    if( defined($tmp) && $tmp =~ m/(\d+)(px)?x?(\d+)?(px)?/ ){
	$str = join('|', $str, defined($3) ? qq[$1x$3px] : qq[$1px] );
    }

    TWiki::Func::writeDebug("_IMAGE START: [$str]\n" ) if( $Debug > 0);

    $str =~ s/^\[\[//;
    $str =~ s/\]\]$//;		 
    $str .= ' ';

    ($file, @args) = split(/\|/, $str);

    if( $file =~ s/^:// ){
	$link_only = 1;
    }
    $file =~ s/^image://i;

    TWiki::Func::writeDebug("$file, size:", scalar(@args), " ", join(", ", @args), "\n" ) if( $Debug > 2);

    $size = '';
    $caption = '';

    foreach ( @args ){
	if( $_ =~ m/^\s*(right|left|center|none)\s*$/i ){
	    $align = $1;

	} elsif( $_ =~ m/^\s*(\d+)px\s*$/i ){
	    $size = $1;

	} elsif( $_ =~ m/^\s*frame\s*$/i ){
	    $frame = 1;

	} elsif( $_ =~ m/^\s*(thumb|thumbnail)\s*$/i ){
	    $thumb = 1;
	    $size = $Default_Thumb;

	} elsif( $_ =~ m/^\s*h(\d+)px\s*$/i ){
	    $height = $1;
	    
	} else {
	    $caption = $_;
	}
    }

    TWiki::Func::writeDebug("[$file] [$align] [$size] frame[$frame] caption[$caption]\n" ) if( $Debug > 1);

    #
    # Do resize here as needed
    # check if allready resized (before)
    # get EXIF info from file
    # Do smart convert, size is final width, adjust height accordingly
    #

    my($src_web, $src_topic, $src_path, $web_path, $dst_path, $view_img,
       $pinfo, $x, $y);

    $src_web   = $params->{web}   || $theWeb;
    $src_topic = $params->{topic} || $theTopic;
    $src_path  = join('/', TWiki::Func::getPubDir(), $src_web, $src_topic);
    $dst_path = join('/', TWiki::Func::getPubDir(),     $theWeb, $theTopic);

    $pinfo = resize($src_path, $dst_path, $file, $size);
    $x = $pinfo->{X};
    $y = $pinfo->{Y};
    if( $pinfo->{DIR} eq $dst_path ){
	$web_path = join('/', TWiki::Func::getPubUrlPath(), $theWeb, $theTopic);
	$view_img  = TWiki::Func::getScriptUrl($theWeb, $theTopic, 'viewfile') .
	    qq[?filename=$file];
    } else {
	$web_path = join('/', TWiki::Func::getPubUrlPath(), $src_web, $src_topic);
	$view_img  = TWiki::Func::getScriptUrl($src_web, $src_topic, 'viewfile') .
	    qq[?filename=$file];
    }

    TWiki::Func::writeDebug("Img => [$pinfo->{DIR}/$pinfo->{FILE}]\n", "Size is ($x, $y)\n" ) if( $Debug > 0 );

    $tmp = join('/', $web_path, $pinfo->{FILE});

    $caption =~ s/ $//;

    if( defined($link_only) ){
	$result = qq[<a href="$view_img" title="$caption">$file</a>];

   } elsif( (scalar(@args) == 1 && $caption ne '') ||
	(!defined($thumb) && !defined($frame) && !defined($align)) ){ # Special case for single option
	$result = sprintf($SIMPLE_FORMAT, $view_img, $caption, $tmp, $caption, $x, $y, $view_img);

    } elsif( defined($frame) ){
	if( !defined($align) ){
	    $align = 'right';
	}
	$result = sprintf($CAPTION_FORMAT, $align, $x+2, $view_img, $caption, $tmp,
			  $caption, $x, $y, $view_img, $caption);

    } elsif( $caption eq '' && !defined($thumb) ) {
	$result = sprintf($NO_CAPTION_FORMAT, $align, $view_img, $tmp, $x, $y, $view_img);

    } else {
	my($enlarge);
	$enlarge = sprintf($MAGNIFY_FORMAT, $view_img) . $caption;
	if( !defined($align) ){
	    $align = 'right';
	}
	$result = sprintf($CAPTION_FORMAT, $align, $x+2, $view_img, $caption, $tmp,
			  $caption, $x, $y, $view_img, $enlarge);
    }

    writeDebug("[$result]\n" ) if( $Debug > 1);

    TWiki::Func::addToHEAD("IMGPLUGIN_STYLE",
			   qq[<link id="ImgPluginCss" rel="stylesheet"  type="text/css" href="$ImgPlugin_Style" media="all" />]);

    return( $result ); 
} # _IMAGE



# The function used to handle the %IMG{...}% tag
# You would have one of these for each tag you want to process.

sub _IMG {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    # For example, %IMG{'foo.gif' topic="SomeTopic"}%
    # $params->{_DEFAULT} will be 'foo.gif'
    # $params->{topic} will be 'SomeTopic'

    my($imgName, $path, $imgTopic, $imgWeb, $altTag, @attrs, $txt);

    $imgName = $params->{_DEFAULT};
    $path = TWiki::Func::getPubUrlPath();
    $imgTopic = $params->{topic} || $theTopic;
    $imgWeb = $params->{web} || $theWeb;
    $altTag = $params->{alt} || '';

    @attrs = qw(align border height width id class);

    $txt = "<img src='$path/$imgWeb/$imgTopic/$imgName' ";

    $txt .= " alt='$altTag'";
    while (my $key = shift @attrs) {
	if (my $val = $params->{$key}) {
	    $txt .= " $key='$val'";
	}
    }
    $txt .= " />";

    return( $txt );
} #_IMG

return 1;
