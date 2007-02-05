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
        $debug %TWikiCompatibility
	$defaultsInitialized 
    	%globalDefaults @renderedOptions @flagOptions @filteredOptions @listOptions
	%options  @unknownParams $name
	%namedDefaults %namedIds $idMapRef $idOrderRef %namedResetIds %itemStatesRead 
    	$resetDone $stateChangeDone $saveDone
	$initText
    );

use strict;
###use warnings;

$TWikiCompatibility{endRenderingHandler} = 1.1;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Cairo, Dakar, Edinburgh, ...';

$REVISION = '1.022'; #dro#  improved AJAX performance; added new feature (state selection for reset button);
#$REVISION = '1.021'; #dro# fixed some major bug (mod_perl, plugin preferences); improved performance (AJAX); fixed minor IE caching bug (AJAX related); added new attributes (tooltip, descr, template, statesel) requested by TWiki:Main.KeithHelfrich; fixed installation instructions bug reported by TWiki:Main.KeithHelfrich
#$REVISION = '1.020'; #dro# added AJAX feature (useajax attribute) requested by TWiki:Main.ShayPierce and TWiki:Main.KeithHelfrich
#$REVISION = '1.019'; #dro# fixed major default options bug reported by TWiki:Main.RichardHitier 
#$REVISION = '1.018'; #dro# fixed notification bug reported by TWiki:Main.JosMaccabiani; fixed a minor whitespace bug; add static attribute
#$REVISION = '1.017'; #dro# fixed access right bug; disabled change/create mail notification (added attribute: notify)
#$REVISION = '1.016'; #dro# fixed access right bug reported by TWiki:Main.SaschaVogt
#$REVISION = '1.015'; #dro# fixed mod_perl preload bug (removed 'use warnings;') reported by TWiki:Main.KennethLavrsen
#$REVISION = '1.014'; #dro# fixed mod_perl bug; fixed deprecated handler problem
#$REVISION = '1.013'; #dro# fixed anchor bug; fixed multiple save bug (performance improvement); fixed reset bugs in named checklists
#$REVISION = '1.012'; #dro# fixed a minor statetopic bug; improved autogenerated checklists (item insertion without state lost); improved docs
#$REVISION = '1.011'; #dro# fixed documentation; fixed reset bug (that comes with URL parameter bug fix); added statetopic attribute
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
    ####$debug = 1;

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

    $initText = $_[0];
    ###### we need exceptions since Dakar release therefore eval is bad
    ###eval {
	    local(%options, %namedDefaults, %itemStatesRead, %namedIds, %namedResetIds, @unknownParams, $name);
            $_[0] =~ s/<\/head>/<script src="%PUBURL%\/%TWIKIWEB%\/$pluginName\/itemstatechange.js" language="javascript" type="text\/javascript"><\/script><\/head>/is unless ($_[0]=~/itemstatechange.js/);
	    $_[0] =~ s/%CHECKLISTSTART%(.*?)%CHECKLISTEND%/&handleAutoChecklist("",$1,$_[0])/sge;
	    $_[0] =~ s/%CHECKLISTSTART{(.*?)}%(.*?)%CHECKLISTEND%/&handleAutoChecklist($1,$2,$_[0])/sge;
	    $_[0] =~ s/%CHECKLIST%/&handleChecklist("",$_[0])/ge;
	    $_[0] =~ s/%CHECKLIST{(.*?)}%/&handleChecklist($1,$_[0])/sge;
	    ##$_[0] =~ s/%CLI%/&handleChecklistItem("",$_[0])/ge;
	    ##$_[0] =~ s/%CLI{(.*?)}%/&handleChecklistItem($1,$_[0])/sge;
	    $_[0] =~ s/([^\n\%]*)%CLI({(.*?)})?%([^\n\%]*)/$1.&handleChecklistItem($3,$_[0],$1,$4).$4/sge;
    ###};
    ###TWiki::Func::writeWarning("${pluginName}: $@") if $@;
}


# =========================
sub initDefaults() {
	TWiki::Func::writeDebug("- ${pluginName}::initDefaults") if $debug;

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
		'statetopic'=> $topic.'ChecklistItemState',
		'notify'=> 0,
		'static'=> 0,
		'useajax'=>1,
		'tooltip'=>'Click me to change my state from \'%STATE%\' to \'%NEXTSTATE%\'',
		'tooltipbgcolor'=>'%WEBBGCOLOR%',
		'descr' => undef,
		'_DEFAULT' => undef,
		'ajaxtopicstyle'=>'plain',
		'descrcharlimit'=>100,
		'template' => undef,
		'statesel' => 0,
	);

	@listOptions = ('states','stateicons');
	@renderedOptions = ( 'text', 'stateicons', 'reset' );

	@filteredOptions = ( 'id', 'name', 'states');

	@flagOptions = ('showlegend', 'anchors', 'useforms', 'notify', 'static' , 'useajax', 'statesel');

	$idMapRef = { };
	
	$idOrderRef = { };

	%namedIds = ( );

	%namedResetIds = ( );

	$resetDone = 0;
	$stateChangeDone = 0;
	$saveDone = 0;

	$defaultsInitialized = 1;

	%namedDefaults = ( );

	%itemStatesRead = ( );

	my $query = TWiki::Func::getCgiQuery();
	&collectAllChecklistItems() if (defined $query->param('clreset')) || (defined $query->param('clpsc'));

}

# =========================
sub initOptions() {
	my ($attributes) = @_;
	my %params = &TWiki::Func::extractParameters($attributes);

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

	# handle _DEFAULT option (_DEFAULT = descr)
	$params{'descr'} = $params{'_DEFAULT'} if defined $params{'_DEFAULT'};

	# handle templates:
	my $tmplName = $params{'template'};
	$tmplName = $namedDefaults{$name}{'template'} unless defined $tmplName;
	$tmplName = ( &TWiki::Func::getPreferencesValue("\U${pluginName}_TEMPLATE\E") || undef) unless defined $tmplName;

        # Setup options (attributes>named defaults>plugin preferences>global defaults):
	%options = ( );
        foreach my $option (@allOptions) {
                my $v = $params{$option};
		if ((defined $tmplName)&&(!defined $v)) {
			$v = (&TWiki::Func::getPreferencesFlag("\U${pluginName}_TEMPLATE_${tmplName}_${option}\E") || undef) if grep /^\Q$option\E$/, @flagOptions;
			$v = (&TWiki::Func::getPreferencesValue("\U${pluginName}_TEMPLATE_${tmplName}_${option}\E") || undef)  unless defined $v;
			$v = undef if (defined $v) && ($v eq "");
		}

		$v = $namedDefaults{$name}{$option} unless defined $v;
                if (defined $v) {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $options{$option} = ($v!~/(false|no|off|0|disable)/i);
                        } else {
                                $options{$option} = $v;
                        }
                } else {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $v = ( TWiki::Func::getPreferencesFlag("\U${pluginName}_$option\E") || undef );
                        } else {
                                $v = ( TWiki::Func::getPreferencesValue("\U${pluginName}_$option\E") || undef ); 
                        }
			$v = undef if (defined $v) && ($v eq "");
                        $options{$option}= (defined $v?$v:$globalDefaults{$option});
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
               $namedDefaults{$name}{$default}= $params{$default} if defined $params{$default};
	}
}
# =========================
sub renderLegend {
	my $query = &TWiki::Func::getCgiQuery();
	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};
	my $legend.=qq@<noautolink>@;
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
	return $legend;
}
# =========================
sub handleChecklist {
	my ($attributes, $refText) = @_;

	TWiki::Func::writeDebug("- ${pluginName}::handleChecklist($attributes,...refText...)") if $debug;

	my $query = &TWiki::Func::getCgiQuery();

	my $text="";

	&initDefaults() unless $defaultsInitialized;

	&initNamedDefaults($attributes);

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};

	if ((defined $query->param("clreset"))&&(!$resetDone)) {
		my $n=$query->param("clreset");
		my $s=(defined $query->param("clresetst"))?$query->param("clresetst"):$states[0];
		if (($options{'name'} eq $n)&&(grep(/^\Q$s\E$/s, @states))) {
			&doChecklistItemStateReset($n,$s,$refText);
			$resetDone=1;
		}
	}
	my $legend = $options{'showlegend'}?&renderLegend():"";

	if (defined $options{'reset'} && !$options{'static'}) {
		$namedResetIds{$name}++;
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

		my $action = &createResetAction($name, $state);
 
		$text.=qq@<noautolink>@;
		if ( ! $options{'useforms'}) {
			$text.=$query->a({name=>"reset${name}"}, '&nbsp;') if $options{'anchors'} && !$options{'useajax'};
			$text.=$legend;
			my $linktext="";
			my $imgparams = {title=>$title, alt=>$title, border=>0};
			$$imgparams{src}=$imgsrc if (defined $imgsrc ) && ($imgsrc!~/^\s*$/s);
			$linktext.=$query->img($imgparams);
			$linktext.=qq@ ${title}@ if ($title!~/^\s*$/i)&&($imgsrc ne "");
			$action="javascript:submitItemStateChange('$action');" if $options{'useajax'} && ($state ne 'STATESEL');
			my $id = &urlEncode("${name}_${state}_".$namedResetIds{$name});
			if ($state eq 'STATESEL') {
				$text.=&createHiddenDirectResetSelectionDiv($namedResetIds{$name},$name,\@states,\@icons); 
				$action="javascript:clpTooltipShow('CLP_SM_DIV_RESET_${name}_$namedResetIds{$name}', 'CLP_A_$id',10,10,true);";
			}
			$text.=$query->a({href=>$action,id=>'CLP_A_'.$id}, $linktext);
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
sub createResetAction {
	my ($name, $state) = @_;
	my $action=&TWiki::Func::getViewUrl($web,$topic);
	$action=~s/#.*$//s;
	$action.=&getUniqueUrlParam($action);


	if ( ! $options{'useforms'} ) {
		$action.=($action=~/\?/?';':'?');
		$action.="clreset=".&urlEncode($name);
		$action.=";clresetst=".&urlEncode($state);
		$action.=';skin='.&urlEncode($options{'ajaxtopicstyle'}) if $options{'useajax'};
	}

	$action.="#reset${name}" if $options{'anchors'} && (!($options{'useajax'}||$options{'useforms'}));
	return $action;
}
# =========================
sub createHiddenDirectResetSelectionDiv {
	my ($id, $name, $statesRef, $iconsRef) = @_;
	my $selTxt ="";
	my $query = &TWiki::Func::getCgiQuery();
	$selTxt=$query->a({-href=>"javascript:clpTooltipHide('CLP_SM_DIV_RESET_${name}_$id');"},$query->sup('[X]'));
	for (my $i=0; $i<=$#$statesRef; $i++) {
		my $s = $$statesRef[$i];
		my $action = &createResetAction($name, $s);
		$action="javascript:submitItemStateChange('$action');clpTooltipHide('CLP_SM_DIV_RESET_${name}_$id');" if $options{'useajax'};
		$selTxt.=$query->a({-href=>$action,-title=>$s,-style=>'vertical-align:bottom;'}, 
			$query->img({id=>"CLP_SM_IMG_RESET_${name}_$id",src=>&getImageSrc($$iconsRef[$i]),alt=>"",border=>0,style=>'cursor:move;vertical-align:bottom'}));
	}

	return $query->div({-id=>"CLP_SM_DIV_RESET_${name}_$id",
			    -style=>"visibility:hidden;position:absolute;top:0;left:0;z-index:2;font: normal 8pt sans-serif;padding: 3px; border: solid 1px; background-color: $options{'tooltipbgcolor'};" }, $selTxt);
}
# =========================
sub substAttributes {
	my ($attributes, $p) = @_;
	
	my %attrHash = &TWiki::Func::extractParameters($attributes);
	my %pHash = (defined $p?&TWiki::Func::extractParameters($p):());
	
	foreach my $a (keys %attrHash) {
		$pHash{$a}=$attrHash{$a};
	}
	my $attr ="";
	foreach my $a (keys %pHash) {
		$attr .= ' '.$a.'="'.$pHash{$a}.'"';
	}
	
	return '%CLI{'.$attr.'}%';
}
# =========================
sub substItemLine {
	my ($l,$attribs)=@_;
	if ($l=~s/(\#\S+)//) {
		$attribs.=" id=\"$1\"";
	}
	if ($l=~/\%CLI{.*?}\%/) {
		$l=~s/\%CLI{(.*?)}\%/\%CLI{$1 $attribs}\%/g;
	} else {
		if (lc($options{'clipos'}) eq 'left') {
			$l=~s/^(\s+[\d\*]+)/"$1 \%CLI{$attribs}% "/e;
		} else {
			$l=~s/^(\s+[\d\*]+.*?)$/"$1 \%CLI{$attribs}%"/e;
		}
	}
	
	return $l;	
};
# =========================
sub handleAutoChecklist {
	my ($attributes, $text) = @_;

	TWiki::Func::writeDebug("- ${pluginName}::handleAutoChecklist($attributes,...text...)") if $debug;

	&initDefaults() unless $defaultsInitialized;

	&initNamedDefaults($attributes);

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	$text=~s/\%CLI(\{([^\}]*)\})?\%/&substAttributes($attributes, $2)/meg;
	$text=~s/^(\s+[\d\*]+.*?)$/&substItemLine($1,$attributes)/meg;

	if (lc($options{'pos'}) eq 'top' ) {
		$text="\%CHECKLIST{$attributes}\%\n$text";
	} else {
		$text.="\n\%CHECKLIST{$attributes}\%";
	}

	return $text;

}
# =========================
sub handleChecklistItem {
	my ($attributes, $text,$textBefore,$textAfter) = @_;

	TWiki::Func::writeDebug("- ${pluginName}::handleChecklistItem($attributes)") if $debug;

	&initDefaults() unless $defaultsInitialized;

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	$namedIds{$options{'name'}}++ unless defined $options{'id'};

	&handleDescription($textBefore, $textAfter);

	my $query = &TWiki::Func::getCgiQuery();

	if ((defined $query->param('clpsc'))&&(!$stateChangeDone)) {
		my ($id,$name,$lastState,$nextstate) = ($query->param('clpsc'),$query->param('clpscn'),$query->param('clpscls'),$query->param('clpscns'));
		if ($options{'name'} eq $name) {
			&doChecklistItemStateChange($id, $name, $lastState, $text, $nextstate) ;
			$stateChangeDone=1;
		}
	}


	return &renderChecklistItem();

}
# =========================
sub handleDescription  {
	my ($textBefore, $textAfter) = @_;
	### TWiki::Func::writeWarning("textBefore='$textBefore', textAfter='$textAfter'");
	my $descr = $$idMapRef{$options{'name'}}{$options{'id'}?$options{'id'}:$namedIds{$options{'name'}}}{'descr'};
	unless ( (defined $options{'descr'}) || ((defined $descr)&&($descr!~/^\s*$/))) {
		$options{'descr'}=$options{'text'} if (defined $options{'text'})&&($options{'text'}!~/^\s*$/s);

		my $text = $textBefore;
		$text.=" ... " if $textBefore !~ /^\s*$/;
		$text.=$textAfter;
		$text.=" ..." if $textAfter !~ /^\s*$/;
		$options{'descr'}=$text unless defined $options{'descr'};
		
		$options{'descr'}=~s/^\s{3,}[\*\d]//sg; ## remove lists
		$options{'descr'}=~s/\|/ /sg; ## remove tables
		$options{'descr'}=~s/<[\/]?[^>]+>/ /sg; ## remove HTML tags
		$options{'descr'}=~s/\%\w+[^\%]*\%/ /sg; ## remove variables

		$options{'descr'}=~s/\s{2,}/ /g; ## remove multiple spaces
		$options{'descr'}=~s/^\s*//g;  
		$options{'descr'}=~s/\s*$//g;  
		

	};
	$options{'descr'}=substr($options{'descr'},0,$options{'descrcharlimit'}) 
		if (defined $options{'descr'})&&(length($options{'descr'})>$options{'descrcharlimit'});
}

# =========================
sub getNextState {
	my ($name, $lastState) = @_;
	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};

	$lastState=$states[0] if ! defined $lastState;

	my $state = $states[0];
	my $icon = $icons[0];
	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $lastState) {
			$state=($i<$#states)?$states[$i+1]:$states[0];
			$icon=($i<$#states)?$icons[$i+1]:$icons[0];
			last;
		}
	}
	TWiki::Func::writeDebug("- ${pluginName}::getNextState($name, $lastState)=$state; allstates=".$options{states}) if $debug;

	return ($state, $icon);
	
}
# =========================
sub checkChangeAccessPermission {
	my ($name, $text) = @_;
	my $ret = 1;

	my $perm = 'CHANGE';
	my $checkTopic = $topic;
	unless (&TWiki::Func::topicExists($web, &getClisTopicName($name))) {
		$perm='CREATE';
		$checkTopic = &getClisTopicName($name);
		$text = undef;
	}
		

	my $mainWebName=&TWiki::Func::getMainWebname();
	my $user =TWiki::Func::getWikiName();
	$user = "$mainWebName.$user" unless $user =~ m/^$mainWebName\./;

	if ( ! &TWiki::Func::checkAccessPermission($perm, $user, $text, $checkTopic, $web)) {
		$ret = 0;

		eval { require TWiki::AccessControlException; };
		if ($@) {
			TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(),TWiki::Func::getOopsUrl($web,$checkTopic,"oopsaccesschange"));
		} else {
			require Error;
			throw TWiki::AccessControlException(
					$perm, 
					$TWiki::Plugins::SESSION->{user},
					$checkTopic, $web, 'denied'
				);
		}
	}
	return $ret;
}
# =========================
sub extractPerms {
	my ($text) = @_;
	my $perms;

	$perms=join("\n",grep /^\s+\*\s*Set (ALLOW|DENY).+/i,split(/\n/,$text));

	return $perms;
}
# =========================
sub doChecklistItemStateReset {
	my ($n, $state, $text) = @_;
	TWiki::Func::writeDebug("- ${pluginName}::doChecklistItemStateReset($n,$state,...text...)") if $debug;

	# access granted?
	return if ! &checkChangeAccessPermission($n, $text);

	if (!defined $state) {
		my @states=split /\|/, $options{'states'};
		$state=$states[0];
	}
	foreach my $id (keys %{$$idMapRef{$n}}) {
		$$idMapRef{$n}{$id}{'state'}=$state;
	}
	&saveChecklistItemStateTopic($n,&extractPerms($text)) if (!$saveDone) && (($saveDone=!$saveDone));
}
# =========================
sub doChecklistItemStateChange {
	my ($id, $n, $lastState, $text, $nextstate) = @_;
	TWiki::Func::writeDebug("- ${pluginName}::doChecklistItemStateChange($id,$n,$lastState,...text...)") if $debug;

	# access granted?
	return if ! &checkChangeAccessPermission($n, $text);
	
	# reload?
	return if ((defined $$idMapRef{$n}{$id}{'state'})&&($$idMapRef{$n}{$id}{'state'} ne $lastState));

	$$idMapRef{$n}{$id}{'state'}=(defined $nextstate?$nextstate:(&getNextState($n, $$idMapRef{$n}{$id}{'state'}))[0]);

	&saveChecklistItemStateTopic($n,&extractPerms($text)) if (!$saveDone) && (($saveDone=!$saveDone));
}
# =========================
sub createAction {
	my ($id, $name, $state, $nextstate) = @_;
	my $action=TWiki::Func::getViewUrl($web,$topic);

	# remove anchor:
	$action=~s/#.*$//i; 

	$action.=getUniqueUrlParam($action);

	if ( ! $options{'useforms'} ) {
		$action.=($action=~/\?/)?";":"?";
		$action.="clpsc=".&urlEncode("$id");
		$action.=";clpscn=".&urlEncode($name);
		$action.=";clpscls=".&urlEncode($state);
		$action.=";clpscns=".&urlEncode($nextstate) if defined $nextstate;
		$action.=';skin='.&urlEncode($options{'ajaxtopicstyle'}) if $options{'useajax'};
	}
	my $query = &TWiki::Func::getCgiQuery();
	my %queryVars = $query->Vars();
	foreach my $p (keys %queryVars) {
		$action.=";$p=".&urlEncode($queryVars{$p}) 
			unless ($p =~ /^(clp.*|clreset.*|contenttype|skin)$/i)||(!$queryVars{$p});
	}
	$action.="#$name$id" if $options{'anchors'} && (!$options{'useajax'});

	return $action;
}
# =========================
sub createTitle {
	my ($name,$state,$icon,$statesRef, $nextstate, $nextstateicon) = @_;
	my $query = &TWiki::Func::getCgiQuery();
	my $title = $options{'tooltip'};
	$title = $state unless defined $title;
	$title=~s /\%STATE\%/$state/sg;
	$title=~s /\%NEXTSTATE\%/($nextstate?$nextstate:(&getNextState($name,$state))[0])/esg;
	$title=~s /\%STATECOUNT\%/($#$statesRef+1)/esg;
	$title=~s /\%STATES\%/join(", ",@{$statesRef})/esg;
	$title=~s /\%LEGEND\%/&renderLegend()/esg;
	$title=~s /\%STATEICON\%/$query->img({src=>&getImageSrc($icon),alt=>$state})/esg;
	$title=~s /\%NEXTSTATEICON\%/$query->img({src=>&getImageSrc($nextstateicon?$nextstateicon:(&getNextState($name,$state))[1]),alt=>$nextstate})/esg;
	return $title;
}
# =========================
sub renderChecklistItem {
	TWiki::Func::writeDebug("- ${pluginName}::renderChecklistItem()") if $debug;
	my $query = &TWiki::Func::getCgiQuery();
	my $text = "";
	my $name = $options{'name'};

	my $tId = $options{'id'}?$options{'id'}:$namedIds{$name};

	my @states = split /\|/, $options{'states'};
	my @icons = split /\|/, $options{'stateicons'};

	### TWiki::Func::writeDebug("- ${pluginName}::stateicons=".$options{'stateicons'}) if $debug;

	my $state = (defined $$idMapRef{$name}{$tId}{'state'}) ? $$idMapRef{$name}{$tId}{'state'} : $states[0];
	my $icon = $icons[0];

	$$idMapRef{$name}{$tId}{'state'}=$state unless defined $$idMapRef{$name}{$tId}{'state'};
	$$idMapRef{$name}{$tId}{'descr'}=$options{'descr'} if defined $options{'descr'};

	push(@{$$idOrderRef{$name}}, $tId) unless grep(/^\Q$tId\E$/,@{$$idOrderRef{$name}});

	for (my $i=0; $i<=$#states; $i++) {
		if ($states[$i] eq $state) {
			$icon=$icons[$i];
			last;
		}
	}

	my ($iconsrc,$textBef,$textAft)=&getImageSrc($icon);

	my $stId = &substIllegalChars($tId); # substituted tId
	my $heState = &htmlEncode($state); # HTML encoded state
	my $ueState = &urlEncode($state); # URL encoded state
	my $uetId = &urlEncode($tId); # URL encoded tId


	my $action = &createAction($stId, $name, $state);

	$text.=qq@<noautolink>@;
	
	$text.=$query->comment("\[CLTABLEPLUGINSORTFIX\]");
	$text.=$heState;
	$text.=$query->comment("\[/CLTABLEPLUGINSORTFIX\]");

	$text.=$query->a({name=>"$name$uetId"}, "&nbsp;") if $options{'anchors'} && !$options{'useajax'};

	if ( ! $options{'useforms'} || $options{'static'}) {
		
		my $linktext="";
		if (lc($options{'clipos'}) ne 'left') {
			$linktext.=$options{'text'}.' ' unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}

		my $title = &createTitle($name, $state, $icon, \@states);

		$linktext.=qq@$textBef@ if $textBef;

		$linktext.=$query->img({id=>"CLP_IMG_$name$uetId", -src=>$iconsrc, -border=>0, -alt=>""});
		$linktext.=qq@$textAft@ if $textAft;
		if (lc($options{'clipos'}) eq 'left') {
			$linktext.=' '.$options{'text'} unless $options{'text'} =~ /^(\s|\&nbsp\;)*$/;
		}
		if ($options{'static'}) {
			$text .= $linktext;
		} else {
			my ($onmouseover, $onmouseout)=("","");
			$action="javascript:submitItemStateChange('$action');" if $options{'useajax'};
			$onmouseover="clpTooltipShow('CLP_TT_$name$uetId','CLP_A_$name$uetId',20,20,true);";
			$onmouseout="clpTooltipHide('CLP_TT_$name$uetId');";
			$text .= $query->div({-id=>"CLP_TT_$name$uetId",-style=>"visibility:hidden;position:absolute;top:0;left:0;z-index:2;font: normal 8pt sans-serif;padding: 3px; border: solid 1px; background-color: $options{'tooltipbgcolor'};"},$title);
			if ($options{'statesel'}) {
				$action="javascript:clpTooltipShow('CLP_SM_DIV_$name$uetId','CLP_A_$name$uetId',10,10,true);";
				$text .= &createHiddenDirectSelectionDiv($uetId, $name, $state, $icon, \@states, \@icons);
			}
			$text .= $query->a({-onmouseover=>$onmouseover,-onmouseout=>$onmouseout,-id=>"CLP_A_$name$uetId",-href=>$action}, $linktext);
		}
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
sub createHiddenDirectSelectionDiv {
	my ($id, $name, $state, $icon, $statesRef, $iconsRef) =  @_;
	my $text ="";
	
	my $query = &TWiki::Func::getCgiQuery();
	my $sl="";
	$sl.=$query->sup($query->a({-href=>"javascript:clpTooltipHide('CLP_SM_DIV_$name$id');", -title=>'close'},'[X]'));
	for (my $i=0; $i<=$#$statesRef; $i++) {
		my ($s, $ic) = ($$statesRef[$i], $$iconsRef[$i]);
		my $action = &createAction($id, $name, $state, $s);
		my $title = &createTitle($name,$state,$icon,$statesRef, $s, $ic);
		$action="javascript:submitItemStateChange('$action');clpTooltipHide('CLP_SM_DIV_$name$id');" if $options{'useajax'};
		$text .= $query->div({-id=>"CLP_SM_TT_$name${id}_$i",-style=>"visibility:hidden;position:absolute;top:0;left:0;z-index:3;font: normal 8pt sans-serif;padding: 3px; border: solid 1px; background-color: $options{'tooltipbgcolor'};"},$title); 
		$sl.=$query->a({
					-id=>"CLP_SM_A_$name${id}_$i", 
					-href=>"$action",
					-style=>'vertical-align:bottom;',
					-onmouseover=>"clpTooltipShow('CLP_SM_TT_$name${id}_$i','CLP_SM_IMG_$name${id}_$i',20,20);", 
					-onmouseout=>"clpTooltipHide('CLP_SM_TT_$name${id}_$i');",
				},
				$query->img({src=>&getImageSrc($ic),id=>"CLP_SM_IMG_$name${id}_$i",alt=>"",border=>0,style=>'vertical-align:bottom;cursor:move;',alt=>""}));
		$sl.='&nbsp;';
	}

	$text.= $query->div({-id=>"CLP_SM_DIV_$name$id",
			-style=>"visibility:hidden;position:absolute;top:0;left:0;z-index:2;font: normal 8pt sans-serif;padding: 3px; border: solid 1px; background-color: $options{'tooltipbgcolor'};"}, $sl);

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
	return "" unless defined $txt;
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
	my $clisTopicName = $options{'statetopic'};
	TWiki::Func::writeDebug("- ${pluginName}::readChecklistItemStateTopic($topic, $web): $clisTopicName") if $debug;

	my $clisTopic = TWiki::Func::readTopicText($web, $clisTopicName);

	if ($clisTopic =~ /^http.*?\/oops/) {
		TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(), $clisTopic);
		return;
	}

	foreach my $line (split /[\r\n]+/, $clisTopic) {
		if ($line =~ /^\s*\|\s*([^\|\*\s]*)\s*\|\s*([^\|\*\s]*)\s*\|\s*([^\|\s]*)\s*\|(\s*([^\|]+)\s*\|)?\s*$/) {
			my ($name,$id,$state,$descr) = ($1,$2,$3,$5);
			$$idMapRef{$name}{$id}{'state'}=$state;
			$$idMapRef{$name}{$id}{'descr'}=$descr;
			push(@{$$idOrderRef{$name}}, $id) unless grep(/^\Q$id\E$/,@{$$idOrderRef{$name}});
		}
	}
}
# =========================
sub getClisTopicName {
	my ($name) = @_;
	return $namedDefaults{$name}{'statetopic'}?$namedDefaults{$name}{'statetopic'}:$globalDefaults{'statetopic'};
}
# =========================
sub saveChecklistItemStateTopic {
	my ($name,$perm) = @_;
	return if $name eq "";
	my $clisTopicName = &getClisTopicName($name);

	TWiki::Func::writeDebug("- ${pluginName}::saveChecklistItemStateTopic($name): $clisTopicName, ".$namedDefaults{$name}{'statetopic'}) if $debug;
	my $oopsUrl = &TWiki::Func::setTopicEditLock($web, $clisTopicName, 1);
	if ($oopsUrl) {
		&TWiki::Func::redirectCgiQuery(TWiki::Func::getCgiQuery(), $oopsUrl);
		return;
	}
	my $topicText = "";
	$topicText.="%RED% WARNING! THIS TOPIC IS GENERATED BY $installWeb.$pluginName PLUGIN. DO NOT EDIT THIS TOPIC (except table data)!%ENDCOLOR%\n";
	$topicText.=qq@%BR%Back to the \[\[$web.$topic\]\[checklist topic $topic\]\].\n\n@;
	foreach my $n ( sort keys %{ $idMapRef } ) {
		next if ($clisTopicName ne $globalDefaults{'statetopic'})&&((!defined $namedDefaults{$n}{'statetopic'})||($clisTopicName ne $namedDefaults{$n}{'statetopic'}));
		next if (($namedDefaults{$n}{'statetopic'})&&($clisTopicName ne $namedDefaults{$n}{'statetopic'}));

		my $states = ($name eq $n)?$options{'states'}:undef;
		$states = $namedDefaults{$n}{'states'} unless defined $states && $states ne "";
		$states = &TWiki::Func::getPreferencesValue("\U$pluginName\E_STATES") unless defined $states && $states ne "";
		$states = $globalDefaults{'states'} unless defined $states && $states ne "";
		my $statesel = join ", ",  (split /\|/, $states);
		$topicText.="\n";
		$topicText.=qq@%EDITTABLE{format="|text,20,$n|text,10,|select,1,$statesel|textarea,2,|"}%\n@;
		$topicText.=qq@%TABLE{footerrows="1"}%\n@;
		$topicText.="|*context*|*id*|*state*|*description*|\n";
		
		###foreach my $id (sort keys %{ $$idMapRef{$n}}) {
		foreach my $id (@{ $$idOrderRef{$n}}) {
			$topicText.="|$n|".&htmlEncode($id)."|".&htmlEncode($$idMapRef{$n}{$id}{'state'})."| ".&htmlEncode($$idMapRef{$n}{$id}{'descr'})." |\n";
		}
		$topicText.=qq@| *$n* | *statistics:* | *%CALC{"\$COUNTITEMS(R2:C\$COLUMN()..R\$ROW(-1):C\$COLUMN())"}%* | *entries: %CALC{"\$ROW(-2)"}%* |\n@;
	}
	if ($perm) {
		$topicText.="\nAccess rights inherited from $web.$topic:\n\n";
		$topicText.="\n$perm\n" if $perm;
	}
	$topicText.="\n-- $installWeb.$pluginName - ".&TWiki::Func::formatTime(time(), "rcs")."\n";
	TWiki::Func::saveTopicText($web, $clisTopicName, $topicText, 1, !$options{'notify'});
	TWiki::Func::setTopicEditLock($web, $clisTopicName, 0);
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
# =========================
sub collectAllChecklistItems {
	local(%namedIds,$resetDone,$stateChangeDone, %options, %namedDefaults);
 
	TWiki::Func::writeDebug( "- ${pluginName}::collectAllChecklistItems()" ) if $debug;

	####my ($text) = &TWiki::Func::readTopicText($web, $topic);
	####return if ($text =~ /^http.*?\/oops/);
	my $text = $initText;

	# remove verbatim/pre blocks:
	####$text=~s/<(verbatim|pre)[^>]*>.*?<\/\1[^>]*>//isg;

	# prevent changes:
	$resetDone=1; $stateChangeDone=1;

	&commonTagsHandler($text, $topic, $web);

	TWiki::Func::writeDebug( "- ${pluginName}::collectAllChecklistItems() done!" ) if $debug;
}
# =========================
sub postRenderingHandler  {
	my $query = TWiki::Func::getCgiQuery();
	if (defined $query) {
		my $startTag=$query->comment("\[CLTABLEPLUGINSORTFIX\]");
		my $endTag=$query->comment("\[/CLTABLEPLUGINSORTFIX\]");
		$_[0]=~s/\Q$startTag\E.*?\Q$endTag\E//sg;
	}
}
# =========================
sub endRenderingHandler  {
	return postRenderingHandler( @_ );
}
1;
