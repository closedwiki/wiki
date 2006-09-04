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

package TWiki::Plugins::RackPlannerPlugin::RackPlanner;

use strict;
###use warnings;


use CGI;
use POSIX qw(ceil);

use vars qw( $session $theTopic $theWeb $topic $web $attributes $text $refText
             $defaultsInitialized %defaults %options @renderedOptions @flagOptions %months %daysofweek
	     @processedTopics @unknownParams 
	     $cgi $pluginName
	 );

$pluginName = "RackPlannerPlugin";

# =========================
sub initPlugin {
	$defaultsInitialized = 0;
};

# =========================
sub expand {
	($attributes, $text, $topic, $web) = @_;
	$refText = $text; $theWeb=$web; $theTopic=$topic;

	&_initDefaults() unless $defaultsInitialized;

	return &_createUnknownParamsMessage() unless &_initOptions($attributes);

	if ($options{'autotopic'} && defined $options{'racks'}) {
		$options{'topic'} .= ($options{'topic'} eq ""?'':','). $options{'racks'};
	}


        return &_render(&_fetch(&_getTopicText()));

}
# =========================
sub _initDefaults {
	my $webbgcolor = &TWiki::Func::getPreferencesValue("WEBBGCOLOR", $web) || '#33CC66';
	%defaults = (
		'topic' => "$web.$topic",
		'autotopic' => 'off',
		'racks' => undef,
		'units' => 46,
		'steps' => 1,
		'emptytext' => 'empty',
	 	'unknownparamsmsg'  => '%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see TWiki.$pluginName topic for more details): %KNOWNPARAMSLIST%',
		'fontsize' => '100%',
		'iconsize' => '16px',
		'dir'=> 'bottomup', # or 'topdown'
		'displayconnectedto' => 0,
		'displaynotes'=>0,
		'displayowner'=>0,
		'notesicon'=>'%P%',
		'connectedtoicon'=>'%M%',
		'conflicticon'=>'%S%',
		'devicefgcolor'=>'#000000',
		'devicebgcolor'=>'#f0f0f0',
		'emptyfgcolor'=> '#000000',
		'emptybgcolor'=> '#f0f0f0',
		'name'=>'U',
		'statformat' => 'Empty Units: %EU<br/>Largest Empty Block: %LEB<br/>Occupied Units: %OU',
		'displaystats' => 1,
	);

	@renderedOptions = ( 'name', 'notesicon','conflicticon', 'connectedtoicon' );
	@flagOptions = ( 'autotopic', 'displaystats', 'displayconnectedto', 'displaynotes', 'displayowner' );


        $defaultsInitialized = 1;

}

# =========================
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
                                $options{$option} = 1 unless $v=~/^(0|on|off)$/i;
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
                        $options{$option}=&TWiki::Func::expandCommonVariables($options{$option}, $web);
                        $options{$option}=&TWiki::Func::renderText($options{$option}, $web);
                }
        }


        @processedTopics = ( );

	$cgi = &TWiki::Func::getCgiQuery();

        return 1;
}

# =========================
sub _fetch {

	my ($text) = @_;
	my %entries = ();

	foreach my $line ( grep(/^\s*\|([^|]*\|){4,}\s*$/,split(/\r?\n/, $text)) ) {
		
		my ($dummy,$server,$rack,$sunit,$ff,$connectedto,$owner,$colimg,$notes) = split /\s*\|\s*/,$line;

		next if $rack =~ /^\*[^\*]+\*$/; ### ignore header

		my $arrRef = $entries{$rack}{$sunit};
		unless (defined $arrRef) {
			my @arr = ( );
			$arrRef = \@arr;
			$entries{$rack}{$sunit}=$arrRef;
		};
	
		my $infosRef = { 'server' => $server, 'formfactor'=>$ff,  'rack'=>$rack, 'sunit'=>$sunit,
				'connectedto'=>$connectedto, 'owner'=>$owner, 'colimg'=>$colimg, 'notes'=>$notes };

		push @{$arrRef}, $infosRef;

	}

	$options{'racks'} = join(',',keys %entries) unless defined $options{'racks'};

	return \%entries;
}

# =========================
sub _render {
	my ($entriesRef) = @_;
	my $text="";

	my @racks = split /\s*\,\s*/, $options{'racks'};

	my $startUnit = -abs($options{'units'});
	my $endUnit = -1;
	my $steps =  abs($options{'steps'});

	if ($options{'dir'}=~/^topdown$/i) {
		$endUnit=-$startUnit;
		$startUnit=1;
	}
	$text .= '<noautolink>';
	$text .= $cgi->start_table({-id=>'rackPlannerPluginTable', -style=>'font-size:'.$options{'fontsize'}});

	### render table header:
	my $tr = "";
	$tr.=$cgi->th({-align=>'center'},$cgi->span({-title=>$options{'units'}},$options{'name'}));
	foreach my $rack (@racks) {
		$tr.=$cgi->th({-align=>'center',-colwidth=>int(80/($#racks+1)).'%'},&TWiki::Func::renderText($rack));

	}
	$text .= $cgi->Tr($tr);

	## render table data:
	$tr="";

	my $utext ="";
	for (my $unit=$startUnit; $unit<=$endUnit; $unit+=$steps) {
		$utext.=$cgi->Tr($cgi->th({-align=>'right'},abs($unit)));
	}
	$utext = $cgi->start_table().$utext.$cgi->end_table();
	$tr.=$cgi->td($utext); 

	my $notesIcon = &_resizeIcon($options{'notesicon'});
	my $connectedtoIcon = &_resizeIcon($options{'connectedtoicon'});

	my $statRow = $cgi->td("");

	foreach my $rack (@racks) {
		my $td= "";
		my $fillRows = 0;

		$statRow.=$cgi->td(&_renderStatistics($$entriesRef{$rack})) if $options{'displaystats'};

		for (my $unit=$startUnit; $unit<=$endUnit; $unit+=$steps) {
			my $itd="";
			my $rowspan=1;
			my $bgcolor=$options{'devicebgcolor'};
			my $fgcolor=$options{'devicefgcolor'};
			my $style ="";
			my $entryListRef = $$entriesRef{$rack}{abs($unit)};
			if ((defined $$entriesRef{$rack}{abs($unit)}) && ($#$entryListRef!=-1) && ($fillRows==0)) {
				my $entryRef = shift @{ $entryListRef };

				if ($$entryRef{'formfactor'} =~ m/(\d+)/) {
					$rowspan=$1 / $options{'steps'};
					$rowspan=1 unless $rowspan>0;
				}

				$fillRows=$rowspan-1;
				my $text=$$entryRef{'server'};
				$text.=":" if ( $options{'displayconnectedto'}||$options{'displayowner'}||$options{'displaynotes'});
				$text.=" ".$$entryRef{'connectedto'} if defined $$entryRef{'connectedto'} && $options{'displayconnectedto'};
				$text.=" ".$$entryRef{'owner'} if defined $$entryRef{'owner'} &&  $options{'owner'};
				$text.=" ".$$entryRef{'notes'} if defined $$entryRef{'notes'} && $options{'notes'};
				

				$itd.=&TWiki::Func::renderText($text);

				$itd = $cgi->span({-title=>$$entryRef{'owner'}}, $itd);

				if ((defined $$entryRef{'connectedto'}) && ($$entryRef{'connectedto'}!~/^\s*$/) && (!$options{'displayconnectedto'})) {
					foreach my $ct (split(/\s*\,\s*/, $$entryRef{'connectedto'})) {
						my $rt = TWiki::Func::renderText($ct);
						if ($rt=~/<a\s+[^>]*?href=\"([^\">]+)\"/) {
							$itd.=$cgi->a({-href=>&encode_entities($1),-title=>&encode_entities($ct)}, $connectedtoIcon);
						} else  {
							$itd.=$cgi->span({-title=>&encode_entities($ct)},$connectedtoIcon);
						}
					}
				}
				
				
				if (defined $$entryRef{'notes'} && $$entryRef{'notes'}!~/^\s*$/ && !$options{'notes'}) {
					my $rt = TWiki::Func::renderText($$entryRef{'notes'});
					if ($rt=~/<a\s+[^>]*?href=\"([^\">]+)\"/) {
						$itd.=$cgi->a({-href=>&encode_entities($1),-title=>&encode_entities($$entryRef{'notes'})},$notesIcon);
					} else  {
						$itd.=$cgi->span({-title=>&encode_entities($$entryRef{'notes'})},$notesIcon);
					}
				}

				foreach my $colimg (split(/\s*,\s*/, $$entryRef{'colimg'})) {
					if ($colimg=~/[\.\/\:]/) {
						$style .= $style eq '' ? '' : ';';
						$style .= 'background-image:url('.encode_entities($colimg).');';
					} elsif ($colimg=~/^(\#[\d\w]+|\w+)$/) {
						if ($style!~/background-color:/) {
							$bgcolor=encode_entities($colimg);
							$style .= $style eq '' ? '' : ';';
							$style .= 'background-color:'.$bgcolor;
						} else {
							$fgcolor=encode_entities($colimg);
							$style .= $style eq '' ? '' : ';';
							$style.='color:'.$fgcolor;
						}
					}
				}

				$itd = $cgi->td({
					-title=>abs($unit), -valign=>'top', 
					-rowspan=>$rowspan, 
					-nowrap=>($rowspan<2)?'1':'',
					-style=>$style,
					-bgcolor=>$bgcolor,
					-color=>$fgcolor
					}, 
					$itd);

				if ($#$entryListRef!=-1) {
					$itd .= $cgi->td({-title=>&_renderConflictTitle(abs($unit),$entryListRef), 
								-bgcolor=>'white', -color=>'red',-style=>'background-color:white;color:red' },$options{'conflicticon'});
				} else {
					$itd .= $cgi->td({-title=>abs($unit)},"&nbsp;") if ($rowspan>1);
				}

			} else {
				$bgcolor=$options{'emptybgcolor'};
				$fgcolor=$options{'emptyfgcolor'};
				if ($fillRows==0) {
					$itd.=$options{'emptytext'};
				} else {
					if (defined $entryListRef && $#$entryListRef!=-1) {
						$itd.=$cgi->span({
								-title=>&_renderConflictTitle(abs($unit),$entryListRef)
								}, $options{'conflicticon'});
						$bgcolor="white";
						$fgcolor="red";
					} else {
						$itd.="&nbsp;"; 
						$bgcolor="white";
					}
					$fillRows--;
				}
				$style="background-color:$bgcolor;color:$fgcolor";
				$itd = $cgi->td({-title=>abs($unit), -style=>$style, -bgcolor=>$bgcolor, -color=>$fgcolor}, $itd);
			}
			$td .= $cgi->Tr({-align=>'left',-valign=>'top'},$itd)."\n";
			
		}
		$td = $cgi->start_table(-style=>'font-size:'.$options{'fontsize'}, -cellpadding=>'0',-cellspacing=>'1',-tableheight=>'100%').$td.$cgi->end_table();
		
		$tr.=$cgi->td($td);
	}
	$tr.=$cgi->td(""); ### XXXX Units
	$text .= $cgi->Tr({-valign=>'top'}, $tr);

	$text.=$cgi->Tr($statRow) if $options{'displaystats'};


	$text .= $cgi->end_table();
	$text .= '</noautolink>';

	return $text;
}
sub _renderConflictTitle {
	my ($unit, $entryListRef) = @_;
	my $title = "$unit: conflict with";
	foreach my $entryRef (@{$entryListRef}) {
		$title.=" ".$$entryRef{'server'};
	}

	return $title;
}
sub _resizeIcon {
	my ($icon) = @_;
	$icon=~s/(<img\s+[^\>]*?width=")[^"]+"/$1$options{'iconsize'}"/;
	$icon=~s/(<img\s+[^\>]*?height=")[^"]+"/$1$options{'iconsize'}"/;
	return $icon;
}
sub _renderStatistics {
	my ($rackEntriesRef) = @_;

	my $statsRef = &_getStatistics($rackEntriesRef);

	my $text = $options{'statformat'};

	$text =~s/%EU/$$statsRef{'emptyUnits'}/g;
	$text =~s/%LEB/$$statsRef{'maxContinuesUnits'}/g;
	$text =~s/%OU/$$statsRef{'occupiedUnits'}/g;
 
	return $text;
}
sub _getStatistics {
	my ($rackEntriesRef) = @_;

	my $startUnit = -abs($options{'units'});
	my $endUnit = -1;
	my $steps =  abs($options{'steps'});

	if ($options{'dir'}=~/^topdown$/i) {
		$endUnit=-$startUnit;
		$startUnit=1;
	}

	my $countEmptyUnits = 0;
	my $countOccupiedUnits = 0;
	my $countContinuesEmptyUnits = 0;
	my $maxContinuesEmptyUnits = 0;
	for (my $unit=$startUnit; $unit<=$endUnit; $unit+=$steps) {
		my $entriesRef = $$rackEntriesRef{abs($unit)};
		if ((defined $entriesRef) && ($#$entriesRef != -1)) {
			$$rackEntriesRef{abs($unit)}[0]{'formfactor'} =~ m/(\d+)/;
			my $u=$1;
			$countOccupiedUnits += $u;
			$countContinuesEmptyUnits = 0;
			$unit += $u-1;
			next;
		} else {
			$countEmptyUnits+=$steps;
			$countContinuesEmptyUnits+=$steps;
			$maxContinuesEmptyUnits=$countContinuesEmptyUnits if ($countContinuesEmptyUnits>$maxContinuesEmptyUnits);
		}
	}
	return { 'emptyUnits'=>$countEmptyUnits, 'occupiedUnits'=>$countOccupiedUnits, 'maxContinuesUnits'=>$maxContinuesEmptyUnits };

}
### dro: following code is derived from TWiki:Plugins.CalendarPlugin:
# =========================
sub _getTopicText() {

        my ($web, $topic, $timezone);

        my $topics = $options{'topic'};

        my @topics = split /,\s*/, $topics;

        my $text = "";
        foreach my $topicpair (@topics) {

		($web, $topic) = split /\./, $topicpair, 2;
		if (!defined $topic) {
			$topic = $web;
			$web = $theWeb;
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
# =========================
sub encode_entities {
	my($text) = @_;

	return $text unless defined $text;
	
	$text =~ s/\</&lt;/g;
	$text =~ s/\>/&gt;/g;
	$text =~ s/\"/&quot;/g;
	$text =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/g;
	$text =~ s/\[\[([^\]]+)\]\]/$1/g;
	
	return $text;
	
}

1;
