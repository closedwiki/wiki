# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2004 TWiki:Main.GerardHickey
# Copyright (C) 2006-2007 TWiki:Main.AndreasVoegele
# Copyright (C) 2007-2011 TWiki:TWiki.TWikiContributor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
#
# TWiki LDAP Plugin
#
#     Written by Gerard Hickey <hickey@kernelrom.com>
#     Modified by Gerald Skerbitz <gsker@tcfreenet.org> to use extractNameValuePair() and provide
#                 for multiple attributes and multiple records.
#     Modified by PatrickNomblot - 26 Jun 2003 to add JPeg Photo
#     Modified by Gerald Skerbitz 24 Oct 2003 to fix bug with shortvs long fields
#     Modified by PatrickNomblot - 9 Dec 2003 to change JPeg Photo to not have IMG hradcoded
#     Modified by GeraldSkerbitz - 13 Jan 2004 to add utf coding 
#     Modified by GeraldSkerbitz and PatrickNomblot - 14 Jan 2004 to add CGI and fix default Filter
#     Modified by GeraldSkerbitz 02 Feb 2004 changed basedn to base everywhere.
#     Modified by GeraldSkerbitz 04 Feb 2004 Code contributed by PatrickNomblot to 
#                  accomodate multiple values per attribute
#     Modified by GeraldSkerbitz 05 Apr 2004 Added Order to sort output 
#     Modified by JoanTouzet 03 Oct 2005 Reindented without tabs; fixes for Dakar, use strict
#     Modified by AndreasVoegele 28 Feb 2006 Fixes for Cairo and Dakar.
#                  Uses Encode or Unicode::MapUTF8 instead of Unicode::String.
#                  New settings starttls, sizelimit, and timelimit.
#     Modified by AndreasVoegele 13 May 2006 Removed sizelimit and timelimit setting.
#                  Always remove the final newline from the result.
#                  Require the Encode module from Perl 5.8.
#     Modified by AndreasVoegele 02 Oct 2006 Convert the search filter to UTF-8.
#     Modified by AndreasVoegele 11 Jul 2007 Add reverse, limit, and skip settings.
 
package TWiki::Plugins::LdapPlugin; 

use strict;

use vars qw(
    $VERSION $RELEASE $debug $pluginName
  );

$VERSION = '$Rev$';
$RELEASE = '2011-01-14';

# Name of this Plugin, only used in this module
$pluginName = 'LdapPlugin';

BEGIN {
    # 'Use locale' for internationalisation of Perl sorting and searching.
    if ($TWiki::cfg{UseLocale} || $TWiki::useLocale) {
        require locale;
        import locale ();
    }
}

sub initPlugin {
    my($theTopic, $theWeb, $theUser, $theInstallWeb) = @_;

    # check for Plugins.pm versions
    if ($TWiki::Plugins::VERSION < 1.025) {
        TWiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag('DEBUG');

    # register the _LDAP function to handle %LDAP{...}%
    #TWiki::Func::registerTagHandler('LDAP', \&_LDAP, 'context-free');

    # Plugin correctly initialized
    return 1;
}

sub _LDAP {
    my($theSession, $theParams, $theTopic, $theWeb) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) start") if $debug;

    eval {
        require Net::LDAP;
        require Encode;
        require File::Spec;
    };
    return "<font color=\"red\">$pluginName: Can't load required modules ($@)</font>" if $@;

    # Get the site charset and wheter to use locales or not.
    my $sitecharset = $TWiki::cfg{Site}{CharSet} || 'iso-8859-1';
    my $uselocale = $TWiki::cfg{UseLocale} || $TWiki::useLocale;

    # host from setting or from parameter
    my $host = $theParams->{host}
        || TWiki::Func::getPluginPreferencesValue('HOST');

    if (!$host) {
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: no host specified") if $debug;
        return "<font color=\"red\">$pluginName: No host specified for search</font>";
    }

    # StartTLS setting
    my $starttls = defined($theParams->{starttls})
        ? $theParams->{starttls} !~ m/(0|off|no)/i
        : TWiki::Func::getPluginPreferencesFlag('STARTTLS');

    # filter from parameter or CgiQuery
    my $cgi = TWiki::Func::getCgiQuery();
    my $cgifilter = '';
    if ($cgi) 
    {
        $cgifilter = $cgi->param('ldapfilter');
        if ($cgifilter) {
            $cgifilter =~ s/^ +//;
            $cgifilter =~ s/^AND\(/&(/;
            $cgifilter =~ s/%(\d\d)/pack("H2",$1)/eg;
        }
    }

    my $filter = $cgifilter || $theParams->{filter};
    if (!$filter) {
        # The word TOPIC in the filter is replaced with the topic.
        $filter = TWiki::Func::getPluginPreferencesValue('DEFAULTFILTER');
        my $topicreplace = TWiki::Func::wikiToUserName($theTopic);
        $filter =~ s/TOPIC/$topicreplace/;
    }
    if (!$filter) {
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: no filter specified") if $debug;
        return "<font color=\"red\">$pluginName: No filter specified for search</font>";
    }
    
    # format from setting or parameter.  Field list extracted from format.
    my @fields = ();
    my $format = $theParams->{format}
        || TWiki::Func::getPluginPreferencesValue('FORMAT')
        || '';
    # get attributes list from format
    if ($format ne 'FIELDLIST') {
        @fields = ($format =~ /\$(\w+)/g);
        if (!@fields) {
            TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: no fields specified") if $debug;
            return "<font color=\"red\">$pluginName: No fields specified for search</font>";
        }
    }

    # separator for multi-value attributes
    my $mvformat = $theParams->{mvformat}
        || TWiki::Func::getPluginPreferencesValue('MVFORMAT')
        || '<br />';

    # fields to sort the search result on
    my $order = $theParams->{order}
        || TWiki::Func::getPluginPreferencesValue('ORDER')
        || '';

    # reverse the order of the result set
    my $reverse = defined($theParams->{reverse})
        ? $theParams->{reverse} !~ m/(0|off|no)/i
        : TWiki::Func::getPluginPreferencesFlag('REVERSE');

    # offset into the result set
    my $skip = $theParams->{skip}
        || TWiki::Func::getPluginPreferencesValue('SKIP')
        || 0;

    # limit the number of rows returned
    my $limit = $theParams->{limit}
        || TWiki::Func::getPluginPreferencesValue('LIMIT')
        || 0;

    # header from setting or parameter
    my $header = $theParams->{header}
        || TWiki::Func::getPluginPreferencesValue('HEADER')
        || '';

    # base from setting or parameter
    my $base = $theParams->{base}
        || TWiki::Func::getPluginPreferencesValue('BASE')
        || '';

    # Special attribute : PHOTO --> need to store the content in a file
    my $jpegphoto = $theParams->{jpegphoto}
        || TWiki::Func::getPluginPreferencesValue('JPEGPHOTO')
        || 'jpegPhoto';
    # jpegDefaultPhoto is the URL of a default photo if someone doesn't have one
    my $jpegdefaultphoto = $theParams->{jpegdefaultphoto}
        || TWiki::Func::getPluginPreferencesValue('JPEGDEFAULTPHOTO')
        || '';
    my $jpegphotodir = File::Spec->catdir(TWiki::Func::getPubDir(), 'LdapPhotos');
    my $jpegphotourlpath = TWiki::Func::getPubUrlPath() . '/LdapPhotos/';
    my $jpegalias = 'alias';
    
    # Error message if LDAP request gives no answer
    my $notfounderror = $theParams->{notfounderror}
        || TWiki::Func::getPluginPreferencesValue('NOTFOUNDERROR')
        || "<font color=\"red\">$pluginName: Search returned no records</font>";

    if ($debug) {
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) HOST $host");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) STARTTLS $starttls");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) BASE $base");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) FILTER $filter");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) HEADER $header");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) FORMAT $format");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) MVFORMAT $mvformat");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) ORDER $order");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) REVERSE $reverse");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) LIMIT $limit");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) SKIP $skip");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) JPEGPHOTO $jpegphoto");
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) JPEGDEFAULTPHOTO $jpegdefaultphoto");
    }

    # Connect to the LDAP server.  Bail out with error if no connect.
    my $ldap = Net::LDAP->new($host);
    if (!$ldap) {
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: cannot connect to $host") if $debug;
        return "<font color=\"red\">$pluginName: Can't connect to LDAP server</font>";
    }

    my $mesg = undef;

    if ($starttls) {
        $mesg = $ldap->start_tls(verify => 'none');
        if ($mesg->code) {
            TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: STARTTLS failed") if $debug;
            return "<font color=\"red\">$pluginName: STARTTLS failed</font>";
        }
    }

    $mesg = $ldap->bind(); # bind anonymously
    #$mesg = $ldap->bind('dn', password => 'secret');
    if ($mesg->code) {
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) error: cannot bind to $host") if $debug;
        return "<font color=\"red\">$pluginName: Can't bind to LDAP server</font>";
    }

    # do the actual LDAP lookup
    Encode::from_to($filter, $sitecharset, 'utf-8');
    $mesg = $ldap->search(base => $base,
                          scope => 'sub',
                          sizelimit => 0,
                          timelimit => 0,
                          filter => $filter,
                          attrs => @fields ? [@fields, $jpegalias] : ['*']);

    # If query succeeds, then print header here (if defined)
    my $max = $mesg->count();
    if ($max == 0) { 
        $ldap->unbind();
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) warning: no records found") if $debug;
        # return message saying no rows were found ....
        return $notfounderror;
    }

    # If $format = FIELDLIST then just return the list of attributes found.
    if ($format eq 'FIELDLIST') {
        # Loop over all entries to add all seen attributes on this query
        # From Net::LDAP::Examples
        my %attrhash = ();
        foreach my $valref (values %{$mesg->as_struct}) {
            map { $attrhash{$_} = 1 } keys %$valref;
        }
        $ldap->unbind();
        TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) returns fieldlist") if $debug;
        return join(', ', sort keys %attrhash);
    }

    # Sort by the fields given in the order parameter.  If the order
    # parameter is not given the result is ordered by fields.
    my @keyfields = $order ? ($order =~ /(\w+)/g) : @fields;

    # The fields must be sorted by length so that fields with longer
    # names are replaced first.  For example, $street must be replaced
    # before $st is replaced.
    my @fields_by_length = sort { length($b) <=> length($a) } @fields;

    # Then get rows of query response
    my %rows = ();
    for (my $i = 0; $i < $max; $i++) {
        my $row = $format;
        my %sortfield = ();
        my $entry = $mesg->entry($i);
        foreach my $x (@fields_by_length) {
            my $y;
            my @values = $entry->get_value($x);
            if ($x eq $jpegphoto) {
                if (@values) {
                    my $file = $entry->get_value($jpegalias);
                    $file =~ tr/a-zA-Z0-9/_/c if $file;
                    $file = $theTopic unless $file;
                    $file .= '.jpg';
                    mkdir($jpegphotodir, 0775) unless -e $jpegphotodir;
                    open(FILE, '>', File::Spec->catfile($jpegphotodir, $file));
                    binmode(FILE);
                    print FILE $values[0];
                    close(FILE);
                    $y = $jpegphotourlpath . $file;
                } else {
                    $y = $jpegdefaultphoto;
                }
            } else {
                $y = join($mvformat, @values);
                Encode::from_to($y, 'utf-8', $sitecharset);
            }
            $y =~ s/\n/ /g; # remove newlines from data (messes with format)
            $row =~ s/\$$x/$y/g; #replace $field with $y (the value)
            # Capture field value for sort
            if (scalar grep (/$x/, @keyfields)) {
                $sortfield{$x} = $y;
            }
        } 
        $rows{join('-', @sortfield{@keyfields})} .= $row . "\n";
    }

    $ldap->unbind();

    $limit = $max if $limit <= 0 || $limit > $max;

    # build $result with %rows{sortfield}
    my $result = $header ? $header . "\n" : '';
    my $oldlocale;
    if ($uselocale) {
        # Unfortunately, only LC_CTYPE is set in TWiki.pm.
        use POSIX qw(locale_h);
        $oldlocale = setlocale(LC_COLLATE);
        setlocale(LC_COLLATE, setlocale(LC_CTYPE));
    }
    my @sorted_result = sort keys %rows;
    @sorted_result = reverse(@sorted_result) if $reverse;
    splice(@sorted_result, 0, $skip);
    splice(@sorted_result, $limit);
    foreach my $key (@sorted_result) {
        $result .= $rows{$key};
    }
    if ($uselocale) {
        setlocale(LC_COLLATE, $oldlocale);
    }

    # Remove the final newline.
    chomp $result;
    TWiki::Func::writeDebug("- ${pluginName}::_LDAP($theWeb.$theTopic) returns $limit records") if $debug;
    return $result;
}

sub _ldap_lookup {
    my($theAttr, $theTopic, $theWeb) = @_;

    my %params = TWiki::Func::extractParameters($theAttr);
    my %lcparams = ();
    while (my($key, $value) = each %params) {
        $lcparams{lc($key)} = $value;
    }
    return _LDAP(undef, \%lcparams, $theTopic, $theWeb);
}

##### TODO: Merge work done by TWiki:Main.JoanTouzet in 2005
##
##sub ldap_lookup () {
##    my $attr = shift;
##    my ($ldap,$i,$x,$y,$row,$mesg);
##    my (@fields, @keyfields);
##    my (%rows, %sortfield);
##
##    &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup( $attr )" ) if $debug;
##
##    my $mvformat=&TWiki::Func::extractNameValuePair( $attr, "mvformat" ) || $LDAP_MvFormat;
##
##    # host from setting or from parameter
##    my $host=&TWiki::Func::extractNameValuePair( $attr, "host" ) || $LDAP_Host;
##
##    # add the defined port
##    $host .= ":$LDAP_Port";
##
##    # Use $host to make connection.  Bail out with error if no connect.
##    if (! ($ldap = Net::LDAP->new ($host))) {
##                # Connection failed!
##                return ("<b> LDAP Connect Failure </b>");
##    }
##
##    # filter from parameter or CgiQuery
##    my $cgi = &TWiki::Func::getCgiQuery();
##    my $cgiFilter = "";
##    if( $cgi->param('ldapfilter') ) 
##    {
##        $cgiFilter = $cgi->param('ldapfilter');
##        $cgiFilter =~ s/^ +//;
##        $cgiFilter =~ s/^AND\(/&(/;
##        $cgiFilter =~ s/%(\d\d)/pack("H2",$1)/eg;
##    }
##
##    my $filter=$cgiFilter || &TWiki::Func::extractNameValuePair($attr, "filter")
##        || $LDAP_Filter;
##
##    if (! $filter) {
##        return("No Filter Specified for Search");
##    }
##
##    # format from setting or parameter.  Field list extracted from format.
##    my $format=&TWiki::Func::extractNameValuePair( $attr,"format")  || $LDAP_Format;
##    if (! $format ) { 
##        return "No Fields Requested";
##    } else {
##        # get attributes list from Format
##        if ($format eq "FIELDLIST") {
##            @fields=();
##        } else {
##            @fields=($format=~ /\$([^\W]+)/g);
##        }
##    }
##
##    my $order=&TWiki::Func::extractNameValuePair( $attr,"order")  || $LDAP_Order;
##    @keyfields = ($order =~ /([^\W]+)/g);
##
##    # header from setting or parameter
##    my $header=&TWiki::Func::extractNameValuePair( $attr,"header") || $LDAP_Header;
##
##    # base from setting or parameter
##    my $base=&TWiki::Func::extractNameValuePair( $attr, "base" ) || $LDAP_Base;
##
##    # Special attribute : PHOTO --> need to store the content in a file
##    # if you never want to process jpeg, comment out the next line
##    # and it won't ever happen.
##    my $jpegPhoto=&TWiki::Func::extractNameValuePair( $attr, "jpegPhoto" ) || $LDAP_jpegPhoto;
##    my $jpegDefaultPhoto=&TWiki::Func::extractNameValuePair( $attr, "jpegDefaultPhoto" ) || $LDAP_jpegDefaultPhoto;
##
##    # Error message if LDAP request gives no answer
##    my $NotFoundError=&TWiki::Func::extractNameValuePair( $attr, "notfounderror" ) 
##            || $LDAP_Notfounderror 
##            || "LDAP Query Returned Zero Records [Filter: =$filter= ]";
##
##    &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup(): HOST=\"$host\" BASE=\"$base\" FILTER=\"$filter\"") if $debug;
##    &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup(): attrs=\"@fields\"") if $debug;
##
##    # do the actual LDAP lookup
##    $mesg = $ldap->search(
##            'host' => $host,
##            'base' => $base,
##            'filter' => $filter,
##            'attrs' => [ @fields ]
##    );
##
##    # If query succeeds, then print header here (if defined)
##    my $max = $mesg->count;
##    my $value="";
##    if ($max) { 
##        $value="$header \n" if ($header);
##    } else {
##        # return message saying no rows were found ....
##        return "$NotFoundError";
##    }
##
##    # If $format = FIELDLIST then just return the list of fields for the entry found.
##    if ($format eq "FIELDLIST") {
##        # Loop over all entries to add all seen attributes on this query
##  # From Net::LDAP::Examples
##  my %attrHash;
##        my $href = $mesg->as_struct;
##  my @arrayOfDNs = keys %$href;
##        foreach ( @arrayOfDNs )
##  {
##      my $valref = $$href{$_};
##      my @arrayOfAttrs = sort keys %$valref;
##      my $attrName;
##      foreach $attrName (@arrayOfAttrs)
##      {
##          $attrHash{$attrName} = '1';
##      }
##  }
##  foreach my $key (keys %attrHash) {
##            $value .= "$key, ";
##  }
##  return $value;
##    }
##
##    %rows=();
##
##    # Then print rows of query response       
##    for ($i=0 ; $i < $max ; $i++) 
##    {
##        %sortfield=();
##        $row=$format;
##        my $entry = $mesg->entry($i);
##        foreach $x (sort { length($b) <=> length($a) } @fields) 
##        {
##            if (defined($entry->get_value($x))) 
##            {
##                $y = join ("$mvformat", $entry->get_value($x) );
##
##                if ( defined ($jpegPhoto) && ($x eq "$jpegPhoto" ) )
##                {
##                    my $dir= TWiki::Func::getPubDir()."/LdapPhotos";
##                    if ( ! -e "$dir")
##                    {
##                        umask(002);
##                        mkdir( $dir, 0775 );
##                        &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup() create $dir/\n") if $debug;
##                    }
##                    my $jpegPhotoFile =  $entry->get_value('alias');
##                    if( "$jpegPhotoFile" eq "") { $jpegPhotoFile=$topic; } 
##                    $jpegPhotoFile=$jpegPhotoFile . ".jpg";
##                    open (FILE, ">$dir/$jpegPhotoFile");
##                    binmode(FILE);
##                    print FILE $y;
##                    close (FILE);
##                    $y=TWiki::Func::getPubUrlPath()."/LdapPhotos/$jpegPhotoFile";
##                    &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup() create $dir/$jpegPhotoFile\n") if $debug;
##                }
##                $y=~s/\n/ /g;           # remove newlines from data (messes with format)
##                $row =~ s/\$$x/$y/ge;   # replace $field with $y (the value)
##            } else {
##                $row =~ s/\$$jpegPhoto/$jpegDefaultPhoto/ge;
##                $row =~ s/\$$x/" "/ge;
##            }
##            # Capture field value for sort
##            if (scalar grep (/$x/,@keyfields)) {
##                $sortfield{$x}=$y;
##                &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup() Field=\"$x\" Sort=\"$y\"" ) if $debug;
##            }
##        } 
##        $row = utf8($row)->latin1;
##        $rows{join("-",@sortfield{@keyfields})}.="$row\n";
##    }
##
##    # build $value with %rows{sortfield}
##    foreach my $key (sort keys %rows) {
##        $value .= "$rows{$key}";
##    }
##
##    &TWiki::Func::writeDebug( "- LdapPlugin::ldap_lookup() returning: $value" ) if $debug;
##    return ($value);
##}

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $theText, $theTopic, $theWeb ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )") if $debug;

    $_[0] =~ s/(?<!\<nop\>)%LDAP{(.*?)}%/&_ldap_lookup($1, $_[1], $_[2])/geo;
}

# vim:et:sts=4:ts=8:sw=4:

1;
