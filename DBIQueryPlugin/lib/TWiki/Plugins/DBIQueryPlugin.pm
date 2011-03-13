# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Vadim Belman, voland@lflat.org
# Copyright (C) 2009 TWiki:Main.ThomasWeigert
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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

package TWiki::Plugins::DBIQueryPlugin;
use strict;
#use Data::Dumper;
#use Digest::MD5 qw(md5_hex);
use DBI;
use Error qw(:try);
use CGI qw(:html2);
use Carp qw(longmess);

use TWiki::Contrib::DatabaseContrib;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $pluginVersion
        $debug $allowDbiDo $maxRecursionLevel
	$query_id %queries %subquery_map
	$protectStart $protectEnd
    );

$VERSION = '$Rev$';
$RELEASE = '2011-03-13';
$pluginVersion = '1.3';

$pluginName = 'DBIQueryPlugin';
$query_id = 0;
$protectStart = '!&lt;ProtectStart&gt;';
$protectEnd = '!&lt;ProtectEnd&gt;';

# =========================

sub message_prefix
{
    my @call = caller(2);
    my $line = (caller(1))[2];
    return "- " . $call[3] . "( $web.$topic )\:$line ";
}

sub warning(@)
{
    return TWiki::Func::writeWarning( message_prefix() . join("", @_) );
}

sub dprint(@)
{
    return TWiki::Func::writeDebug( message_prefix() . join("", @_) ) if $debug;
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.000 ) {
        warning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $maxRecursionLevel = 100;

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DBIQUERYPLUGIN_DEBUG");
    $Error::Debug = $debug;

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    #$allowDbiDo = TWiki::Func::getPluginPreferencesValue( "ALLOW_DBI_DO" ) || "TWikiAdminGroup";

    # Plugin correctly initialized
    dprint "initPlugin is OK";
    return 1;
}

# =========================

my $true_regex = qr/^(?:y(?:es)?|on|1|)$/i;

# {{{sub on_off
sub on_off
{
    return 1 if $_[0] && $_[0] =~ $true_regex;
}
# }}}

# {{{sub nl2br
sub nl2br
{
    $_[0] =~ s/\r?\n/\%BR\%/g;
    return $_[0];
}
# }}}

# {{{sub protectValue
sub protectValue
{
    my $val = shift;
    dprint "Before protecting: $val\n";
    $val =~ s/(.)/\.$1/gs;
    $val =~ s/\\(n|r)/\\\\$1/gs;
    $val =~ s/\n/\\n/gs;
    $val =~ s/\r/\\r/gs;
    $val = escapeHTML($val);
    dprint "After protecting: $val\n";
    return "${protectStart}${val}${protectEnd}";
}
# }}}

# {{{sub unprotectValue
sub unprotectValue
{
    my $val = shift;
    dprint "Before unprotecting: $val\n";
    my $cgiQuery = TWiki::Func::getCgiQuery();
    $val = $cgiQuery->unescapeHTML($val);
    $val =~ s/(?<!\\)\\n/\n/gs;
    $val =~ s/(?<!\\)\\r/\r/gs;
    $val =~ s/\\\\(n|r)/\\$1/gs;
    $val =~ s/\.(.)/$1/gs;
    dprint "After unprotecting: $val\n";
    return $val;
}
# }}}

# {{{sub query_params
sub query_params
{
    my $param_str = shift;

    my %params = TWiki::Func::extractParameters($param_str);
    my @list2hash = qw(unquoted protected multivalued);

    foreach my $param (@list2hash) {
	if (defined $params{$param}) {
	    $params{$param} = {
		map {$_ => 1} split " ", $params{$param}
	    };
	} else {
	    $params{$param} = {};
	}
    }

    return %params;
}
# }}}

# {{{sub newQID
sub newQID
{
    $query_id++;
    return "DBI_CONTENT$query_id";
}
# }}}

# {{{sub wikiErrMsg
sub wikiErrMsg
{
    return "<strong>\%RED\%<pre>" . join("", @_) . "</pre>\%ENDCOLOR\%</strong>";
}
# }}}

# {{{sub registerSubquery
sub registerQuery
{
    my ($qid, $params) = @_;
    if ($params->{subquery}) {
	$queries{$qid}{subquery} = $params->{subquery};
	$subquery_map{$params->{subquery}} = $qid;
	return "";
    }
    return "\%$qid\%";
}
# }}}

# {{{sub do_allowed
sub do_allowed
{
    my ($conname) = @_;
}
# }}}

# {{{sub storeDoQuery
sub storeDoQuery
{
    my ($param_str, $content) = @_;
    my %params;
    my $conname;

    %params = query_params($param_str);
    $conname = $params{_DEFAULT};

    return wikiErrMsg("This DBI connection is not defined: $conname.")
	unless db_connected($conname);

    my $allowed = db_allowed($conname, "$web.$topic");
    return wikiErrMsg("You are not allowed to modify this DB ($web.$topic).")
	unless $allowed;

    my $qid = newQID;

    unless (defined $content) {
	if (defined $params{topic} && TWiki::Func::topicExists(undef, $params{topic})) {
	    $content = TWiki::Func::readTopicText(undef, $params{topic}, undef, 1);
	    if (defined $params{script}) {
		return wikiErrMsg("%<nop>DBI_DO% script name must be a valid identifier")
		    unless $params{script} =~ /^\w\w*$/;
		if ($content =~ /%DBI_CODE{"$params{script}"}%(.*?)%DBI_CODE%/s) {
		    $content = $1;
		} else {
		    undef $content;
		}
		if (defined $content) {
		    $content =~ s/^\s*%CODE{.*?}%(.*)%ENDCODE%\s*$/$1/s;
		    $content =~ s/^\s*<pre>(.*)<\/pre>\s*$/$1/s;
		}
	    }
	}
	return wikiErrMsg("No code defined for this %<nop>DBI_DO% variable")
	    unless defined $content;
    }

    $queries{$qid}{params} = \%params;
    $queries{$qid}{connection} = $conname;
    $queries{$qid}{type} = "do";
    $queries{$qid}{code} = $content;
    my $script_name = $params{script} ?
	                  $params{script} : 
			  ($params{name} ?
			      $params{name} : 
			      ($params{subquery} ?
				  $params{subquery} :
				  "dbi_do_script"
			      )
			  );
    $queries{$qid}{script_name} = $params{topic} ? "$params{topic}\:\:$script_name" : $script_name;

    return registerQuery($qid, \%params);
}
# }}}

# {{{sub storeQuery
sub storeQuery
{
    my ($param_str, $content) = @_;
    my %params;
    my $conname;

    %params = query_params($param_str);
    $conname = $params{_DEFAULT};

    return wikiErrMsg("This DBI connection is not defined: $conname.")
	unless db_connected($conname);

    my $qid = newQID;

    $queries{$qid}{params} = \%params;
    $queries{$qid}{connection} = $conname;
    $queries{$qid}{type} = "query";
    $queries{$qid}{_nesting} = 0;

    my $content_kwd = qr/\n\.(head(?:er)?|body|footer)\s*/s;

    my %map_kwd = (
	head => header =>
    );

    my @content = split $content_kwd, $content;

    my $statement = shift @content;

    for (my $i = 1; $i < @content; $i+=2) {
	$content[$i] =~ s/\n*$//s;
	$content[$i] =~ s/\n/ /gs;
	$content[$i] =~ s/(?<!\\)\\n/\n/gs;
	$content[$i] =~ s/\\\\n/\\n/gs;
	my $kwd = $map_kwd{$content[$i - 1]} || $content[$i - 1];
	$queries{$qid}{$kwd} = $content[$i];
    }

    $queries{$qid}{statement} = $statement;

#    dprint "Query data:\n", Dumper($queries{$qid});

    return registerQuery($qid, \%params);
}
# }}}

# {{{sub storeCallQuery
sub storeCallQuery
{
    my ($param_str) = @_;
    my %params;

    my $qid = newQID;

    %params = TWiki::Func::extractParameters($param_str);
    $queries{$qid}{columns} = \%params;
    $queries{$qid}{call} = $params{_DEFAULT};
    $queries{$qid}{type} = 'query';
    $queries{$qid}{_nesting} = 0;

    return "\%$qid\%";
}
# }}}

# {{{sub dbiCode
sub dbiCode
{
    my ($param_str, $content) = @_;
    my %params;

    %params = TWiki::Func::extractParameters($param_str);

    unless ($content =~ /^\s*%CODE{.*?}%(.*)%ENDCODE%\s*$/s) {
	$content = "<pre>$content</pre>";
    }

    return <<EOT;
<table width=\"100\%\" border=\"0\" cellspacing="5px">
  <tr>
    <td nowrap> *Script name* </td>
    <td> =$params{_DEFAULT}= </td>
  </tr>
  <tr valign="top">
    <td nowrap> *Script code* </td>
    <td> $content </td>
  </tr>
</table>
EOT
}
# }}}

# {{{sub expandColumns
sub expandColumns
{
    my ($text, $columns) = @_;

    dprint ">>>>> EXPANDING:\n--------------------------------\n$text\n--------------------------------\n";
    if (keys %$columns) {
	my $regex = "\%(" . join("|", keys %$columns) . ")\%";
	$text =~ s/$regex/$columns->{$1}/ge;
    }
    $text =~ s/\%DBI_(?:SUBQUERY|EXEC){(.*?)}\%/&subQuery($1, $columns)/ge;
    dprint "<<<<< EXPANDED:\n--------------------------------\n$text\n--------------------------------\n";

    return $text;
}
# }}}

# {{{sub executeQueryByType
sub executeQueryByType
{
    my ($qid, $columns) = @_;
    $columns ||= {};
    my $query = $queries{$qid};
    return (
	$query->{type} eq 'query' ?
	    getQueryResult($qid, $columns) :
		(
		    $query->{type} eq 'do' ?
			doQuery($qid, $columns) :
#			wikiErrMsg("INTERNAL: Query type `$query->{type}' is unknown.")
		        ''
		)
    );
}
# }}}

# {{{sub subQuery
sub subQuery
{
    my %params = query_params(shift);
    my $columns = shift;
    dprint "Processing subquery $params{_DEFAULT} => $subquery_map{$params{_DEFAULT}}";
    return executeQueryByType($subquery_map{$params{_DEFAULT}}, $columns);
}
# }}}

# {{{sub getQueryResult
sub getQueryResult
{
    my ($qid, $columns) = @_;

    my $query = $queries{$qid};
    return wikiErrMsg("Subquery $qid is not defined.") unless defined $query;

    my $params = $query->{params} || {};
    $columns ||= {};

    if ($query->{_nesting} > $maxRecursionLevel) {
	my $errmsg = "Deep recursion (more then $maxRecursionLevel) occured for subquery $params->{subquery}";
	warning $errmsg;
	throw Error::Simple($errmsg);
    }

    my $result = "";

    if (defined $query->{call}) {

	$result = getQueryResult($subquery_map{$query->{call}}, $query->{columns});

    } else {
	$query->{_nesting}++;
	dprint "Nesting level $query->{_nesting} for subquery ", ($query->{subquery} || "UNDEFINED"), "....\n";;
	$columns->{".nesting."} = $query->{_nesting};

	my $dbh = $query->{dbh} = db_connect($params->{_DEFAULT});
	throw Error::Simple("DBI connect error for connection ".$params->{_DEFAULT}) unless $dbh;

	if (defined $query->{header}) {
	    $result .= expandColumns($query->{header}, $columns);
	}

	my $statement = TWiki::Func::expandCommonVariables(
	    expandColumns($query->{statement}, $columns),
	    $topic,
	    $web
	);
	$query->{expanded_statement} = $statement;
	dprint $statement;

	my $sth = $dbh->prepare($statement);
	$sth->execute;

	my $fetched = 0;
	while (my $row = $sth->fetchrow_hashref) {
	    unless ($fetched) {
		dprint "Columns: ", join(", ", keys %$row);
	    }
	    $fetched++;

	    # Prepare row for output;
	    foreach my $col (keys %$row) {
		if ($col =~ /\s/) {
		    (my $out_col = $col) =~ s/\s/_/;
		    $row->{$out_col} = $row->{$col};
		    delete $row->{$col};
		    $col=$out_col;
		}
		$row->{$col} = '_NULL_' unless defined $row->{$col};
		$row->{$col} = nl2br(escapeHTML($row->{$col}))
		    unless defined $params->{unquoted}{$col};
		$row->{$col} = protectValue($row->{$col})
		    if $params->{protected}{$col};
		dprint "";
	    }

	    my $all_columns = {%$columns, %$row};
	    my $out = expandColumns($query->{body}, $all_columns);
	    $result .= $out;
	}

	if ($fetched > 0 || $query->{_nesting} < 2) {
	    if (defined $query->{footer}) {
		$result .= expandColumns($query->{footer}, $columns);
	    }
	} else {
	    # Avoid any output for empty recursively called subqueries.
	    $result = "";
	}

	$query->{_nesting}--;
    }

    return $result;
}
# }}}

# {{{sub doQuery
sub doQuery
{
    my ($qid, $columns) = @_;

    my $query = $queries{$qid};
    my $params = $query->{params} || {};
    my $rc = "";
    $columns ||= {};

    dprint "doQuery()\n";

    my %multivalued;
    if (defined $params->{multivalued}) {
	%multivalued = %{$params->{multivalued}};
    }

    # Preparing sub() code.
    my $dbh = $query->{dbh} = db_connect($params->{_DEFAULT});
    throw Error::Simple("DBI connect error for connection ".$params->{_DEFAULT}) unless $dbh;
    my $cgiQuery = TWiki::Func::getCgiQuery();
    my $sub_code = <<EOC;
sub {
    my (\$dbh, \$cgiQuery, \$varParams, \$dbRecord) = \@_;
    my \@params = \$cgiQuery->param;
    my \%httpParams; # = %{\$cgiQuery->Vars};
    foreach my \$param (\@params) {
	my \@val = \$cgiQuery->param(\$param);
	\$httpParams{\$param} = (\$multivalued{\$param} || (\@val > 1)) ? \\\@val : \$val[0];
    }
    my \$rc = "";

#line 1,"$query->{script_name}"
    $query->{code}

    return \$rc;
}
EOC

    my $sub = eval $sub_code;
    return wikiErrMsg($@) if $@;
    $rc = $sub->($dbh, $cgiQuery, $params, $columns);

    return $rc;
}
# }}}

# {{{sub handleQueries
sub handleQueries
{
    foreach my $qid (sort keys %queries) {
	my $query = $queries{$qid};
	dprint "Processing query $qid\n";
	try {
	    $query->{result} = executeQueryByType($qid)
		unless $query->{subquery};
	}
	catch Error::Simple with {
	    my $err = shift;
	    warning $err->{-text};
	    my $query_text = "";
	    if (defined $query->{expanded_statement}) {
		$query_text = "<br><pre>$query->{expanded_statement}</pre>";
	    }
	    if ($debug) {
		$query->{result} = wikiErrMsg("<pre>", $err->stacktrace, "</pre>", $query_text);
	    } else {
		$query->{result} = wikiErrMsg("$err->{-text}$query_text");
	    }
	}
	otherwise {
	    warning "There is a problem with QID $qid on connection $queries{$qid}{connection}";
	    my $errstr;
	    if (defined $queries{$qid}{dbh}) {
		$errstr = $queries{$qid}{dbh}->errstr;
	    } else {
		$errstr = $DBI::errstr;
	    }
	    warning "DBI Error for query $qid: $errstr";
	    $query->{result} = wikiErrMsg("DBI Error: $errstr");
	};
	dprint "RESULT:\n", defined $query->{result} ? $query->{result} : "*UNDEFINED*";
    }
}
# }}}

my $level = 0;
# {{{sub processPage
sub processPage
{

    $level++;
    dprint "### $level\n\n";

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    my $doHandle = 0;
    $_[0] =~ s/%DBI_VERSION%/$pluginVersion/gs;
    if ($_[0] =~ s/%DBI_DO{(.*?)}%(?:(.*?)%DBI_DO%)?/&storeDoQuery($1, $2)/ges) {
	$doHandle = 1;
    }
    $_[0] =~ s/\%DBI_CODE{(.*?)}%(.*?)\%DBI_CODE%/&dbiCode($1, $2)/ges;
    if ($_[0] =~ s/%DBI_QUERY{(.*?)}%(.*?)%DBI_QUERY%/&storeQuery($1, $2)/ges) {
	$doHandle = 1;
    }
    if ($_[0] =~ s/%DBI_CALL{(.*?)}%/&storeCallQuery($1)/ges) {
	$doHandle = 1;
    }
    if ($doHandle) {
	handleQueries;
	$_[0] =~ s/%(DBI_CONTENT\d+)%/$queries{$1}{result}/ges;
    }

    # Do not disconnect from databases if processing inclusions.

    $level--;

    db_disconnect if $level < 1;
}
# }}}

# =========================
# {{{sub beforeCommonTagsHandler
sub beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    processPage(@_);
}
# }}}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::CommonTagsHandler( $_[2].$_[1] )" ) if $debug;
    if ($_[3]) { # We're being included
	processPage(@_);
    }
}

# =========================
sub postRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    dprint "- ${pluginName}::endRenderingHandler( $web.$topic )";

    $_[0] =~ s/$protectStart(.*?)$protectEnd/&unprotectValue($1)/ges;

}

# =========================
1;
