# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2006-2007 Stéphane Lenclud, twiki@lenclud.com
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

$VERSION = 'v0.9';
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
sub preRenderingHandler {
# do not uncomment, use $_[0], $_[1]... instead
#my( $text, $pMap ) = @_;

    #TWiki::Func::writeDebug( "- ${pluginName}::preRenderingHandler-Before( $_[0] )" ) if $debug;

    # Render here, not in commonTagsHandler so that lists produced by
    # Plugins, TOC and SEARCH can be rendered
    $_[0] =~ s/ {3}/\t/gs if $_[0] =~/%TREEBROWSER/; #SL: As far as I can tell this replaces three space characters with tabulation, why?
	 $_[0] =~ s/%TREEBROWSER{(.*?)}%(([\n\r]+[^\t]{1}[^\n\r]*)*?)(([\n\r]+\t[^\n\r]*)+)/&handleTreeView($1, $2, $4)/ges;
	 #SL: Get ride of lonely TREEBROWSER tag.
	 $_[0] =~ s/%TREEBROWSER{(.*?)}%/&handleLonelyTreeView($1)/ges;
}

=pod
Get rides of unprocessed %TREEBROWSER{}% tags.
A %TREEBROWSER{}% tag won't be processed if it is not followed by a tree.
=cut
sub handleLonelyTreeView {
    my ( $theAttr) = @_;
	TWiki::Func::writeDebug( "- ${pluginName}::handleLonelyTreeView( $theAttr )" ) if $debug;
    # Get the =warn= parameter if any. =warn= specifies a message to be displayed by unprocessed tag.
    my $warn = &TWiki::Func::extractNameValuePair( $theAttr, "warn" );
	return $warn;
	}

=pod
Called when a %TREEBROWSER{}% tag need to be processed.
It reads various settings and configurations from the tag argument list and the TWiki preferences.
=cut
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
		  #TWiki::Func::writeDebug( "- ${pluginName}::handleTreeView() returns $thePre$theList" ) if $debug;
        return "$thePre$theList";
    }
	
   my $theTitle = &TWiki::Func::extractNameValuePair( $theAttr, "title" );
   my $wraptext = &TWiki::Func::extractNameValuePair( $theAttr, "wraptext" );
   my $open1 = &TWiki::Func::extractNameValuePair( $theAttr, "openTo" );
   my $open2 = &TWiki::Func::extractNameValuePair( $theAttr, "openAll" );
   my $shared = &TWiki::Func::extractNameValuePair( $theAttr, "shared" );
   my $useLines = &TWiki::Func::extractNameValuePair( $theAttr, "uselines" );  
   my $usePlusMinus = &TWiki::Func::extractNameValuePair( $theAttr, "useplusminus" );
   my $noIndent = &TWiki::Func::extractNameValuePair( $theAttr, "noindent" );
   my $noRoot = &TWiki::Func::extractNameValuePair( $theAttr, "noroot" );
   my $noCss = &TWiki::Func::extractNameValuePair( $theAttr, "nocss" );
   # =style= specifies the CSS file to be used.
   my $style = &TWiki::Func::extractNameValuePair( $theAttr, "style" );
   $style=dtree unless TWiki::Func::attachmentExists($installWeb,$pluginName,"$style.css"); #Default to dtree
   my $useStatusText = &TWiki::Func::extractNameValuePair( $theAttr, "usestatustext" );
   my $closeSameLevel = &TWiki::Func::extractNameValuePair( $theAttr, "closesamelevel" );    
   my $icons = 0;
   $icons = 1 if ($type eq "icon");
   my $wrap = 0;
   $wrap = 1 if ($wraptext eq "on");
   my $openall = 0;
   $openall = 1 if ($open2 eq "on");
   my $opento = 0;
   $opento = $open1 if (!$openall && $open1);
    
   return $thePre . &renderTreeView( $type, $params, $useLines, $usePlusMinus, $useStatusText, $closeSameLevel, $noIndent, $noRoot, $noCss, $theTitle, $icons, $shared, $openall, $opento, $theList, $style );
}

sub renderTreeView
{
    my ( $theType, $theParams, $useLines, $usePlusMinus, $useStatusText, $closeSameLevel, $noIndent, $noRoot, $noCss, $theTitle, $icons, $shared, $openAll, $openTo, $theText, $style ) = @_;

    $theText =~ s/^[\n\r]*//os;
    my @tree = ();
    my $level = 0;
    my $type = "";
    my $text = "";

    my $attach = TWiki::Func::getPubUrlPath();
    my $docgraphics = $attach . "/$installWeb/TWikiDocGraphics";
    $attach .= "/$installWeb/$pluginName";
    my $attachUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();
    
    $theParams="" unless defined $theParams; #Initialize if not defined to get ride of warnings in apache error logs       
	 #$theParams=TWiki::Func::expandCommonVariables($theParams); #SL: consider using that in future development
	 $theParams =~ s/%PUBURL%/$attachUrl/go;
    $attachUrl .= "/$installWeb/$pluginName";
    $theParams =~ s/%ATTACHURL%/$attachUrl/go;
    $theParams =~ s/%WEB%/$installWeb/go;
    $theParams =~ s/%MAINWEB%/TWiki::Func::getMainWebname()/geo;
    $theParams =~ s/%TWIKIWEB%/TWiki::Func::getTwikiWebname()/geo;      

    my ( $rooticon, $docicon, $fldricon, $fldropenicon )
       = split( /, */, $theParams );
    my $width   = 16;
    my $height  = 16;
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
   my $script = "";
   #Include javascript
   $script .= "<script type=\"text/javascript\" src=\"$attachUrl/dtree.js\"></script>";
   $text = "<div class=\"dtree\">";
   #Include CSS unless no CSS specified
   $text .="<style type=\"text/css\" media=\"all\">\@import \"$attachUrl/$style.css\";</style>" unless ($noCss=~/true|1|on/i);    
   $text .="<script type=\"text/javascript\">
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
    $text .= "$var.config.noIndent=true;\n" if ($noIndent=~/true|1|on/i);
    $text .= "$var.config.useLines=false;\n" if (($useLines=~/false|0|off/i) || $noIndent); #noident override uselines, prevents java bug :)
    $text .= "$var.config.usePlusMinus=false;\n" if (($usePlusMinus=~/false|0|off/i) || $noIndent);#noident override useplusminus, prevents java bug :)
    $text .= "$var.config.closeSameLevel=true;\n" if ($closeSameLevel=~/true|1|on/i);
    $text .= "$var.config.noRoot=true;\n" if ($noRoot=~/true|1|on/i);


    $text .= "$var.config.useStatusText=false;\n"; #Broken due to dtree usage if ($useStatusText=~/true|1|on/i);
    $text .= "$var.config.useSelection=false;\n"; #Broken due to dtree usage
    $text .= "$var.config.folderLinks=false;\n"; #Broken due to dtree usage
    $theTitle = &TWiki::Func::renderText( $theTitle, $web );
    $theTitle =~ s/\"/\\\"/go;
    $text .= "$var.add(0,-1,\"$theTitle\");\n";
    my @fldrs = ();
    my $fldr = 0;
    for( my $i = 0; $i < scalar( @tree ); $i++ ) {
      my $label = $tree[$i]->{'text'};
      my $iconImg;
      if ( $label =~ /^\s*(<b>)?\s*icon:([^\s]+)\s*(.*)/ )
			{
			$label = $3;
			$label = "$1 $3" if ( $1 );
			$iconImg = "$attach/$2";
      	}
		else
			{
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
