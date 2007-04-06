
# TWiki ($wikiversion has version info)
#
# Copyright (C) 2002 Slava Kozlov,
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

# =========================
package TWiki::Plugins::TreePlugin;

use strict;
use warnings;

use TWiki::Func;

use TWiki::Plugins::TreePlugin::TWikiNode;
use TWiki::Plugins::TreePlugin::ListNodeFormatter;
use TWiki::Plugins::TreePlugin::ColorNodeFormatter;
use TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::HOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::ImgNodeFormatter;

# =========================
use vars qw(
  $gWeb $gTopic $user $installWeb $VERSION $debug $INTREE
  %FormatMap $RootLabel $AGdebugmsg $pluginName
);

$pluginName = 'TreePlugin';
$VERSION = '0.9';
$RootLabel = "_RootLabel_";    # what we use to label the root of a tree if not a topic

# =========================
sub initPlugin {
    ( $gTopic, $gWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning("Version mismatch between TreePlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "TreePlugin_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );


    &TWiki::Func::writeDebug("installWeb: $installWeb") if $debug;

    my $cgi = &TWiki::Func::getCgiQuery();
    if ( !$cgi ) {
        return 0;
    }
    
    TWiki::Func::registerTagHandler( 'TREEVIEW', \&HandleTreeTag );
    TWiki::Func::registerTagHandler( 'TREE', \&HandleTreeTag );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TreePlugin::initPlugin( $gWeb.$gTopic ) is OK")
      if $debug;
    return 1;
}

=pod
Tag handler for TREE and TREEVIEW
=cut 

# bugs re recursion:
#	1) doesn't remember webs so: recursion across webs is problematic
#	2) if two topics with identical names in different webs AND
#		both have a TREEVIEW tag -> the second will be excluded

$AGdebugmsg = "<br \/>AG debug message<br \/>";

sub HandleTreeTag
    {
    my($session, $params, $aTopic, $aWeb) = @_;    

    my $cgi   = &TWiki::Func::getCgiQuery();
    my $plist = $cgi->query_string();
    $plist .= "\&" if $plist;
    my $CurrUrl = $cgi->url . $cgi->path_info() . "?" . $plist;

    my $attrWeb = $params->{'web'} || $aWeb || "";
    #Get root topic id in the form =web.topic=
    my $rootTopicId = $params->{'topic'} ? "$attrWeb.".$params->{'topic'} : $RootLabel; 
  
    my $attrFormatting;
        
    my $attrHeader='';
    if (defined $params->{'header'})
        {
        $attrHeader ='<div class="treePluginHeader">'. $params->{'header'}."</div>\n";
        }
    else
        {
        #Make sure the tree starts on a new line and get formatted correctly
        $attrHeader="\n"; 
        }

    my $attrFormat = $params->{'format'} || "";
    
    my $attrFormatBranch =
      $params->{'formatbranch'} || "";
    $attrFormatting =
      $params->{'formatting'} || "";
    my $attrStartlevel =
      $params->{'startlevel'} || -1; # -1 means not defined
    #SL: If no =topic= and =startlevel= parameter was given then set =startlevel= to 1
    #This workaround get ride of the empty root line when rendering a tree for an entire Web
    if (($rootTopicId eq $RootLabel) && ($attrStartlevel==-1)) { $attrStartlevel=1; } #
    my $attrStoplevel =
      $params->{'stoplevel'} || 999;
    my $doBookView =
      $params->{'bookview'} || "";
    my $attrLevelPrefix =
      $params->{'levelprefix'} || "";
    
    # set the type of formatting
    my $formatter = setFormatter($attrFormatting);

    $formatter->data( "startlevel", $attrStartlevel );
    $formatter->data( "stoplevel",  $attrStoplevel );
    $formatter->data( "url",        $CurrUrl );
    $formatter->data( "levelprefix", $attrLevelPrefix );
        
    # if bookView, read bookview file as format
    if ($doBookView) {
        $formatter->data( "format", &TWiki::Func::readTemplate("booktree") );
    }
    else {

        # else set the format(s), if any
        $formatter->data( "format", $attrFormat ) if ($attrFormat);
        $formatter->data( "branchformat", $attrFormatBranch )
          if ($attrFormatBranch);

    }
    
    #Before doing the SEARCH, if no format was specified use formatter's default
    #SL: I know it's a bit mad what's going on between $attrFormat, $formatter->data('format') and $params->{'format'} but that will do for now
    $params->{'format'}=$formatter->data("format") if ($attrFormat eq "");

    # get search results
    my $search = doSEARCH( $attrWeb, $params, $formatter );

    #SL: from here we parse the result of the SEARCH to build up our true
    # I really don't like the way that algorithm was written though. It very confusing and hard to maintain
    # We should really loop twice trough all topics:
    #    first time to build up node objects
    #    second time to create parent/child association
    # Doing that would also most certainly remove the need for that cycle stuff in the end for web tree.
    # It will also allow us to fix/control that issue with blank line separating _orphans trees from the main tree_       

    my %nodes = ();
    my $root = getTWikiNode( $RootLabel, \%nodes );    # make top dog node

    # loop thru topics
    foreach ( split /\n/, $search ) {
        #my ( $topic, $modTime, $author, $summary ) = #SL: was
        my ( $nodeWeb, $nodeTopic, $nodeFormat ) = split /\|/;    # parse out node data
        my $nodeId = "$nodeWeb.$nodeTopic";
    
        #If no node format default to the formatter's format     
        if (!$nodeFormat) {$nodeFormat=$formatter->data("format");}

        #Get parent
        #SL: We could get the parent from the SEARCH
        #I wonder if that would give us any performance gain
        #...since we would need to make the scope="text" 
        my $parentId = getParentId($nodeWeb,$nodeTopic);
        my $parent = (defined $parentId) ? getTWikiNode( $parentId, \%nodes )    # yes i have a parent, get it
          : $root;       # otherwise root's my parent
       
        # create my node (or if it's already created get it)
        my $node = getTWikiNode( $nodeId, \%nodes );
        
        $node->data( "web",     $nodeWeb );
        $node->data( "topic",   $nodeTopic );
        #Set the format for this node as it came back from the SEARCH
        $node->data( "format",  "$nodeFormat\n" ); #SL: new

        $node->data( "parent", $parent );
        $parent->add_child($node);    # hook me up
    }

    return "<!-- No Topic -->"
      unless $nodes{$rootTopicId};      # nope, the wanted node ain't here

    $root->name(" ");    # change root's name so it don't show up, hack

    # format the tree & parse TWiki tags and rendering
    my $renderedTree = "";
    if ( $rootTopicId ne $RootLabel ) {
        #SL: was using TWiki::Func::expandCommonVariables
        #SL:  should be nod need to expand common variable anymore here, thanks to doSEARCH
        $renderedTree = $attrHeader . $nodes{$rootTopicId}->toHTMLFormat($formatter);
    }
    else {
        # no starting topic given so do all topics
        #SL:  should look at the cycle stuff, that's probably causing the blank line when root topic is not found, should be optional 
        my %rootnodes = %{ _findRootsBreakingCycles( \%nodes ) };
        foreach my $i ( sort keys(%rootnodes) ) {
            #SL: was using TWiki::Func::expandCommonVariables, no need now as it was done by doSEARCH
            $renderedTree .= $attrHeader . $rootnodes{$i}->toHTMLFormat($formatter)
        }
    }

    #$renderedTree = $AGdebugmsg . $renderedTree;
    $renderedTree =
        "<div class=\"treePlugin\">"
      . $renderedTree
      . "</div><!--//treePlugin-->";

    #SL: Substitute $index in the rendered tree, $index is most useful to implement menus in combination with TreeBrowserPlugin
    #SL Later: well actually TreeBrowserPlugin now supports =autotoggle= so TreeBrowserPlugin can get away without using that $index in most cases.
    if ( defined $formatter->data("format") ) {
        my $Index = 0;
        $renderedTree =~ s/\$Index/$Index++;$Index/egi;
    }

    return $renderedTree;
}

=pod
Get a TWiki::Plugins::TreePlugin::TWikiNode object from the given hash
Create a new one if not found.
@param [in] scalar node id
@param [in] scalar hash reference
@return Pointer to TWiki::Plugins::TreePlugin::TWikiNode object
=cut

sub getTWikiNode {
    my ( $name, $hash ) = @_;
    my $node = $hash->{$name};    # look for node
    if ( !$node ) {               # create if not there
        $node = TWiki::Plugins::TreePlugin::TWikiNode->new($name);
        $hash->{$name} = $node;
    }
    return $node;
}

=pod

=cut

sub getParentId {
    my ($aWeb, $aTopic) = @_;
    my ( $meta, $text ) = &TWiki::Func::readTopic( $aWeb, $aTopic );
    my $ref = $meta->get("TOPICPARENT");
    return undef unless (defined $ref); 
    #my %par = (defined $ref ? %$ref : ()); #cast
    my $parent = $ref->{'name'};
    return undef unless (defined $parent); #Handle the case where META:TOPICPARENT does not specify a name !?!
    #Now deal with the case where we have no web specified in the parent Codev.GetRidOfTheDot
    unless ($parent=~/.+\.+/) #unless web.topic format
        {
        #Prepend the web 
        $parent="$aWeb.$parent"; 
        }
    return $parent;
}


=pod
Just do a %SEARCH%

given attribute and formatter
returns \n-seperated list of topics,
each topic line is composed of
topicname|modtime|author|summary (if applicable)

@param [in] scalar. The web to search for.
@param [in] hash reference. The tag parameters.
@param [in] reference to a formatter object.
@return The output of our %SEARCH%
=cut

sub doSEARCH {
    my ( $attrWeb, $params, $formatter ) = @_;

    my $excludetopic=$params->{'excludetopic'} || "";

    my $searchVal   = ".*";
    my $searchScope = "topic";

    my $searchWeb = ($attrWeb) ? $attrWeb : "all";

    #We build up our SEARCH format parameter
    #   * First comes our topic identifier 
    #   * Next comes our topic format
    my $searchTmpl = "\$web|\$topic";
    $searchTmpl .= "|" . $params->{'format'};
    
    #	ok. make the topic list and return it  (use this routine for now)
    #   hopefully there'll be an optimized one later    
    my $search="%SEARCH{search=\"$searchVal\" web=\"$searchWeb\" format=\"$searchTmpl\" scope=\"$searchScope\" regex=\"on\" nosearch=\"on\" nototal=\"on\" noempty=\"on\" excludetopic=\"$excludetopic\"}%";
    &TWiki::Func::writeDebug($search) if $debug;    

    return TWiki::Func::expandCommonVariables($search);
}



sub getLinkName {
    my ( $node ) = @_;
    return $node->name(); # SL: just return the name which is in fact the id now in format web.topic    
    #return $node->name() unless $node->data("web");
    #return $node->data("web") . "." . $node->data('topic');
}

sub _findRootsBreakingCycles {
    my ($hashMappingNamesToNodes) = @_;
    my %roots = ();

    $AGdebugmsg = "";
    foreach my $i ( sort keys(%$hashMappingNamesToNodes) ) {
        my $ultimateParentNode =
          _findUltimateParentBreakingCycles( ${$hashMappingNamesToNodes}{$i} );
        $roots{ $ultimateParentNode->name() } = $ultimateParentNode;
    }

    return \%roots;
}

sub _findUltimateParentBreakingCycles {
    my $orignode       = shift;
    my $node           = $orignode;
    my %alreadyvisited = ();
    my $parent;
    while ( $parent = _findParent($node) ) {

        # break cycles
        if ( $alreadyvisited{ $parent->name() } ) {
            $AGdebugmsg = $AGdebugmsg
              . "pre-rm:"
              . $parent->toStringNonRecursive()
              . " <br \/>\n";
            $parent->remove_child($node);
            $AGdebugmsg = $AGdebugmsg
              . "post-rm:"
              . $parent->toStringNonRecursive()
              . " <br \/>\n";
            $AGdebugmsg = $AGdebugmsg
              . $parent->name() . "<-"
              . $node->name()
              . " \n<br \/>\n";
            my $cycleroot =
              TWiki::Plugins::TreePlugin::TWikiNode->new(
                $parent->name() . " cycle..." );
            my $cycleleaf =
              TWiki::Plugins::TreePlugin::TWikiNode->new(
                $node->name() . " ...cycle" );
            $node->data( "parent", $cycleroot );
            $cycleroot->add_child($node);
            $parent->add_child($cycleleaf);

            # TBD: give some indication of cycle broken
            return $cycleroot;
        }
        else {
            $alreadyvisited{ $parent->name() } = 1;
        }

        # move up
        $node = $parent;
    }
    $AGdebugmsg = $AGdebugmsg
      . "findUltimateParent("
      . $orignode->name() . ")" . "="
      . $node->name() . "<br \/>";
    return $node;
}

sub _findParent {
    my $node = shift;
    $AGdebugmsg = $AGdebugmsg
      . "findParent("
      . $node->name() . ")" . "="
      . ( $node->data("parent") ? $node->data("parent")->name() : "no-parent" )
      . "<br \/>";
    return $node->data("parent");
}

# lazy variable init
# ned to abstract this at some point

sub setFormatter {
    my ($name) = @_;

    # my $formatter = $FormatMap{$name};
    # return $formatter if $formatter;
    my $formatter;

    # -- look up how to do case in Perl! :) SL: lol, I have no idea myself
    if ( $name eq "ullist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::ListNodeFormatter( "<ul> ",
            " </ul>" );
    }
    elsif ( $name =~ m/coloroutline(.*)/ ) {
        my $attrs = $1;
        $attrs =~ s/^://;
        $formatter = new TWiki::Plugins::TreePlugin::ColorNodeFormatter($attrs);
    }
    elsif ( $name =~ m/imageoutline(.*)/ ) {
        my $attrs = $1;
        $attrs =~ s/^://;
        $formatter =
          new TWiki::Plugins::TreePlugin::ImgNodeFormatter(
            split( /:/, $attrs ) );
    }
    elsif ( $name eq "ollist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::ListNodeFormatter( "<ol> ",
            " </ol>" );
    }
    elsif ( $name eq "hlist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::HOutlineNodeFormatter(
            "<h\$level> \$outnum \$web.\$topic </h\$level> \$summary");
    }
    else {
        $name = "outline";
        $formatter =
          new TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter(
            "\$outnum \$web.\$topic <br \/>");
    }

    # remember and return
    return $formatter;

    # $FormatMap{$name} = $formatter;
}





1;
