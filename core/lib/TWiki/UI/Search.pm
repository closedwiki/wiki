# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2011 Peter Thoeny, peter[at]thoeny.org
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
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::Search

UI functions for searching.

=cut

package TWiki::UI::Search;

use strict;

require TWiki;

=pod

---++ StaticMethod search( $session )

Perform a search as dictated by CGI parameters:

| *Parameter:* | *Description:* | *Default:* |
| ="text"= | Search term. Is a keyword search, literal search or regular expression search, depending on the =type= parameter. SearchHelp has more | required |
| =search="text"= | (Alternative to above) | N/A |
| =web="Name"= <br /> =web="%USERSWEB%, Know"= <br /> =web="all"= | Comma-separated list of webs to search. The special word =all= means all webs that doe *not* have the =NOSEARCHALL= variable set to =on= in their %WEBPREFSTOPIC%. You can specifically *exclude* webs from an =all= search using a minus sign - for example, =web="all,-Secretweb"=. | Current web |
| =topic="%WEBPREFSTOPIC%"= <br /> =topic="*Bug"= | Limit search to topics: A topic, a topic with asterisk wildcards, or a list of topics separated by comma. | All topics in a web |
| =excludetopic="Web*"= <br /> =excludetopic="%HOMETOPIC%, <nop>WebChanges"= | Exclude topics from search: A topic, a topic with asterisk wildcards, or a list of topics separated by comma. | None |
| =type="keyword"= <br /> =type="literal"= <br /> =type="regex"= | Do a keyword search like =soap "web service" -shampoo=; a literal search like =web service=; or RegularExpression search like =soap;web service;!shampoo= | =%<nop>SEARCHVAR- DEFAULTTYPE%= [[TWikiPreferences][preferences]] setting (%SEARCHVARDEFAULTTYPE%) |
| =scope="topic"= <br /> =scope="text"= <br /> =scope="all"= | Search topic name (title); the text (body) of topic; or all (both) | ="text"= |
| =order="topic"= <br /> =order="created"= <br />  =order="modified"= <br /> =order="editby"= <br /> =order=<br />&nbsp;"formfield(name)"= | Sort the results of search by the topic names, topic creation time, last modified time, last editor, or named field of TWikiForms. The sorting is done web by web; in case you want to sort across webs, create a [[FormattedSearch][formatted]] table and sort it with TablePlugin's initsort | Sort by topic name |
| =limit="all"= <br /> =limit="16"= | Limit the number of results returned. This is done after sorting if =order= is specified | All results |
| =date="..."= | limits the results to those pages with latest edit time in the given TimeInterval.  | All results |
| =reverse="on"= | Reverse the direction of the search | Ascending search |
| =casesensitive="on"= | Case sensitive search | Ignore case |
| =bookview="on"= | BookView search, e.g. show complete topic text | Show topic summary |
| =nonoise="on"= | Shorthand for =nosummary="on" nosearch="on" nototal="on" zeroresults="off" noheader="on" noempty="on"= | Off |
| =nosummary="on"= | Show topic title only | Show topic summary |
| =nosearch="on"= | Suppress search string | Show search string |
| =noheader="on"= | Suppress search header <br /> <span style='background: #FFB0B0;'> *Topics: Changed: By:* </span> | Show search header |
| =nototal="on"= | Do not show number of topics found | Show number |
| =zeroresults="off"= | Suppress all output if there are no hits | =zeroresults="on"=, displays: "Number of topics: 0" |
| =noempty="on"= | Suppress results for webs that have no hits. | Show webs with no hits |
| =header="..."= <br /> =format="..."= | Custom format results: see *[[FormattedSearch]]* for usage, variables &amp; examples | Results in table |
| =expandvariables="on"= | Expand variables before applying a FormattedSearch on a search hit. Useful to show the expanded text, e.g. to show the result of a SpreadSheetPlugin =%<nop>CALC{}%= instead of the formula | Raw text |
| =multiple="on"= | Multiple hits per topic. Each hit can be [[FormattedSearch][formatted]]. The last token is used in case of a regular expression ";" _and_ search | Only one hit per topic |
| =nofinalnewline="on"= | If =on=, the search variable does not end in a line by itself. Any text continuing immediately after the search tag on the same line will be rendered as part of the table generated by the search, if appropriate. | =off= |
| =separator=", "= | Line separator between hits | Newline ="$n"= |

=cut

sub search {
    my $session = shift;

    my $query = $session->{request};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    unless ( $session->{store}->webExists( $webName ) ) {
        require TWiki::OopsException;
        throw TWiki::OopsException(
            'accessdenied',
            def => 'no_such_web',
            web => $webName,
            topic => $topic,
            params => [ 'search' ] );
    }

    # The CGI.pm docs claim that it returns all of the values in a
    # multiple select if called in a list context, but that may not
    # work (didn't on the dev box -- perl 5.004_4 and CGI.pm 2.36 on
    # Linux (Slackware 2.0.33) with Apache 1.2.  That being the case,
    # we need to parse them out here.

#    my @webs          = $query->param( 'web' ) || ( $webName ); #doesn't work

    # Note for those unused to Perlishness:
    # -------------------------------------
    # The pipeline at the end of this assignment splits the full query
    # string on '&' or ';' and selects out the params that begin with 'web=',
    # replacing them with whatever is after that.  In the case of a
    # single list of webs passed as a string (say, from a text entry
    # field) it does more processing than it needs to to get the
    # correct string, but so what?  The pipline is the second
    # parameter to the join, and consists of the last two lines.  The
    # join takes the results of the pipeline and strings them back
    # together, space delimited, which is exactly what &searchWeb
    # needs.
    # Note that mod_perl/cgi appears to use ';' as separator, whereas plain cgi uses '&'

    my $attrWeb       = join ' ',
                        grep { s/^web=(.*)$/$1/ }
                        split(/[&;]/, $query->query_string);
    # need to unescape URL-encoded data since we use the raw query_string
    # suggested by JeromeBouvattier
    $attrWeb =~ tr/+/ /;       # pluses become spaces
    $attrWeb =~ s/%([0-9a-fA-F]{2})/pack('c',hex($1))/ge;  # %20 becomes space

    # 'scalar' is used below to get the scalar value of the parameter
    # because it returns the empty string for undef.

    my $text = $session->search->searchWeb(
#        _callback       => \&_contentCallback,	#FIXME - can't process format=| $topic | line by line...
        _callback       => undef,
        _cbdata         => undef,
        'inline'          => 0,
        'search'        => scalar $query->param( 'search' ),
        'web'           => $attrWeb,
        'topic'         => scalar $query->param( 'topic' ),
        'excludetopic'  => scalar $query->param( 'excludetopic' ),
        'scope'         => scalar $query->param( 'scope' ),
        'order'         => scalar $query->param( 'order' ),
        'type'          => scalar $query->param( 'type' ) ||
          $session->{prefs}->getPreferencesValue( 'SEARCHDEFAULTTYPE' ),
        'regex'         => scalar $query->param( 'regex' ),
        'limit'         => scalar $query->param( 'limit' ),
        'reverse'       => scalar $query->param( 'reverse' ),
        'casesensitive' => scalar $query->param( 'casesensitive' ),
        'nosummary'     => scalar $query->param( 'nosummary' ),
        'nosearch'      => scalar $query->param( 'nosearch' ),
        'noheader'      => scalar $query->param( 'noheader' ),
        'nototal'       => scalar $query->param( 'nototal' ),
        'bookview'      => scalar $query->param( 'bookview' ),
        'showlock'      => scalar $query->param( 'showlock' ),
        'expandvariables' => scalar $query->param( 'expandvariables' ),
        'noempty'       => scalar $query->param( 'noempty' ),
        'template'      => scalar $query->param( 'template' ),
        'header'        => scalar $query->param( 'header' ),
        'format'        => scalar $query->param( 'format' ),
        'footer'        => scalar $query->param( 'footer' ),
        'multiple'      => scalar $query->param( 'multiple' ),
        'default'       => scalar $query->param( 'default' ),
        'separator'     => scalar $query->param( 'separator' ),
        'subweb'     => scalar $query->param( 'subweb' )
    );
 
    $session->writeCompletePage($text);
    
}

# TSA SMELL: Review this in case of defining _callback above
sub _contentCallback {
    TWiki::spamProof( $_[1] );
#FIXME: if you're going to define a callback, you have to convert from TML too    
    print $_[1];
}

1;

