# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
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

package TWiki::Plugins::SkillsPlugin;

# TODO: Conditional require
require TWiki::Plugins::SkillsPlugin::Category;
require TWiki::Plugins::SkillsPlugin::Skill;
require TWiki::Plugins::SkillsPlugin::UserSkill;

use strict;
use vars qw(    $VERSION
                $RELEASE
                $NO_PREFS_IN_TOPIC
                $SHORTDESCRIPTION
                $pluginName
                $doneYui
        );

# Plugin Variables
$VERSION = '$Rev: 9813$';
$RELEASE = 'Dakar';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Allows users to list their skills, which can then be searched';
$pluginName = 'SkillsPlugin';

# ========================= INIT
sub initPlugin {
    
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        _Warn( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Register tag %SKILLS%
    TWiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );
    
    # Register REST handlers
    ##my $v = 0; could register only on certain topics (as defined in configure/preferences ##
    #if( $v != 0 {
    TWiki::Func::registerRESTHandler('addNewCategory', \&_restAddNewCategory );
    TWiki::Func::registerRESTHandler('renameCategory', \&_restRenameCategory );
    TWiki::Func::registerRESTHandler('deleteCategory', \&_restDeleteCategory );
    TWiki::Func::registerRESTHandler('addNewSkill', \&_restAddNewSkill );
    
    TWiki::Func::registerRESTHandler('getCategories', \&_restGetCategories );
    TWiki::Func::registerRESTHandler('getSkills', \&_restGetSkills );
    #}
    TWiki::Func::registerRESTHandler('getSkillDetails', \&_restGetSkillDetails );
    TWiki::Func::registerRESTHandler('addEditSkill', \&_restAddEditSkill );
    
    $doneYui = 0;

    _Debug("initPlugin is OK");

    return 1;
}

# ========================= TAGS
sub _handleTag {

    my $out = '';

    my $action = $_[1]->{action} || $_[1]->{_DEFAULT} || return 'No action specified';

    my $start = "<noautolink>\n";
    my $end = "\n</noautolink>";

    for ($action){
        /user/ and $out = $start . TWiki::Plugins::SkillsPlugin::_tagUserSkills($_[1]) . $end, last;
    #    /group/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_tagGroupSkills($_[1]) . $end, last; # shows skills for a particular group
        /browse/ and $out = $start . TWiki::Plugins::SkillsPlugin::_tagBrowseSkills($_[1]) . $end, last;
        /edit/ and $out = $start . TWiki::Plugins::SkillsPlugin::_tagEditSkills($_[1]) . $end, last;
        /showskill/ and $out = $start . TWiki::Plugins::SkillsPlugin::_tagShowSkills($_[1]) . $end, last;
        /showcat/ and $out = $start . TWiki::Plugins::SkillsPlugin::_tagShowCategories($_[1]) . $end, last; # show all categories in a format
    #    /search/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_searchForm($_[1]) . $end, last;
    }

    #_addCssStyle();

    #$allowedit = 0;

    return $out;
}

# allows the user to print all categories in format of their choice
sub _tagShowCategories {
    
    my $params = shift;
    
    return _showCategories(
        $params->{format},
        $params->{separator}
        );
}

sub _tagShowSkills {
    my $params = shift;
    
    return _showSkills(
        $params->{category},
        $params->{format},
        $params->{separator},
        $params->{prefix},
        $params->{suffix}
        );
}

# creates a form allowing users to edit their skills
sub _tagEditSkills {
    
    # SMELL:
    # CSS (where is best? needs to be defineable and overrideable)

    my $user = TWiki::Func::getWikiName();
    
    my $out = TWiki::Func::readTemplate( 'skillsedit' );
    
    # expand our variables in template
    my $formDef = 'name="addedit-skill-form" id="addedit-skill-form"';
    $out =~ s/%FORMDEFINITION%/$formDef/g;
    
    my $messageContainerDef = 'id="addedit-skills-message-container"  style="display:none;"';
    $out =~ s/%SKILLMESSAGECONTAINERDEF%/$messageContainerDef/g;
    my $messagePic = _getImages('info');
    my $message = "$messagePic <span id='addedit-skills-message'></span>";
    $out =~ s/%SKILLMESSAGE%/$message/g;
    
    # get categories
    my $catSelect = '<select name="category" id="addedit-category-select"></select>';
    $out =~ s/%CATEGORYSELECT%/$catSelect/g;
    
    my $skillSelect = '<select name="skill" id="addedit-skill-select"></select>';
    $out =~ s/%SKILLSELECT%/$skillSelect/g;
    
    $out =~ s!%RATINGSELECT\{1\}%!<input type="radio" name="addedit-skill-rating" value="1" />!g;
    $out =~ s!%RATINGSELECT\{2\}%!<input type="radio" name="addedit-skill-rating" value="2" />!g;
    $out =~ s!%RATINGSELECT\{3\}%!<input type="radio" name="addedit-skill-rating" value="3" />!g;
    $out =~ s!%RATINGSELECT\{4\}%!<input type="radio" name="addedit-skill-rating" value="4" />!g;
    $out =~ s!%RATINGSELECT\{0\}%!<input type="radio" name="addedit-skill-rating" value="0" />!g;
    
    my $comment = 'id="addedit-skill-comment" type="text" name="comment"';
    $out =~ s/%SKILLCOMMENTDEF%/$comment/g;
    
    # to clear textbox
    my $clearPic = _getImages('clear');
    my $clear = "<span id='addedit-skill-comment-clear' style='display:none;'>$clearPic</span>";
    $out =~ s/%SKILLCOMMENTCLEAR%/$clear/g;
    
    my $submit = '<input name="skill-submit" id="addedit-skill-submit" type="button" value="Add/Edit" class="twikiSubmit">';
    $out =~ s/%SKILLSUBMIT%/$submit/g;
    
    # add CSS to head
    _addYUI();
    TWiki::Func::addToHEAD('SKILLSPLUGIN_EDITSKILLS_CSS','<style type="text/css" media="all">@import url("/twiki/pub/TWiki/SkillsPlugin/style.css");</style>');
    TWiki::Func::addToHEAD('SKILLSPLUGIN_EDITSKILLS_JS','<script src="/twiki/pub/TWiki/SkillsPlugin/main.js" language="javascript" type="text/javascript"></script>');
    
    return $out;
}

sub _tagUserSkills {
    
    my $params = shift;
    
    my $user = $params->{user} || TWiki::Func::getWikiName();
    my $twisty = $params->{twisty} || 'closed';
    
    my $out = TWiki::Func::readTemplate( 'skillsuserview' );
    my $tmplRepeat = TWiki::Func::readTemplate( 'skillsuserviewrepeated' );
    
    my( undef, $tmplCat, $tmplSkillContStart, $tmplSkillStart, $tmplSkill, $tmplRating, $tmplComment, $tmplSkillEnd, $tmplSkillContEnd ) = split( /%SPLIT%/, $tmplRepeat );
    
    my $userSkills = _getUserSkills( $user );
    my $allSkills = _getAllSkills();
    
    # get image paths
    my $ratingPic = _getImages( 'star' );
    my $skillPic = _getImages( 'open' );
    my $commentPic = _getImages( 'comment' );
    my $twistyCloseImg = _getImages( 'twistyclose' );
    
    my $jsVars = "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "; # create namespace in JS
    
    my $repeatedLine;
    foreach my $cat ( @{ $allSkills } ){
        my $catDone = 0;
        my $skillOut = 0;
        
        foreach my $skill ( @{ $cat->getSkills(); } ){
            if( my $obj_userSkill = _getUserSkill( $user, $skill, $cat->name, $userSkills ) ){
                # produce output line
                # add to array/string which will be output in %REPEAT%
                my $lineOut;
                
                $skillOut = 1;
                
                # category
                unless( $catDone == 1 ){ 
                    $lineOut .= $tmplCat;
                    $lineOut .= $tmplSkillContStart
                }
                $catDone = 1;
                
                $lineOut .= $tmplSkillStart;
                
                # skill
                $lineOut .= $tmplSkill;
                
                # rating
                my $i = 1;
                while( $i < $obj_userSkill->rating ){
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i ++;
                }
                my $ratingOut = $tmplRating;
                $ratingOut =~ s/%RATING%/$ratingPic/g;
                $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
                $lineOut .= $ratingOut;
                $i ++;
                while( $i <= 4 ){
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i ++;
                }
                
                # comment
                $lineOut .= $tmplComment;
                
                $lineOut .= $tmplSkillEnd;
                
                # subsitutions
                #$lineOut =~ s!%SKILLTWISTY%!<span id="%CATEGORY%_twisty"></span>!g;
                #$lineOut =~ s/%CATEGORY%/$cat->name/ge;
                $lineOut =~ s/%SKILL%/$skill/g;
                $lineOut =~ s/%SKILLICON%/$skillPic/g;
                if( $obj_userSkill->comment ){
                    my $commentLink = "<span id='comment|" . $cat->name . "|$skill' title='" . $obj_userSkill->comment . "' class='SkillsPluginComments' >$commentPic</span>";
                    $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
                    $lineOut =~ s/%COMMENTOUT%/$obj_userSkill->comment/ge;
                } else {
                    $lineOut =~ s/%COMMENTLINK%//g;
                    $lineOut =~ s/%COMMENTOUT%//g;
                }
                
                $repeatedLine .= $lineOut;
            }
        }
        
        # subsitutions
        my $catTwist = '<span id="' . $cat->name . '_twistyImage" class="SkillsPlugin-twisty-link"> ' . $twistyCloseImg . '</span>';
        $repeatedLine =~ s!%SKILLTWISTY%!$catTwist!g;
        my $catLink = '<span id="' . $cat->name . '_twistyLink" class="SkillsPlugin-twisty-link">' . $cat->name . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        my $skillContDef = 'id="' . $cat->name . '_twist"';
        $repeatedLine =~ s/%SKILLCONTDEF%/$skillContDef/g;
        
        $repeatedLine .= $tmplSkillContEnd unless( $skillOut == 0 );
    }
    
    $out =~ s/%REPEAT%/$repeatedLine/g;
    $out =~ s/%SKILLUSER%/$user/g;
    
    $jsVars .= "SkillsPlugin.vars.twistyState = '$twisty';";
    my $twistyOpenImgSrc = _getImagesSrc( 'twistyopen' );
    $jsVars .= "SkillsPlugin.vars.twistyOpenImgSrc = \"$twistyOpenImgSrc\";";
    my $twistyCloseImgSrc = _getImagesSrc( 'twistyclose' );
    $jsVars .= "SkillsPlugin.vars.twistyCloseImgSrc = \"$twistyCloseImgSrc\";";
    
    _addYUI();
    TWiki::Func::addToHEAD('SKILLSPLUGIN_CSS','<style type="text/css" media="all">@import url("/twiki/pub/TWiki/SkillsPlugin/style.css");</style>');
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JS','<script src="/twiki/pub/TWiki/SkillsPlugin/main.js" language="javascript" type="text/javascript"></script>');
    
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JSVARS',"<script language='javascript' type='text/javascript'>$jsVars</script>");
    
    return $out;
}

sub _tagBrowseSkills {
    # parameteres:
    #category="Cat1, Cat2"
    #skill="Skill1, Skill2"
    #twisty="open"
    
    my $params = shift;
    my @pCat = split( ',' , $params->{category});
    my @pSkill = split( ',' , $params->{skill});
    my $twisty = $params->{twisty} || 'closed';
    
    my $allSkills = _getAllSkills();
    
    my $out = TWiki::Func::readTemplate( 'skillsbrowseview' );
    my $tmplRepeat = TWiki::Func::readTemplate( 'skillsbrowseviewrepeated' );
    
    my( undef, $tmplCat, $tmplSkillContStart, $tmplSkillStart, $tmplSkill, $tmplRating, $tmplComment, $tmplSkillEnd, $tmplSkillContEnd ) = split( /%SPLIT%/, $tmplRepeat );
    my $foo;
    
    # get image paths
    my $ratingPic = _getImages( 'star' );
    my $skillPic = _getImages( 'open' );
    my $commentPic = _getImages( 'comment' );
    my $twistyCloseImg = _getImages( 'twistyclose' );
    
    my $jsVars = "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "; # create namespace in JS
    
    my $repeatedLine;
    for my $cat ( @{ $allSkills } ){
        my $catDone = 0;
        my $skillOut = 0;
        
        # check if cat is wanted or if all are
        if( @pCat ){
            next unless _isInArray( $cat->name, \@pCat );
        }
        
        # print cat line
        $foo .= $cat->name;
        
        for my $skill ( @{ $cat->getSkills(); } ){
            # check if cat and skill is wanted or all are
            if( @pCat && @pSkill ){
                next unless _isInArray( $skill, \@pSkill );
            }
            
            # need to get all users that have this skill
            
            # produce output line
            # add to array/string which will be output in %REPEAT%
            my $lineOut;
            
            $skillOut = 1;
            
            # category
            unless( $catDone == 1 ){ 
                $lineOut .= $tmplCat;
                $lineOut .= $tmplSkillContStart
            }
            
            $lineOut .= $tmplSkillStart;
            
            # skill
            $lineOut .= $tmplSkill;
            
            # rating
            my $i = 1;
            while( $i < $obj_userSkill->rating ){
                my $ratingOut = $tmplRating;
                $ratingOut =~ s/%RATING%/&nbsp;/g;
                $ratingOut =~ s/%RATINGDEF%//g;
                $lineOut .= $ratingOut;
                $i ++;
            }
            my $ratingOut = $tmplRating;
            $ratingOut =~ s/%RATING%/$ratingPic/g;
            $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
            $lineOut .= $ratingOut;
            $i ++;
            while( $i <= 4 ){
                my $ratingOut = $tmplRating;
                $ratingOut =~ s/%RATING%/&nbsp;/g;
                $ratingOut =~ s/%RATINGDEF%//g;
                $lineOut .= $ratingOut;
                $i ++;
            }
            
            # comment
            $lineOut .= $tmplComment;
            
            $lineOut .= $tmplSkillEnd;
            
            # subsitutions
            #$lineOut =~ s!%SKILLTWISTY%!<span id="%CATEGORY%_twisty"></span>!g;
            #$lineOut =~ s/%CATEGORY%/$cat->name/ge;
            $lineOut =~ s/%SKILL%/$skill/g;
            $lineOut =~ s/%SKILLICON%/$skillPic/g;
            if( $obj_userSkill->comment ){
                my $commentLink = "<span id='comment|" . $cat->name . "|$skill' title='" . $obj_userSkill->comment . "' class='SkillsPluginComments' >$commentPic</span>";
                $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
                $lineOut =~ s/%COMMENTOUT%/$obj_userSkill->comment/ge;
            } else {
                $lineOut =~ s/%COMMENTLINK%//g;
                $lineOut =~ s/%COMMENTOUT%//g;
            }
            
            $repeatedLine .= $lineOut;
            
            # print skill line
            $foo .= $skill;
        }
        # subsitutions
        my $catTwist = '<span id="' . $cat->name . '_twistyImage" class="SkillsPlugin-twisty-link"> ' . $twistyCloseImg . '</span>';
        $repeatedLine =~ s!%SKILLTWISTY%!$catTwist!g;
        my $catLink = '<span id="' . $cat->name . '_twistyLink" class="SkillsPlugin-twisty-link">' . $cat->name . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        my $skillContDef = 'id="' . $cat->name . '_twist"';
        $repeatedLine =~ s/%SKILLCONTDEF%/$skillContDef/g;
        
        $repeatedLine .= $tmplSkillContEnd unless( $skillOut == 0 );
    }
    
    _addYUI();
    TWiki::Func::addToHEAD('SKILLSPLUGIN_CSS','<style type="text/css" media="all">@import url("/twiki/pub/TWiki/SkillsPlugin/style.css");</style>');
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JS','<script src="/twiki/pub/TWiki/SkillsPlugin/main.js" language="javascript" type="text/javascript"></script>');
    
    return $out;
}

# ========================= REST
sub _restAddNewCategory {
    
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: addNewCategory' );
    
    my $newCat = TWiki::Func::getCgiQuery()->param('newcategory');
    
    my $error = _addNewCategory( $newCat );
    
    my $message;
    if( $error ){
        $message = "Error adding category '$newCat' - $error";
    } else {
        $message = "New category '$newCat' added.";
    }
    
    $message = _urlEncode( $message );
    
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    my $url = TWiki::Func::getScriptUrl($web, $topic, 'view')
            . '?skillsmessage=' . $message;
    TWiki::Func::redirectCgiQuery( undef, $url );
}

sub _restRenameCategory {
    
}

sub _restDeleteCategory {
    
}

sub _restAddNewSkill {
    
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: addNewCategory' );
    
    my $newSkill = TWiki::Func::getCgiQuery()->param('newskill');
    my $cat = TWiki::Func::getCgiQuery()->param('incategory');
    
    #_Debug("$cat: $newSkill");
    
    my $error = _addNewSkill( $newSkill, $cat );
    
    my $message;
    if( $error ){
        $message = "Error adding skill '$newSkill' to category '$cat' - $error";
    } else {
        $message = "New category '$newSkill' added.";
    }
    
    $message = _urlEncode( $message );
    
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    my $url = TWiki::Func::getScriptUrl($web, $topic, 'view')
            . '?skillsmessage=' . $message;
    TWiki::Func::redirectCgiQuery( undef, $url );
}

sub _restRenameSkill {
    # rename the skill
    # need to change the skill file,
    # and the users
}

sub _restMoveSkill {
    
}

sub _restDeleteSkill {
    
}

sub _restGetCategories {
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getCategories' );
    
    my $out = _tagShowCategories( { format => '$category', separator => '|' } );
    return $out;
}

sub _restGetSkills {
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkills' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    my $out = _tagShowSkills( { category => $cat, format => '$skill', separator => '|' } );
    return $out;
}

sub _restGetSkillDetails {
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkillDetails' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    my $skill = TWiki::Func::getCgiQuery()->param('skill');
    
    my $user = TWiki::Func::getWikiName();
    
    _Debug( $user . $cat . $skill );
    
    my $obj_user = _getUserSkill($user, $skill, $cat);
    
    unless( $obj_user ){
        return '';
    }
    
    my $out = '{';
    $out .= _createJSON( {
            skill => $obj_user->name,
            category => $obj_user->category,
            rating => $obj_user->rating,
            comment => $obj_user->comment
    } );
    $out .= '}';
    return $out;
}

sub _restAddEditSkill {
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkillDetails' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    my $skill = TWiki::Func::getCgiQuery()->param('skill');
    my $rating = TWiki::Func::getCgiQuery()->param('addedit-skill-rating');
    my $comment = TWiki::Func::getCgiQuery()->param('comment');
    
    my $user = TWiki::Func::getWikiName();
    
    my $error = _addEditUserSkill( $user, $cat, $skill, $rating, $comment );
    
    my $message;
    if( $error ){
        $message = "Error adding/editing skill '$skill' - $error";
    } else {
        $message = "Skill '$skill' added/edited.";
    }
    
    return $message;
}

# ========================= FUNCTIONS
# adds a new category
sub _addNewCategory {
    # TODO: Permissions
    my( $newCat ) = @_;
    
    return 'Category not specified' unless( $newCat );
    
    my $allSkills = _getAllSkills();
    return 'Category already exists' if( _categoryExists( $newCat, $allSkills ) );
    
    my $new_obj_cat = TWiki::Plugins::SkillsPlugin::Category->new( $newCat );
    push @{ $allSkills }, $new_obj_cat;
    
    _saveSkills($allSkills);
    
    return undef; # no error
}

sub _addNewSkill {
    # TODO: Permissions
    my( $newSkill, $cat ) = @_;
    
    my $allSkills = _getAllSkills();
    my $obj_cat = _getCategoryByName( $cat, $allSkills );
    
    return 'Could not find category/category does not exist.' unless $obj_cat;
    
    my $skills = $obj_cat->getSkills;
    
    return 'Skill already exists.' if( $obj_cat->skillExists( $newSkill ) );
    
    $obj_cat->addSkill( $newSkill );
    
    my $obj_cat2 = _getCategoryByName( $cat, $allSkills );
    
    # Save to file
    _saveSkills($allSkills);
    
    return undef;
}

sub _showCategories {
    my ( $format, $separator ) = @_;
    
    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$category' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    my $text = '';
    my $line = '';
    
    my $allSkills = _getAllSkills();
    
    my @cats;
    foreach my $cat ( @{ $allSkills } ){
        push @cats, $cat->name;
    }
    
    $text = join(
        $separator,
            map {
                $line = $format;
                $line =~ s/\$category/$_/go;
                $line;
        } @cats
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
# TODO: specify multiple categories? needed?
sub _showSkills {
    #my $qCatSeparator = $params->{categoryseparator};
    my( $cat, $format, $separator, $prefix, $suffix, $catSeparator ) = @_;

    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go;
    $suffix =~ s/\$n/\n/go;


    my $text = '';
    my $line = '';
    
    # get all skills
    # if category is specified, only show skills in that category
    # else, show them all
    
    my $allSkills = _getAllSkills();
    
    if ($cat){
        
        my $skills;
        
        foreach my $obj_cat ( @{ $allSkills } ){
            if( $cat eq $obj_cat->name ){
                $skills = $obj_cat->getSkills;
                last;
            }
        }
        
        $text = join(
            $separator,
                map {
                    $line = $format;
                    $line =~ s/\$skill/$_/go;
                    $line;
            } @$skills
        );
        
        return $text;
        
    }
    # all skills and categories
    else {
        $catSeparator = "\n" unless ( $catSeparator ne '' );
        
        foreach my $obj_cat ( @{ $allSkills } ){
            my $prefixLine = $prefix;
            $prefixLine =~ s/\$category/$obj_cat->name/goe;
            $prefixLine =~ s/\$n/\n/go;
            $text .= $prefixLine;
            
            $text .= join(
                $separator,
                map {
                    $line = $format;
                    $line =~ s/\$category/$obj_cat->name/goe;
                    $line =~ s/\$skill/$_/go;
                    $line;
                } @{ $obj_cat->getSkills }
            );
            
            my $suffixLine = $suffix;
            $suffixLine =~ s/\$category/$obj_cat->name/goe;
            $suffixLine =~ s/\$n/\n/go;
            $text .= $suffixLine;

            # seperate each category
            $text .= $catSeparator;
        }

        return $text;
    }
}

# =========================
# gets all skills from file
# returns array of category objects
sub _getAllSkills {
    # TODO: could store in session to prevent multiple file reads?
    # TODO: could store using Storable? Or maybe in tmp?
    _Debug( 'reading skills.txt' );
    my $workArea =  TWiki::Func::getWorkArea( $pluginName );
    my $file;
    unless ( $file = TWiki::Func::readFile( $workArea . '/skills.txt' ) ){
        # no existing skills
        _Debug('skills.txt not found. No skills loaded.');
        return;
    }
    
    my @allSkills;
    
    my @text = grep { !/^\#.*/ } split('\n', $file);
    foreach my $line (@text){
        $line =~ s/(.*)://g;
        my $cat = $1;
        my @skills = split(',', $line);
        my $obj_cat = TWiki::Plugins::SkillsPlugin::Category->new($cat, \@skills);
        #push @{ $allSkills{$cat} }, @skills;
        push @allSkills, $obj_cat;
    }
    
    #@allSkills = sort @allSkills;
    # TODO: need to sort by cat->name...
    
    return \@allSkills;
    
}

sub _categoryExists {

    if( _getCategoryByName( @_ ) ){
        return 1;
    } else {
        return undef;
    }
}

sub _getCategoryByName {
    my( $cat, $allSkills ) = @_;
    
    foreach my $obj_cat( @{ $allSkills } ){
        if( lc$obj_cat->name eq lc$cat ){
            return $obj_cat;
        }
    }
    return undef;
}

# Saves all the available categories and skills
sub _saveSkills {
    my $allSkills = shift;
    my $out = "# This file is generated. Do NOT edit!\n";

    foreach my $obj_cat ( @{ $allSkills } ){
        $out .= $obj_cat->name . ':' . join(',', @{ $obj_cat->getSkills } ) . "\n";
    }

    my $workArea =  TWiki::Func::getWorkArea( $pluginName );

    TWiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

sub _getUserSkill {
    my( $user, $skill, $cat, $userSkills ) = @_;
    
    unless( $userSkills ){
        $userSkills = _getUserSkills( $user );
    }
    
    foreach my $obj_userSkill ( @{ $userSkills } ){
        if( $cat eq $obj_userSkill->category && $skill eq $obj_userSkill->name ){
            return $obj_userSkill;
        }
    }
    return undef;
}

sub _getUserSkills {
    my $userTopic = shift;

    my $mainWeb = TWiki::Func::getMainWebname();

    my( $meta, undef ) = TWiki::Func::readTopic( $mainWeb, $userTopic );
    my @skillsMeta = $meta->find('SKILLS');
    
    my @userSkills;
    foreach my $skillMeta ( @skillsMeta ){
        my $obj_userSkill = TWiki::Plugins::SkillsPlugin::UserSkill->new(
            $skillMeta->{name},
            $skillMeta->{category},
            $skillMeta->{rating},
            $skillMeta->{comment}
            );
        push @userSkills, $obj_userSkill;
    }
    
    return (\@userSkills);
}

sub _getAllUserSkills {
    
}

sub _addEditUserSkill {
    my ($user, $cat, $skill, $rating, $comment ) = @_;
    
    my $userSkills = _getUserSkills( $user );
    
    my $edited;
    foreach my $obj_userSkill ( @{ $userSkills } ){
        if( $cat eq $obj_userSkill->category && $skill eq $obj_userSkill->name ){
            $obj_userSkill->rating( $rating );
            $obj_userSkill->comment( $comment );
            $edited = 1;
            last;
        }
    }
    
    unless( $edited ){
        my $obj_newUserSkill = TWiki::Plugins::SkillsPlugin::UserSkill->new(
            $skill,
            $cat,
            $rating,
            $comment
            );
        push @{ $userSkills }, $obj_newUserSkill;
    }
    # save skills
    my $error = _saveUserSkills( $user, $userSkills );
    
    return $error;
}

sub _saveUserSkills {
    my( $user, $userSkills ) = @_;
    my $mainWeb = TWiki::Func::getMainWebname();

    my( $meta, $text ) = TWiki::Func::readTopic( $mainWeb, $user );

    $meta->remove('SKILLS');
    foreach my $obj_userSkill ( @{ $userSkills } ){
        $meta->putKeyed('SKILLS', {
                name => $obj_userSkill->name,
                category => $obj_userSkill->category,
                rating => $obj_userSkill->rating,
                comment => $obj_userSkill->comment
        }); 
    }
    my $error = TWiki::Func::saveTopic( $mainWeb, $user, $meta, $text, { dontlog => 1, comment=> 'SkillsPlugin', minor => 1 });
    if ($error){
        TWiki::Plugins::SkillsPlugin::_Warn("saveUserSkills error - $error");
    }
    return $error;
}

# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
sub _addYUI {

    return if ( $doneYui == 1 );
    $doneYui = 1;

    my $yui;
    #TODO
    eval 'use TWiki::Contrib::YahooUserInterfaceContrib';
    if (! $@ ) {
        _Debug( 'YahooUserInterfaceContrib is installed, using local files' );
        $yui = '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/connection/connection-min.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/element/element-beta-min.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/json/json-min.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/animation/animation-min.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/container/container-min.js"></script>'
             # style
             . '<link rel="stylesheet" type="text/css" href="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/container/assets/skins/sam/container.css" />';
    } else {
        _Debug( 'YahooUserInterfaceContrib is not installed, using Yahoo servers' );
        $yui = '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/connection/connection-min.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/element/element-beta-min.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/json/json-min.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/animation/animation-min.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/container/container-min.js"></script>'
             # style
             . '<link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.5.2/build/container/assets/skins/sam/container.css" />';
    }

    TWiki::Func::addToHEAD($pluginName . '_yui', $yui);
}

# ========================= UTILITIES
# Taken from TagMePlugin (http://twiki.org/cgi-bin/view/Plugins/TagMePlugin)
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

# because skills might be 'C++', a grep does not seem to be the best way to check a value is in an array
# therefore we loop array and use eq
# better way to this? please let me know! (andrewjones86@gmail.com)
sub _isInArray {
    my( $match, $array ) = @_;
    
    for( @{ $array } ){
        return 1 if( lc( $_ ) eq lc( $match ) );
    }
    return 0;
}

sub _createJSON {
    my $params = shift;
    # loop over param keys
    # create the JSON (internal only i.e. just the inner part (TODO better explanation!))
    # "param":"key" # TODO key could be array?
    my $out;
    while( my ( $key, $value ) = each( %{ $params } ) ){
        $out .= "\"$key\":\"$value\",";
    }
    $out =~ s/,$//;
    return $out;
}

# gets the images used in output table
sub _getImages {

    my $image = shift;

    my $docpath = _getDocPath();
        
    # Create image tags. Mainly to set a helpful alt attribute
    for ($image){
        /twistyopen/ and return "<img width='16' alt='twisty open' align='top' src='$docpath/toggleopen.gif' height='16' border='0' />", last;
        /twistyclose/ and return "<img width='16' alt='twisty close' align='top' src='$docpath/toggleclose.gif' height='16' border='0' />", last;
        /star/ and return "<img width='16' alt='*' align='top' src='$docpath/stargold.gif' height='16' border='0' />", last;
        /open/ and return "<img width='16' alt='-' align='top' src='$docpath/dot_ur.gif' height='16' border='0' />", last;
        /comment/ and return "<img width='16' alt='+' class='SkillsPlugins-comment-img' align='top' src='$docpath/note.gif' height='16' border='0' />", last;
        /clear/ and return "<img width='16' alt='Clear' align='top' src='$docpath/choice-cancel.gif' height='16' border='0' />", last;
        /info/ and return "<img width='16' alt='Info' align='top' src='$docpath/info.gif' height='16' border='0' />", last;
    }
}

# gets the images used in output table
sub _getImagesSrc {

    my $image = shift;

    my $docpath = _getDocPath();
        
    # Create image tags. Mainly to set a helpful alt attribute
    for ($image){
        /twistyopen/ and return "$docpath/toggleopen.gif", last;
        /twistyclose/ and return "$docpath/toggleclose.gif", last;
    }
}

sub _getDocPath {
    return TWiki::Func::getPubUrlPath() . '/' . # /pub/
           TWiki::Func::getTwikiWebname() . '/' . # TWiki/
           'TWikiDocGraphics'; # doc topic
}

sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning( "- TWiki::Plugins::${pluginName}: $text" );
}

# logs actions in the standard twiki log
sub _Log {
    my $text = shift;

    my $logAction = $TWiki::cfg{Plugins}{$pluginName}{Log} || 1;

    my ($web, $topic) = _getCurrentTopic();

    if ($logAction) {
        $TWiki::Plugins::SESSION
        ? $TWiki::Plugins::SESSION->writeLog( "skills", "$web.$topic",
        $text )
        : TWiki::Store::writeLog( "skills", "$web.$topic", $text );
    }

    _Debug($text);
}

1;
