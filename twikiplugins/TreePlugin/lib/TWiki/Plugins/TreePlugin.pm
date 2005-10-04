#
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

#use TWiki::Func;

use TWiki::Plugins::TreePlugin::TWikiNode;
use TWiki::Plugins::TreePlugin::ListNodeFormatter;
use TWiki::Plugins::TreePlugin::ColorNodeFormatter;
use TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::HOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::ImgNodeFormatter;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $INTREE
        %FormatMap %TreeTopics $RootLabel $cgi $CurrUrl
    );

$VERSION = '$Rev$';

$RootLabel = "_"; # what we use to label the root of a tree if not a topic


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between TreePlugin and Plugins.pm" );
        return 0;
    }

    $cgi = &TWiki::Func::getCgiQuery();

    &TWiki::Func::writeDebug( "installWeb: $installWeb" );
    
    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    # $exampleCfgVar = &TWiki::Func::getPreferencesValue( "TreePlugin_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "TreePlugin_DEBUG" );

	# mod_perl will have trouble because these three vals are globals
    %TreeTopics = ();
    if( ! $cgi ) {
        return 0;
    }
    my $plist = $cgi->query_string();
	$plist .= "\&" if $plist;
	$CurrUrl = $cgi->url . $cgi->path_info() . "?" . $plist;
    # $CurrUrl =~ s/\&/\&amp;/go;
    
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::TreePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
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
    my ($attrWeb, $attributes, $formatter) = @_;

    my $attrForm = TWiki::Func::extractNameValuePair( $attributes, "form" ) || "";

	my $searchVal = ".*";
	my $searchScope = "topic";

#	not functioning
#    if ($attrForm) {
#    	$searchVal = "%META:FORM\{.*name=\\\"$attrForm\\\"\}%";
#    	$searchScope = "text";
#    }

	my $searchWeb = ($attrWeb) ? $attrWeb : "all" ;
    my $searchTmpl = "\$topic|%TIME%|%AUTHOR%";

    # optimization: remember not to save heavy memory values
    if ($formatter->data("format") =~ m/\$(summary|text)/) {
		$formatter->data("fullSubs", 1);
		$searchTmpl .= "|\$summary";
    }
    
    #	ok. make the topic list and return it  (use this routine for now)
    #   hopefully there'll be an optimized one later

	return TWiki::Func::expandCommonVariables(	"%SEARCH{search=\"$searchVal\" web=\"$searchWeb\" format=\"$searchTmpl\" scope=\"$searchScope\" regex=\"on\" nosearch=\"on\" nototal=\"on\" noempty=\"on\"}%");

}

# bugs re recursion:
#	1) doesn't remember webs so: recursion across webs is problematic
#	2) if two topics with identical names in different webs AND
#		both have a TREEVIEW tag -> the second will be excluded

sub handleTreeView {
	my ($topic, $web, $attributes) = @_;
	

	
    my $attrWeb   = TWiki::Func::extractNameValuePair( $attributes, "web" ) || $web || "";
    my $attrTopic = TWiki::Func::extractNameValuePair( $attributes, "topic" ) || $RootLabel; # ie, do all web, needs to be nonempty
	cgiOverride(\$attrWeb, "treeweb");
	cgiOverride(\$attrTopic, "treetopic");
	cgiOverride(\$attrFormatting, "formatting");
	
	# we've expanded TRESEARCH on this topic before, we won't repeat
	return "<!-- Self-recursion -->"
    	if ($TreeTopics{$topic});

    # global hash, record this object and attrTopic too (as initial seed)
    $TreeTopics{$topic} = 1;
	$TreeTopics{$attrTopic} = 1;
	    
	my $attrHeader = TWiki::Func::extractNameValuePair( $attributes, "header" ) || "";
	$attrHeader .= "\n" if ($attrHeader); # to enable |-tables foramtting
	my $attrFormat = TWiki::Func::extractNameValuePair( $attributes, "format" ) || "";
	$attrFormat .= "\n" if ($attrFormat); # to enable |-tables formatting
	my $attrFormatBranch = TWiki::Func::extractNameValuePair( $attributes, "formatbranch" ) || "";
    my $attrFormatting = TWiki::Func::extractNameValuePair( $attributes, "formatting" ) || "";
    my $attrStoplevel = TWiki::Func::extractNameValuePair( $attributes, "stoplevel" ) || 999;
    my $doBookView = TWiki::Func::extractNameValuePair( $attributes, "bookview" ) || "";
	
	cgiOverride(\$attrFormatting, "formatting");
	
    # set the type of formatting
    my $formatter = setFormatter($attrFormatting);

    $formatter->data("stoplevel", $attrStoplevel);    
    $formatter->data("url", $CurrUrl);
    
    # if bookView, read bookview file as format
    if ($doBookView) {
		$formatter->data("format", &TWiki::Func::readTemplate( "booktree" ));
    } else {
    	# else set the format(s), if any
        $formatter->data("format", $attrFormat) if ($attrFormat);
	    $formatter->data("branchformat",$attrFormatBranch) if ($attrFormatBranch);
    }
    
    # get search results
    my $search = _getSearchString($attrWeb, $attributes, $formatter);

    my %nodes = ();
    my $root = _findTWikiNode($RootLabel, \%nodes);    # make top dog node
    
    # loop thru topics
    foreach (split /\n/, $search) {
        my ($topic, $modTime, $author, $summary) = split /\|/; # parse out data

		# get parent
        my( $meta, $text ) = &TWiki::Func::readTopic( $attrWeb, $topic );

        my %par;
        if(defined(&TWiki::Meta::findOne)) {
            %par = $meta->findOne( "TOPICPARENT" );
        } else {
            my $r = $meta->get( "TOPICPARENT" );
            next unless $r;
            %par = %{$r};
        }
        my $parent = ( %par )
             ?  _findTWikiNode($par{"name"}, \%nodes)    # yes i have a parent, get it
             : $root;                              # otherwise root's my parent

        # create my node (or if it's already created get it)
        my $node = _findTWikiNode($topic, \%nodes);
        
        $node->data("author", $author);
		$node->data("web", $attrWeb);
        $node->data("modTime", $modTime);
		
        # big memory items, only save if need to 
        if ( $formatter->data("fullSubs") ) {
                $node->data("summary", $summary);
                $node->data("text", $text);
                $node->data("meta", $meta);
        }
        $parent->add_child($node);                 # hook me up
    }
    
    return "<!-- No Topic -->" unless $nodes{$attrTopic}; # nope, the wanted node ain't here
    
    $root->name(" "); # change root's name so it don't show up, hack
    
    # format the tree & parse TWiki tags and rendering
    return TWiki::Func::expandCommonVariables(
    	$attrHeader.$nodes{$attrTopic}->toHTMLFormat($formatter),
        $attrTopic,
        $attrWeb);
}


# lazy variable init
# ned to abstract this at some point

sub setFormatter {
    my ($name) = @_;
    # my $formatter = $FormatMap{$name};
    # return $formatter if $formatter;
    my $formatter;
    
    # -- look up how to do case in Perl! :)
    if ($name eq "ullist") {
        $formatter = new TWiki::Plugins::TreePlugin::ListNodeFormatter("<ul> ", " </ul>");
    } elsif ($name =~ m/coloroutline(.*)/ ) {
    	my $attrs = $1;
    	$attrs =~ s/^://;
        $formatter = new TWiki::Plugins::TreePlugin::ColorNodeFormatter($attrs);    
    } elsif ($name =~ m/imageoutline(.*)/ ) {
    	my $attrs = $1;
    	$attrs =~ s/^://;
        $formatter = new TWiki::Plugins::TreePlugin::ImgNodeFormatter(split(/:/,$attrs));
    } elsif ($name eq "ollist") {
        $formatter = new TWiki::Plugins::TreePlugin::ListNodeFormatter("<ol> ", " </ol>");
    } elsif ($name eq "hlist") {
        $formatter = new TWiki::Plugins::TreePlugin::HOutlineNodeFormatter(
        	"<h\$level> \$outnum \$topic </h\$level> \$summary");
    } else {
        $name = "outline";
		$formatter = new TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter(
        	"\$outnum \$topic <br>");
    }
    
    # remember and return
    return $formatter;
    
    # $FormatMap{$name} = $formatter;
}


sub _findTWikiNode {
    my ($name, $hash) = @_;
    my $child = $hash->{$name}; # look for child
    if (! $child) {             # create if not there
        $child = TWiki::Plugins::TreePlugin::TWikiNode->new($name);
        $hash->{$name} = $child;
    }
    return $child;
}

# use cgi var to override given variable ref

sub cgiOverride {
    my $variable = shift;
    my $paramname = shift;
    
    my $tmp = $cgi->param( $paramname );
    $$variable = $tmp if( $tmp );
}

# allow other classes to see the installation web
sub installWeb {
    return $installWeb;
}

#sub handleCreateChildInput {
#	my ($args, $web) = @_;
#
#	my ($addtext, $meta, $text);
#
#	if( TWiki::Func::topicExists( $web, "AddUnder" ) ) {
#			( $meta, $addtext ) = &TWiki::Func::readTopic( $web, "AddUnder" );
#	}
#
#	# need to reread to get the meta of this topic
#	( $meta, $text ) = &TWiki::Func::readTopic( $web, $topic );
#
#	# change meta according to new attributes (reuse $meta for object props)
#	if ($args) {
#		$meta = setMetaFromAttr($meta, $args);
#	}
#
#	# put in fields data (if this is going to be a form)
#
#	my $formfields;
#
#	# so: is new topic to have a form? if so, put in new fields
#	my %form = $meta->findOne( "FORM" );
#	if( %form ) {
#		my $name = $form{"name"};
#		$formfields = &TWiki::Form::getFieldParams($meta);
#		my $forminput = "<input type=\"hidden\" name=\"formtemplate\" value=\"$name\" />";
#		$addtext =~ s/%FORMINPUT%/$forminput/e;
#	} else {
#		$addtext =~ s/%FORMINPUT%//g;
#	}
#
#	$addtext =~ s/%ADDFORM%/$formfields/g;
#
#	return $addtext;
#}
#
#
## changes the passed meta, to the given fields value of the given args
#
#sub setMetaFromAttr {
#	my ($meta, $args) = @_; 
#
#	# no matter what, no inherited values in child's form
#	if (&TWiki::Func::extractNameValuePair($args, "resetform")){
#		$meta->remove ("FIELD");
#		return $meta;
#	}
#
#	# get this form name
#	my %form = $meta->findOne( "FORM" );
#	my $name = $form{"name"} if ( %form ) || "";
#
#	# get new form name, if any
#	my $newform = TWiki::Func::extractNameValuePair($args, "form");
#
#	# if newform & different, just set new form name (& delete all fields)
#	if ($newform && $newform ne $name) {
#		$meta->put( "FORM", ( "name" => $newform) );
#		$meta->remove ("FIELD");
#	}
#
#	my $fields = TWiki::Func::extractNameValuePair($args, "fields");
#
#	# put in new fields into $meta
#
#	# hash of fields
#	my %f = map { split( /=/, $_ ) }
#		grep { /[^\=]*\=[^\=]*$/ }
#		split (/\s*,\s*/, $fields) ;
#
#	foreach (keys %f) {
#		my @a = ( "name" =>  $_, "value" => $f{$_} );
#		$meta->put( "FIELD", @a );
#	}
#
#	return $meta;
#}

1;
