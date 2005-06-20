# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::HolidaylistPlugin;    # change the package name and $pluginName!!!
use POSIX;
use Date::Calc qw(:all);


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar 
	@Days @names $min_timestamp $max_timestamp,$daystoprint,$tablecaption
    );

$VERSION = '1.021';
$pluginName = 'HolidaylistPlugin';  # Name of this Plugin

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
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  $_[0] =~ s/%HOLIDAYLIST%/&_handleMyScript("", $_[1], $_[2])/ge;
  $_[0] =~ s/%HOLIDAYLIST{(.*?)}%/&_handleMyScript( $1, $_[1], $_[2] )/ge;

    #TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}
# =========================
sub _handleMyScript
{
    my($attributes, $theTopic, $theWeb ) = @_;
    my $tmp;
    my @days = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun");
    # collect attributes if they exist
    $daystoprint = 30;
    $tmp = scalar TWiki::Func::extractNameValuePair( $attributes, "daystoprint" );
    $daystoprint = $tmp if( $tmp );
    $tablecaption = "&nbsp;";
    $tmp = scalar TWiki::Func::extractNameValuePair( $attributes, "tablecaption" );
    $tablecaption = $tmp if( $tmp );

    @Days = ();
    @names = ();
    my ($sec1,$min1,$hour1,$mday1,$mon1,$year1,$wday1,$yday1,$isdst1) = localtime(time);
    $min_timestamp = mktime(0,0,0,$mday1,$mon1,$year1);
    my ($sec2,$min2,$hour2,$mday2,$mon2,$year2,$wday2,$yday2,$isdst2) = localtime(time() +(86400 * $daystoprint));
    $max_timestamp = mktime(59,59,23,$mday2,$mon2,$year2);
    #Get the names of the people from a topic. By default the current topic.
    @names = get_names($theTopic, $theWeb);
    #Create an initial table, which assumes that nobody is away. Use the global @names list for this.
    create_empty_list();
    #Open the vac document. By default the current topic. Replace associative array entries with real values.
    get_vac_list($theTopic, $theWeb);
    my $result;
    #First line of the vacation result. Result will be sent back to the commonHandler.
    $result .= "<table border=1 bgcolor='#EEFFFA' link='#CC0000' alink='#FF3300' ><tr>\n";
    $result .= qq(<caption ALIGN="top">$tablecaption</caption>\n);
    #The vacation table will start from today. Give the header: days, dates etc.
    $result .= qq(<tr bgcolor="#507493"><th valign="bottom">Name</th>);
    foreach my $t_timestamp (@Days){
	my ($sec3,$min3,$hour3,$mday3,$mon3,$year3,$wday3,$yday3,$isdst3) = localtime($t_timestamp);
	my $mmonth = Month_to_Text($mon3+1);
	$mmonth = substr($mmonth,0,3);
	my ($mweek,$myear) = Week_of_Year(($year3+1900),($mon3+1),($mday3)); 
        if ($days[$wday3] =~/Sat/){ 
	    $result .= qq(<td bgcolor="#FFFFFF">&nbsp;</td>);
	}
	elsif($days[$wday3] =~/Sun/){ 
	    $result .= qq(<td bgcolor="#FFFFFF">&nbsp;</td>);
	}
	else{
	    $small_day = substr($days[$wday3],0,1);
	    $result .= qq(<th><span style="font-size: 10px;">$mmonth<br>$small_day<br>$mday3</span></th>);
	}
    }
    $result .= "\n";

   #print the table
    foreach my $n (@names){
	chomp($n);	
	$result .= "<tr><th>$n </th>";
	foreach $d (@Days){
	    if(!is_wkend($d) ){
		$result .= qq(<td align="center">${$d}{$n}</td>);
	    }
	    else{
		$result .= qq(<td bgcolor="#FFFFFF">&nbsp;</td>);
	    }
	}
	$result .= "\n";
    }   
    $result .= "\n</table>\n"; 
    return $result;
}

# =========================

# =========================


#sub routines for this Plugin
sub create_empty_list{
    foreach my $n (@names){
	my $myday = 0;
	@Days = ();
	while ($myday <$daystoprint){
	    my $theday = time + (86400 * $myday); 
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($theday);	    
	    my $timestamp = mktime(0,0,1,$mday,$mon,$year);
            push(@Days,$timestamp);
	    ${$timestamp}{$n} = qq(<img src="%PUBURL%/$installWeb/SmiliesPlugin/mad.gif">);
	    $myday = $myday +1;
	}
    }
}
# =========================
sub get_names{
    my($theTopic, $theWeb ) = @_;
    my @names=();
    my ($line, @fielddates, @dates, $person);
    open(PEOPLE,"$TWiki::dataDir/$theWeb/$theTopic.txt") || die "can't open names list to read";
    while (defined($line = <PEOPLE>)){
	chomp($line); 
	if ($line =~/^\s+\* [0-9]/){
	    @fielddates = split(/\*/,$line);
	    @dates = split(/\-/,$fielddates[1]);
	    if (defined($dates[2])){
		($person      = $dates[2]) =~s/^\s*(.*?)\s*$/$1/;
	    }
	    else{
		($person      = $dates[1]) =~s/^\s*(.*?)\s*$/$1/;
	    }
	    if (grep(/$person/i, @names) < 1) {
		push(@names,$person);
	    }
	}
    }
    close(PEOPLE);
    return sort(@names);
}
# =========================
sub get_vac_list{
    my( $theTopic, $theWeb ) = @_;
    my ($line, @fielddates, @dates, $person, $second_date, $first_date, $timestamp1, $now, $timestamp2, $tomorrow, $ts_tom);
    # open the vac list from the wiki document.
    open(VAC,"<$TWiki::dataDir/$theWeb/$theTopic.txt") || die "can't open vac db to read";
        while (defined($line = <VAC>)){
            chomp($line); 
	    if ($line =~/^\s+\* [0-9]/){
		@fielddates = split(/\*/,$line);
		@dates = split(/\-/,$fielddates[1]);
                if (defined($dates[2])){
		    ($person      = $dates[2]) =~s/^\s*(.*?)\s*$/$1/;
		    ($second_date = $dates[1]) =~s/^\s*(.*?)\s*$/$1/;
		    ($first_date  = $dates[0]) =~s/^\s*(.*?)\s*$/$1/;
		    $timestamp1 = get_timestamp($first_date);		    
		    $now = time();
		    if ($timestamp1 >= $now){
			${$timestamp1}{$person} = qq(<img src="%PUBURL%/$installWeb/SmiliesPlugin/cool.gif">);
		    }
		    $timestamp2 = get_timestamp($second_date);
                    $tomorrow =  add_a_day($first_date);	
		    $ts_tom   =  get_timestamp($tomorrow);
		    while( $ts_tom <= $timestamp2 ){
		        #print "$tomorrow $ts_tom $timestamp2 $min_timestamp $max_timestamp\n";
			if (($ts_tom > $min_timestamp) && ($ts_tom < $max_timestamp)){
			    ${$ts_tom}{$person} = qq(<img src="%PUBURL%/$installWeb/SmiliesPlugin/cool.gif">);
			}
			$tomorrow =  add_a_day($tomorrow);
			$ts_tom   =  get_timestamp($tomorrow);
		    }

		}
		else{
		    ($person      = $dates[1]) =~s/^\s*(.*?)\s*$/$1/;
		    ($first_date  = $dates[0]) =~s/^\s*(.*?)\s*$/$1/;
		    $timestamp1 = get_timestamp($first_date);		    
		    $now = time();
		    if ($timestamp1 > $now){
			${$timestamp1}{$person} = qq(<img src="%PUBURL%/$installWeb/SmiliesPlugin/thumbs.gif">);
		    }
		}
	    }
	    
	}
    close(VAC);
}
# =========================
sub get_timestamp(){
    my $t = $_[0];
    my @mt_fields = split(/\s+/,$t);
    my $mday  = $mt_fields[0]; 
    my $the_month = $mt_fields[1];
    my $mmon  = get_month_as_number($the_month);  
    my $myear = $mt_fields[2] - 1900; 
    my $timestamp = mktime(0,0,1,$mday,$mmon,$myear);
    return $timestamp;
}
# =========================
sub add_a_day(){
    my $t = $_[0];
    my @months = ( "Jan", "Feb", "Mar", "Apr",
                   "May", "Jun", "Jul", "Aug", "Sep",
                   "Oct", "Nov", "Dec" );
    my @days = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun");

    my @mt_fields = split(/\s+/,$t);
    my $myday  = $mt_fields[0]; 
    my $the_month = $mt_fields[1];
    my $mmon  = get_month_as_number($the_month);  
    my $myear = $mt_fields[2] - 1900; 
    my $timestamp = mktime(0,0,0,$myday,$mmon,$myear);
    $timestamp = $timestamp + 86400;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);
    my $theyear =  1900 + $year;   
    my $new_date = "$mday $months[$mon] $theyear";
    return $new_date;
}

sub get_month_as_number(){
    my $month1;
    my $themonth = $_[0];
    if($themonth eq  'Jan') { $month1 = 0} 
    elsif($themonth eq  'Feb') { $month1 = 1} 
    elsif($themonth eq  'Mar') { $month1 = 2} 
    elsif($themonth eq  'Apr') { $month1 = 3}
    elsif($themonth eq  "May") { $month1 = 4}
    elsif($themonth eq  'Jun') { $month1 = 5} 
    elsif($themonth eq  'Jul') { $month1 = 6} 
    elsif($themonth eq  'Aug') { $month1 = 7}
    elsif($themonth eq  'Sep') { $month1 = 8}
    elsif($themonth eq  'Oct') { $month1 = 9} 
    elsif($themonth eq  'Nov') { $month1 = 10} 
    elsif($themonth eq  'Dec') { $month1 = 11}
 
    return $month1;
}

sub is_wkend(){
    my $t = $_[0];
    my @days = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun");
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($t);
    return 1 if(($days[$wday] eq "Sat") || ($days[$wday] eq "Sun"));
    return 0;
}
# =========================
1;
