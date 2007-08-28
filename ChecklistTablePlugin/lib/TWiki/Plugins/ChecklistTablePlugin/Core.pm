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
# TODO
#    + own sort instead of table sort (allows EDIT/+ buttons to stay within table header, CAUTION!: what happenz if there is no table header?)
#    + JavaScript based adds/inserts/moves/edits (maybe AJAX too)
#

package TWiki::Plugins::ChecklistTablePlugin::Core;

use strict;
## use warnings;

use vars qw( %defaults @flagOptions $defaultsInitialized  %options $cgi $STARTENCODE $ENDENCODE @unknownParams);

$STARTENCODE = "--CHECKLISTTABLEPLUGIN_ENCODED[";
$ENDENCODE = "]CHECKLISTTABLEPLUGIN_ENCODED--";


# =========================
sub handle {
	# my ($text,$topic,$web) = @_;
	
	_initDefaults() unless $defaultsInitialized;

	return if _handleActions(@_);

	_render(@_);
	
}
# =========================
sub _render {

	local(%options);
	local(@unknownParams);

	my $text ="";

	my $insidePRE = 0;
	my $foundTable = 0;
	my @table = ( );
	my $tablenum = -1;
	my $row = -1;
	foreach my $line (split /\r?\n/, "$_[0]\n<nop>\n") {
		$insidePRE = 1 if $line =~ /<(pre|verbatim)\b/i;
		$insidePRE = 0 if $line =~ /<\/(pre|verbatim)>/i; 

		if ($insidePRE) {
			$text .= "$line\n";
			next;
		}

		if ($line =~ s/%CHECKLISTTABLE({(.*?)})?%/_initOptions($2,$_[1],$_[2])/eg) {
			@table = ();
			$foundTable = 1;
			$row = -1;
			$tablenum++;
		} elsif ($foundTable) {
			if ($line =~ /^\s*\|[^\|]*\|/) {
				$row++;
				_collectTableData(\@table, $tablenum, $line, $row);
				$line = undef;
			}  else {
				
				$line = _renderTable( _sortTable($tablenum,\@table), $tablenum).$line;
				$foundTable = 0;
			}
		}

		$text.="$line\n" if defined $line;
	}

	$_[0] = $text;
	
}
# =========================
sub _collectTableData {
	my ($tableRef, $tablenum, $line, $row) = @_;

	my @data = split( /\|/, '--'.$line.'--');
	
	shift @data; pop @data;

	my %rowdata;

	$rowdata{'data'} = \@data;
	$rowdata{'row'} = $row;
	$rowdata{'line'} = $line;
	$rowdata{'header'} = $line =~ /\|\s*\*[^\*]*\*\s*\|/;

	push @{ $tableRef }, \%rowdata;
	
}

# =========================
sub _renderTable {
	my ($tableRef, $tablenum) = @_;
	my $text = "";

	$options{"_RowCount_$tablenum"}=$#$tableRef;

	_fixFormatAndHeaderOptions((defined $tableRef && $#$tableRef > -1 ?  $$tableRef[0] : undef));

	## anchor name (an):
	my $an = "CLTP_TABLE_$tablenum";

	$text.=$cgi->start_form('post',TWiki::Func::getScriptUrl($options{'theWeb'},$options{'theTopic'},'viewauth')."#$an");
	$text.=$cgi->a({-name=>$an});


	if (!defined $cgi->param("cltp_action_$tablenum")) {
		if ($#$tableRef>-1) {
			$text.=_renderButtons('edittable',$tablenum);
			$text.=_renderButtons('first',$tablenum);
		}

	}
	$text.=qq@%TABLE{sort="off"}%@; ##  if !$options{'headerislabel'}; ## generally switched off
	$text.="\n";
	$text.=_renderTableHeader($tablenum);

	my $firstRendered = 0;
	foreach my $tableEntry ( @{$tableRef} ) {
		my $row = "";

		if (defined $cgi->param("cltp_action_${tablenum}_first") && !$firstRendered && !$$tableEntry{'header'}) {
			$row .= _renderForm('insertfirst',$tablenum, undef, 0) if defined $cgi->param("cltp_action_${tablenum}_first");
			$firstRendered = 1;
		}

		if ($$tableEntry{'header'} && $options{'headerislabel'}) {
			$row.=_renderTableHeader($tablenum, $tableEntry);
		} elsif ($cgi->param("cltp_action_${tablenum}_editrow_$$tableEntry{'row'}")) {
			$row.=_renderForm('editrow', $tablenum, $tableEntry);
		} elsif ($cgi->param("cltp_action_${tablenum}_edittable")) {
			$row.=_renderForm('edittable.editrow', $tablenum, $tableEntry);
		} else {
			$row.=_renderTableData($tablenum, $tableEntry);
		}
		if (defined $cgi->param("cltp_action_${tablenum}_ins_$$tableEntry{'row'}")) {
			$row.=_renderForm('insertrow',$tablenum, undef, $$tableEntry{'row'});
		}
		$text.=$row;
	}
	$text.= _renderForm('addrow',$tablenum,undef,$#$tableRef + 1) unless defined $cgi->param("cltp_action_$tablenum");
	$text.= _renderButtons('edittable', $tablenum) unless defined $cgi->param("cltp_action_$tablenum") || $#$tableRef<0;
	$text.= _renderButtons('savetable', $tablenum) if defined $cgi->param("cltp_action_${tablenum}_edittable");

	### preserve table sort order of all checklist tables:
	foreach my $param (grep(/^cltp_\d+_sort/,$cgi->param())) {
		$text .= $cgi->hidden(-name=>$param,-value=>$cgi->param($param));
	}


	$text.=$cgi->end_form();

	$text.="\n";
	return $text;
}
# =========================
sub _renderForm {
	my ($what, $tablenum, $entryRef, $row) = @_;

	my @formats = split(/\|/,$options{'format'});
	shift @formats; 

	$row = $options{"_RowCount_$tablenum"} unless defined $row; 
	$row = $$entryRef{'row'} if defined $entryRef;
	$row = 0 unless $row>-1;

	my $dataRef;
	
	$dataRef = $$entryRef{'data'} if defined $entryRef;

	my $text = "| ";
	for (my $c=0; $c<=$#formats; $c++) {
		my $format = $formats[$c];

		$format = $defaults{'defaultcellformat'} if defined $entryRef && $$entryRef{'header'} && !$options{'headerislabel'};

		my ($type, $param, $default) = split(/\s*,\s*/,$format,3);


		my $value;
		$value = $$dataRef[$c] if defined $dataRef;
		$value = $default unless defined $value;
		$value = "" unless defined $value;

		my $valname = "cltp_val_${tablenum}_${row}_${c}";

		my $evalue = $STARTENCODE._editencode($value).$ENDENCODE;

		if ($type eq 'item') {
			$text .=  (defined $entryRef)? $value 
					: qq@%CLI{id="blubber.$tablenum.$row.$c" static="on"@
					  .($options{'name'} ne '_default'?qq@ name="$options{'name'}"@:"")
					  .(defined $options{'template'}?qq@ template="$options{'template'}"@:"")
					  .qq@}%@;
		} elsif ($type eq 'row') {
			$text .= $row + 1;
		} elsif ($type eq 'text') {
			$text .= $cgi->textfield(-name=>$valname, -value=>$evalue, -size=>$param);
		} elsif ($type eq 'textarea') {
			my ($rows,$cols) = split(/x/i,$param);
			$text .= $cgi->textarea(-name=>$valname, -value=> $evalue, -rows=>$rows, -columns=>$cols);
		} elsif ($type eq 'select') {
			my @selopts = split(/,\s*/,$default);
			$text .= $STARTENCODE._editencode($cgi->popup_menu(-name=>$valname, -size=>$param, -values=>\@selopts, -default=>($default ne $value)?$value:""),1).$ENDENCODE;
		} elsif ($type eq 'checkbox') {
			my @selopts = split(/,\s*/,$default);
			my @values = split(/,\s*/,$value);
			$text .= $STARTENCODE._editencode($cgi->checkbox_group(-name=>$valname, -values=>\@selopts, -columns=>$param,-defaults=>(defined $entryRef)?\@values:$selopts[0]),1).$ENDENCODE;
		} elsif ($type eq 'radio') {
			my @selopts = split(/,\s*/,$default);
			$value = $selopts[0] unless defined $value && $value ne "" && grep /^\Q$value\E$/,@selopts;
			$text .= $STARTENCODE._editencode(
				$cgi->radio_group(-name=>$valname, -columns=>$param, -values=>\@selopts, -default=>$value), 1
				).$ENDENCODE;
		} elsif ($type eq 'date') {
			my($initval,$dateformat);
			($initval,$dateformat) = split(/\s*,\s*/,$default,2) if defined $default;
			$initval="" unless defined $initval;
			$dateformat=TWiki::Func::getPreferencesValue('JSCALENDARDATEFORMAT') if (!defined $dateformat || $dateformat eq "");
			$dateformat=~s/'/\\'/g if defined $dateformat;
			$evalue = $STARTENCODE._editencode($initval).$ENDENCODE unless defined $entryRef;
			$text .= $cgi->textfield(-name=>$valname, -value=>$evalue, -size=>$param, -id=>$valname);
			$text .= $cgi->image_button(-name=>'calendar', -src=>'%PUBURLPATH%/TWiki/JSCalendarContrib/img.gif', -alt=>'Calendar', -title=>'Calendar', -onClick=>qq@return showCalendar('$valname','$dateformat')@);
		} else { # label or unkown:
			$text.= $evalue;
		}
		
		$text .='|';

	}
	$text.= '*&nbsp;'._renderButtons($what,$tablenum, $row).'&nbsp;* |';
	return "$text\n";
}

# =========================
sub _fixFormatAndHeaderOptions {
	my ($entryRef) = @_;

	my @format = split(/\|/, $options{'format'});
	my @header = split(/\|/, $options{'header'});
	shift @format; 
	shift @header;


	my $columns = 0;
	if (defined $entryRef) {
		$columns = $#{$$entryRef{'data'}};
	} else {
		$columns = $#format;
	}


	if ($columns != $#format) {
		my $newformat ="";
		for (my $c=0; $c<=$columns; $c++) {

			if (defined $entryRef) {
				if ($$entryRef{'data'}[$c] =~ /^\s*\%CLI[^\%]*%\s*$/) {
					$newformat.='|item';
				} else {
					$newformat.='|'.$options{'defaultcellformat'};
				}
			} else {
				$newformat.='|'.$options{'defaultcellformat'};
			}

		}
		$newformat.="|";
		$options{'format'}=$newformat;
	}

	if ($options{'header'} ne 'off') {
		$options{'header'} = 'off' if $#header != $#format;

		$options{'header'} = 'off' if (defined $entryRef)&&($$entryRef{'header'});

		$options{'header'} = 'off' if $columns != $#header;
	}
	
}
# =========================
sub _renderTableHeader {
	my ($tablenum, $entryRef) = @_;


	my $header = "";

	if (defined $entryRef) {
		$header = $$entryRef{'line'};
	} elsif ($options{'header'} ne 'off') {
		$header = $options{'header'};
	} else {
		return "";
	}
	my @cells = split(/\s*\|\s*/, $header);
	shift @cells;
	$header = "|";
	for (my $c=0; $c<=$#cells; $c++) {
		my $param = "cltp_${tablenum}_sort";
		my $cell = $cells[$c];
		$cell=~s/^\s*\*//;
		$cell=~s/\*\s*$//;
		my $dir = 'asc';
		$dir = 'desc' if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_asc/);
		$dir = "default" if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_desc/);

		my $sortmarker="";
		$sortmarker=$dir eq "desc" ? $cgi->span({-title=>'ascending order'},'^') :  $cgi->span({-title=>'descending order'},'v') 
					if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_(asc|desc)$/);
		my $ncgi=new CGI($cgi);
		$ncgi->param($param,"${c}_${dir}");
		$cell = "$sortmarker " . $cgi->a({-href=>$ncgi->self_url()."#CLTP_TABLE_$tablenum", -title=>"sort table"}, $cell);

		$header.="*$cell*|";
	}

	my $text ="$header*&nbsp;&nbsp;*|";

	return "$text\n";
}
# =========================
sub _renderTableData {
	my ($tablenum, $entryRef) = @_;

	my $rowcount = $options{"_RowCount_$tablenum"};
	my $row = $$entryRef{'row'};


	my $text = "";

	$text .= $$entryRef{'line'};

	$text .= "*&nbsp;";
	$text .= _renderButtons('show', $tablenum, $row, $rowcount) unless defined $cgi->param("cltp_action_$tablenum");
	$text .= "&nbsp;* |";

	$text=~s/\%CLTP_ROWNUMBER\%/($row+1)/ge;

	return "$text\n";
}
# =========================
sub _renderButtons {
	my ($what, $tablenum, $row, $rowcount) = @_;
	my $text = "";
	if ($what eq 'show') {
		## e:
		$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_editrow_${row}", -title=>'Edit Entry', -value=>' E ', -src=>$options{'editrowicon'});
		## +:
		if ($row < $rowcount) {
			$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_ins_${row}", -title=>'Insert Entry', -value=>' + ',-src=>$options{'insertrowicon'});
		} else {
			$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_cancel", -title=>'Insert Entry', -value=>'   ',-src=>$options{'dummyicon'}); 
		}
		## ^ v:
		if ($options{'allowmove'}) {
			if ($row > 0 ) {
				$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_up_".($row-1), -title=>'Move Entry Up', -value=>' ^ ',-src=>$options{'moverowupicon'}); 
			} else {
				$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_cancel", -title=>'Move Entry Up', -value=>'   ',-src=>$options{'dummyicon'}); 
			}
			if ($row < $rowcount) {
				$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_down_${row}", -title=>'Move Entry Down', -value=>' v ',-src=>$options{'moverowdownicon'});
				
			} else {
				$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_cancel", -title=>'Move Entry Down', -value=>'   ',-src=>$options{'dummyicon'});
			}
		}
		$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_delrow_${row}", -title=>'Remove Entry', -value=>' - ',-src=>$options{'deleterowicon'}); 
	} elsif ($what eq 'addrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_addrow_${row}", -value=>'Add');
	} elsif ($what eq 'insertrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_addrow_${row}", -value=>'Insert');
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>'Cancel');
	} elsif ($what eq 'editrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_saverow_${row}", -value=>'Save');
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_qsaverow_${row}", -value=>'Quiet Save') if $options{'quietsave'};
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>'Cancel');
	} elsif ($what eq 'first') {
		$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_first", -title=>"Insert entry", -value=>' + ',-src=>$options{'insertrowicon'});
	} elsif ($what eq 'insertfirst') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_insertfirst", -value=>"Insert");
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>"Cancel");
	} elsif ($what eq 'edittable') {
		$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_edittable", -title=>'Edit table', -value=>'EDIT', -src=>$options{'edittableicon'});
	} elsif ($what eq 'savetable') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_savetable", -value=>"Save");
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_qsavetable", -value=>"Quiet Save") if $options{'quietsave'};
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>"Cancel");
	}
	return $text;
}
# =========================
sub _handleActions {
	my ($text,$theTopic,$theWeb) = @_;
	

	my @cltpactions = grep(/^cltp_action_\d+_(ins|first|edittable|editrow|addrow|delrow|up|down|cancel|saverow|qsaverow|savetable|qsavetable|insertfirst)(_\d+)?$/, $cgi->param());
	return 0 if ($#cltpactions != 0);

	#### Check access permissions (before any action...):
	my $mainWebName=&TWiki::Func::getMainWebname();
	my $user =TWiki::Func::getWikiName();
	$user = "$mainWebName.$user" unless $user =~ m/^$mainWebName\./;

	if (! TWiki::Func::checkAccessPermission("CHANGE",$user,undef,$theTopic, $theWeb)) {
		eval { require TWiki::AccessControlException; };
		if ($@) {
			TWiki::Func::redirectCgiQuery($cgi,TWiki::Func::getOopsUrl($theWeb,$theTopic,"oopsaccesschange"));
		} else {
			require Error;
			throw TWiki::AccessControlException(
					'CHANGE', 
					$TWiki::Plugins::SESSION->{user},
					$theTopic, $theWeb, 'denied'
				);
		}
		return;
	}


	my $action = $cltpactions[0];
	$action =~ s/^cltp_action_(\d+)_([^_]+)(_(\d+))?/$2/;
	my ($tablenum, $rownum) = ($1,$4);

	$cgi->delete("etedit");

	$cgi->param("cltp_action_$tablenum","1");
	if ($action =~ /^(cancel|saverow|qsaverow|savetable|qsavetable|addrow|delrow|up|down|insertfirst)$/) {
		my $error;
		$error = _handleChangeAction($theTopic, $theWeb, $action, $tablenum, $rownum) unless $action eq 'cancel';

		TWiki::Func::setTopicEditLock($theWeb, $theTopic, 0);

		my $url = TWiki::Func::getViewUrl($theWeb,$theTopic);
		## preserve sort order:
		if (!$error) {
			$url=~s/(\#.*)$//;
			my $anchor = $1;
			$url.="?";
			foreach my $param (grep(/^cltp_\d+_sort$/,$cgi->param())) {
				$url.="$param=".$cgi->param($param).";";
			}
			$url.=$anchor if defined $anchor;
		}
		TWiki::Func::redirectCgiQuery($cgi, $error ? $error : $url );
		return 1;
	} else { # ins|first|editrow|edittable
		
		my $oopsUrl = TWiki::Func::setTopicEditLock($theWeb, $theTopic, 1);
		if ($oopsUrl) {
			TWiki::Func::redirectCgiQuery($cgi, $oopsUrl);
			return 1;
		}
	}

	return 0; ### no actions (better: redirects) done
}

# =========================
sub _handleChangeAction {
	my ($theTopic, $theWeb, $action, $tablenum, $rownum) = @_;

	return if $action eq 'cancel';
	my $newText = "";
	my $text = TWiki::Func::readTopicText($theWeb,$theTopic);

	$rownum=-2 unless defined $rownum;

	my $insidePRE = 0;
	my $tablefound = 0;
	my $table = -1;
	my $row = -1;

	my @topic =  split(/\r?\n/, $text."\n<nop>\n");
	my $linenumber = -1;
	my $firstInserted = 0;
	foreach my $line ( @topic ) {
		$linenumber++;
		$insidePRE = 1 if $line =~ /<(pre|verbatim)\b/i;
		$insidePRE = 0 if $line =~ /<\/(pre|verbatim)>/i; 

		if ($insidePRE) {
			$newText .= "$line\n";
			next;
		}

		if ($line =~ /\%CHECKLISTTABLE({(.*?)})?\%/) {
			my $attributes = $2;
			$table++; $row=-1;
			$tablefound = ($tablenum == $table);
			$firstInserted = 0;
			_initOptions($attributes) if ($tablefound) ;
		} elsif ($tablefound) {
			$row++; 

			if ($line =~ /^\s*\|[^\|]*\|/) {
				my @data = split(/\|/, '--'.$line.'--');
				shift @data; pop @data;

				_fixFormatAndHeaderOptions(_getHashRef(\@data,$row,($data[0]=~/\*[^\*]*\*/))) if $row == 0;

				if (($line=~/\|\s*\*[^\*]*\*/)&&$options{'headerislabel'}) { # ignore header
					$newText .= "$line\n";
					next;
				}
				if (($action eq 'insertfirst')&&(!$firstInserted))  {
					$line = _createRowFromCgi('new',$tablenum, 0) ."\n$line";
					$firstInserted = 1;
				}
	

				if ($action eq 'savetable' || $action eq 'qsavetable') {
					$line = _createRowFromCgi('update', $tablenum, $row, \@data);
				} elsif ($row == $rownum) {
					if ($action eq 'saverow' || $action eq 'qsaverow') {
						$line = _createRowFromCgi('update', $tablenum, $row, \@data);
					} elsif ($action eq 'delrow') {
						$line = undef;
					} elsif ($action eq 'addrow') {
						$line = "$line\n"._createRowFromCgi('new',$tablenum, $row);
					} elsif ($action =~ /^(down|up)$/) {
						my $bline = $line;
						$line = $topic[$linenumber + 1];
						$topic[$linenumber + 1]  = $bline;
					}
				}
			
			} else {
				if (($row == $rownum)&&($action eq 'addrow')) {
					$line = _createRowFromCgi('new',$tablenum, $row)."\n$line";
				}
		
				$tablefound = 0;
			}
		}

		$newText.="$line\n" if defined $line;
	}
	$newText=~s/\n<nop>\n$//s;

	return TWiki::Func::saveTopicText($theWeb, $theTopic, $newText, 1, $action =~ /^(qsaverow|qsavetable)$/);
	
}
# =========================
sub _getHashRef {
	my ($dataRef, $row, $header) = @_;
	my %data;
	$data{'data'} = $dataRef;
	$data{'row'} = $row;
	$data{'header'} = $header;
	return \%data;
}
# =========================
# two actions: 'new' or 'update'
sub _createRowFromCgi {
	my($action,$tablenum, $row, $dataRef) = @_;
	my @formats = split(/\|/, $options{'format'});
	shift @formats; 
	
	my $text = '|';
	for (my $c=0; $c<=$#formats; $c++) {
		my $format = $formats[$c];
		my ($type,$attribute,$val) = split(/\s*,\s*/,$format);
		my $paramname = "cltp_val_${tablenum}_${row}_$c";

		my $value;
		$value  = _encode(join(", ",$cgi->param($paramname))) if defined $cgi->param($paramname);

		$cgi->delete($paramname);

		$value = $val unless defined $value;

		if ($action eq 'new') {
			if ($type eq 'item') {
				$value  = qq@%CLI{id="@.sprintf("%d-%03d-%03d",time(),$tablenum,$row).qq@"@;
				$value .= qq@ template="$options{'template'}"@ if defined $options{'template'};
				$value .= qq@ name="$options{'name'}"@ unless $options{'name'} eq '_default';
				$value .= qq@}%@;
			} elsif ($type eq 'row') {
				$value = '%CLTP_ROWNUMBER%';
			}
		} else {
			if (($type eq 'item')||($type eq 'row')) {
				$value = $$dataRef[$c];
			}
		}

		$text.="$value|";
		
	}
	return $text;
}

# =========================
sub _initDefaults {
	%defaults = ( 
		'_DEFAULT' => undef,
		'unknownparamsmsg' => '%RED% %TWIKIWEB%.ChecklistTablePlugin: Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see TWiki.ChecklistTablePlugin topic for more details): %KNOWNPARAMSLIST%',
		'header' => '|*State*|*Item*|*Comment*|',
		'format' => '|item|text,30|textarea,3x30|',
		'name' => '_default',
		'template'=> undef,
		'defaultcellformat'=> 'textarea,3x20',
		'allowmove' => 0,
		##'edittableicon'=>'%PUBURLPATH%/%TWIKIWEB%/EditTablePlugin/edittable.gif',
		'edittableicon'=>'%ICONURL{edittopic}%',
		'moverowupicon'=>'%ICONURL{up}%',
		'moverowdownicon'=>'%ICONURL{down}%',
		'insertrowicon'=>'%ICONURL{plus}%',
		'editrowicon'=>'%ICONURL{pencil}%',
		'deleterowicon'=>'%ICONURL{choice-no}%',
		'dummyicon'=>'%ICONURL{empty}%',
		'quietsave'=>'on',
		'headerislabel'=>'on',
		'sort'=>'on',
	);
	@flagOptions = ('allowmove', 'quietsave', 'headerislabel', 'sort');
	$cgi = TWiki::Func::getCgiQuery();
	$defaultsInitialized = 1;
}
# =========================
sub _initOptions {
	my ($attributes,$topic,$web) = @_;
	my %params = TWiki::Func::extractParameters($attributes);

	my @allOptions = keys %defaults;

	@unknownParams= ( );
	foreach my $option (keys %params) {
		push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
	}

	## _DEFAULT:
	$params{'name'} = $params{'_DEFAULT'} if defined $params{'_DEFAULT'} && ! defined $params{'name'};

	## all options:
	foreach my $option (@allOptions) {
		my $v = $params{$option};
		if (defined $v) {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$options{$option} = ($v!~/(false|no|off|0|disable)/i);
			} else {
				$options{$option} = $v;
			}
		} else {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$v = ( TWiki::Func::getPreferencesFlag("\U${TWiki::Plugins::ChecklistTablePlugin::pluginName}_$option\E") || undef );
			} else {
				$v = TWiki::Func::getPreferencesValue("\U${TWiki::Plugins::ChecklistTablePlugin::pluginName}_$option\E"); 
			}
			$v = undef if (defined $v) && ($v eq "");
			$options{$option}= (defined $v?$v:$defaults{$option});
		}
	}

	$options{"theWeb"}=$web;
	$options{"theTopic"}=$topic;

	return $#unknownParams>-1?_createUnknownParamsMessage():"";

}
# =========================
sub _createUnknownParamsMessage {
	my $msg="";
	$msg = TWiki::Func::getPreferencesValue('UNKNOWNPARAMSMSG') || undef;
	$msg = $defaults{'unknownparamsmsg'} unless defined $msg;
	$msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
	my @params = sort grep {!/^(_DEFAULT|unknownparamsmsg)$/} keys %defaults;
	$msg =~ s/\%KNOWNPARAMSLIST\%/join(', ',@params)/eg;

	return $msg;
}
# =========================
sub _editencode  {
	my ($text,$html) = @_;
	
	$text = _encode($text);
	$text =~ s/<br\s*\/?>/&#10;/g;	
	$text =~ s/\*/&#35;/g;
	$text =~ s/_/&#95;/g;
	$text =~ s/=/&#61;/g;
	$text =~ s/</&#60;/g if ! defined $html;
	$text =~ s/(\%)/'&#'.ord($1).';'/eg;

	return $text;
}
# =========================
sub _encode {
	my ($text) =@_;

	return $text unless defined $text;

	$text =~ s/\|/&#124;/g;
	$text =~ s/\r?\n/<br\/>/g;
	
	return $text;
}
# =========================
sub _editdecode {
	my ($text) = @_;
	$text =~ s/&(amp;)?#124;/\|/g;
	$text =~ s/&(amp;)?#10;/\r\n/g;
	$text =~ s/&(amp;)?#35;/*/g;
	$text =~ s/&(amp;)?#95;/_/g;
	$text =~ s/&(amp;)?#61;/=/g;
	# $text =~ s/&(amp;)?#60;/</g;
	$text =~ s/&(amp;)#(\d+);/&#$2;/g; ## fix encoded characters &amp;#....;
	return $text;
}
# =========================
sub handlePost {
	$_[0] =~ s/\Q$STARTENCODE\E(.*?)\Q$ENDENCODE\E/_editdecode($1)/esg;
}
# =========================
sub _sortTable {
	my ($tablenum, $tabledataRef) = @_;
	
	return $tabledataRef if !$options{'sort'};
	my @newtabledata = @{$tabledataRef};

	my ($column, $dir) = (undef, undef);
	foreach my $param (grep /^cltp_\Q$tablenum\E_sort$/, $cgi->param()) {
		($column,$dir)=split(/\_/,$cgi->param($param));
	}
	if (defined $column && defined $dir && $dir ne "default") {

		sub _mysort {
			my ($dir,$column) = @_;
			if ($$a{'header'}) {
				return -1;
			} elsif ($$b{'header'}) {
				return +1;
			}
			return uc($$a{'data'}[$column]) cmp uc($$b{'data'}[$column]) if $dir eq 'asc';
			return uc($$b{'data'}[$column]) cmp uc($$a{'data'}[$column]);
		};

		@newtabledata = sort { _mysort($dir,$column); }  @{$tabledataRef};
	}
	return \@newtabledata;
}


1;
