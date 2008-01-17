=pod

---+ package FamilyTreePlugin

Copyright (C) Crawford Currie 2005 http://c-dot.co.uk

=cut

package TWiki::Plugins::FamilyTreePlugin;

use strict;

use vars qw( $VERSION $RELEASE $pluginName $debug $exampleCfgVar $node );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4';

$pluginName = 'FamilyTreePlugin';  # Name of this Plugin

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'MANCESTORS', \&_MANCESTORS );
    TWiki::Func::registerTagHandler( 'FANCESTORS', \&_FANCESTORS );
    TWiki::Func::registerTagHandler( 'DESCENDANTS', \&_DESCENDANTS );
    TWiki::Func::registerTagHandler( 'GRDESCENDANTS', \&_GRDESCENDANTS );

    return 1;
}

# Handle the %MANCESTORS% tag
sub _MANCESTORS {
    my($session, $params, $topic, $web) = @_;

    my $to = $params->{_DEFAULT};
    my @stack;
    my $wife = '';

    return "Bad parameters" unless( $to );

    while( my $parents = _getParents( $to )) {

        my $col = ' <strong> '.$to .' </strong> '.$wife.' <br /> ';

        my $sibs = _getSiblings( $parents, $to );
        $col .= join(' <br /> ', @$sibs);

        $wife = 'm. '. _getFemale( $parents );
        $to = _getMale( $parents );

        unshift( @stack, $col );
    }
    unshift( @stack, ' <strong> '.$to.' </strong> '.$wife );

    my $row = CGI::Tr( join('',
                            map{ CGI::td({ valign=>'top' }, $_) }
                              @stack ));
    return CGI::table( {border=>1}, $row );
}

# Handle the %FANCESTORS% tag
sub _FANCESTORS {
    my($session, $params, $topic, $web) = @_;

    my $to = $params->{_DEFAULT};
    my @stack;
    my $husband = '';

    return "Bad parameters" unless( $to );

    while( my $parents = _getParents( $to )) {

        my $col = ' <strong> '.$to .' </strong> '.$husband.' <br /> ';

        my $sibs = _getSiblings( $parents, $to );
        $col .= join(' <br /> ', @$sibs);

        $husband = 'm. '. _getMale( $parents );
        $to = _getFemale( $parents );

        unshift( @stack, $col );
    }
    unshift( @stack, ' <strong> '.$to.' </strong> '.$husband );

    my $row = CGI::Tr( join('',
                            map{ CGI::td({ valign=>'top' }, $_) }
                              @stack ));
    return CGI::table( {border=>1}, $row );
}

# Handle the %DESCENDANTS% tag
sub _DESCENDANTS {
    my($session, $params, $topic, $web) = @_;

    my $to = $params->{_DEFAULT} || $topic;

    return _expandDescendants( $to );
}

# Handle the %GRDESCENDANTS% tag
#  - Graph the descendants using GraphViz - DirectedGraphPlugin
# 
sub _GRDESCENDANTS {
    my($session, $params, $topic, $web) = @_;

    my $to = $params->{_DEFAULT} || $topic;
    my $engine = $params->{engine} || "dot";
    my $raw = $params->{raw} || 0;
    my $orient = $params->{orientation} ;
    my $ranksep = $params->{ranksep} || ".25";
    my $nodesep = $params->{nodesep} || ".25";
    my $size = $params->{size} ;

    my $lt = "<";
    if ($raw == 1) {$lt = "&lt;";}

    $node = 0;  # Counter for unnamed nodes (no issue) 

    my $nodeURL = TWiki::Func::getScriptUrl( $web, "X", "view" );
    chop($nodeURL);
    
    my  $gdPrefix .= $lt . "dot map=1 vectorformats=\"ps\" engine=\"$engine\" >\n";
	$gdPrefix .= "    digraph G { \n";
	$gdPrefix .= "       orientation=\"$orient\"\n" if $orient;
	$gdPrefix .= "       size = \"$size\"; \n" if $size;  #Graph size in width,high
	#$gdPrefix .= "       page = \"8.5,11\"; \n";  # Used to set multi-page PS output - breaks png output
	$gdPrefix .= "       ranksep=\"$ranksep\"; nodesep=\"$nodesep\";\n";        
	$gdPrefix .= "       node [URL=\"" . $nodeURL . "\\N\" ];\n";

    my $gdSuffix = "}\n </dot>\n ";

    return $gdPrefix . _graphDescendants( $to ) . $gdSuffix;
    #return "<verbatim>" . $gdPrefix . _graphDescendants( $to ) . $gdSuffix . "</verbatim>";
}


# Generate a table representing all descendants of $who
sub _graphDescendants {
    my $who = shift;

    my $marriages = _getMarriages( $who );

    my $martable = '';
    foreach my $marriage ( @$marriages ) {
        $martable .= "$who -> $marriage [arrowhead=\"none\"];\n";
        my $kids = _getOffspring( $marriage );
        my $childs = '';
        my $cs = 1;
        if(scalar(@$kids)) {
            foreach my $issue ( @$kids ) {
	        $martable .= "$marriage -> $issue [arrowhead=\"none\"];\n";
                $childs .=  _graphDescendants( $issue );
            }
            $cs = scalar(@$kids);
        } else {
	    $node++;
            $childs = "$marriage -> n$node [arrowhead=\"none\", style=\"dotted\"]";
	    $childs .= "n$node [shape=plaintext,label=\"no issue\",fontname=\"Helvetica-Oblique\"];\n"; 
	    }
   
        my $m1 = "%SPACEOUT{" . _getMale( $marriage ) . "}% m. %SPACEOUT{" . _getFemale( $marriage ) . "}%" ;

	my $mdate = TWiki::Func::expandCommonVariables( '%FORMFIELD{"Date" topic="'.$marriage.'"}%');
	my $m3 = TWiki::Func::expandCommonVariables( '%FORMFIELD{"Disolved" topic="'.$marriage.'"}%');
	if (length($m3) > 1) {   $mdate .= " - " . $m3 ;}
	$m3 = TWiki::Func::expandCommonVariables( '%FORMFIELD{"Cause" topic="'.$marriage.'"}%');
	if (length($m3) > 1) {   $mdate .= " (" . $m3 . ")" ;}

        if (length($mdate) > 1) { $mdate = "\\n " . $mdate; }
	
	my $m = " $marriage [shape=plaintext,label=\"$m1$mdate\" ];\n";
         
        $martable .=  $m . $childs;
    }
    my $w = $who . "[shape=record,label=\"%SPACEOUT{$who}%" ;
    $w .= "\\l b. %FORMFIELD{\"Born\" topic=\"$who\"}%";
    $w .= "\\l d. %FORMFIELD{\"Died\" topic=\"$who\"}%\\l\" ];\n";
    return  $w .
       $martable ;
}


# Generate a table representing all descendants of $who
sub _expandDescendants {
    my $who = shift;

    my $marriages = _getMarriages( $who );

    my $martable = '';
    foreach my $marriage ( @$marriages ) {
        my $kids = _getOffspring( $marriage );
        my $childs = '';
        my $cs = 1;
        if(scalar(@$kids)) {
            foreach my $issue ( @$kids ) {
                $childs .= CGI::td(
                    _expandDescendants( $issue ));
            }
            $cs = scalar(@$kids);
        } else {
            $childs = CGI::td(CGI::em('no issue'));
        }
        my $m = "[[$marriage][%SPACEOUT{$marriage}%]]";
        $m .= CGI::br().CGI::em('%FORMFIELD{"Date" topic="'.$marriage.'"}%');
        $martable .= CGI::td(
            CGI::table( {style => 'border:none;'},
                CGI::Tr(CGI::td({colspan=>$cs, align=>'center'}, $m)).
                CGI::Tr({valign=>'top' },$childs)));
    }
    my $w = CGI::strong("[[$who][%SPACEOUT{$who}%]]");
    $w .= CGI::br().CGI::em('b. %FORMFIELD{"Born" topic="'.$who.'"}%');
    $w .= CGI::br().CGI::em('d. %FORMFIELD{"Died" topic="'.$who.'"}%');
    $w = CGI::table( {style => 'border: dotted thin green; width:auto'},
                     CGI::Tr(CGI::td($w)) );
    return CGI::table({  },
      CGI::Tr({valign=>'top' },
              CGI::td({align=>'center',
                       colspan=>scalar(@$marriages)}, $w)).
      CGI::Tr({valign=>'top' }, $martable ));
}

# Find out who $who married
sub _getMarriages {
    my $who = shift;
    my $list = TWiki::Func::expandCommonVariables(
        '%SEARCH{ "(^'.$who.'X|X'.$who.'$)"
                  type="regex"
                  format="$topic"
                  multiple="on"
                  scope="topic"
                  nonoise="on"
                  separator=","}%');
    my @names = split(/,/, $list);
    return \@names;
}

# Get the name of the union record that $of is logged as the issue of
sub _getParents {
    my $of = shift;

    # Establish the main line of descent
    my $parents = TWiki::Func::expandCommonVariables(
        '%SEARCH{ "\| '.$of.' \|"
         type="regex"
         format="$topic"
         header=""
         nonoise="on"}%' );
    return $parents;
}

# Get the value of the "Male" field from a union record
sub _getMale {
    my $of = shift;

    return TWiki::Func::expandCommonVariables(
        '%FORMFIELD{"Male" topic="'.$of.'"}%');
}

# Get the value of the "Female" field from a union record
sub _getFemale {
    my $of = shift;

    return TWiki::Func::expandCommonVariables(
        '%FORMFIELD{"Female" topic="'.$of.'"}%');
}

# Get the siblings of a person record, as an array ref
sub _getSiblings {
    my( $parents, $child ) = @_;

    my $kids = _getOffspring( $parents );
    my @names = grep { !/^$child$/ } @$kids;
    return \@names;
}

# Get all the offspring of a union, as an array ref
sub _getOffspring {
    my $marriage = shift;
    my $list = TWiki::Func::expandCommonVariables(
        '%SEARCH{ "^\| [A-Z][A-Za-z0-9]+ \|.?$"
         type="regex"
         topic="'.$marriage.'"
         multiple="on"
         format="$text"
         separator="|"
         header=""
         nonoise="on"}%' );
    my @names = grep { $_ } map { s/\s+//g; $_ } split(/\|/, $list);
    return \@names;
}

1;
