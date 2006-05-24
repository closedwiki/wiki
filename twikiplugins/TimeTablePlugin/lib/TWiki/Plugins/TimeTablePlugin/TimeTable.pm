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
###use warnings;


use CGI;
use Date::Calc qw(:all);

use vars qw( $session $theTopic $theWeb $topic $web $attributes $text $refText
             $defaultsInitialized %defaults %options @renderedOptions @flagOptions %months %daysofweek
	     @processedTopics @unknownParams
	     $months_rx $date_rx $daterange_rx $bullet_rx $bulletdate_rx $bulletdaterange_rx $dow_rx $day_rx
	     $year_rx $monthyear_rx $monthyearrange_rx
	     $hour_rx $minute_rx $am_rx $pm_rx $ampm_rx $time_rx $timerange_rx
	     $dowrange_rx $dowlist_rx
	     $cgi $pluginName
	 );

$pluginName = "TimeTablePlugin";
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
sub inflate {
	my ($attributes, $text, $topic, $web) = @_;

	my ($starttime, $endtime, $fgcolor, $bgcolor) = &_getTTCMValues($attributes);

	&_initDefaults() unless $defaultsInitialized;
	return &_createUnknownParamsMessage() unless &_initOptions('');

	my $cgi = new CGI;

	my $title = &_renderTime($starttime,"12pm").'-'.&_renderTime($endtime,"12pm")
			.' / '.&_renderTime($starttime,24).'-'.&_renderTime($endtime,24);

	$fgcolor='' unless defined $fgcolor;
	$bgcolor='' unless defined $bgcolor;

	return $cgi->span(
			{
				-style=>"color:$fgcolor;background-color:$bgcolor",
				-title=>$title
			}, &_renderTime($starttime).'-'.&_renderTime($endtime));
}
sub _getTTCMValues {
	my ($attributes) = @_;
	my $textattr = &TWiki::Func::extractNameValuePair($attributes);

	my ($timerange, $fgcolor, $bgcolor) = split /\s*\,\s*/, $textattr;
	if (!$bgcolor) {
		$bgcolor = $fgcolor;
		$fgcolor = undef;
	}

	my ($starttime,$endtime) = split /-/,$timerange;
	($starttime,$endtime) = (&_getTime($starttime), &_getTime($endtime));

	return ($starttime, $endtime, $fgcolor, $bgcolor);

}
sub _initDefaults {
	my $webbgcolor = &TWiki::Func::getPreferencesValue("WEBBGCOLOR", $web) || '#33CC66';
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
		showweekend => 1,		# show weekend
		descrlimit => 10,		# per line description text limit
		showtimeline => 'both',		# 
		tableheadercolor => $webbgcolor,#
		eventbgcolor => '#AAAAAA',	#
		eventfgcolor => 'black',	#
		name => '&nbsp;',		# content of the first cell
		weekendbgcolor => $webbgcolor,	#
		weekendfgcolor => 'black',	#
		tablebgcolor => 'white',	# table background color
		timeformat => '24', 		# timeformat 12 or 24
		unknownparamsmsg => '%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMS LIST% %ENDCOLOR% <br/> Allowed parameters are (see TWiki.$pluginName topic for more details): %KNOWNPARAMSLIST%',
		displaytime => 0,		# display time in description
		workingstarttime => '9:00',	# 
		workingendtime => '17:00',
		workingbgcolor => 'white',	
		workingfgcolor => 'black',
		compatmode => 0, 		# compatibility mode
		cmheaderformat => '<font size="-2">%b<br/>%a<br/>%e</font>',   # format of the header
                todaybgcolor    => undef,       # background color for today cells (usefull for a defined startdate)
                todayfgcolor    => undef,       # foreground color for today cells (usefull for a dark todaybgcolor)
		days	=> 7,			# XXX for later use
	);

	@renderedOptions = ('tablecaption', 'name');
	@flagOptions = ( 'compatmode', 'showweekend', 'displaytime' );


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
                                $v = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_\U$option\E") || undef;
                        } else {
                                $v = &TWiki::Func::getPreferencesValue("\U$pluginName\E_\U$option\E") || undef;
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

	$cgi = CGI->new();
        return 1;



}
sub _getTime {
	my ($strtime) = @_;

	return undef unless defined $strtime;
	
	$strtime =~ s/^(\d+)(:(\d+))?//;
	my ($hh,$mm)=($1,$3);
	$hh = 0 unless $hh;
	$mm = 0 unless $mm;

	$hh+=12 if ($strtime =~ m/$pm_rx/);

	return $hh*60+$mm;
}
sub _fetch {

	my ($text) = @_;
	my %entries = ();

	##for (my $day=1; $day<7; $day++) {
	##	$entries{$day}= ( );
	##}

	my ($dd, $mm, $yy) = &_getStartDate();
	my ($eyy,$emm,$edd) = Add_Delta_Days($yy,$mm,$dd, 7);

	my $startDays = Date_to_Days($yy,$mm,$dd);
	my $endDays = Date_to_Days($eyy,$emm,$edd);

	my $STARTTIME = &_getTime($options{'starttime'});
	my $TIMEINTERVAL = $options{'timeinterval'};

	foreach my $line (grep(/$bullet_rx/, split(/\r?\n/, $text))) {

		$line =~ s/$bullet_rx//g; 

		my $excref = &_fetchExceptions($line, $startDays, $endDays);


		if ($line =~ m/^($dowrange_rx)\s+\-\s+($timerange_rx)/ ) {
			### DOW - DOW - hh:mm - hh:mm
			my ($startdow,$enddow,$starttime,$endtime, $descr,$color) = split /\s+\-\s+/, $line, 6;
			my ($fgcolor,$bgcolor);
			if ($color) {
				($fgcolor,$bgcolor) = split(/\s*\,\s*/,$color);
				if (($fgcolor)&&(!$bgcolor)) {
					$bgcolor = $fgcolor;
					$fgcolor = undef;
				}
			}

			$startdow=$daysofweek{$startdow};
			$enddow=$daysofweek{$enddow};
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			for (my $dow = $startdow; $dow<=$enddow; $dow++) {
				push @{$entries{$dow}}, 
					{ 	'starttime' => $starttime, 
						'endtime' => $endtime, 
						'nstarttime' => &_normalize($starttime, $STARTTIME, $TIMEINTERVAL),
						'nendtime' => &_normalize($endtime, $STARTTIME, $TIMEINTERVAL),
						'descr' => $descr , 
						'fgcolor'=>$fgcolor,
						'bgcolor'=>$bgcolor
					};
			}

		} elsif ($line =~ m/^($dow_rx)\s+\-\s+$timerange_rx/ ) {
			### DOW - hh:mm - hh:mm
			my ($dow,$starttime,$endtime,$descr,$color) = split /\s+\-\s+/, $line, 5;
			$dow=$daysofweek{$dow};
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			my ($fgcolor,$bgcolor);
			if ($color) {
				($fgcolor,$bgcolor) = split(/\s*\,\s*/,$color);
				if (!defined $bgcolor) {
					$bgcolor = $fgcolor;
					$fgcolor = undef;
				}
			}
			push @{$entries{$dow}}, { 
				'starttime' => $starttime, 
				'endtime' => $endtime, 
				'nstarttime' => &_normalize($starttime, $STARTTIME, $TIMEINTERVAL),
				'nendtime' => &_normalize($endtime, $STARTTIME, $TIMEINTERVAL),
				'descr'=>$descr,
				'fgcolor'=>$fgcolor,
				'bgcolor'=>$bgcolor
				};

		} elsif ($line =~m /^($dowlist_rx)\s+\-\s+($timerange_rx)/ ) { # XXX DONT WORK YET
			my ($dowlist,$starttime,$endtime,$descr,$color) = split /\s+\-\s+/, $line, 5;
			$starttime=&_getTime($starttime);
			$endtime=&_getTime($endtime);
			my @dowlistarr = split /\s*\,\s*/, $dowlist;
			my ($fgcolor,$bgcolor) = split(/\s*\,\s*/,$color);
			if (!defined $bgcolor) {
				$bgcolor = $fgcolor;
				$fgcolor = undef;
			}
			foreach my $dow (@dowlistarr) {
				push @{$entries{$dow}}, { 
					'starttime'=>$starttime,  
					'endtime' => $endtime, 
					'nstarttime' => &_normalize($starttime, $STARTTIME, $TIMEINTERVAL),
					'nendtime' => &_normalize($endtime, $STARTTIME, $TIMEINTERVAL),
					'descr'=>$descr,
					'fgcolor'=>$fgcolor,
					'bgcolor'=>$bgcolor
					};
			}
		} elsif ($options{'compatmode'}) {

			&_fetchCompat($line, \%entries, $excref);
		}



	}
	

	return \%entries;
}

sub _render {
	my ($entries_ref) = @_;

	my ($dd,$mm,$yy)=&_getStartDate();
	my ($tyy, $tmm, $tdd) = Today();
	my $startDateDays = Date_to_Days($yy,$mm,$dd);
	my $todayDays = Date_to_Days($tyy,$tmm,$tdd);

	my ($starttime,$endtime) = ( &_getTime($options{'starttime'}), &_getTime($options{'endtime'}));

	my $text = "";

	my($tr,$td);
	$text .= '<font size="-2">';
	$text .= $cgi->start_table({-bgcolor=>$options{'tablebgcolor'}, -cellpadding=>'0',-cellspacing=>'1', -id=>'timeTablePluginTable'});
	$text .= $cgi->caption($options{'tablecaption'});

	### render weekday header:
	$tr=$cgi->td($options{name}); 
	for (my $dow = 0; $dow < 7; $dow++) {
		next if (!$options{'showweekend'})&&($dow>4);
		my $colbgcolor = $options{(($dow>4)?'weekendbgcolor':'tableheadercolor')};
		$colbgcolor = $options{'todaybgcolor'} if ($options{'todaybgcolor'})&&($todayDays==$startDateDays+$dow);
		$colbgcolor = '' unless defined $colbgcolor;
		my $colfgcolor = $options{(($dow>4)?'weekendfgcolor':'black')};
		$colfgcolor = $options{'todayfgcolor'} if ($options{'todayfgcolor'})&&($todayDays==$startDateDays+$dow);
		$colfgcolor = '' unless defined $colfgcolor;

		my ($yy1,$mm1,$dd1)= Add_Delta_Days($yy,$mm,$dd,$dow);
		$tr .= $cgi->td({-style=>"color:$colfgcolor", -bgcolor=>$colbgcolor,-valign=>"top", -align=>"center"},&_mystrftime($yy1,$mm1,$dd1));
	}
	$text .= $cgi->Tr($tr);
	$text .= "\n";

	### render time line:
	$tr = "";
	$tr.=$cgi->td({-valign=>"top"},($options{'showtimeline'}=~m/(left|both)/i?&_renderTimeline():"&nbsp;"));

	### render timetable:
	for (my $dow = 0; $dow < 7; $dow++) {
		next if (!$options{'showweekend'})&&($dow>4);
		my $dowentries_ref = $$entries_ref{$dow+1};
		if (! defined $dowentries_ref) {
			$tr.=$cgi->td("&nbsp;");
			next;
		}

		my $colbgcolor = $options{(($dow>4)?'weekendbgcolor':'tablebgcolor')};
		$colbgcolor = $options{'todaybgcolor'} if ($options{'todaybgcolor'})&&($todayDays==$startDateDays+$dow);
		my $colfgcolor = $options{(($dow>4)?'weekendfgcolor':'black')};
		$colfgcolor = $options{'todayfgcolor'} if ($options{'todayfgcolor'})&&($todayDays==$startDateDays+$dow);

		###$td = $cgi->start_table({-rules=>"rows", -border=>"1",-cellpadding=>'0',-cellspacing=>'0', -tableheight=>"100%"});
		###$td = $cgi->start_table({-bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1', -tableheight=>"100%"});
		$td = $cgi->start_table({-bgcolor=>$colbgcolor, -cellpadding=>'0',-cellspacing=>'1', -tableheight=>"100%"});
		my ($itr, $itd);
		for (my $min=$starttime; $min <=$endtime; $min+=$options{'timeinterval'}) {
			my $mentries = &_getMatchingEntries($dowentries_ref, $min, $options{'timeinterval'}, $starttime);
			$itr="";
			if ($#$mentries>-1) {
				my $rs;
				foreach my $mentry_ref ( @{$mentries})  {
					my $fillRows = &_countConflicts($mentry_ref,$dowentries_ref, $starttime, $options{'timeinterval'});

					$rs= &_getEntryRows($mentry_ref, $min, $starttime, $endtime, $options{'timeinterval'});

					$itr.=$cgi->td({-nowrap=>"",
							-valign=>"top",
							-bgcolor=>$$mentry_ref{'bgcolor'}?$$mentry_ref{'bgcolor'}:$options{eventbgcolor},
							-rowspan=>$rs+$fillRows}, 
							&_renderText($mentry_ref, $rs,$fillRows)
							);
				}
				$td .=$cgi->Tr($itr)."\n";
				$itr=$cgi->td('&nbsp;');
				##$itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;'); ## DEBUG
				##$itr=$cgi->td('X'); ## DEBUG
				$td .=$cgi->Tr($itr)."\n";	
			} else {
				$itr=$cgi->td("&nbsp;");
				##$itr=$cgi->td({-valign=>'bottom', -align=>'left'}, '<font size="-4">'.&_renderTime($min).'</font>&nbsp;'); ## DEBUG
				$td .=$cgi->Tr($itr)."\n";
			}
		}

		$td .= $cgi->end_table();
		$tr.=$cgi->td({-valign=>"top"},$td);

	}
	$tr.=$cgi->td({-valign=>"top"},&_renderTimeline()) if ($options{'showtimeline'}=~m/(both|right)/i);

	$text.= $cgi->Tr($tr);


	$text .= $cgi->end_table();
	$text .= '</font>';


	return $text;
}
sub _renderText {
	my ($mentry_ref, $rs, $fillRows) = @_;
	my $tddata ="";
	my ($mst,$met) = ($$mentry_ref{'starttime'},$$mentry_ref{'endtime'});

	my $title = ($$mentry_ref{'longdescr'}?$$mentry_ref{'longdescr'}:$$mentry_ref{'descr'});
	$title .= ' ('.&_renderTime($mst).'-'.&_renderTime($met).')';

	$title=TWiki::Func::renderText($title,$web);
	$title=~s/<\/?[^>]+>//g;

	### $title.=" (rows=$rs, fillRows=$fillRows)"; ## DEBUG

	my $text = $$mentry_ref{'descr'};
	$text.=' ('.&_renderTime($mst).'-'.&_renderTime($met).')' if $options{'displaytime'};
	
	my $nt="";
	for (my $l=0; $l<$rs; $l++) {
		my $sub;
		my $offset = $l*$options{'descrlimit'};
		last if $offset>length($text);
		$sub  = substr($text, $offset, $options{'descrlimit'});
		last if (length($sub)<=0);
		$nt .= (($l==$rs-1)&&(length($sub)>$options{'descrlimit'}))? substr($sub,0,$options{'descrlimit'}-3).'...':$sub;
		$nt .='<br/>' unless $l==$rs-1;
	}	
	$text=$nt;

	##$tddata.= $cgi->div({-title=>$title, -style=>'font-family:monospace;'}, $text);
	$tddata.= $cgi->div({
			-title=>$title, 
			-style=>'color:'.($$mentry_ref{'fgcolor'}?$$mentry_ref{'fgcolor'}:$options{'eventfgcolor'}).';'
			}, $text);

	return $tddata;
}
sub _renderTimeline {
	###my $td = $cgi->start_table({-rules=>"rows",-border=>'1',-cellpadding=>'0',-cellspacing=>'0'});
	my $td = $cgi->start_table({-bgcolor=>"#fafafa", -cellpadding=>'0',-cellspacing=>'1'});
	my ($starttime,$endtime) = ( &_getTime($options{'starttime'}), &_getTime($options{'endtime'}));
	my ($wst,$wet) = ( &_getTime($options{'workingstarttime'}), &_getTime($options{'workingendtime'}) );
	for (my $min=$starttime; $min <=$endtime ; $min+=$options{'timeinterval'}) {
		$td .= $cgi->Tr($cgi->td({
			-bgcolor=>(($min>=$wst)&&($min<=$wet))?$options{'workingbgcolor'}:$options{'tableheadercolor'}, 
			-align=>"right"},
				$cgi->div({
						-style=>'color:'.$options{'workingfgcolor'},
						-title=>&_renderTime($min,'12am').' / '.&_renderTime($min,24)
					},
						&_renderTime($min)
					)
			));
		$td .= "\n";
	}
	$td .= $cgi->end_table();
	return $td;
}
sub _normalize {
	my ($time, $starttime, $interval) = @_;
	if ((!defined $time)||(!defined $starttime)||(! defined $interval)) {
		TWiki::Func::writeWarning("_normalize needs time ($time), starttime ($starttime) and interval ($interval)");
	} else {
		$time = int(( $time + ($starttime % $interval ) ) / $interval)*$interval;
		$time=$starttime if $time<$starttime ;
	}

	return $time;
}
sub _countConflicts {
	my ($entry_ref, $entries_ref, $starttime, $interval) = @_;
	my $c=1;
	my ($sd1,$ed1) = ($$entry_ref{'nstarttime'},$$entry_ref{'nendtime'});
	my (%visitedstartdates);
	foreach my $e (@{$entries_ref}) {
		my ($sd2,$ed2) = ($$e{'nstarttime'},$$e{'nendtime'});

		# go to the next if the same entry:
		next if $e == $entry_ref;

		# count only one conflict for events with same start time:
		next if defined $visitedstartdates{$sd2};
		$visitedstartdates{$sd2}=$ed2;

		# increase if the other start time is in my time range or my end time is in the time range of the other:
		$c++ if (($sd2>$sd1)&&($sd2<$ed1)) || (($ed1>$sd2)&&($ed1<$ed2));

		# decrease if my start time and end time is completly in a time range or the other:
		$c-- if ($sd1>=$sd2)&&($sd1<$ed2)&&($ed1>$sd2)&&($ed1<$ed2); 
	}		
	return $c;
}
sub _getEntryRows {
	my ($entry_ref, $time, $mintime, $maxtime, $interval) = @_;
	my ($rows)=1;
	my ($starttime,$endtime)=($$entry_ref{'nstarttime'}, $$entry_ref{'nendtime'});

	$starttime=$time if $starttime<$mintime;
	$endtime=$maxtime+$interval if $endtime>$maxtime;

	$endtime+=$interval if ($starttime==$endtime);

	$rows=sprintf("%d",(abs($endtime-$starttime+1)/$interval));

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
	### XXX setup a sort order for conflict entries (default: no sort)XXX
	### @matches = sort { $$b{'endtime'} <=> $$a{'endtime'} } @matches;
	### @matches = sort { $$a{'descr'} <=> $$b{'descr'} } @matches;
	return \@matches;
}
sub _renderTime {
	my ($hours, $minutes) = ( int($_[0]/60), ($_[0] % 60) );
	my ($timeformat) = ( $_[1]?$_[1]:$options{'timeformat'} );

	$hours-=12 if ($hours>12)&&($timeformat =~ m/^12/);
	my $time = sprintf("%02d",$hours).':'.sprintf("%02d",$minutes);
	
	$time.=(int($_[0]/60)>12)?"p$1m$2":"a$1m$2" if ($timeformat =~ m/[ap](\.?)m(\.?)$/);
	$time.=(int($_[0]/60)>12)?"P$1m$2":"A$1m$2" if ($timeformat =~ m/[AP](\.?)M(\.?)$/);
	
	return $time;
}
sub _getStartDate() {
        my ($yy,$mm,$dd) = Today();

        # handle startdate (absolute or offset)
        if (defined $options{'startdate'}) {
                my $sd = $options{'startdate'};
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
        if (defined $options{'year'}) {
                my $year = $options{'year'};
                if ($year =~ /^(\d{4})$/) {
                        $yy=$year;
                } elsif ($year =~ /^([\+\-]?\d+)$/) {
                        ($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, $1, 0);
                } 
        }
        # handle month (absolute or offset)
        if (defined $options{'month'}) {
                my $month = $options{'month'};
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

	
	my $dow = Day_of_Week($yy, $mm, $dd);
	($yy,$mm,$dd)=Add_Delta_Days($yy, $mm, $dd, -($dow-1));

        return ($dd,$mm,$yy);
}
sub _mystrftime($$$) {
        my ($yy,$mm,$dd) = @_;
        my $text = $options{'compatmode'}?$options{'cmheaderformat'}:$options{'headerformat'};

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
# =========================
sub _createUnknownParamsMessage {
        my $msg;
        $msg = TWiki::Func::getPreferencesValue("\U$pluginName\E_UNKNOWNPARAMSMSG") || undef;
        $msg = $defaults{unknownparamsmsg} unless defined $msg;
        $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
        $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
        return $msg;
}



sub _fetchCompat {
	my ($line, $entries_ref, $excref) = @_;

	my ($dd, $mm, $yy) = &_getStartDate();
	my ($eyy,$emm,$edd) = Add_Delta_Days($yy,$mm,$dd, 7);

	my $startDays = Date_to_Days($yy,$mm,$dd);
	my $endDays = Date_to_Days($eyy,$emm,$edd);

	my $STARTTIME = &_getTime($options{'starttime'});
	my $TIMEINTERVAL = $options{'timeinterval'};

	my ($descr, $tt);
	my ($starttime,$endtime,$nstarttime,$nendtime,$fgcolor,$bgcolor);
	my ($strdate);

	if ($line=~m/%TTCM{(.*?)}/) {
		$line =~ s/%TTCM{(.*?)}%//;
		$tt=$1;
		($starttime,$endtime,$fgcolor,$bgcolor) = _getTTCMValues($tt);
	} else {
		$starttime=0; $endtime=24*60; $fgcolor=undef; $bgcolor=undef;
	}
	if ((defined $starttime)&&(defined $endtime)) {
		($nstarttime, $nendtime) = ( &_normalize($starttime, $STARTTIME, $TIMEINTERVAL),
					     &_normalize($endtime, $STARTTIME, $TIMEINTERVAL) );
	} else {
		$nstarttime=undef;
		$nendtime=undef;
	}

	if (($line =~ m/^$daterange_rx/) || ($line =~ m/^$date_rx/)
			|| ($line =~ m/^$monthyearrange_rx/)  || ($line =~ m/^$monthyear_rx/)) {
		### dd MMM yyyy - dd MMM yyyy
		### dd MMM yyyy
		### MMM yyyy 
		### MMM yyyy - MMM yyyy
		my ($sdate,$edate);
		if (($line=~m/^$daterange_rx/)||($line =~ m/^$monthyearrange_rx/)) {
			($sdate,$edate,$descr) = split /\s+\-\s+/, $line;
		} else {
			($sdate,$descr) = split /\s+\-\s+/, $line;
			$edate=$sdate;
		}

		my ($start, $end) = ( &_getDays($sdate), &_getDays($edate, 1) );

		$descr =~ s/^\s*//; $descr =~ s/\s*$//; # strip whitespaces 

		my $date = $startDays;
		for (my $day=0; ($day<7)&&(($date+$day)<=$end); $day++) {
			next if $$excref[$day];
			if (($date+$day)>=$start) {
				push @{$$entries_ref{$day+1}}, 
					{ 
						'descr' => $descr,
						'longdescr' => $line,
						'starttime' => $starttime,
						'endtime' => $endtime,
						'nstarttime' => $nstarttime,
						'nendtime' => $nendtime,
						'fgcolor' => $fgcolor,
						'bgcolor' => $bgcolor
					};
			}
		}
	} elsif ($line =~ m/^A\s+$date_rx/) {
		### Yearly: A dd MMM yyyy

		($strdate,$descr) = split /\s+\-\s+/, $line;
		$strdate=~s/^A\s+//;

		my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
                $mm1 = $months{$mm1};
		return unless check_date($yy1, $mm1, $dd1);
		
		for (my $day=0; $day<7; $day++) {
			next if $$excref[$day];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$day);
			if (($m==$mm1)&&($d==$dd1)) {
				push @{$$entries_ref{$day+1}},
                                        {
                                                'descr' => $descr,
                                                'longdescr' => $line,
                                                'starttime' => $starttime,
                                                'endtime' => $endtime,
                                                'nstarttime' => $nstarttime,
                                                'nendtime' => $nendtime,
                                                'fgcolor' => $fgcolor,
                                                'bgcolor' => $bgcolor
                                        };
			}

		}
		
	} elsif ($line =~ m/^$day_rx\s+($months_rx)/) {
                ### Interval: dd MMM
		($strdate, $descr) = split /\s+\-\s+/, $line;
		my ($dd1, $mm1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};
		return if $dd1>31;

		for (my $day=0; $day<7; $day++) {
			next if $$excref[$day];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$day);
			if (($mm1==$m)&&($dd1==$d)) {
				push @{$$entries_ref{$day+1}},
                                        {
                                                'descr' => $descr,
                                                'longdescr' => $line,
                                                'starttime' => $starttime,
                                                'endtime' => $endtime,
                                                'nstarttime' => $nstarttime,
                                                'nendtime' => $nendtime,
                                                'fgcolor' => $fgcolor,
                                                'bgcolor' => $bgcolor
                                        };
			}
		}
	} elsif ($line =~ m/^[0-9L](\.|th)?\s+($dow_rx)(\s+($months_rx))?/) {
                ### Interval: w DDD MMM 
                ### Interval: L DDD MMM 
                ### Monthly: w DDD
                ### Monthly: L DDD

		($strdate,$descr) = split /\s+\-\s+/, $line;

		my ($n1, $dow1, $mm1) = split /\s+/, $strdate;
                $dow1 = $daysofweek{$dow1};
                $mm1 = $months{$mm1} if defined $mm1;

		for (my $day=0; $day<7; $day++) {
			next if $$excref[$day];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$day);
                        if ((! defined $mm1) || ($m == $mm1)) {
                                my ($yy2,$mm2,$dd2);
                                if ($n1 eq 'L') {
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
					push @{$$entries_ref{$day+1}},
						{
							'descr' => $descr,
							'longdescr' => $line,
							'starttime' => $starttime,
							'endtime' => $endtime,
							'nstarttime' => $nstarttime,
							'nendtime' => $nendtime,
							'fgcolor' => $fgcolor,
							'bgcolor' => $bgcolor
						};
                                } # if
                        } # if
		} # for 
	} elsif ($line =~ m/^$day_rx\s+/) {
                ### Monthly: dd
		($strdate, $descr) = split /\s+\-\s+/, $line;
		return if $strdate > 31;
		for (my $day=0; $day<7; $day++) {
			next if $$excref[$day];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$day);
			if ($strdate == $d) {
				push @{$$entries_ref{$day+1}},
					{
						'descr' => $descr,
						'longdescr' => $line,
						'starttime' => $starttime,
						'endtime' => $endtime,
						'nstarttime' => $nstarttime,
						'nendtime' => $nendtime,
						'fgcolor' => $fgcolor,
						'bgcolor' => $bgcolor
					};
			} # if
		} # for
	} elsif ($line =~ m/^E\s+($dow_rx)/) {
                ### Monthly: E DDD dd MMM yyy - dd MMM yyyy
                ### Monthly: E DDD dd MMM yyy
                ### Monthly: E DDD
                my $strdate2 = undef;
                if ($line =~ m/^E\s+($dow_rx)\s+$daterange_rx/) {
                        ($strdate, $strdate2, $descr) = split /\s+\-\s+/, $line;
                } else {
                        ($strdate, $descr) = split /\s+\-\s+/, $line;
                }
                $strdate=~s/^E\s+//;
                my ($dow1) = split /\s+/, $strdate;
                $dow1=$daysofweek{$dow1};

                $strdate=~s/^\S+\s*//;

                my ($start, $end) = (undef, undef);
                if ((defined $strdate)&&($strdate ne "")) {
                        $start = &_getDays($strdate);
                        return unless defined $start;
                }

                if (defined $strdate2) {
                        $end = &_getDays($strdate2);
                        return unless defined $end;
                }

                return if (defined $start) && ($start > $endDays);
                return if (defined $end) && ($end < $startDays);

		for (my $day=0; $day<7; $day++) {
			next if $$excref[$day];
                        my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$day);
                        my $date = Date_to_Days($y,$m,$d);
                        my $dow = Day_of_Week($y, $m, $d);
                        if ( ($dow==$dow1)
                            && ( (!defined $start) || ($date>=$start) )
                            && ( (!defined $end)   || ($date<=$end) )
                           ) {
                                push @{$$entries_ref{$day+1}},
                                        {
                                                'descr' => $descr,
                                                'longdescr' => $line,
                                                'starttime' => $starttime,
                                                'endtime' => $endtime,
                                                'nstarttime' => $nstarttime,
                                                'nendtime' => $nendtime,
                                                'fgcolor' => $fgcolor,
                                                'bgcolor' => $bgcolor
                                        };
                        }

		}
	} elsif ($line =~ m/^E\d+\s+$date_rx/) {
                ### Periodic: En dd MMM yyyy - dd MMM yyyy
                ### Periodic: En dd MMM yyyy
                my $strdate2 = undef;
                if ($line =~ m/^E\d+\s+$daterange_rx/) {
                        ($strdate, $strdate2, $descr) = split /\s+\-\s+/, $line;
                } else {
                        ($strdate, $descr) = split /\s+\-\s+/, $line, 4;
                }

                $strdate=~s/^E//;
                my ($n1) = split /\s+/, $strdate;

                return unless $n1 > 0;

                $strdate=~s/^\d+\s+//;

                my ($start, $end) = (undef, undef);
                my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
                $mm1 = $months{$mm1};

                $start = &_getDays($strdate);
                return unless defined $start;

                $end = &_getDays($strdate2) if defined $strdate2;
                return if (defined $strdate2)&&(!defined $end);

                return if (defined $start) && ($start > $endDays);
                return if (defined $end) && ($end < $startDays);

                ($yy1, $mm1, $dd1) = Add_Delta_Days($yy1, $mm1, $dd1, 
                        $n1 * int( (abs($startDays-$start)/$n1) + ($startDays-$start!=0?1:0) ) );
                $start = Date_to_Days($yy1, $mm1, $dd1);

                # start at first occurence and increment by repeating count ($n1)
                for (my $day=(abs($startDays-$start) % $n1); (($day < 7)&&((!defined $end) || ( ($startDays+$day) <= $end)) ); $day+=$n1) {
			next if $$excref[$day];
                        if (($startDays+$day) >= $start) {
                                push @{$$entries_ref{$day+1}},
                                        {
                                                'descr' => $descr,
                                                'longdescr' => $line,
                                                'starttime' => $starttime,
                                                'endtime' => $endtime,
                                                'nstarttime' => $nstarttime,
                                                'nendtime' => $nendtime,
                                                'fgcolor' => $fgcolor,
                                                'bgcolor' => $bgcolor
                                        };

                        }
                } # for

	} # elsif
} # sub

sub _getDays {
        my ($date,$ldom) = @_;
        my $days = undef;

        $date=~s/^\s*//;
        $date=~s/\s*$//;

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
        $dd=~/(\d+)/;
        $dd=$1;
        $days = check_date($yy,$mm,$dd) ? Date_to_Days($yy,$mm,$dd) : undef;

        return $days;

}
sub _fetchExceptions {
        my ($line, $startDays, $endDays) = @_;

        my @exceptions = ( );

        $_[0] =~s /X\s*{\s*([^}]+)\s*}// || return \@exceptions;
        my $ex=$1;


        for my $x ( split /\s*\,\s*/, $ex ) {
                my ($start, $end) = (undef, undef);
                if (($x =~ m/^$daterange_rx$/)||($x =~ m/^$monthyearrange_rx/)) {
                        my ($sdate,$edate) = split /\s*\-\s*/, $x;
                        $start = &_getDays($sdate,0);
                        $end = &_getDays($edate,1);

                } elsif (($x =~ m/^$date_rx/)||($x =~ m/^$monthyear_rx/)) {
                        $start = &_getDays($x,0);
                        $end = &_getDays($x, 1);
                }
                next unless defined $start && ($start <= $endDays);
                next unless defined $end &&   ($end >= $startDays);

                for (my $i=0; ($i<7)&&(($startDays+$i)<=$end); $i++) {
                        $exceptions[$i] = 1 if ( (($startDays+$i)>=$start) && (($startDays+$i)<=$end) );
                }
        }

        return \@exceptions;
}


1;
