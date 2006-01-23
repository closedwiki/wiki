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
package TWiki::Plugins::ChecklistPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $REVISION $pluginName
        $debug 
	$defaultsInitialized 
    	%globalDefaults %namedDefaults @renderedOptions @flagOptions @filteredOptions @listOptions
	%namedIds $idMapRef $query
	%itemStatesRead 
	%options  @unknownParams $name
    	$resetDone $stateChangeDone
    );

use strict;
use warnings;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'NovemberEdition';

$REVISION = '1.011'; #dro# fixed documentation; fixed reset bug (that comes with URL parameter bug fix); added statetopic attribute
#$REVISION = '1.010'; #dro# fixed URL parameter bugs (preserve URL parameters; URL encoding); used CGI module to generate HTML; fixed table sorting bug in a ChecklistItemState topic
#$REVISION = '1.009'; #dro# fixed stateicons handling; fixed TablePlugin sorting problem
#$REVISION = '1.008'; #dro# fixed docs; changed default text positioning (text attribute); allowed common variable usage in stateicons attribute; fixed multiple checklists bugs
#$REVISION = '1.007'; #dro# added new feature (CHECKLISTSTART/END tags, attributes: clipos, pos); fixed bugs
#$REVISION = '1.006'; #dro# added new attribute (useforms); fixed legend bug; fixed HTML encoding bug
#$REVISION = '1.005'; #dro# fixed major bug (edit lock); fixed html encoding; improved doc
#$REVISION = '1.004'; #dro# added unknown parameter handling (new attribute: unknownparamsmsg); added 'set to a given state' feature; changed reset behavior; fixed typos
#$VERSION = '1.003'; #dro# added attributes (showlegend, anchors); fixed states bug (illegal characters in states option); improved documentation; fixed typos; fixed some minor bugs
#$VERSION = '1.002'; #dro# fixed cache problems; fixed HTML/URL encoding bugs; fixed reload bug; fixed reset image button bug; added anchors 
#$VERSION = '1.001'; #dro# added new features ('reset','text' attributes); fixed 'name' attribute bug; fixed documentation bugs
#$VERSION = '1.000'; #dro# initial version

$pluginName = 'ChecklistPlugin';  # Name of this Plugin

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

    # XXX
    ### $debug = 1;

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
	    $_[0] =~ s/%CHECKLISTSTART{(.*?)}%(.*?)%CHECKLISTEND%/&handleAutoChecklist($1,$2)/sge;
	    $_[0] =~ s/%CHECKLISTSTART%(.*?)%CHECKLISTEND%/&handleAutoChecklist("",$1)/sge;
	    $_[0] =~ s/%CHECKLIST{(.*?)}%/&handleChecklist($1,$_[0])/ge;
	    $_[0] =~ s/%CHECKLIST%/&handleChecklist("",$_[0])/ge;
	    $_[0] =~ s/%CLI%/&handleChecklistItem("")/ge;
	    $_[0] =~ s/%CLI{(.*?)}%/&handleChecklistItem($1)/ge;
    };
    TWiki::Func::writeWarning("${pluginName}: $@") if $@;
}


# =========================
sub initDefaults() {
	TWiki::Func::writeDebug("initDefaults") if $debug;

	my $pubUrlPath = TWiki::Func::getPubUrlPath();
	%globalDefaults = (
		'id' => undef,
		'name' => '_default',
		'states' => 'todo|done',
		'stateicons' =>':-I|:ok:',
		'text' => '',
		'reset' => undef,
		'showlegend' => 0,
		'anchors' => 1,
		'unknownparamsmsg' => '%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see TWiki.ChecklistPlugin topic for more details): %KNOWNPARAMSLIST%',
		'useforms' => 0,
		'clipos'=> 'right',
		'pos'=>'bottom',
		'statetopic'=> $topic.'ChecklistItemState'
	);

	@listOptions = ('states','stateicons');
	@renderedOptions = ( 'text', 'stateicons', 'reset' );

	@filteredOptions = ( 'id', 'name', 'states');

	@flagOptions = ('showlegend', 'anchors', 'useforms' );

	$idMapRef = { };

	$query = TWiki::Func::getCgiQuery();

	$resetDone = 0;
	$stateChangeDone = 0;

	$defaultsInitialized = 1;

	%namedDefaults = ( );

}

# =========================
sub initOptions() {
	my ($attributes) = @_;
	my %params = TWiki::Func::extractParameters($attributes);

	my @allOptions = keys %globalDefaults;

        # Check attributes:
        @unknownParams= ( );
        foreach my $option (keys %params) {
                push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
        }
        return 0 if $#unknownParams != -1; 

	my $name;
	
	$name=&substIllegalChars($params{'name'}) if defined $params{'name'};
	$name=$globalDefaults{'name'} unless defined $name;

        # Setup options (attributes>named defaults>plugin preferences>global defaults):
	%options = ( );
        foreach my $option (@allOptions) {
                my $v = $params{$option};
		$v = $namedDefaults{$name}{$option} unless defined $v;
                if (defined $v) {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $options{$option} = ($v!~/(false|no|off|0|disable)/i);
                        } else {
                                $options{$option} = $v;
                        }
                } else {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $v = TWiki::Func::getPluginPreferencesFlag("\U$option\E") || undef;
                        } else {
                                $v = TWiki::Func::getPluginPreferencesValue("\U$option\E") || undef;
                        }
                        $options{$option}=(defined $v)? $v : $globalDefaults{$option};
                }

        }
        # Render some options:
        foreach my $option (@renderedOptions) {
		next unless defined $options{$option};
                if ($options{$option} !~ /^(\s|\&nbsp\;)*$/) {
			$options{$option}=~s/(<nop>|!)//sg;
			$options{$option}=&TWiki::Func::expandCommonVariables($options{$option},$topic, $web);
			if (grep /^\Q$option\E$/,@listOptions) {
				my @newlist = ( );
				foreach my $i (split /\|/,$options{$option}) {
					my $newval=&TWiki::Func::renderText($i, $web);
					$newval=~s/\|/\&brvbar\;/sg;
					push  @newlist, $newval;
				}
				$options{$option}=join('|',@newlist);
			} else {
				$options{$option}=&TWiki::Func::renderText($options{$option}, $web);
			}
                }
        }

	# filter some options:
	foreach my $option (@filteredOptions) {
		next unless defined $options{$option};
		if (grep /^\Q$option\E$/,@listOptions) {
			my @newlist = ( ) ;
			foreach my $i (split /\|/, $options{$option}) {
				my $newval = &substIllegalChars($i); 
				$newval=~s/\|/\&brvbar\;/sg;
				push @newlist, $newval;
			}
			$options{$option}=join('|',@newlist);
		} else {
			$options{$option}=&substIllegalChars($options{$option});
		}
	}


	# read item states:
	if (! $itemStatesRead{$name}) {
		&readChecklistItemStateTopic($idMapRef);
		$itemStatesRead{$name} = 1;
	}

	return 1;
}
# =========================
sub initNamedDefaults {
	my ($attributes) = @_;

	my %params = TWiki::Func::extractParameters($attributes);

	$name = &substIllegalChars($params{'name'}) if defined $params{'name'};
	$name = $globalDefaults{'name'} unless defined $name;

	# create named defaults (attributes>named defaults>global defaults):
	foreach my $default (keys %globalDefaults) {
		$namedDefaults{$name}{$default}=
			(defined $params{$default})?
					$params{$default}:
					((defined $namedDefaults{$name}{$default})?
						$namedDefaults{$name}{$default}:
						$globalDefaults{$default});
	}
}
# =========================
sub handleChecklist {
	my ($attributes, $refText) = @_;

	my $text="";

	&initDefaults() unless $defaultsInitialized;

	&initNamedDefaults($attributes);

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	my @states = split /\|/, $options{'states'};

	if ((defined $query->param("clreset"))&&(!$resetDone)) {
		my $n=$query->param("clreset");
		my $s=(defined $query->param("clresetst"))?$query->param("clresetst"):$states[0];
		if (($options{'name'} eq $n)&&(grep(/^\Q$s\E$/s, @states))) {
			&collectAllChecklistItems($refText) unless $s eq $states[0];
			&doChecklistItemStateReset($n,$s);
			$resetDone=1;
		}
	}
	my $legend = "";
	if ($options{'showlegend'}) {
		my @icons = split /\|/, $options{'stateicons'};
		$legend.=qq@<noautolink>@;
		$legend.=qq@(@;
		foreach my $state (@states) {
			my $icon = shift @icons;
			my ($iconsrc) = &getImageSrc($icon);
			my $heState = &htmlEncode($state);
			$legend.=$query->img({src=>$iconsrc, alt=>$heState, title=>$heState});
			$legend.=qq@ - $heState @;
		}
		$legend.=qq@) @;
		$legend.=qq@</noautolink>@;
	}

	if (defined $options{'reset'}) {
		my $reset = $options{'reset'};
		my $state = (split /\|/, $options{'states'})[0];

		if ($reset=~/\@(\S+)/s) {
			$state=$1;
			$reset=~s/\@\S+//s;
		}
		
		my ($imgsrc) = &getImageSrc($reset);
		$imgsrc="" unless defined $imgsrc;

		my $title=$reset;
		$title=~s/<\S+[^>]*\>//sg; # strip HTML
		$title=&htmlEncode($title);

		my $action=&TWiki::Func::getViewUrl($web,$topic);
		$action=~s/#.*$//s;
		$action.=&getUniqueUrlParam($action);


		if ( ! $options{'useforms'} ) {
			$action.="&clreset=".&urlEncode($name);
			$action.="&clresetst=".&urlEncode($state);
		}

		$action.="#reset${name}" if $options{'anchors'};

		$text.=qq@<noautolink>@;
		if ( ! $options{'useforms'}) {
			$text.=$query->a({name=>"reset${name}"}, '&nbsp;') if $options{'anchors'};
			$text.=$legend;
			my $linktext="";
			my $imgparams = {title=>$title, alt=>$title, border=>0};
			$$imgparams{src}=$imgsrc if (defined $imgsrc ) && ($imgsrc!~/^\s*$/s);
			$linktext.=$query->img($imgparams);
			$linktext.=qq@ ${title}@ if ($title!~/^\s*$/i)&&($imgsrc ne "");
			$text.=$query->a({href=>$action}, $linktext);
		} else {
			my $form="";
			$form.=$query->start_form({method=>'post', action=>$action});
			$form.=$legend;
			$form.=$query->a({name=>"reset${name}"},'&nbsp;') if $options{'anchors'} ;
			$form.=$query->hidden({name=>'clresetst', value=>&htmlEncode($state)});
			$form.=$query->image_button({name=>"clreset", value=>&htmlEncode($name),
				src=>$imgsrc, title=>$title, alt=>$title});
			$form.=" $title" if ($title!~/^\s*$/i)&&($imgsrc ne "");
			$form.=' '.&htmlEncode($options{'text'}) if defined $options{'text'};
			$form.=$query->end_form();
			$form=~s/[\r\n]+//sg;
			$text.=$form;
		}
		$text.=qq@</noautolink>@;
	} else {
		$text.=$legend; 
	}

	return $text;
}
# =========================
sub handleAutoChecklist {
	my ($attributes, $text) = @_;

	&initDefaults() unless $defaultsInitialized;

	&initNamedDefaults($attributes);

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	if (lc($options{'clipos'}) eq 'left') {
		$text=~s/^(\s+[\d\*]+)/"$1 \%CLI{$attributes}% "/meg;
	} else {
		$text=~s/^(\s+[\d\*]+.*?)$/"$1 \%CLI{$attributes}%"/meg;
	}

	if (lc($options{'pos'}) eq 'top' ) {
		$text="\%CHECKLIST{$attributes}\%\n$text";
	} else {
		$text.="\n\%CHECKLIST{$attributes}\%";
	}

	return $text;

}
# =========================
sub handleChecklistItem {
	my ($attributes) = @_;


	&initDefaults() unless $defaultsInitialized;

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	$namedIds{$options{'name'}}++ unless defined $options{'id'};

	if ((defined $query->param('clpsc'))&&(!$stateChangeDone)) {
		my ($id,$name,$lastState) = ($query->param('clpsc'),$query->param('clpscn'),$query->param('clpscls'));
		if ($options{'name'} eq $name) {
			&doChecklistItemStateChange($id, $name, $lastState) ;
			$stateChangeDone=1;
		}
	}


	return &renderChecklistItem();

}
# =========================
sub getNextState {
	my ($name, $lastState) = @_;
	my @states = split /\|/, $options{'states'};

	$lastState=$states[0] if ! defined $lastState;

	my $state = $states[0];
	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $lastState) {
			$state=($i<$#states)?$states[$i+1]:$states[0];
			last;
		}
	}
	TWiki::Func::writeDebug("getNextState($name, $lastState)=$state; allstates=".$options{states}) if $debug;

	return $state;
	
}
# =========================
sub doChecklistItemStateReset {
	my ($n, $state) = @_;
	TWiki::Func::writeDebug("doChecklistItemStateReset($n,$state)") if $debug;
	if (!defined $state) {
		my @states=split /\|/, $options{'states'};
		$state=$states[0];
	}
	foreach my $id (keys %{$$idMapRef{$n}}) {
		$$idMapRef{$n}{$id}=$state;
	}
	&saveChecklistItemStateTopic($n);
}
# =========================
sub doChecklistItemStateChange {
	my ($id, $n, $lastState) = @_;
	TWiki::Func::writeDebug("doChecklistItemStateChange($id,$n,$lastState)") if $debug;

	# reload?
	return if ((defined $$idMapRef{$n}{$id})&&($$idMapRef{$n}{$id} ne $lastState));

	$$idMapRef{$n}{$id}=&getNextState($n, $$idMapRef{$n}{$id});

	&saveChecklistItemStateTopic($n);
}
# =========================
sub renderChecklistItem {
	TWiki::Func::writeDebug("renderChecklistItem") if $debug;
	my $text = "";
	my $name = $options{'name'};

	my $tId = $options{'id'}?$options{'id'}:$namedIds{$name};

	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};

	### TWiki::Func::writeDebug("stateicons=".$options{'stateicons'}) if $debug;

	my $state = (defined $$idMapRef{$name}{$tId}) ? $$idMapRef{$name}{$tId} : $states[0];
	my $icon = $icons[0];

	$$idMapRef{$name}{$tId}=$state unless defined $$idMapRef{$name}{$tId};


	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $state) {
			$icon=$icons[$i];
			last;
		}
	}

	my ($iconsrc,$textBef,$textAft)=&getImageSrc($icon);

	my $action=TWiki::Func::getViewUrl($web,$topic);

	# remove anchor:
	$action=~s/#.*$//i; 

	$action.=getUniqueUrlParam($action);

	my $stId = &substIllegalChars($tId); # substituted tId
	my $heState = &htmlEncode($state); # HTML encoded state
	my $ueState = &urlEncode($state); # URL encoded state
	my $uetId = &urlEncode($tId); # URL encoded tId

	if ( ! $options{'useforms'} ) {
		$action.=($action=~/\?/)?"&":"?";
		$action.="clpsc=".&urlEncode("$stId");
		$action.="&clpscn=".&urlEncode($name);
		$action.="&clpscls=$ueState";
	}
	my %queryVars = $query->Vars();
	foreach my $p (keys %queryVars) {
		$action.="&$p=".&urlEncode($queryVars{$p}) 
			unless ($p =~ /^(clp.*|clreset.*|contenttype|)$/i)||(!$queryVars{$p});
	}
	$action.="#$stId" if $options{'anchors'};

	$text.=qq@<noautolink>@;
	
	$text.=$query->comment("\[CLTABLEPLUGINSORTFIX\]");
	$text.=$heState;
	$text.=$query->comment("\[/CLTABLEPLUGINSORTFIX\]");

	$text.=$query->a({name=>$uetId}, "&nbsp;") if $options{'anchors'};

	if ( ! $options{'useforms'} ) {
		
		my $linktext="";
		if (lc($options{'clipos'}) ne 'left') {
			$linktext.=$options{'text'}.' ' unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}
		$linktext.=qq@$textBef@ if $textBef;
		$linktext.=$query->img({src=>$iconsrc, border=>0, title=>$heState, alt=>$heState});
		$linktext.=qq@$textAft@ if $textAft;
		if (lc($options{'clipos'}) eq 'left') {
			$linktext.=' '.$options{'text'} unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}
		$text.=$query->a({-href=>$action},$linktext);
	} else {
		my $form=$query->start_form(-method=>"POST", -action=>$action, -name=>"changeitemstate\[$stId\]");
		$form.=$query->hidden(-name=>'clpscls', -value=>$heState);
		$form.=$query->hidden(-name=>'clpscn', -value=>&htmlEncode($name));
		if (lc($options{'clipos'}) ne 'left') {
			$form.=$options{'text'}.' ' unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}
		$form.=qq@$textBef@ if $textBef;
		$form.=$query->image_button(-name=>'clpsc', -src=>$iconsrc, 
				-value=>$stId, -title=>$heState, -alt=>$heState);
		$form.=qq@$textAft@ if $textAft;
		if (lc($options{'clipos'}) eq 'left') {
			$form.=' '.$options{'text'} unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}
		$form.=$query->end_form();
		$form=~s/[\r\n]+//gs;
		$text.=$form;
	}
	$text.=qq@</noautolink>@;

	return $text;
}
# =========================
sub getUniqueUrlParam {
	my ($url) = @_;
	my $r = 0;
	$r = rand(1000) while ($r <= 100);
	return (($url=~/\?/)?'&':'?').'clpid='.time().int($r);
}
# =========================
sub urlEncode {
	my ($txt)=@_;
	$txt=~s/([^A-Za-z0-9\$\-\_\.\+\!\*\'\(\)\,])/sprintf("%%%02X", ord($1))/seg;
	return $txt;
}
# =========================
sub htmlEncode {
	my ($txt)=@_;
	$txt=~s/(["<>])/sprintf("&#%02X;", ord($1))/seg;
	
	return $txt;
}
# ========================
sub substIllegalChars {
	my ($txt) = @_;
	$txt=~s/[^A-Za-z0-9\-\.\_]//sg if defined $txt;
	return $txt;
}
# ========================
sub getImageSrc {
	my ($txt)=@_;
	my ($src,$b,$a) = (undef, undef, undef);
	##if ($txt=~/$(.*?)img[^>]+?src="([^">]+?)"[^>]*(.*)$/is) {
	if ($txt=~/^([^<]*)<img[^>]+?src="([^">]+?)"[^>]*>(.*)$/is) {
		##$src=$1;
		($b,$src,$a)=($1,$2,$3);
	}
	return ($src,$b,$a);
}



# =========================
sub readChecklistItemStateTopic {
	my ($idMapRef) = @_;
	TWiki::Func::writeDebug("readChecklistItemStateTopic($topic,$web)") if $debug;
	my $clisTopicName = $options{'statetopic'};
	TWiki::Func::writeDebug("readChecklistItemStateTopic($topic, $web): $clisTopicName") if $debug;

	my $clisTopic = TWiki::Func::readTopicText($web, $clisTopicName);

	if ($clisTopic =~ /^http.*?\/oops/) {
		TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(), $clisTopic);
		return;
	}

	foreach my $line (split /[\r\n]+/, $clisTopic) {
		if ($line =~ /^\s*\|\s*([^\|\*]*)\s*\|\s*([^\|\*]*)\s*\|\s*([^\|]*)\s*\|\s*$/) {
			$$idMapRef{$1}{$2}=$3;
		}
	}
}
# =========================
sub saveChecklistItemStateTopic {
	my ($name) = @_;
	my $clisTopicName = $options{'statetopic'};

	TWiki::Func::writeDebug("saveChecklistItemStateTopic($topic, $web): $clisTopicName") if $debug;
	my $oopsUrl = TWiki::Func::setTopicEditLock($web, $clisTopicName, 1);
	if ($oopsUrl) {
		TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(), $oopsUrl);
		return;
	}
	my $topicText = "";
	$topicText.="%RED% WARNING! THIS TOPIC IS GENERATED BY $installWeb.$pluginName PLUGIN. DO NOT EDIT THIS TOPIC (except table data)!%ENDCOLOR%\n";
	$topicText.=qq@%BR%Back to the \[\[$web.$topic\]\[checklist topic $topic\]\].\n\n@;
	foreach my $n ( sort keys %{ $idMapRef } ) {
		next if ($clisTopicName ne $globalDefaults{'statetopic'})&&($clisTopicName ne $namedDefaults{$n}{'statetopic'});
		my $statesel = join ", ",  (split /\|/, ($namedDefaults{$n}{'states'}?$namedDefaults{$n}{'states'}:$globalDefaults{'states'}));
		$topicText.="\n";
		$topicText.=qq@%EDITTABLE{format="|text,20,$n|text,10,|select,1,$statesel|"}%\n@;
		$topicText.=qq@%TABLE{footerrows="1"}%\n@;
		$topicText.="|*context*|*id*|*state*|\n";
		
		foreach my $id (sort keys %{ $$idMapRef{$n}}) {
			$topicText.="|$n|".&htmlEncode($id)."|".&htmlEncode($$idMapRef{$n}{$id})."|\n";
		}
		$topicText.=qq@| *$n* | *statistics:* | * %CALC{"\$COUNTITEMS(R2:C\$COLUMN()..R\$ROW(-1):C\$COLUMN())"}% * |\n@;
	}
	$topicText.="\n-- $installWeb.$pluginName - ".&TWiki::Func::formatTime(time(), "rcs")."\n";
	TWiki::Func::saveTopicText($web, $clisTopicName, $topicText);
	TWiki::Func::setTopicEditLock($web, $clisTopicName, 0);
}
# =========================
sub collectAllChecklistItems {
	my ($text) = @_;
	local(%namedIds);
	$text =~ s/%CLI%/&handleChecklistItem("")/ge;
	$text =~ s/%CLI{(.*?)}%/&handleChecklistItem($1, $_[0])/ge;
}

# =========================
sub createUnknownParamsMessage {
	my $msg="";
        $msg = TWiki::Func::getPreferencesValue('UNKNOWNPARAMSMSG') || undef;
        $msg = $globalDefaults{'unknownparamsmsg'} unless defined $msg;
        $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
        $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %globalDefaults)/eg;

	return $msg;
}

sub endRenderingHandler  {
	if (defined $query) {
		my $startTag=$query->comment("\[CLTABLEPLUGINSORTFIX\]");
		my $endTag=$query->comment("\[/CLTABLEPLUGINSORTFIX\]");
		$_[0]=~s/\Q$startTag\E.*?\Q$endTag\E//sg;
	}
}
1;
