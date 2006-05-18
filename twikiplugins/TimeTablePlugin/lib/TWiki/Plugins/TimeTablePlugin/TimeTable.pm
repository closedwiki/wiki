# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::TimeTablePlugin::TimeTable;

use strict;
use warnings;

use CGI;
use Date::Calc qw(:all);

use vars qw( $session $theTopic $theWeb $topic $web $attributes $text $refText
             $defaultsInitialized %defaults %options @renderedOptions @flagOptions %months %daysofweek
	     @processedTopics @unknownParams
	     $months_rx $date_rx $daterange_rx $bullet_rx $bulletdate_rx $bulletdaterange_rx $dow_rx $day_rx
	     $year_rx $monthyear_rx $monthyearrange_rx
	     $hour_rx $minute_rx $am_rx $pm_rx $ampm_rx $time_rx $timerange_rx
	     $dowrange_rx $dowlist_rx


	 );

BEGIN {
	$defaultsInitialized = 0;
};

sub expand {
	($attributes, $text, $topic, $web) = @_;
	$refText = $text; $theWeb=$web; $theTopic=$topic;

	&_initDefaults() unless $defaultsInitialized;

	return &_createUnknownParamsMessage() unless &_initOptions($attributes);

        &_initRegexs(); 

        return &_render(&_fetch(&_getTopicText()));


}
sub _initDefaults {
	%defaults = (
		tablecaption => "Timetable",	# table caption
		lang => 'English',		# default language
		topic => "$web.$topic",		# topic with dates
		startdate => undef,		# a start date
		starttime => '7:00',		# a start time
		endtime => '20:00',		# a end time
		timeinterval => '30',		# time interval in minutes
		month => undef,
		year => undef,
		daynames => undef,
		monthnames => undef,
		headerformat => '<font size="-2">%a</font>',
		showweekend => 1		# show weekend
	);

	@renderedOptions = ('tablecaption');
	@flagOptions = ( 'showweekend' );


        %months = ( Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, 
                    Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12 );

        %daysofweek = ( Mon=>1, Tue=>2, Wed=>3, Thu=>4, Fri=>5, Sat=>6, Sun=>7 );

        $defaultsInitialized = 1;

}
sub _initRegexs {
        # some regular expressions:
        $months_rx = join('|', map(quotemeta($_), keys(%months)));
        $dow_rx = join('|', map(quotemeta($_), keys(%daysofweek)));
        $year_rx = "[12][0-9]{3}";
        $monthyear_rx = "($months_rx)\\s+$year_rx";
        $monthyearrange_rx = "$monthyear_rx\\s+\\-\\s+$monthyear_rx";
        $day_rx = "[0-3]?[0-9](\.|th)?";
        $date_rx = "$day_rx\\s+($months_rx)\\s+$year_rx";
        $daterange_rx = "$date_rx\\s*-\\s*$date_rx";
        $bullet_rx = "^\\s+\\*\\s*";
        $bulletdate_rx = "$bullet_rx$date_rx\\s*-";
        $bulletdaterange_rx = "$bulletdate_rx\\s*$date_rx\\s*-";

	$hour_rx = "([0-1]?[0-9]|2[0-4])";
	$minute_rx = "[0-5]?[0-9]";
	$am_rx = "[aA]\\.?[mM]\\.?";
	$pm_rx = "[pP]\\.?[mM]\\.?";
	$ampm_rx = "($am_rx|$pm_rx)";
	
	$time_rx = "$hour_rx([\.:]$minute_rx)?$ampm_rx?";
	$timerange_rx="$time_rx\\s*-\\s*$time_rx";

	$dowrange_rx="($dow_rx)\\s*-\\s*($dow_rx)";
	$dowlist_rx="($dow_rx)((\\s*,\\s*)($dow_rx))";
}

sub _initOptions {
        my ($attributes) = @_;

	TWiki::Func::writeWarning("_initOptions($attributes)");

        my %params = &TWiki::Func::extractParameters($attributes);

        my @allOptions = keys %defaults;
        # Check attributes:
        @unknownParams= ( );
        foreach my $option (keys %params) {
                push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
        }
        return 0 if $#unknownParams != -1; 

        # Setup options (attributes>plugin preferences>defaults):
        %options= ();
        foreach my $option (@allOptions) {
                my $v = $params{$option};
                if (defined $v) {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $options{$option} = ($v!=0)&&($v!~/no/i)&&($v!~/off/i);
                        } else {
                                $options{$option} = $v;
                        }
                } else {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $v = TWiki::Func::getPluginPreferencesFlag("\U$option\E") || undef;
                        } else {
                                $v = TWiki::Func::getPluginPreferencesValue("\U$option\E") || undef;
                        }
                        $options{$option}=(defined $v)? $v : $defaults{$option};
                }

        }
        # Render some options:
        foreach my $option (@renderedOptions) {
                if ($options{$option} !~ /^(\s|\&nbsp\;)*$/) {
                        $options{$option}=&TWiki::Func::renderText($options{$option}, $web);
                }
        }

        Date::Calc::Language(Date::Calc::Decode_Language($options{lang}));

        # Setup language specific month and day names:
        for (my $i=1; $i < 13; $i++) {
                if ($i < 8) {
                        my $dt = Day_of_Week_to_Text($i);
                        $daysofweek{$dt} = $i;
                        $daysofweek{Day_of_Week_Abbreviation($i)} = $i;
                        $daysofweek{substr($dt, 0, 2)} = $i;
                }
                my $mt = Month_to_Text($i);
                $months{$mt} = $i;
                $months{substr($mt,0,3)} = $i;
        }

        # Setup user defined daynames:
        if ((defined $options{daynames}) && (defined $defaults{daynames}) && ($options{daynames} ne $defaults{daynames})) {
                my @dn = split /\s*\|\s*/, $options{daynames};
                if ($#dn == 6) {
                        for (my $i=1; $i<8; $i++) {
                                $daysofweek{$dn[$i-1]}=$i;
                        }
                }
        }
        # Setup user defined monthnames:
        if ((defined $options{monthnames}) && (defined $defaults{monthnames}) && ($options{monthnames} ne $defaults{monthnames})) {
                my @mn = split /\s*\|\s*/, $options{monthnames};
                if ($#mn == 11) {
                        for (my $i=1; $i<13; $i++) {
                                $months{$mn[$i-1]} = $i;
                        }       
                }
        }

        @processedTopics = ( );
        return 1;



}
sub _getTime {
	my ($strtime) = @_;
	
	$strtime =~ s/^(\d+)(:(\d+))?//;
	my ($hh,$mm)=($1,$3);
	$mm = 0 unless $mm;

	$strtime =~ m/($ampm_rx)/;
	my ($ampm) = $1;
	$hh+=12 if ($ampm =~ m/$pm_rx/);

	return $hh*60+$mm;
}
sub _fetch {

	my ($text) = @_;
	my %entries = ();

	foreach my $line (grep(/$bullet_rx/, split(/\r?\n/, $text))) {

		$line =~ s/$bullet_rx//g; 

		if ($line =~ m/^$dowrange_rx\s+\-\s+$timerange_rx/ ) {
			### DOW - DOW - hh:mm - hh:mm
			my ($startdow,$enddow,$starttime,$endtime, $descr,$color) = split /\s+\-\s+/, $line, 6;

			$startdow=$daysofweek{$startdow};
			$enddow=$daysofweek{$enddow};
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			for (my $dow = $startdow; $dow<=$enddow; $dow++) {
				push @{$entries{$dow}}, { 'starttime' => $starttime, 'endtime' => $endtime, 'descr' => $descr , 'color'=>$color};
			}

		} elsif ($line =~ m/^$dow_rx\s+\-\s+$timerange_rx/ ) {
			### DOW - hh:mm - hh:mm
			my ($dow,$starttime,$endtime,$descr,$color) = split /\s+\-\s+/, $line, 5;
			$dow=$daysofweek{$dow};
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			push @{$entries{$dow}}, { 'starttime' => $starttime, 'endtime' => $endtime, 'descr'=>$descr,'color'=>$color };

		} elsif ($line =~m /^$dowlist_rx\s+\-\s+$timerange_rx/ ) {
			my ($dowlist,$starttime,$endtime,$descr,$color) = split /\s+\-\s+/, $line, 5;
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			my @dowlistarr = split /\s*\,\s*/, $dowlist;
			foreach my $dow (@dowlistarr) {
				push @{$entries{$dow}}, { 'starttime'=>$starttime,  'endtime' => $endtime, 'descr'=>$descr,'color'=>$color };
			}
		}



	}
	

	return \%entries;
}

sub _render {
	my ($entries_ref) = @_;

	my ($yy,$mm,$dd, $week);

	($yy,$mm,$dd)=Today();
	($week,$yy)=Week_of_Year($yy,$mm,$dd);
	($yy,$mm,$dd)=Monday_of_Week($week,$yy);

	my $text = "";
	my $cgi = new CGI;

	my($tr,$td);
	$text .= '<font size="-2">';
	$text .= $cgi->start_table({-bgcolor=>"#aaaaaa", -cellpadding=>'0',-cellspacing=>'1', -id=>'timeTablePluginTable'});
	$text .= $cgi->caption($options{'tablecaption'});

	### render weekday header:
	$tr=$cgi->td("&nbsp;"); ### XXX option! 
	for (my $dow = 0; $dow < 7; $dow++) {
		next if ($options{'showweekend'}==0)&&($dow>4);
		my ($yy1,$mm1,$dd1)= Add_Delta_Days($yy,$mm,$dd,$dow);
		$tr .= $cgi->td({-bgcolor=>"#33CC66",-valign=>"top", -align=>"center"},&_mystrftime($yy1,$mm1,$dd1));
	}
	$text .= $cgi->Tr($tr);
	$text .= "\n";

	### render time list:
	$tr = "";
	###$td = $cgi->start_table({-rules=>"rows",-border=>'1',-cellpadding=>'0',-cellspacing=>'0'});
	$td = $cgi->start_table({-bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1'});
	my ($starttime,$endtime) = ( &_getTime($options{'starttime'}), &_getTime($options{'endtime'}));
	for (my $min=$starttime; $min <=$endtime ; $min+=$options{'timeinterval'}) {
		$td .= $cgi->Tr($cgi->td({-bgcolor=>"#33CC66", -align=>"right"},&_renderTime($min)));
		$td .= "\n";
	}
	$td .= $cgi->end_table();
	$tr.=$cgi->td({-valign=>"top"},$td);

	### render timetable:
	for (my $dow = 0; $dow < 7; $dow++) {
		next if ($options{'showweekend'}==0)&&($dow>4);
		my $dowentries_ref = $$entries_ref{$dow+1};
		if (! defined $dowentries_ref) {
			$tr.=$cgi->td("&nbsp;");
			next;
		}
		###$td = $cgi->start_table({-rules=>"rows", -border=>"1",-cellpadding=>'0',-cellspacing=>'0', -tableheight=>"100%"});
		$td = $cgi->start_table({-nowrap=>1, -bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1', -tableheight=>"100%"});
		my ($itr, $itd);
		my $fillRows = 0;
		for (my $min=$starttime; $min <=$endtime; $min+=$options{'timeinterval'}) {
			my $mentries = &_getMatchingEntries($dowentries_ref, $min, $options{'timeinterval'}, $starttime);
			$itr="";
			if ($#$mentries>-1) {
				my $rs;
				foreach my $mentry_ref ( @{$mentries})  {
					$fillRows=&_countConflicts($mentry_ref,$dowentries_ref)-$#$mentries;
					$rs= _getEntryRows($mentry_ref, $min, $endtime, $options{'timeinterval'});
					my ($mst,$met) = ($$mentry_ref{'starttime'},$$mentry_ref{'endtime'});
					$itr.=$cgi->td({-valign=>"top",
							-bgcolor=>$$mentry_ref{'color'}?$$mentry_ref{'color'}:"#aaaaaa",
							-rowspan=>$rs+$fillRows}, 
							$$mentry_ref{'descr'}
							.($rs==1?'':' <font size="-2">'.&_renderTime($mst).'-'.&_renderTime($met).'</font>')
							);
				}
				$td .=$cgi->Tr($itr)."\n";
				$itr=$cgi->td('&nbsp;');
				##$itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;');
				$td .=$cgi->Tr($itr)."\n";	
			} else {
				## $itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;');
				$itr=$cgi->td("&nbsp;");
				$td .=$cgi->Tr($itr)."\n";
			}
		}
		$td .= $cgi->end_table();
		if ($dow>5) {
			 $tr.=$cgi->td({-bgcolor=>"#33CC66", -valign=>"top"},$td);
		} else {
			$tr.=$cgi->td({-valign=>"top"},$td);
		}


	}
	$td = $cgi->start_table({-bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1'});
	####my ($starttime,$endtime) = ( &_getTime($options{'starttime'}), &_getTime($options{'endtime'}));
	for (my $min=$starttime; $min <=$endtime ; $min+=$options{'timeinterval'}) {
		$td .= $cgi->Tr($cgi->td({-bgcolor=>"#33CC66", -align=>"right"},&_renderTime($min)));
		$td .= "\n";
	}
	$td .= $cgi->end_table();
	$tr.=$cgi->td({-valign=>"top"},$td);

	$text.= $cgi->Tr($tr);


	$text .= $cgi->end_table();
	$text .= '</font>';


	return $text;
}
sub _countConflicts {
	my ($entry_ref, $entries_ref) = @_;
	my $c=0;
	my ($sd1,$ed1) = ($$entry_ref{'starttime'},$$entry_ref{'endtime'});
	foreach my $e (@{$entries_ref}) {
		my ($sd2,$ed2) = ($$e{'starttime'},$$e{'endtime'});
		$c++ if (($sd2 >=$sd1) && ($sd2<$ed1));
	}
	return $c;
}
sub _renderTime {
	return sprintf("%02d",int($_[0]/60)).":".sprintf("%02d",int($_[0] % 60))
}
sub _getEntryRows {
	my ($entry_ref, $time, $maxtime, $interval) = @_;
	my ($rows)=1;
	my ($starttime,$endtime)=($$entry_ref{'starttime'}, $$entry_ref{'endtime'});

	$starttime=$time if $starttime<$time;
	$endtime=$maxtime+$interval+1 if $endtime>$maxtime;
	$rows=sprintf("%d",(abs($endtime-$starttime+$interval-1)/$interval));

	return $rows>=1?$rows:1;
}
sub _getMatchingEntries {
	my ($entries_arrref, $time, $interval, $starttime) = @_;
	my (@matches);
	foreach my $entryref ( @{$entries_arrref} ) {
		my $stime = $$entryref{'starttime'};
		my $etime = $$entryref{'endtime'};
		push(@matches, $entryref) 
			if (($stime >= $time) && ($stime < $time+$interval))
				|| (($time==$starttime)&&($stime<$time)&&($etime>$starttime))
		;
	}
	@matches = sort { $$b{'endtime'} <=> $$a{'endtime'} } @matches;
	return \@matches;
}
sub _getStartDate() {
        my ($yy,$mm,$dd) = Today();

        # handle startdate (absolute or offset)
        if (defined $options{startdate}) {
                my $sd = $options{startdate};
                $sd =~ s/^\s*(.*?)\s*$/$1/; # cut whitespaces
                if ($sd =~ /^$date_rx$/) {
                        my ($d,$m,$y);
                        ($d,$m,$y) = split(/\s+/, $sd);
                        ($dd, $mm, $yy) = ($d, $months{$m},$y) if check_date($y, $months{$m},$d);
                } elsif ($sd =~ /^([\+\-]?\d+)$/) {
                        ($yy, $mm, $dd) = Add_Delta_Days($yy, $mm, $dd, $1);
                }
        } 
        # handle year (absolute or offset)
        if (defined $options{year}) {
                my $year = $options{year};
                if ($year =~ /^(\d{4})$/) {
                        $yy=$year;
                } elsif ($year =~ /^([\+\-]?\d+)$/) {
                        ($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, $1, 0);
                } 
        }
        # handle month (absolute or offset)
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
sub _mystrftime($$$) {
        my ($yy,$mm,$dd) = @_;
        my $text = $options{headerformat};

        my $dow = Day_of_Week($yy,$mm,$dd);
        my $t_dow =  undef;
        if (defined $options{daynames}) {
                my @dn = split  /\|/, $options{daynames};
                $t_dow = $dn[$dow-1] if $#dn == 6;
        }
        $t_dow = Day_of_Week_to_Text($dow) unless defined $t_dow;

        my $t_mm = undef;; 
        if (defined $options{monthnames}) {
                my @mn = split /\|/, $options{monthnames};
                $t_mm = $mn[$mm-1] if $#mn == 11;
        }
        $t_mm = Month_to_Text($mm) unless defined $t_mm;

        my $doy = Day_of_Year($yy,$mm,$dd);
        my $wn = Week_Number($yy,$mm,$dd);
        my $t_wn = $wn<10?"0$wn":$wn;

        my $y = substr("$yy",-2,2);

        my %tmap = (
                        '%a'    => substr($t_dow, 0, 2), '%A'   => $t_dow,
                        '%b'    => substr($t_mm,0,3), '%B'      => $t_mm,
                        '%c'    => Date_to_Text_Long($yy,$mm,$dd), '%C' => This_Year(),
                        '%d'    => $dd<10?"0$dd":$dd, '%D' => "$mm/$dd/$yy",
                        '%e'    => $dd,
                        '%F'    => "$yy-$mm-$dd",
                        '%g'    => $y, '%G' => $yy,
                        '%h'    => substr($t_mm,0,3),
                        '%j'    => ($doy<100)? (($doy<10)?"00$doy":"0$doy") : $doy,
                        '%m'    => ($mm<10)?"0$mm":$mm,
                        '%n'    => '<br/>',
                        '%t'    => "<code>\t</code>",
                        '%u'    => $dow, '%U' => $t_wn,
                        '%V'    => $t_wn,
                        '%w'    => $dow-1, '%W' => $t_wn,
                        '%x'    => Date_to_Text($yy,$mm,$dd),
                        '%y'    => $y,  '%Y' => $yy,
                        '%%'    => '%'
                );
        
        # replace all known conversion specifiers:
        $text =~ s/(%[a-z\%\+]?)/(defined $tmap{$1})?$tmap{$1}:$1/ieg;

        return $text;
}



### dro: following code is derived from TWiki:Plugins.CalendarPlugin:
# =========================
sub _getTopicText() {

        my ($web, $topic);

        my $topics = $options{topic};
        my @topics = split /,\s*/, $topics;

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
                        $text .= &_readTopicText($web, $topic);
                }
        }

        $text =~ s/%INCLUDE{(.*?)}%/&_expandIncludedEvents($1, \@processedTopics)/geo;
        
        return $text;
        
}

# =========================
sub _readTopicText
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
sub _expandIncludedEvents
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
        $text =~ s/%INCLUDE{(.*?)}%/&_expandIncludedEvents( $1, $theProcessedTopicsRef )/geo;

        ## $text = TWiki::Func::expandCommonVariables($text, $theTopic, $theWeb);

        return $text;
}


1;

