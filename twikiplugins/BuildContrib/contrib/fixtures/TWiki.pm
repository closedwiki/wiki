=begin text

---++ Package TWiki - test fixture
A test fixture module that provides ultra-thin implementations of some of
the TWiki functions that are required by plugins and add-ons.

For full details, read the code.

=cut

$TWiki::wikiPrefsTopicname = "TWikiPreferences";
$TWiki::webPrefsTopicname = "WebPreferences";
$TWiki::notifyTopicname = "WebNotify";
$TWiki::cmdQuote = "'";

#$TWiki::webNameRegex = "[A-Z]+[A-Za-z0-9]*";
#$TWiki::anchorRegex = "\#[A-Za-z0-9_]+";
use strict;

package TWiki;

sub basicInitialize() {
}

sub initialize {
  my ( $path, $remuser, $topic, $url, $query ) = @_;
  # initialize $webName and $topicName
  my $webName   = "Main";
  if( $topic && $topic =~ /(.*)\.(.*)/ ) {
	# is "bin/script?topic=Webname.SomeTopic"
	$webName = $1 || "";
	$topic = $2 || "";
  } else {
	$topic = "WebHome";
  }

  return ($topic, $webName, "scripturlpath", "testrunner", $BaseFixture::testData);
}

sub getEmailOfUser
{
    my( $wikiName ) = @_;		# WikiName without web prefix

    return ("$wikiName\@test.email");
}

sub makeTopicSummary {
    my( $theText, $theTopic, $theWeb ) = @_;

    return $theText;
}

sub formatTime
{
    my ($epochSeconds, $formatString, $outputTimeZone) = @_;
    my $value = $epochSeconds;
	my @isoMonth = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

    # use default TWiki format "31 Dec 1999 - 23:59" unless specified
    $formatString = "\$day \$month \$year - \$hour:\$min" unless( $formatString );
    $outputTimeZone = "gmtime" unless( $outputTimeZone );

    my( $sec, $min, $hour, $day, $mon, $year, $wday) = gmtime( $epochSeconds );
      ( $sec, $min, $hour, $day, $mon, $year, $wday ) = localtime( $epochSeconds ) if( $outputTimeZone eq "servertime" );

    #standard twiki date time formats
    if( $formatString =~ /rcs/i ) {
        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = "\$year/\$mo/\$day \$hour:\$min:\$sec";
    } elsif ( $formatString =~ /http|email/i ) {
        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
            # - based on RFC 2616/1123 and HTTP::Date; also used
        # by TWiki::Net for Date header in emails.
        $formatString = "\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz";
    } elsif ( $formatString =~ /iso/i ) {
        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30Z"
        $formatString = "\$year-\$mo-\$dayT\$hour:\$min";
        if( $outputTimeZone eq "gmtime" ) {
            $formatString = $formatString."Z";
        } else {
        }
    }

    $value = $formatString;
    $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
    my @weekDay = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    $value =~ s/\$wday/$weekDay[$wday]/geoi;
    $value =~ s/\$mon[t]?[h]?/$isoMonth[$mon]/goi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
    $value =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

#TODO: how do we get the different timezone strings (and when we add usertime, then what?)

    my $tz_str = "GMT";
    $tz_str = "Local" if ( $outputTimeZone eq "servertime" );
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}

sub isWebName {
    my $name = shift;

    return grep $name, TWiki::Store::getAllWebs();
}

sub handleTmplP
{
    my( $theParam ) = @_;

    $theParam =~ s/"//g;
    my $value = &TWiki::Store::handleTmplP( $theParam );
    return $value;
}

sub extractNameValuePair
{
    my( $str, $name ) = @_;

    my $value = "";
    return $value unless( $str );

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;  # distinguish between "" and "0"
        }

    } else {
        # test if format: { "value" ... }
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/ ) {
            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;  # distinguish between "" and "0";

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        } else {
            # format is: %VAR{ value }%
            $value = $str;
        }
    }

    return $value;
}

sub handleUrlParam
{
    my( $theArgs ) = @_;
    my $cgiQuery = $BaseFixture::query;

    my $param     = extractNameValuePair( $theArgs );
    my $newLine   = extractNameValuePair( $theArgs, "newline" ) || "";
    my $encode    = extractNameValuePair( $theArgs, "encode" ) || "";
    my $multiple  = extractNameValuePair( $theArgs, "multiple" ) || "";
    my $separator = extractNameValuePair( $theArgs, "separator" ) || "\n";
    my $value = "";
    if( $cgiQuery ) {
        if( $multiple ) {
            my @valueArray = $cgiQuery->param( $param );
            if( @valueArray ) {
                unless( $multiple =~ m/^on$/i ) {
                    my $item = "";
                    @valueArray = map {
                        $item = $_;
                        $_ = $multiple;
                        $_ .= $item unless( s/\$item/$item/go );
                        $_
                    } @valueArray;
                }
                $value = join ( $separator, @valueArray );
            }
        } else {
            $value = $cgiQuery->param( $param );
            $value = "" unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    $value = handleUrlEncode( $value, 0, $encode ) if( $encode );
    unless( $value ) {
        $value = extractNameValuePair( $theArgs, "default" ) || "";
    }
    return $value;
}

sub TWiki::expandVariablesOnTopicCreation {
  my ( $theText, $theUser, $theWikiName, $theWikiUserName ) = @_;

  my $today = TWiki::Func::formatTime(time(), "\$day \$mon \$year", "gmtime");
  #$theUser         = $userName                     unless $theUser;
  $theWikiName     = TWiki::Func::userToWikiName( $theUser, 1 ) unless $theWikiName;
  $theWikiUserName = TWiki::Func::userToWikiName( $theUser )    unless $theWikiUserName;

  $theText =~ s/%DATE%/$today/go;
  $theText =~ s/%USERNAME%/$theUser/go;                     # "jdoe"
  $theText =~ s/%WIKINAME%/$theWikiName/go;                 # "JonDoe"
  $theText =~ s/%WIKIUSERNAME%/$theWikiUserName/go;         # "Main.JonDoe"
  $theText =~ s/%URLPARAM{(.*?)}%/&TWiki::handleUrlParam($1)/geo;  # expand URL parameters
  $theText =~ s/%NOP{.*?}%//gos;  # Remove filler: Use it to remove access control at time of
  $theText =~ s/%NOP%//go;        # topic instantiation or to prevent search from hitting a template

  return $theText;
}

1;
