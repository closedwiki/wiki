
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
  %FormatMap $RootLabel
);

$VERSION = '0.7';

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

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TreePlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

#&TWiki::Func::writeDebug( "- TreePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    #$_[0] =~ s/%CREATECHILD%/&handleCreateChildInput(0, $_[2])/geo;
    #$_[0] =~ s/%CREATECHILD{(.*?)}%/&handleCreateChildInput($1, $_[2])/geo;
    $_[0] =~ s/%TREEVIEW%/&handleTreeView($_[1], $_[2], "")/geo;
    $_[0] =~ s/%TREEVIEW{(.*?)}%/&handleTreeView($_[1], $_[2], $1)/geo;

}

# given attribute and formatter
# returns \n-seperated list of topics,
# each topic line is composed of
#        topicname|modtime|author|summary (if applicable)

sub _getSearchString {
    my ( $attrWeb, $attributes, $formatter ) = @_;

    my $attrForm = TWiki::Func::extractNameValuePair( $attributes, "form" )
      || "";

    my $searchVal   = ".*";
    my $searchScope = "topic";

    #	not functioning
    #    if ($attrForm) {
    #    	$searchVal = "%META:FORM\{.*name=\\\"$attrForm\\\"\}%";
    #    	$searchScope = "text";
    #    }

    my $searchWeb = ($attrWeb) ? $attrWeb : "all";
    my $searchTmpl = "\$topic|%TIME%|%AUTHOR%";

    # optimization: remember not to save heavy memory values
    if (   $formatter->data("format")
        && $formatter->data("format") =~ m/\$(summary|text)/ )
    {
        $formatter->data( "fullSubs", 1 );
        $searchTmpl .= "|\$summary";
    }

    #	ok. make the topic list and return it  (use this routine for now)
    #   hopefully there'll be an optimized one later

    return TWiki::Func::expandCommonVariables(
"%SEARCH{search=\"$searchVal\" web=\"$searchWeb\" format=\"$searchTmpl\" scope=\"$searchScope\" regex=\"on\" nosearch=\"on\" nototal=\"on\" noempty=\"on\"}%"
    );

}

# bugs re recursion:
#	1) doesn't remember webs so: recursion across webs is problematic
#	2) if two topics with identical names in different webs AND
#		both have a TREEVIEW tag -> the second will be excluded

$AGdebugmsg = "<br>AG debug message<br>";

# bugs re recursion:
#	1) doesn't remember webs so: recursion across webs is problematic
#	2) if two topics with identical names in different webs AND
#		both have a TREEVIEW tag -> the second will be excluded

sub handleTreeView {
    my ( $topic, $web, $attributes ) = @_;

    my $cgi   = &TWiki::Func::getCgiQuery();
    my $plist = $cgi->query_string();
    $plist .= "\&" if $plist;
    $CurrUrl = $cgi->url . $cgi->path_info() . "?" . $plist;

    # $CurrUrl =~ s/\&/\&amp;/go;

    my $attrWeb = TWiki::Func::extractNameValuePair( $attributes, "web" )
      || $web
      || "";
    my $attrTopic = TWiki::Func::extractNameValuePair( $attributes, "topic" )
      || $RootLabel;    # ie, do all web, needs to be nonempty
    cgiOverride( \$attrWeb,        "treeweb" );
    cgiOverride( \$attrTopic,      "treetopic" );
    cgiOverride( \$attrFormatting, "formatting" );

    # we've expanded TREESEARCH on this topic before, we won't repeat
    #	return "<!-- Self-recursion -->" if ($TreeTopics{$topic});

    #    # global hash, record this object and attrTopic too (as initial seed)
    #    $TreeTopics{$topic} = 1;
    #	$TreeTopics{$attrTopic} = 1;

    my $attrHeader =
        "<div class=\"treePluginHeader\"> "
      . TWiki::Func::extractNameValuePair( $attributes, "header" )
      . " </div><!--//treePluginHeader-->" || "";
    $attrHeader .= "\n" if ($attrHeader);    # to enable |-tables formatting
    my $attrFormat = TWiki::Func::extractNameValuePair( $attributes, "format" )
      || "";
    $attrFormat .= "\n" if ($attrFormat);    # to enable |-tables formatting
    my $attrFormatBranch =
      TWiki::Func::extractNameValuePair( $attributes, "formatbranch" ) || "";
    my $attrFormatting =
      TWiki::Func::extractNameValuePair( $attributes, "formatting" ) || "";
    my $attrStartlevel =
      TWiki::Func::extractNameValuePair( $attributes, "startlevel" ) || 0;
    my $attrStoplevel =
      TWiki::Func::extractNameValuePair( $attributes, "stoplevel" ) || 999;
    my $doBookView =
      TWiki::Func::extractNameValuePair( $attributes, "bookview" ) || "";
    my $attrLevelPrefix =
      TWiki::Func::extractNameValuePair( $attributes, "levelprefix" ) || "";
    cgiOverride( \$attrFormatting, "formatting" );

    # set the type of formatting
    my $formatter = setFormatter($attrFormatting);

    $formatter->data( "startlevel", $attrStartlevel );
    $formatter->data( "stoplevel",  $attrStoplevel );
    $formatter->data( "url",        $CurrUrl );

    # if bookView, read bookview file as format
    if ($doBookView) {
        $formatter->data( "format", &TWiki::Func::readTemplate("booktree") );
    }
    else {

        # else set the format(s), if any
        $formatter->data( "format", $attrFormat ) if ($attrFormat);
        $formatter->data( "branchformat", $attrFormatBranch )
          if ($attrFormatBranch);
        $formatter->data( "levelprefix", $attrLevelPrefix )
          if ($attrLevelPrefix);
    }

    # get search results
    my $search = _getSearchString( $attrWeb, $attributes, $formatter );

    my %nodes = ();
    my $root = _findTWikiNode( $RootLabel, \%nodes );    # make top dog node

    # loop thru topics
    foreach ( split /\n/, $search ) {
        my ( $topic, $modTime, $author, $summary ) =
          split /\|/;    # parse out data

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
          ? _findTWikiNode( $par{"name"},
            \%nodes )    # yes i have a parent, get it
          : $root;       # otherwise root's my parent

        # create my node (or if it's already created get it)
        my $node = _findTWikiNode( $topic, \%nodes );

        $node->data( "author",  $author );
        $node->data( "web",     $attrWeb );
        $node->data( "modTime", $modTime );

        # big memory items, only save if need to
        if ( $formatter->data("fullSubs") ) {
            $node->data( "summary", $summary );
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
    if ( defined $formatter->data("format") ) {
        my $Index = 0;
        $renderedTree =~ s/\$Index/$Index++;$Index/egi;
    }

    return $renderedTree;
}

sub getLinkName {
    my ( $node, $level ) = @_;
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
    while ( $parent = _findParent($node) ) {

        # break cycles
        if ( $alreadyvisited{ $parent->name() } ) {
            $AGdebugmsg = $AGdebugmsg
              . "pre-rm:"
              . $parent->toStringNonRecursive()
              . " <br>\n";
            $parent->remove_child($node);
            $AGdebugmsg = $AGdebugmsg
              . "post-rm:"
              . $parent->toStringNonRecursive()
              . " <br>\n";
            $AGdebugmsg = $AGdebugmsg
              . $parent->name() . "<-"
              . $node->name()
              . " \n<br>\n";
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
      . $node->name() . "<br>";
    return $node;
}

sub _findParent {
    my $node = shift;
    $AGdebugmsg = $AGdebugmsg
      . "findParent("
      . $node->name() . ")" . "="
      . ( $node->data("parent") ? $node->data("parent")->name() : "no-parent" )
      . "<br>";
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

# use cgi var to override given variable ref

sub cgiOverride {
    my $variable  = shift;
    my $paramname = shift;

    my $cgi = &TWiki::Func::getCgiQuery();
    if ( !$cgi ) {
        return;
    }
    else {
        my $tmp = $cgi->param($paramname);
        $$variable = $tmp if ($tmp);
    }
}

# allow other classes to see the installation web
sub installWeb {
    return $installWeb;
}

sub handleCreateChildInput {
    my ( $args, $web ) = @_;

    my ( $addtext, $meta, $text );

    if ( TWiki::Func::topicExists( $web, "AddUnder" ) ) {
        ( $meta, $addtext ) = &TWiki::Func::readTopic( $web, "AddUnder" );
    }

    # need to reread to get the meta of this topic
    ( $meta, $text ) = &TWiki::Func::readTopic( $web, $topic );

    # change meta according to new attributes (reuse $meta for object props)
    if ($args) {
        $meta = setMetaFromAttr( $meta, $args );
    }

    # put in fields data (if this is going to be a form)

    my $formfields;

    # so: is new topic to have a form? if so, put in new fields

    my $ref = 0;
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        $ref = $meta->findOne("FORM");
    }
    else {
        $ref = $meta->get("FORM");
    }

    my %form = ( defined $ref ? %$ref : () );

    if (%form) {
        my $name = $form{"name"};
        $formfields = &TWiki::Form::getFieldParams($meta);
        my $forminput =
          "<input type=\"hidden\" name=\"formtemplate\" value=\"$name\" />";
        $addtext =~ s/%FORMINPUT%/$forminput/e;
    }
    else {
        $addtext =~ s/%FORMINPUT%//g;
    }

    $addtext =~ s/%ADDFORM%/$formfields/g;

    return $addtext;
}

# changes the passed meta, to the given fields value of the given args

sub setMetaFromAttr {
    my ( $meta, $args ) = @_;

    # no matter what, no inherited values in child's form
    if ( &TWiki::extractNameValuePair( $args, "resetform" ) ) {
        $meta->remove("FIELD");
        return $meta;
    }

    # get this form name
    my $ref = 0;
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        $ref = $meta->findOne("FORM");
    }
    else {
        $ref = $meta->get("FORM");
    }

    my %form = ( defined $ref ? %$ref : () );
    my $name = $form{"name"} if (%form) || "";

    # get new form name, if any
    my $newform = TWiki::extractNameValuePair( $args, "form" );

    # if newform & different, just set new form name (& delete all fields)
    if ( $newform && $newform ne $name ) {
        $meta->put( "FORM", ( "name" => $newform ) );
        $meta->remove("FIELD");
    }

    my $fields = TWiki::extractNameValuePair( $args, "fields" );

    # put in new fields into $meta

    # hash of fields
    my %f = map { split( /=/, $_ ) }
      grep { /[^\=]*\=[^\=]*$/ }
      split( /\s*,\s*/, $fields );

    foreach ( keys %f ) {
        my @a = ( "name" => $_, "value" => $f{$_} );
        $meta->put( "FIELD", @a );
    }

    return $meta;
}

1;
