
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
  $web $topic $user $installWeb $VERSION $debug $INTREE
  %FormatMap $RootLabel $AGdebugmsg
);

$VERSION = '0.9';

$RootLabel =
  "_RootLabel_";    # what we use to label the root of a tree if not a topic

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between TreePlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "TreePlugin_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("TreePlugin_DEBUG");

    &TWiki::Func::writeDebug("installWeb: $installWeb") if $debug;

    my $cgi = &TWiki::Func::getCgiQuery();
    if ( !$cgi ) {
        return 0;
    }
    
    TWiki::Func::registerTagHandler( 'TREEVIEW', \&HandleTreeTag );
    TWiki::Func::registerTagHandler( 'TREE', \&HandleTreeTag );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TreePlugin::initPlugin( $web.$topic ) is OK")
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
    my($session, $params, $topic, $web) = @_;    

    my $cgi   = &TWiki::Func::getCgiQuery();
    my $plist = $cgi->query_string();
    $plist .= "\&" if $plist;
    my $CurrUrl = $cgi->url . $cgi->path_info() . "?" . $plist;

    # $CurrUrl =~ s/\&/\&amp;/go;

    my $attrWeb = $params->{'web'} || $web || "";
    my $attrTopic = $params->{'topic'} || $RootLabel;    # ie, do all web, needs to be nonempty

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
    if (($attrTopic eq $RootLabel) && ($attrStartlevel==-1)) { $attrStartlevel=1; } #
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
    my $search = _getSearchString( $attrWeb, $params, $formatter );

    my %nodes = ();
    my $root = _findTWikiNode( $RootLabel, \%nodes );    # make top dog node

    # loop thru topics
    foreach ( split /\n/, $search ) {
        #my ( $topic, $modTime, $author, $summary ) = #SL: was
        my ( $topic, $format ) =
          split /\|/;    # parse out data
    
        #If no node format default to the formatter's format     
        if (!$format) {$format=$formatter->data("format")}

        # get parent
        my ( $meta, $text ) = &TWiki::Func::readTopic( $attrWeb, $topic );

        my $ref = 0;
        if ( $TWiki::Plugins::VERSION < 1.1 ) {
            $ref = $meta->findOne("TOPICPARENT");
        }
        else {
            $ref = $meta->get("TOPICPARENT");
        }

        my %par = ( defined $ref ? %$ref : () );
        my $parent = (%par)
          ? _findTWikiNode( $par{'name'},
            \%nodes )    # yes i have a parent, get it
          : $root;       # otherwise root's my parent

        # create my node (or if it's already created get it)
        my $node = _findTWikiNode( $topic, \%nodes );
        

        #$node->data( "web",     $attrWeb );
        #Set the format for this node as it came back from the SEARCH
        $node->data( "format",  "$format\n" ); #SL: new


        # big memory items, only save if need to
        if ( $formatter->data("fullSubs") ) {
            #$node->data( "summary", $summary );
            $node->data( "text",    $text );
            $node->data( "meta",    $meta );
        }
        $node->data( "parent", $parent );
        $parent->add_child($node);    # hook me up
    }

    return "<!-- No Topic -->"
      unless $nodes{$attrTopic};      # nope, the wanted node ain't here

    $root->name(" ");    # change root's name so it don't show up, hack

    # format the tree & parse TWiki tags and rendering
    my $renderedTree = "";
    if ( $attrTopic ne $RootLabel ) {

        # running from a given topic
        $renderedTree =
          TWiki::Func::expandCommonVariables(
            $attrHeader . $nodes{$attrTopic}->toHTMLFormat($formatter),
            $attrTopic, $attrWeb );
    }
    else {

        # no starting topic given so do all topics
        my %rootnodes = %{ _findRootsBreakingCycles( \%nodes ) };
        foreach my $i ( sort keys(%rootnodes) ) {
            $renderedTree .=
              TWiki::Func::expandCommonVariables(
                $attrHeader . $rootnodes{$i}->toHTMLFormat($formatter),
                $attrTopic, $attrWeb );
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


# given attribute and formatter
# returns \n-seperated list of topics,
# each topic line is composed of
#        topicname|modtime|author|summary (if applicable)

sub _getSearchString {
    my ( $attrWeb, $params, $formatter ) = @_;

    my $excludetopic=$params->{'excludetopic'} || "";

    my $searchVal   = ".*";
    my $searchScope = "topic";

    my $searchWeb = ($attrWeb) ? $attrWeb : "all";

    #We build up our SEARCH format parameter
    #   * First comes our topic identifier 
    #   * Next comes our topic format
    my $searchTmpl = "\$topic"; #SL: shall we $web.$topic instead ? Mmmmn maybe not
    $searchTmpl .= "|" . $params->{'format'};
    
    #	ok. make the topic list and return it  (use this routine for now)
    #   hopefully there'll be an optimized one later    
    return TWiki::Func::expandCommonVariables(
"%SEARCH{search=\"$searchVal\" web=\"$searchWeb\" format=\"$searchTmpl\" scope=\"$searchScope\" regex=\"on\" nosearch=\"on\" nototal=\"on\" noempty=\"on\" excludetopic=\"$excludetopic\"}%"
    );

}



sub getLinkName {
    my ( $node ) = @_;
    return $node->name() unless $node->data("web");
    return $node->data("web") . "." . $node->name();
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

    # -- look up how to do case in Perl! :)
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

# TBD: so far as I can tell, the code below is mis-commented.
# It is not finding a child of a node via the lookup;
# instead, it is finding an entry for the node itself.
sub _findTWikiNode {
    my ( $name, $hash ) = @_;
    my $node = $hash->{$name};    # look for node
    if ( !$node ) {               # create if not there
        $node = TWiki::Plugins::TreePlugin::TWikiNode->new($name);
        $hash->{$name} = $node;
    }
    return $node;
}

1;
