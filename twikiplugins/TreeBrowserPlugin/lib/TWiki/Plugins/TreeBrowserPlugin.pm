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
# Extensions:
# a. allow custom icons for the nodes (could either use prefix to text
#    (see RenderListPlugin) or pass in %TREEBROWSER% tag
# b. Allow wrapping of long text
#
#    
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#


# =========================
package TWiki::Plugins::TreeBrowserPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $js
    );

$VERSION = '1.031';
$pluginName = 'TreeBrowserPlugin';

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
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $js = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Render here, not in commonTagsHandler so that lists produced by
    # Plugins, TOC and SEARCH can be rendered
    $_[0] =~ s/ {3}/\t/gs if $_[0] =~/%TREEBROWSER/;
    $_[0] =~ s/%TREEBROWSER{(.*?)}%(([\n\r]+[^\t]{1}[^\n\r]*)*?)(([\n\r]+\t[^\n\r]*)+)/&handleTreeView($1, $2, $4)/ges;
}

sub handleTreeView {
    my ( $theAttr, $thePre, $theList ) = @_;

    # decode attributes if these are added
    my $theme = &TWiki::Func::extractNameValuePair( $theAttr, "theme" ) ||
                &TWiki::Func::extractNameValuePair( $theAttr );
    $theme = "TREEBROWSERPLUGIN_" . uc( $theme ) . "_THEME";
    $theme = &TWiki::Func::getPreferencesValue( $theme ) || "unrecognized theme type";
    my ( $type, $params ) = split( /, */, $theme, 2 );
    $type = lc( $type );

    unless ( $type eq "tree" || $type eq "icon" ) {
        return "$thePre$theList";
    }
    my $theTitle = &TWiki::Func::extractNameValuePair( $theAttr, "title" );
    my $wraptext = &TWiki::Func::extractNameValuePair( $theAttr, "wraptext" );
    my $open1 = &TWiki::Func::extractNameValuePair( $theAttr, "openTo" );
    my $open2 = &TWiki::Func::extractNameValuePair( $theAttr, "openAll" );
    my $shared = &TWiki::Func::extractNameValuePair( $theAttr, "shared" );
    my $icons = 0;
    $icons = 1 if ($type eq "icon");
    my $wrap = 0;
    $wrap = 1 if ($wraptext eq "on");
    my $isunique = 0;
    $isunique = 1 if ($unique eq "on");
    my $openall = 0;
    $openall = 1 if ($open2 eq "on");
    my $opento = 0;
    $opento = $open1 if (!$openall && $open1);
    
    return $thePre . &renderTreeView( $type, $params, $theTitle, $icons, $shared, $openall, $opento, $theList );
}

sub renderTreeView
{
    my ( $theType, $theParams, $theTitle, $icons, $shared, $openAll, $openTo, $theText ) = @_;

    $theText =~ s/^[\n\r]*//os;
    my @tree = ();
    my $level = 0;
    my $type = "";
    my $text = "";

    my $attach = TWiki::Func::getPubUrlPath();
    my $docgraphics = $attach . "/$installWeb/TWikiDocGraphics";
    $attach .= "/$installWeb/$pluginName";
    my $attachUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();
    $theParams =~ s/%PUBURL%/$attachUrl/go;
    $attachUrl .= "/$installWeb/$pluginName";
    $theParams =~ s/%ATTACHURL%/$attachUrl/go;
    $theParams =~ s/%WEB%/$installWeb/go;
    $theParams =~ s/%MAINWEB%/TWiki::Func::getMainWebname()/geo;
    $theParams =~ s/%TWIKIWEB%/TWiki::Func::getTwikiWebname()/geo;
    my ( $rooticon, $docicon, $fldricon, $fldropenicon )
       = split( /, */, $theParams );
    $width   = 16;
    $height  = 16;
    $docicon = "$attach/page.gif" unless( $docicon );
    $docicon = "$docgraphics/$docicon" unless ( !$docicon || $docicon =~ m#/#o );
    #$docicon = fixImageTag( $docicon, $width, $height );
    $fldricon = "$attach/folder.gif" unless( $fldricon );
    $fldricon = "$docgraphics/$fldricon" unless ( !$fldricon || $fldricon =~ m#/#o );
    #$fldricon = fixImageTag( $fldricon, $width, $height );
    $fldropenicon = "$attach/folderopen.gif" unless( $fldropenicon );
    $fldropenicon = "$docgraphics/$fldropenicon" unless ( !$fldropenicon || $fldropenicon =~ m#/#o );
    #$fldropenicon = fixImageTag( $fldropenicon, $width, $height );
    $rooticon = "$attach/home.gif" unless( $rooticon );
    $rooticon = "$docgraphics/$rooticon" unless ( !$rooticon || $rooticon =~ m#/#o );
    #$rooticon = fixImageTag( $rooticon, $width, $height );

    foreach( split ( /[\n\r]+/, $theText ) ) {
        m/^(\t+)(.) *(.*)/;
        $level = length( $1 );
        $type = $2;
        $text = $3;
        push( @tree, { level => $level, type => $type, text => $text } );
    }

    $js++;
    my $var = ($shared)?$shared:"d$js";
    my $script = "
<link rel=\"StyleSheet\" href=\"$attachUrl/dtree.css\" type=\"text/css\" />
<script type=\"text/javascript\" src=\"$attachUrl/dtree.js\"></script>";
    $text = "<div class=\"dtree\"><script type=\"text/javascript\">
<!--
$var = new dTree('$var');\n";
    $text .= "$var.config.inOrder=true;\n";
    $text .= "$var.config.iconPath='" . $attach . "/';\n";
    $text .= "$var.updateIconPath();\n";
    $text .= "$var.icon.root=\'$rooticon\';\n";
#    $text .= "$var.icon.folder=\'$fldricon\';\n";
#    $text .= "$var.icon.folderOpen=\'$fldropenicon\';\n";
#    $text .= "$var.icon.node=\'$docicon\';\n";
    $text .= "$var.config.useIcons=false;\n" unless $icons;
    $text .= "$var.config.shared=true;\n" if $shared;
    $theTitle = &TWiki::Func::renderText( $theTitle, $web );
    $theTitle =~ s/\"/\\\"/go;
    $text .= "$var.add(0,-1,\"<b>$theTitle</b>\");\n";
    my @fldrs = ();
    my $fldr = 0;
    for( my $i = 0; $i < scalar( @tree ); $i++ ) {
      my $label = $tree[$i]->{'text'};
      my $iconImg;
      if ( $label =~ /^\s*(<b>)?\s*icon:([^\s]+)\s*(.*)/ ) {
	$label = $3;
	$label = "$1 $3" if ( $1 );
	# SMELL: why are we forcing this to be a gif file? And in $attach?
	$iconImg = "$attach/$2";
      } else {
	$iconImg = $docicon;
      }
      my $id = $i+1;
      $label = &TWiki::Func::renderText( $label, $web );
      $label =~ s/\"/\\\"/go;
      my $lvl = $tree[$i]->{'level'};
      my $nextlvl = ($i == scalar( @tree ) - 1)?$lvl:$tree[$i+1]->{'level'};
      if ( $lvl < $nextlvl ) {
	if ( $lvl < ($nextlvl - 1) ) {
	  # indented too far, correct
	  TWiki::Func::writeWarning("TreeBrowserPlugin: In topic $topic, item \'" . $tree[$i+1]->{'text'} . "\' to deeply indented.");
	  $nextlvl = $lvl + 1;
	  $tree[$i+1]->{'level'} = $nextlvl;
	}
	$text .= "$var.add($id,$fldr,\"$label\",'','','',\'$fldricon\',\'$fldropenicon\');\n";
	push @fldrs, $fldr;
        $fldr = $id;
      } elsif ( $lvl == $nextlvl) {
	$text .= "$var.add($id,$fldr,\"$label\",'','','',\'$iconImg\');\n";
      }
	else {
        $text .= "$var.add($id,$fldr,\"$label\",'','','',\'$iconImg\');\n";
	for ( my $j = $lvl; $j > $nextlvl; $j-- ) {
	  $fldr = pop @fldrs;
	}
      }
    }
    $text .= "document.write($var);\n";
    $text .= "$var.openAll();\n" if $openAll;
    $text .= "$var.openTo($openTo);\n" if $openTo;
    $text .= "//-->\n</script></div>";
    # fall back if JavaScript is turned off
    $text .= "\n<noscript>\n$theText</noscript>";
    if ( $js == 1 ) {
      return $script . $text;
    } else {
      return $text;
    }
}

1;
