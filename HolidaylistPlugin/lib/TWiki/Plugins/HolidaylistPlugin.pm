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
package TWiki::Plugins::HolidaylistPlugin;    

# =========================

use Date::Calc qw(:all);

# not really required:
eval { 
	use HTML::Entities 'encode_entities';
}; 

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug 
	%defaults @renderedOptions %options $refText %months %daysofweek
	$months_rx $date_rx $daterange_rx $bullet_rx $bulletdate_rx $bulletdaterange_rx $dow_rx $day_rx
	$year_rx $monthyear_rx $monthyearrange_rx
	$defaultsInitialized
	$theWeb $theTopic
    );

$VERSION = '1.010'; #dro# added exception handling; added compatibility mode (new attributes: compatmode, compatmodeicon) with full CalendarPlugin event type support; added documentation
#$VERSION = '1.009'; #dro# fixed major bug (WikiNames and forced links in names) reported by TWiki:Main.KennethLavrsen; fixed documentation bugs; added INCLUDE expansion (for topics in topic attribute value); added name rendering
#$VERSION = '1.008'; #dro# added new attributes (nwidth,tcwidth,removeatwork,tablecaptionalign,headerformat); performance fixes; allowed digits in the month attribute
#$VERSION = '1.007'; #dro# personal icon support; new attributes (month,year); icon tooltips with dates/person/location/icon; fixed '-' bug
#$VERSION = '1.006'; #dro# added new features (location support; todaybgcolor; todayfgcolor)
#$VERSION = '1.005'; #dro# added new features (startdate support; weekendbgcolor); fixed documentation bugs
#$VERSION = '1.004'; #dro# some performance improvements; code cleanup; documentation
#$VERSION = '1.003'; #dro# fix plugin preferences handling; format column name; rename some subroutines
#$VERSION = '1.002'; #dro# renders some options; fixes: white space bug, documentation bugs; 
#$VERSION = '1.001'; #dro# complete reimplementation of HolidaylistPlugin
#$VERSION = '1.021'; #pj# initial version

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

    $defaultsInitialized = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    eval {
	    $_[0] =~ s/%HOLIDAYLIST%/&handleHolidaylist("", $_[0], $_[1], $_[2])/ge;
	    $_[0] =~ s/%HOLIDAYLIST{(.*?)}%/&handleHolidaylist($1, $_[0], $_[1], $_[2])/ge;
    };
    TWiki::Func::writeWarning("${pluginName}: $@") if $@;


}
# =========================
sub initDefaults() {
	my $webbgcolor = &TWiki::Func::getPreferencesValue("WEBBGCOLOR", $web) || 'white';
	%defaults = (
		days		=> 30,		# days to show
		lang		=> 'English',	# language
		tablecaption	=> '&nbsp;',	# table caption
		cellpadding     => 1,		# table cellpadding 
		cellspacing	=> 0,		# table cellspacing
		border		=> 1,		# table border
		topic		=> "$web.$topic",	# topic with calendar entries
		tableheadercolor=>  $webbgcolor,	# table header color
		tablebgcolor	=> 'white',	# table background color
		workicon => '&nbsp;',		# on work icon (old behavior: ':mad:')
		holidayicon => '8-)',		# on holiday icon
		adayofficon => ':ok:',		# a day off icon
		showweekends	=> 0,		# show weekends with month day and weekday in header and icons in cells
		name 		=> 'Name',	# first cell entry
		weekendbgcolor	=> $webbgcolor, # background color of weekend cells
		startdate	=> undef,	# start date or a day offset
		notatworkicon	=> ':-I',	# not at work icon
		todaybgcolor	=> undef,	# background color for today cells (usefull for a defined startdate)
		todayfgcolor	=> undef,	# foreground color for today cells (usefull for a dark todaybgcolor)
		month		=> undef,	# the month or a offset
		year		=> undef,	# the year or a offset
		tcwidth		=> undef,	# width of the smily cells
		nwidth		=> undef,	# width of the first column
		removeatwork	=> 0,		# removes names without calendar entries from table if set to "1"
		tablecaptionalign=> 'top',	# table caption alignment (top|bottom|left|right)
		headerformat	=> '<font size="-2">%b<br/>%a<br/>%e</font>',	# format of the header
		compatmode	=> 0,		# compatibility mode (allows all CalendarPlugin event types)
		compatmodeicon	=> ':-)' 	# compatibility mode icon
	);

	# reminder: don't forget change documentation (HolidaylistPlugin topic) if you add a new rendered option
	@renderedOptions = ( 'tablecaption', 'name', 'holidayicon', 'adayofficon', 'workicon', 'notatworkicon', 'compatmodeicon' );

	

	%months = ( Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, 
	            Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12 );

	%daysofweek = ( Mon=>1, Tue=>2, Wed=>3, Thu=>4, Fri=>5, Sat=>6, Sun=>7 );

	# some regular expressions:
	$months_rx = join('|', keys %months);
	$dow_rx = join('|', keys %daysofweek);
	$year_rx = "[12][0-9]{3}";
	$monthyear_rx = "($months_rx)\\s+$year_rx";
	$monthyearrange_rx = "$monthyear_rx\\s+\\-\\s+$monthyear_rx";
	$day_rx = "[0-3]?[0-9]";
	$date_rx = "$day_rx\\s+($months_rx)\\s+$year_rx";
	$daterange_rx = "$date_rx\\s*-\\s*$date_rx";
	$bullet_rx = "^\\s+\\*\\s*";
	$bulletdate_rx = "$bullet_rx$date_rx\\s*-";
	$bulletdaterange_rx = "$bulletdate_rx\\s*$date_rx\\s*-";

	$defaultsInitialized = 1;
}
# =========================
sub initOptions() {
	my ($attributes) = @_;

	# Setup options (attributes>plugin preferences>defaults) and render some options:
	foreach $option (keys %defaults) {
		$v = &TWiki::Func::extractNameValuePair($attributes,$option) || undef;
		if (defined $v) {
			$options{$option} = $v;
		} else {
			$v = TWiki::Func::getPluginPreferencesValue("\U$option\E") || undef;
			$options{$option}=(defined $v)? $v : $defaults{$option};
		}

		if (grep(/^\Q$option\E$/, @renderedOptions) && ( $options{$option} !~ /^(\s|\&nbsp\;)*$/ )) {
		 	$options{$option}=&TWiki::Func::renderText($options{$option}, $web);
		}
	}

}
# =========================
sub handleHolidaylist() {
	($attributes, $refText, $theTopic, $theWeb) = @_;

	&initDefaults() unless $defaultsInitialized;

	&initOptions($attributes);

	return &renderHolidaylist(&fetchHolidaylist(&getTopicText()));
}
# =========================
sub getStartDate() {
	my ($yy,$mm,$dd) = Today();

	if (defined $options{startdate}) {
		my $sd = $options{startdate};
		$sd =~ s/^\s*(.*?)\s*$/$1/; # cut whitespaces
		if ($sd =~ /^$date_rx$/) {
			my ($d,$m,$y);
			eval {
				($d,$m,$y) = split(/\s+/, $sd);
				Date_to_Days($y,$months{$m},$d); # fails if startdate is a illegal date
			};
			($dd,$mm,$yy)=($d,$months{$m},$y) unless $@;
		} elsif ($sd =~ /^([\+\-]?\d+)$/) {
			($yy, $mm, $dd) = Add_Delta_Days($yy, $mm, $dd, $1);
		}
	} 
	if (defined $options{year}) {
		my $year = $options{year};
		if ($year =~ /^(\d{4})$/) {
			$yy=$year;
		} elsif ($year =~ /^([\+\-]?\d+)$/) {
			($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, $1, 0);
		} 
	}
	if (defined $options{month}) {
		my $month = $options{month};
		my $matched = 1;
		if ($month=~/^($months_rx)$/) {
			$mm=$months{$1};
		} elsif ($month=~/^([\+\-]\d+)$/) {
			($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, 0, $1);
		} elsif (($month=~/^\d?\d$/)&&($month>0)&&($month<13)) {
			$mm=$month;
		} else {
			$matched = 0;
		}
		if ($matched) {
			$dd=1;
			$options{days}=Days_in_Month($yy, $mm);
		}
	}

	return ($dd,$mm,$yy);
}
# =========================
sub getDays {
	my ($date,$ldom) = @_;
	my $days = undef;

	my ($yy,$mm,$dd);
	if ($date =~ /^$date_rx$/) {
		($dd,$mm,$yy) = split /\s+/, $date;
		$mm = $months{$mm};
	} elsif ($date =~ /^$monthyear_rx$/) {
		($mm, $yy) = split /\s+/, $date;
		$mm = $months{$mm};
		$dd = $ldom? Days_in_Month($yy, $mm) : 1;
	} else {
		return undef;
	}
	$days = check_date($yy,$mm,$dd) ? Date_to_Days($yy,$mm,$dd) : undef;

	return $days;

}
# =========================
sub getTableRefs {
	# cut whitespaces
	$person=~s/\s+$//;

	my $ptableref = $table{$person};
	my $ltableref = $locationtable{$person};
	my $itableref = $icontable{$person};

	if (!defined $ptableref) {
		my @ptable = ();
		$ptableref=\@ptable;
		$table{$person}=$ptableref;
		my @ltable = ();
		$ltableref=\@ltable;
		$locationtable{$person}=$ltableref;
		my @itable = ();
		$itableref=\@itable;
		$icontable{$person}=$itableref;
	}

	return ($ptableref, $ltableref, $itableref);
	
}
# =========================
sub handleDateRange {

	my ($ptableref,$ltableref,$itableref) = getTableRefs();

	my  $date = $startDays;
	for (my $i=0; $i < $options{days}; $i++) {
		next if $$excref[$i];
		if ((($date+$i)>=$start) && (($date+$i)<=$end)) {
			$$ltableref[$i]=$descr;
			if (defined $icon) {
				$$ptableref[$i]=4;
				$$itableref[$i]=$icon;
			} elsif (defined $location) {
				$$ptableref[$i]=3;
			} else {
				$$ptableref[$i]= ($start!=$end) ? 1 : 2;
			}
		}
	}
}
# =========================
sub fetchHolidaylist {
	my ($text) = @_;
	local %table = ( );
	local %locationtable = ( );
	local %icontable = ( );

	local ($dd,$mm,$yy) = &getStartDate();

	local ($startDays) = Date_to_Days($yy,$mm,$dd);
	
	local ($eyy, $emm, $edd) = Add_Delta_Days($yy,$mm,$dd,$options{days});
	local ($endDays) = Date_to_Days($eyy,$emm,$edd); 
	
	local ($line, $descr);
	foreach $line (grep(/$bullet_rx/, split(/\r?\n/, $text))) {
		local ($person, $start, $end, $location, $icon);

		$line =~ s/$bullet_rx//g; 

		$descr = $line;

		local $excref = &fetchExceptions();

		if ( ($line =~ m/^$daterange_rx/) || ($line =~ m/^$monthyearrange_rx/) ) {
			my ($sdate, $edate);
			($sdate,$edate,$person,$location,$icon) = split /\s+\-\s+/, $line, 5;
			($start, $end ) = ( getDays($sdate, 0), getDays($edate, 1) );
			next unless (defined $start) && (defined $end);

			handleDateRange(); 

		} elsif ( ($line =~ m/^$date_rx/) || ($line =~ m/^$monthyear_rx/) ) {
			my $date;
			($date, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
			($start, $end) = ( getDays($date,0), getDays($date,1) );
			next unless (defined $start) && (defined $end);

			handleDateRange();
		} elsif ($options{compatmode}) {
			&handleCalendarEvents();
		}

	}
	return (\%table, \%locationtable, \%icontable);
}
sub fetchExceptions {

	my @exceptions = ( );

	$line =~s /X\s+{\s*([^}]+)\s*}// || return \@exceptions;
	my $ex=$1;


	for $x ( split /\s*\,\s*/, $ex ) {
		my ($start, $end) = (undef, undef);
		if ($x =~ m/^$daterange_rx$/) {
			my ($sdate,$edate) = split /\s*\-\s*/, $x;
			my ($dd1,$mm1,$yy1) = split /\s+/, $sdate;
			my ($dd2,$mm2,$yy2) = split /\s+/, $edate;
			$mm1 = $months{$mm1};
			$mm2 = $months{$mm2};
			$start = Date_to_Days($yy1,$mm1,$dd1) if check_date($yy1,$mm1,$dd1);
			$end = Date_to_Days($yy2,$mm2,$dd2) if check_date($yy2,$mm2,$dd2);

		} elsif ($x =~ m/$date_rx/) {
			my ($dd1,$mm1,$yy1) = split /\s+/, $x;
			$mm1 = $months{$mm1};
			$start = Date_to_Days($yy1,$mm1,$dd1) if check_date($yy1,$mm1,$dd1);
			$end = $start;
		}
		next unless defined $start && ($start <= $endDays);
		next unless defined $end &&   ($end >= $startDays);

		for (my $i=0; $i<$options{days}; $i++) {
			$exceptions[$i] = 1 if ( (($startDays+$i)>=$start) && (($startDays+$i)<=$end) );
		}
	}

	return \@exceptions;
}
sub handleCalendarEvents {
	my ($strdate);

	if  ($line =~ m/^A\s+$date_rx/) {
		### Yearly: A dd MMM yyyy
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = getTableRefs();
		$strdate=~s/^A\s+//;
		my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};

		return unless check_date($yy1, $mm1, $dd1);

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			
			if (($mm1==$m) && ($dd1==$d)) {
				$$ptableref[$i] = 5;
				$$ltableref[$i] = $descr . ' ('.($y-$yy1).')';
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^$day_rx\s+($months_rx)/) {
		## Interval: dd MMM
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = getTableRefs();
		my ($dd1, $mm1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if (($mm1==$m)&&($dd1==$d)) {
				$$ptableref[$i] = 5;
				$$ltableref[$i] = $descr;
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^[0-9L]\s+($dow_rx)(\s+($months_rx))?/) {
		### Interval: w DDD MMM 
		### Interval: L DDD MMM 
		### Monthly: w DDD
		### Monthly: L DDD

		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = getTableRefs();
		my ($n1,$dow1,$mm1) = split /\s+/, $strdate;
		$dow1 = $daysofweek{$dow1};
		$mm1 = $months{$mm1} if defined $mm1;

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if ((! defined $mm1) || ($m == $mm1)) {
				my ($yy2,$mm2,$dd2);
				if ($n1 == 'L') {
					$n1 = 6;
					do {
						$n1--;
						($yy2, $mm2, $dd2)=Nth_Weekday_of_Month_Year($y, $m, $dow1, $n1); 
					} until ($yy2);
				} else {
					eval { # may fail with a illegal factor
						($yy2, $mm2, $dd2) = Nth_Weekday_of_Month_Year($y, $m, $dow1, $n1);
					};
					next if $@;
				}

				if (($dd2)&&($dd2==$d)) {
					$$ptableref[$i] = 5;
					$$ltableref[$i] = $descr;
					$$itableref[$i] = $icon;
				}
			}
		}
	} elsif ($line =~ m/^$day_rx\s+/) {
		### Monthly: dd
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = getTableRefs();
		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if ($strdate == $d) {
				$$ptableref[$i] = 5;
				$$ltableref[$i] = $descr;
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^E\s+($dow_rx)/) {
		### Monthly: E DDD dd MMM yyy - dd MMM yyyy
		### Monthly: E DDD dd MMM yyy
		### Monthly: E DDD

		my $strdate2 = undef;
		if ($line =~ m/^E\s+($dow_rx)\s+$daterange_rx/) {
			($strdate, $strdate2, $person, $location, $icon) = split /\s+\-\s+/, $line, 5;
		} else {
			($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		}
		$strdate=~s/^E\s+//;
		my ($dow1) = split /\s+/, $strdate;
		$dow1=$daysofweek{$dow1};

		$strdate=~s/^($dow_rx)\s+//g;

		my ($start, $end) = (undef, undef);
		if ((defined $strdate)&&($strdate != "")) {
			$start = getDays($strdate);
			return unless defined $start;
		}

		if (defined $strdate2) {
			$end = getDays($strdate2);
			return unless defined $end;
		}

		return if (defined $start) && ($start > $endDays);
		return if (defined $end) && ($end < $startDays);

		my ($ptableref,$ltableref,$itableref) = getTableRefs();	
		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			my $date = Date_to_Days($y,$m,$d);
			my $dow = Day_of_Week($y, $m, $d);
			if ( ($dow==$dow1)
			    && ( (!defined $start) || ($date>=$start) )
			    && ( (!defined $end)   || ($date<=$end) )
			   ) {
				$$ptableref[$i] = 5;
				$$ltableref[$i] = $descr;
				$$itableref[$i] = $icon;
			}
		}

	} elsif ($line =~ m/^E\d+\s+$date_rx/) {
		### Periodic: En dd MMM yyyy - dd MMM yyyy
		### Periodic: En dd MMM yyyy
		my $strdate2 = undef;
		if ($line =~ m/^E\d+\s+$daterange_rx/) {
			($strdate, $strdate2, $person, $location, $icon) = split /\s+\-\s+/, $line, 5;
		} else {
			($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		}
		my ($ptableref,$ltableref,$itableref) = getTableRefs();

		$strdate=~s/^E//;
		my ($n1) = split /\s+/, $strdate;

		return unless $n1 > 0;

		$strdate=~s/^\d+\s+//;

		($start, $end) = (undef, undef);
		my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};

		$start = getDays($strdate);
		return unless defined $start;

		$end = getDays($strdate2) if defined $strdate2;
		return if (defined $strdate2)&&(!defined $end);

		return if (defined $start) && ($start > $endDays);
		return if (defined $end) && ($end < $startDays);

		($yy1, $mm1, $dd1) = Add_Delta_Days($yy1, $mm1, $dd1, 
			$n1 * int( (abs($startDays-$start)/$n1) + ($startDays-$start!=0?1:0) ) );
		$start = Date_to_Days($yy1, $mm1, $dd1);

		# start at first occurence and increment by repeating count ($n1)
		for (my $i=(abs($startDays-$start) % $n1); $i < $options{days}; $i+=$n1) {
			next if $$excref[$i];
			if ((!defined $end) || ( ($startDays+$i) <= $end) ) {
				$$ptableref[$i] = 5;
				$$ltableref[$i] = $descr;
				$$itableref[$i] = $icon;

				$start += $n1;
			} else {
				last;
			}
		} # for
	} # if

} # sub handleCalendarEvents
# =========================
sub mystrftime($$$) {
	my ($yy,$mm,$dd) = @_;
	my $text = $options{headerformat};

	my $dow = Day_of_Week($yy,$mm,$dd);
	my $t_dow=  Day_of_Week_to_Text($dow);
	my $t_mm = Month_to_Text($mm);
	my $doy = Day_of_Year($yy,$mm,$dd);
	my $wn = Week_Number($yy,$mm,$dd);
	my $t_wn = $wn<10?"0$wn":$wn;

	my $y = substr("$yy",-2,2);

	my %tmap = (
			'%a'	=> substr($t_dow, 0, 2), '%A'	=> $t_dow,
			'%b'	=> substr($t_mm,0,3), '%B'	=> $t_mm,
			'%c'	=> Date_to_Text_Long($yy,$mm,$dd), '%C'	=> This_Year(),
			'%d'	=> $dd<10?"0$dd":$dd, '%D' => "$mm/$dd/$yy",
			'%e'	=> $dd,
			'%F'	=> "$yy-$mm-$dd",
			'%g'	=> $y, '%G' => $yy,
			'%h'	=> substr($t_mm,0,3),
			'%j'	=> ($doy<100)? (($doy<10)?"00$doy":"0$doy") : $doy,
			'%m'	=> ($mm<10)?"0$mm":$mm,
			'%n'	=> '<br/>',
			'%t'	=> "<code>\t</code>",
			'%u'	=> $dow, '%U' => $t_wn,
			'%V'	=> $t_wn,
			'%w'	=> $dow-1, '%W'	=> $t_wn,
			'%x'	=> Date_to_Text($yy,$mm,$dd),
			'%y'	=> $y,	'%Y' => $yy,
			'%%'	=> '%'
		);
	
	# replace all known conversion specifiers:
	$text =~ s/(%[a-z\%\+]?)/(defined $tmap{$1})?$tmap{$1}:$1/ieg;

	return $text;
}
# =========================
sub renderHolidaylist() {
	my ($tableRef, $locationTableRef, $iconTableRef) = @_;
	my $text = "";

	Date::Calc::Language(Date::Calc::Decode_Language($options{lang}));

	my ($ty,$tm,$td) = Today();
	my $today = Date_to_Days($ty,$tm,$td);

	# create table header:
	
	$text .= '<noautolink><table border="'.$options{border}.'"'
               . ' cellpadding="'.$options{cellpadding}.'"'
               . ' cellspacing="'.$options{cellspacing}.'"'
	       . ' bgcolor="'.$options{tablebgcolor}.'"'
	       .  '>' 
	       . "\n" ;

	$text .= '<caption align="'.$options{tablecaptionalign}.'"><noautolink>'.$options{tablecaption}.'</noautolink></caption>'."\n";

	$text .= '<tr bgcolor="'.$options{tableheadercolor}.'">';
	$text .= '<th align="left"'.(defined $options{nwidth}?' width="'.$options{nwidth}.'"':'').'>'
			.'<noautolink>'
			.$options{name}
			.'</noautolink>'
			.'</th>';

	my ($dd,$mm,$yy) = getStartDate();

	for (my $i=0; $i< $options{days}; $i++) {
		my ($yy1,$mm1,$dd1) = Add_Delta_Days($yy, $mm, $dd, $i);
		my $dow = Day_of_Week($yy1,$mm1,$dd1);
		my $date = Date_to_Days($yy1, $mm1, $dd1);

		my $bgcolor = $options{tableheadercolor};
		$bgcolor=$options{weekendbgcolor} unless $dow < 6;
		$bgcolor=$options{todaybgcolor} if (defined $options{todaybgcolor})&&($today == $date);
		
		$text.='<th align="center" bgcolor="'.$bgcolor.'"'
			. (((defined $options{tcwidth})&&(($dow<6)||$options{showweekends}))?' width="'.$options{tcwidth}.'"':'')
		        .((($today==$date)&&(defined $options{todayfgcolor}))?' style="color:' . $options{todayfgcolor} . '"' : '') .'>';
		$text.='<noautolink>';
		if (($dow < 6)|| $options{showweekends}) { 
			$text .= &mystrftime($yy1,$mm1,$dd1);
		} else {
			$text .= '&nbsp;';
		}
		$text.='</noautolink>';
		$text.='</th>';
	}

	$text .= "</tr>\n";

	# create table with names and dates:

	my %iconstates = ( 0 => $options{workicon},
                           1 => $options{holidayicon},
			   2 => $options{adayofficon},
			   3 => $options{notatworkicon},
			   4 => $options{notatworkicon},
			   5 => $options{compatmodeicon}
			);


	foreach my $person (sort keys %{$tableRef}) {
		my $ptableref=$$tableRef{$person};
		my $ltableref=$$locationTableRef{$person};
		my $itableref=$$iconTableRef{$person};

		# ignore table rows without a entry if removeatwork == 1
		next if $options{removeatwork} && !grep(/[^0]+/, join('', map( $_ || 0, @{$ptableref})));

		$text .= '<tr><th align="left"><noautolink>'.TWiki::Func::renderText($person,$web).'</noautolink></th>';
		for (my $i=0; $i<$options{days}; $i++) {
			my ($yy1, $mm1, $dd1) = Add_Delta_Days($yy, $mm, $dd, $i);
			my $dow = Day_of_Week($yy1, $mm1, $dd1);

			my $bgcolor = $options{tablebgcolor};
			$bgcolor = $options{weekendbgcolor} unless $dow < 6;
			$bgcolor = $options{todaybgcolor} if (defined $options{todaybgcolor}) && ($today == Date_to_Days($yy1, $mm1, $dd1));

			$text.= '<td align="center" bgcolor="'.$bgcolor.'"><noautolink>';

                        if (($dow < 6)||$options{showweekends}) { 
				my $icon= $iconstates{ defined $$ptableref[$i]?$$ptableref[$i]:0};
				if (defined $$itableref[$i]) {
					$icon = $$itableref[$i];
					$icon = TWiki::Func::renderText($icon, $web) if $icon !~ /^(\s|\&nbsp\;)*$/;
				}
				# could fail if HTML::Entities is not installed:
				eval { 
					my $location = $$ltableref[$i] if defined $ltableref;
					if (defined $location) {

						$location=encode_entities($location); # quote special characters like "<>

						$location=~s/\[\[/!\[\[/g; # quote forced links
						$location=~s/[A-Z][a-z0-9]+[\.\/]([A-Z])/$1/g; # delete Web names
						$location=~s/([A-Z][a-z]+\w*[A-Z][a-z0-9]+)/!$1/g; # quote WikiNames
						$location=~s/\%\w+(\{[^\}\%]*\})?\%//g; # delete Vars

						$icon=~s/(<img[^>]+alt=")[^">]+("[^>]*>)/$1$location$2/is;
						$icon=~s/(<img[^>]+title=")[^">]+("[^>]*>)/$1$location$2/is;
					}
				};
				$text.= $icon;
			} else {
				$text.= '&nbsp;';
			}
                        $text.= '</noautolink></td>';
		}
		$text .= "</tr>\n";
	}
	$text .= '</table></noautolink>';

	return $text;
}
### dro: following code is derived from TWiki:Plugins.CalendarPlugin:
# =========================
sub getTopicText() {

	my ($web, $topic);

	my $topics = $options{topic};
	my @topics = split /,\s*/, $topics;

	my @processedTopics = ( );

	my $text = "";
	foreach my $topicpair (@topics) {
		if ($topicpair =~ m/([^\.]+)\.([^\.]+)/) {
			($web, $topic) = ($1, $2);
		} else {
			$web = $theWeb;
			$topic = $topicpair;
		}

		# ignore processed topics;
		grep( /^\Q$web.$topic\E$/, @processedTopics ) && next;

		push(@processedTopics, "$web.$topic");

		if (($topic eq $theTopic) && ($web eq $theWeb)) {
			# use current text so that preview can show unsaved events
			$text .= $refText;
		} else {
			$text .= &readTopicText($web, $topic);
		}
	}

	$text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents($1, \@processedTopics)/geo;
	
	return $text;
	
}

# =========================
sub readTopicText
{
	my( $theWeb, $theTopic ) = @_;
	my $text = '';
	if( $TWiki::Plugins::VERSION >= 1.010 ) {
		$text = &TWiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
	} else {
		$text = &TWiki::Func::readTopic( $theWeb, $theTopic );
	}
	# return raw topic text, including meta data
	return $text;
}
# =========================
sub expandIncludedEvents
{
	my( $theAttributes, $theProcessedTopicsRef ) = @_;

	my ($theWeb, $theTopic) = ($web, $topic);

	my $webTopic = &TWiki::Func::extractNameValuePair( $theAttributes );
	if( $webTopic =~ /^([^\.]+)[\.\/](.*)$/ ) {
		$theWeb = $1;
		$theTopic = $2;
	} else {
		$theTopic = $webTopic;
	}

	# prevent recursive loop
	grep (/^\Q$theWeb.$theTopic\E$/, @{$theProcessedTopicsRef}) and return "";

	push( @{$theProcessedTopicsRef}, "$theWeb.$theTopic" );

	my $text = &readTopicText( $theWeb, $theTopic );

	$text =~ s/.*?%STARTINCLUDE%//s;
	$text =~ s/%STOPINCLUDE%.*//s;

	# recursively expand includes
	$text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $theProcessedTopicsRef )/geo;

	$text = TWiki::Func::expandCommonVariables($text, $theTopic, $theWeb);

	return $text;
}

1;
