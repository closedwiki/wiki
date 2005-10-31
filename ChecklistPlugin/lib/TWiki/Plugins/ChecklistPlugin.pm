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
        $web $topic $user $installWeb $VERSION $pluginName
        $debug 
	$defaultsInitialized %globalDefaults %namedDefaults @renderedOptions @flagOptions @filteredOptions
	%namedIds $idMapRef $query
	$resetDone $stateChangeDone
    );

$VERSION = '1.003'; #dro# added showlegend attribute; fixed states bug (illegal characters in states option)
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
	    $_[0] =~ s/%CHECKLIST{(.*?)}%/&handleChecklist($1,$_[0])/ge;
	    $_[0] =~ s/%CHECKLIST%/&handleChecklist("",$_[0])/ge;
	    $_[0] =~ s/%CLI%/&handleChecklistItem("",$_[0])/ge;
	    $_[0] =~ s/%CLI{(.*?)}%/&handleChecklistItem($1, $_[0])/ge;
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
		'showlegend' => 'off'
	);

	@listOptions = ('states','stateicons');
	@renderedOptions = ( 'text', 'stateicons', 'reset');

	@filteredOptions = ( 'id', 'name', 'states');

	@flagOptions = ('showlegend' );

	$idMapRef = &readChecklistItemStateTopic();

	$query = TWiki::Func::getCgiQuery();

	$resetDone = 0;
	$stateChangeDone = 0;

	$defaultsInitialized = 1;

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
        foreach my $option (@allOptions) {
                $v = $params{$option};
		$v = $namedDefaults{$name}{$option} unless defined $v;
                if (defined $v) {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $options{$option} = ($v!~/false/i)&&($v!~/no/i)&&($v!~/off/i);
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
			if (grep /^\Q$option\E$/,@listOptions) {
				my @newlist = ( );
				foreach my $i (split /\|/,$options{$option}) {
					my $newval=TWiki::Func::renderText($i,$web);
					$newval=~s/\|/\&brvbar\;/sg;
					push  @newlist, $newval;
				}
				$options{$option}=join('|',@newlist);
				TWiki::Func::writeDebug("listed option $option found:".$options{$option}) if $debug;
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


	
}
# =========================
sub handleChecklist {
	local ($attributes, $refText) = @_;

	my $text="";

	local(%options, @unknownParams);

	&initDefaults() unless $defaultsInitialized;

	my %params = TWiki::Func::extractParameters($attributes);

	my $name = $params{'name'};
	$name=$globalDefaults{'name'} unless defined $name;

	# create named defaults (attributes>global defaults):
	foreach $default (keys %globalDefaults) {
		$namedDefaults{$name}{$default}=
			(defined $params{$default})?
					$params{$default}:$globalDefaults{$default};
		
	}

	&initOptions($attributes);

	if ((defined $query->param("clreset"))&&(!$resetDone)) {
		&doChecklistItemStateReset($query->param("clreset"));
		$resetDone=1;
	}
	my $legend = "";
	if ($options{'showlegend'}) {
		my @icons = split /\|/, $options{'stateicons'};
		my @states = split /\|/, $options{'states'};
		$legend.=qq@<noautolink>@;
		$legend.=qq@(@;
		while (my $state = shift @states) {
			my $icon = shift @icons;
			$icon=~s/(alt|title)="[^">"]+/$1="$state"/sg;
			$legend.=qq@$icon - $state @; 	
		}
		$legend.=qq@)@;
		$legend.=qq@</noautolink>@;
	}

	if (defined $options{'reset'}) {
		my $imgsrc = &getImageSrc($options{'reset'});

		my $title=$options{'reset'};
		$title=~s/<\S+[^>]*\>//sg; # strip HTML
		$title=&htmlEncode($title);

		my $action=&TWiki::Func::getViewUrl($web,$topic);
		$action=~s/#.*$//s;
		$action.=getUniqueUrlParam($action);
		$action.="#reset${name}";
		
		$text.=qq@<noautolink>@;
		$text.=qq@<form method="post" action="$action">@;
		$text.=$legend;
		$text.=qq@<a name="reset${name}">&nbsp;</a>@;
		$text.=qq@<input type="image" name="clreset" value="$name"@;
		$text.=qq@ src="$imgsrc"@ if (defined $imgsrc ) && ($imgsrc!~/^\s*$/s);
		$text.=qq@ title="$title" alt="$title"@;
		$text.=qq@>@;
		$text.=" $title" if ($title!~/^\s*$/i)&&($imgsrc ne "");
		$text.=' '.&htmlEncode($options{'text'}) if defined $options{'text'};
		$text.=qq@</input>@;
		$text.=qq@</form>@;
		$text.=qq@</noautolink>@;
	} else {
		$text.=$legend; 
	}

	return $text;
}
# =========================
sub handleChecklistItem {
	local ($attributes, $refText) = @_;

	local(%options, @unknownParams);

	&initDefaults() unless $defaultsInitialized;

	&initOptions($attributes);

	$namedIds{$options{'name'}}++ unless defined $options{'id'};

	if ((defined $query->param("clpsc"))&&(!$stateChangeDone)) {
		&doChecklistItemStateChange($query->param("clpsc"),$query->param("clpscls"));
		$stateChangeDone=1;
	}


	return &renderChecklistItem();

}
# =========================
sub getNextState {
	my ($lastState) = @_;
	my @states = split /\|/, $options{'states'};

	$lastState=$states[0] if ! defined $lastState;

	my $state = $states[0];
	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $lastState) {
			$state=($i<$#states)?$states[$i+1]:$states[0];
			last;
		}
	}
	TWiki::Func::writeDebug("getNextState($lastState)=$state; allstates=".$options{states}) if $debug;

	return $state;
	
}
# =========================
sub doChecklistItemStateReset {
	my ($name) = @_;
	TWiki::Func::writeDebug("doChecklistItemStateReset($name)") if $debug;
	foreach $id (%{ $$idMapRef{$name}}) {
		delete $$idMapRef{$name}{$id};
	}
	&saveChecklistItemStateTopic();
}
# =========================
sub doChecklistItemStateChange {
	my ($name_id, $lastState) = @_;
	TWiki::Func::writeDebug("doChecklistItemStateChange($name_id)") if $debug;

	$name_id=~/^([^\[]+)\[([^\]]+)\]$/;
	my ($name, $id) = ($1, $2);

	# reload?
	return if ((defined $$idMapRef{$name}{$id})&&($$idMapRef{$name}{$id} ne $lastState));

	$$idMapRef{$name}{$id}=&getNextState($$idMapRef{$name}{$id});

	&saveChecklistItemStateTopic();
}
# =========================
sub renderChecklistItem {
	TWiki::Func::writeDebug("renderChecklistItem") if $debug;
	my $text = "";
	my $name = $options{'name'};

	my $tId = $options{'id'}?$options{'id'}:$namedIds{$name};

	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};

	TWiki::Func::writeDebug("stateicons=".$options{'stateicons'}) if $debug;

	my $state = (defined $$idMapRef{$name}{$tId}) ? $$idMapRef{$name}{$tId} : $states[0];
	my $icon = $icons[0];

	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $state) {
			$icon=$icons[$i];
			last;
		}
	}

	my $iconsrc=&getImageSrc($icon);

	my $action=TWiki::Func::getViewUrl($web,$topic);

	# remove anchor
	$action=~s/#.*$//i; 

	$action.=getUniqueUrlParam($action);

	my $stId = &substIllegalChars($tId); # substituted tId
	my $heState = &htmlEncode($state); # HTML encoded state
	my $uetId = &urlEncode($tId); # URL encoded tId

	$text.=qq@<noautolink>@;
	$text.=qq@<a name="$stId">&nbsp;</a>@;
	$text.=qq@<form action="$action#$stId" name="changeitemstate\[$stId\]" method="post">@;
	$text.=qq@<input type="hidden" name="clpscls" value="$heState"/>@;
	$text.=qq@<input src="$iconsrc" type="image" name="clpsc" value="$name\[$stId\]" @;
	$text.=qq@title="$heState" alt="$heState"/>@;
	$text.=' '.$options{'text'} unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
	$text.=qq@</form></noautolink>@;

	## $action.=($action=~/\?/)?"&":"?";
	## $action.="clpsc=$uetId";
	## $text.=qq@<noautolink>@;
	## $text.=qq@<a name="$uetId"/>@;
	## $text.=qq@<a href="$action"><img border="0" src="$iconsrc" title="$heState" alt="$heState" /></a>@;
	## $text.=qq@</noautolink>@;

	return $text;
}
# =========================
sub getUniqueUrlParam {
	my ($url) = @_;
	my $r = 0;
	$r = rand(256) while ($r <= 1);
	return (($url=~/\?/)?'&':'?').(int($r)*time());
}
# =========================
sub urlEncode {
	my ($txt)=@_;
	$txt=~s/([^A-Za-z0-9\-\.])/sprintf("%%%02X", ord($1))/seg;
	return $txt;
}
# =========================
sub htmlEncode {
	my ($txt)=@_;
	$txt=~s/([^A-Za-z0-9\-\.\s\_])/sprintf("&#%02X;", ord($1))/seg;
	return $txt;
}
# ========================
sub substIllegalChars {
	my ($txt)=@_;
	$txt=~s/([^A-Za-z0-9\-\.\_])//seg;
	return $txt;
}
# ========================
sub getImageSrc {
	my ($txt)=@_;
	my $ret = undef;
	if ($txt=~/img[^>]+?src="([^">]+?)"[^>]*/is) {
		$ret=$1;
	}
	return $ret;
}



# =========================
sub readChecklistItemStateTopic {
	TWiki::Func::writeDebug("readChecklistItemStateTopic($topic,$web)") if $debug;
	my $clisTopicName = "${topic}ChecklistItemState";


	my ($oopsUrl, $loginName, $unlockTime) = TWiki::Func::checkTopicEditLock($web, $clisTopicName );
	if ($oopsUrl ne "") {
		TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(), $oopsUrl);
		return;
	}
	my $clisTopic = TWiki::Func::readTopicText($web, $clisTopicName);

	my %idMap;
	foreach $line (split /[\r\n]+/, $clisTopic) {
		if ($line =~ /^\s*\|([^\|\*]*)\|([^\|\*]*)\|([^\|]*)\|\s*$/) {
			$idMap{$1}{$2}=$3;
		}
	}
	return \%idMap;
}
# =========================
sub saveChecklistItemStateTopic {
	my $clisTopicName = "${topic}ChecklistItemState";
	TWiki::Func::writeDebug("saveChecklistItemStateTopic($topic, $web): $clisTopicName") if $debug;
	## TWiki::Func::setTopicEditLock($web, $clisTopicName, 1);
	my $topicText = "";
	$topicText.="%RED% WARNING! THIS TOPIC IS GENERATED BY $installWeb.$pluginName PLUGIN. DO NOT EDIT!%ENDCOLOR%\n";
	$topicText.="|*context*|*id*|*state*|\n";
	foreach my $name ( sort keys %{ $idMapRef } ) {
		foreach my $id (sort keys %{ $$idMapRef{$name}}) {
			$topicText.="|$name|$id|".$$idMapRef{$name}{$id}."|\n";
		}
	}
	TWiki::Func::saveTopicText($web, $clisTopicName, $topicText, 0, 1);
}

1;
