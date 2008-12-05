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

require TWiki::Plugins::SkillsPlugin::UserSkills;
require TWiki::Plugins::SkillsPlugin::SkillsStore;

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
    TWiki::Func::registerRESTHandler('renameSkill', \&_restRenameSkill );
    TWiki::Func::registerRESTHandler('moveSkill', \&_restMoveSkill );
    TWiki::Func::registerRESTHandler('deleteSkill', \&_restDeleteSkill );
    #}
    
    TWiki::Func::registerRESTHandler('getCategories', \&_restGetCategories );
    TWiki::Func::registerRESTHandler('getSkills', \&_restGetSkills );
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
sub _tagShowCategories { # done
    
    my $params = shift;
    
    return _showCategories(
        $params->{format},
        $params->{separator}
        );
}

sub _tagShowSkills { # done
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
sub _tagEditSkills { # done, except UI
    
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
    my $jsVars = 'SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";';
    _addJS( $jsVars );
    
    return $out;
}

sub _tagUserSkills { # done, but needs better images + js includes; also want oops instead of panel
    
    my $params = shift;
    
    my $user = $params->{user} || TWiki::Func::getWikiName();
    my $twisty = $params->{twisty} || 'closed';
    
    my $out = TWiki::Func::readTemplate( 'skillsuserview' );
    my $tmplRepeat = TWiki::Func::readTemplate( 'skillsuserviewrepeated' );
    
    my( undef, $tmplCat, $tmplSkillContStart, $tmplSkillStart, $tmplSkill, $tmplRating, $tmplComment, $tmplSkillEnd, $tmplSkillContEnd ) = split( /%SPLIT%/, $tmplRepeat );
    
    my $skills = TWiki::Plugins::SkillsPlugin::SkillsStore->new();
    my $userSkills = TWiki::Plugins::SkillsPlugin::UserSkills->new();
    
    # get image paths
    my $ratingPic = _getImages( 'star' );
    my $skillPic = _getImages( 'open' );
    my $commentPic = _getImages( 'comment' );
    my $twistyCloseImg = _getImages( 'twistyclose' );
    
    my $jsVars = "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "; # create namespace in JS
    
    my $repeatedLine;
    
    my $itCategories = $skills->eachCat;
    while( $itCategories->hasNext() ){
        my $cat = $itCategories->next();
        
        my $catDone = 0;
        my $skillOut = 0;
        
        # iterator over skills?
        my $itSkills = $cat->eachSkill;
        while( $itSkills->hasNext() ){
            my $skill = $itSkills->next();
            # does user have this skill?
            if( my $obj_userSkill = $userSkills->getSkillForUser( $user, $skill->name, $cat->name ) ){
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
                my $skillName = $skill->name;
                $lineOut =~ s/%SKILL%/$skillName/g;
                $lineOut =~ s/%SKILLICON%/$skillPic/g;
                if( $obj_userSkill->comment ){
                    my $url = TWiki::Func::getScriptUrl('Main', 'WebHome', 'oops',
                        template => 'oopsgeneric',
                        param1 => 'Skills Plugin Comment',
                        param2 => "---++++ Comment for skill '" . $skill->name . "' by $user",
                        param3 => "$user has logged the following comment next to skill '" . $skill->name . "'.",
                        param4 => "<blockquote>" . $obj_userSkill->comment . "</blockquote>"
                    );
                    $url .= ';cover=skills';
                    my $commentLink = "<a id='comment|" . $cat->name . "|" . $skill->name . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
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
    
    _addJS( $jsVars );
    
    return $out;
}

sub _tagBrowseSkills { # TODO
    
}

# ========================= REST
sub _restAddNewCategory { # done
    
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: addNewCategory' );
    
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my $newCat = TWiki::Func::getCgiQuery()->param('newcategory');
    
    my $error = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->addNewCategory( $newCat );
    return _returnFromRest( $web, $topic, "Error adding category '$newCat' - $error" ) if $error;
    
    # success
    return _returnFromRest( $web, $topic, "New category '$newCat' added." );
}

sub _restRenameCategory { # done
    
    _Debug( 'REST handler: renameCategory' );
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my $oldCat = TWiki::Func::getCgiQuery()->param('oldcategory') || return _returnFromRest( $web, $topic, "'oldcategory' parameter is required'" );
    my $newCat = TWiki::Func::getCgiQuery()->param('newcategory') || return _returnFromRest( $web, $topic, "'newcategory' parameter is required'" );
    
    # rename in skills.txt
    my $renameSkillsError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic, "Error renaming category '$oldCat' to '$newCat' - $renameSkillsError" ) if $renameSkillsError;
    
    # rename in users
    my $renameUserError =  TWiki::Plugins::SkillsPlugin::UserSkills->new()->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic, "Error renaming category '$oldCat' to '$newCat' - $renameUserError" ) if $renameUserError;
    
    # success
    return _returnFromRest( $web, $topic, "Category '$oldCat' has been renamed to '$newCat'." );
}

sub _restDeleteCategory { # done
    _Debug( 'REST handler: deleteCategory' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('oldcategory');
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    # delete in skills.txt
    my $deleteStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->deleteCategory( $cat );
    return _returnFromRest( $web, $topic, "Error deleting category '$cat' - $deleteStoreError" ) if $deleteStoreError;
    
    # rename in users
    my $deleteUserError =  TWiki::Plugins::SkillsPlugin::UserSkills->new()->deleteCategory( $cat );
    return _returnFromRest( $web, $topic, "Error deleting category '$cat' - $deleteUserError" ) if $deleteUserError;
    
    # success
    return _returnFromRest( $web, $topic, "Category '$cat' has been deleted, along with its skills." );
}

sub _restAddNewSkill { # done
    
    _Debug( 'REST handler: addNewCategory' );
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my $newSkill = TWiki::Func::getCgiQuery()->param('newskill');
    my $cat = TWiki::Func::getCgiQuery()->param('incategory');
    
    my $error = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->addNewSkill( $newSkill, $cat );
    return _returnFromRest( $web, $topic, "Error adding skill '$newSkill' to category '$cat' - $error" ) if $error;
    
    # success
    return _returnFromRest( $web, $topic, "New skill '$newSkill' added." );
}

sub _restRenameSkill { # done
    _Debug( 'REST handler: renameSkill' );
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my( $category, $oldSkill ) = split( /\|/, TWiki::Func::getCgiQuery()->param('oldskill') ); # oldskill looks like Category|Skill
    my $newSkill = TWiki::Func::getCgiQuery()->param('newskill');
    
    # rename in skills.txt
    my $renameStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic, "Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameStoreError" ) if $renameStoreError;
    
    # rename in users
    my $renameUserError =  TWiki::Plugins::SkillsPlugin::UserSkills->new()->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic, "Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameUserError" ) if $renameUserError;
    
    # success
    return _returnFromRest( $web, $topic, "Skill '$oldSkill' has been renamed to '$newSkill'." );
}

sub _restMoveSkill { # done
    _Debug( 'REST handler: moveSkill' );
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my( $oldCat, $skill ) = split( /\|/, TWiki::Func::getCgiQuery()->param('movefrom') ); # movefrom looks like Category|Skill
    my $newCat = TWiki::Func::getCgiQuery()->param('moveto');
    
    _Debug("$skill, $oldCat, $newCat");
    
    # rename in skills.txt
    my $moveStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic, "Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveStoreError" ) if $moveStoreError;
    
    # rename in users
    my $moveUserError =  TWiki::Plugins::SkillsPlugin::UserSkills->new()->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic, "Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveUserError" ) if $moveUserError;
    
    # success
    return _returnFromRest( $web, $topic, "Skill '$skill' has been move from '$oldCat' to '$newCat'." );
}

sub _restDeleteSkill { # done
    _Debug( 'REST handler: deleteSkill' );
    
    my( $web, $topic ) = TWiki::Func::normalizeWebTopicName( undef, TWiki::Func::getCgiQuery()->param('topic') );
    
    my( $cat, $oldSkill ) = split( /\|/, TWiki::Func::getCgiQuery()->param('oldskill') ); # oldskill looks like Category|Skill
    
     # delete in skills.txt
    my $deleteStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic, "Error deleting skill '$oldSkill' - $deleteStoreError" ) if $deleteStoreError;
    
    # rename in users
    my $deleteUserError =  TWiki::Plugins::SkillsPlugin::UserSkills->new()->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic, "Error deleting skill '$oldSkill' - $deleteUserError" ) if $deleteUserError;
    
    # success
    return _returnFromRest( $web, $topic, "Skill '$oldSkill' has been deleted from category '$cat'." );
}

sub _restGetCategories { # done
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getCategories' );
    
    return _tagShowCategories( { format => '$category', separator => '|' } );
}

sub _restGetSkills { # done
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkills' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    return _tagShowSkills( { category => $cat, format => '$skill', separator => '|' } );
}

sub _restGetSkillDetails { # done
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkillDetails' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    my $skill = TWiki::Func::getCgiQuery()->param('skill');
    
    my $user = TWiki::Func::getWikiName();
    
    my $obj_userSkill = TWiki::Plugins::SkillsPlugin::UserSkills->new()->getSkillForUser( $user, $skill, $cat );
    
    unless( $obj_userSkill ){
        return '';
    }
    
    my $out = '{';
    $out .= _createJSON( {
            skill => $obj_userSkill->name,
            category => $obj_userSkill->category,
            rating => $obj_userSkill->rating,
            comment => $obj_userSkill->comment
    } );
    $out .= '}';
    return $out;
}

sub _restAddEditSkill { # done
    my ($session, $plugin, $verb, $response) = @_;
    
    _Debug( 'REST handler: getSkillDetails' );
    
    my $cat = TWiki::Func::getCgiQuery()->param('category');
    my $skill = TWiki::Func::getCgiQuery()->param('skill');
    my $rating = TWiki::Func::getCgiQuery()->param('addedit-skill-rating');
    my $comment = TWiki::Func::getCgiQuery()->param('comment');
    
    my $user = TWiki::Func::getWikiName();
    
    my $error = TWiki::Plugins::SkillsPlugin::UserSkills->new()->addEditUserSkill( $user, $cat, $skill, $rating, $comment );
    
    my $message;
    if( $error ){
        $message = "Error adding/editing skill '$skill' - $error";
    } else {
        $message = "Skill '$skill' added/edited.";
    }
    
    return $message;
}

# ========================= FUNCTIONS

# returns all the categories in the defined format
sub _showCategories { # done
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
    
    my $cats = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();
    $text = join(
        $separator,
            map {
                $line = $format;
                $line =~ s/\$category/$_/go;
                $line;
            } @{ $cats }
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
sub _showSkills { # done
    
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
    
    # iterator of all categories
    my $categories = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;
    
    if ($cat){ # category specified
        
        my $skills;
        
        while( $categories->hasNext() ){
            my $obj_cat = $categories->next();
            if( $cat eq $obj_cat->name ){
                $skills = $obj_cat->getSkillNames;
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
        
        while( $categories->hasNext() ){
            my $obj_cat = $categories->next();
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
                } @{ $obj_cat->getSkillNames }
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

# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
sub _addYUI {

    return if ( $doneYui == 1 );
    $doneYui = 1;

    my $yui;
    #TODO clean up
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

sub _addJS {
    #my $vars = shift;
    my $jsVars;
    if( my $vars = shift ){
        $jsVars = 'if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; '; # create namespace in JS
        $jsVars .= $vars;
    }
    if( TWiki::Func::isGuest() ){
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 0;';
    } else {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 1;';
    }
    TWiki::Func::addToHEAD('SKILLSPLUGIN_JS',"<script language='javascript' type='text/javascript'>$jsVars</script><script src='/twiki/pub/TWiki/SkillsPlugin/main.js' language='javascript' type='text/javascript'></script>");
}

# ========================= UTILITIES
# Taken from TagMePlugin (http://twiki.org/cgi-bin/view/Plugins/TagMePlugin)
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
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

sub _returnFromRest {
    my( $web, $topic, $message ) = @_;
    
    $message = _urlEncode( $message );
    
    my $url = TWiki::Func::getScriptUrl($web, $topic, 'view')
            . '?skillsmessage=' . $message;
    TWiki::Func::redirectCgiQuery( undef, $url );
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
