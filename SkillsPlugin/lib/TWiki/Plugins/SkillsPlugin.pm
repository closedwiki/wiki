# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 - 2009 Andrew Jones, andrewjones86@googlemail.com
# Copyright (C) 2007-2011 TWiki:TWiki.TWikiContributor
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

# Conditionally required in this module
#require TWiki::Plugins::SkillsPlugin::Category;
#require TWiki::Plugins::SkillsPlugin::UserSkill;
#require TWiki::Plugins::SkillsPlugin::UserSkills;
#require TWiki::Plugins::SkillsPlugin::SkillsStore;

use strict;
use vars qw(    $VERSION
  $RELEASE
  $NO_PREFS_IN_TOPIC
  $SHORTDESCRIPTION
  $pluginName
  $doneHeads
);

# Plugin Variables
$VERSION           = '$Rev$';
$RELEASE           = '2011-01-17';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION =
  'Allows users to list their skills, which can then be searched';
$pluginName = 'SkillsPlugin';

# ========================= INIT
sub initPlugin {

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        _Warn("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Register tag %SKILLS%
    TWiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );

    # Register REST handlers
    TWiki::Func::registerRESTHandler( 'addNewCategory', \&_restAddNewCategory );
    TWiki::Func::registerRESTHandler( 'renameCategory', \&_restRenameCategory );
    TWiki::Func::registerRESTHandler( 'deleteCategory', \&_restDeleteCategory );
    TWiki::Func::registerRESTHandler( 'addNewSkill',    \&_restAddNewSkill );
    TWiki::Func::registerRESTHandler( 'renameSkill',    \&_restRenameSkill );
    TWiki::Func::registerRESTHandler( 'moveSkill',      \&_restMoveSkill );
    TWiki::Func::registerRESTHandler( 'deleteSkill',    \&_restDeleteSkill );

    TWiki::Func::registerRESTHandler( 'search', \&_restSearch );

    TWiki::Func::registerRESTHandler( 'getCategories', \&_restGetCategories );
    TWiki::Func::registerRESTHandler( 'getSkills',     \&_restGetSkills );
    TWiki::Func::registerRESTHandler( 'getSkillDetails',
        \&_restGetSkillDetails );
    TWiki::Func::registerRESTHandler( 'addEditSkill', \&_restAddEditSkill );

    _Debug("initPlugin is OK");

    return 1;
}

# ========================= TAGS
sub _handleTag {

    my $out = '';

    my $action =
         $_[1]->{action}
      || $_[1]->{_DEFAULT}
      || return 'No action specified';

    my $start = "<noautolink>\n";
    my $end   = "\n</noautolink>";

    $doneHeads = 0;

    for ($action) {
        /user/
          and $out =
          $start . TWiki::Plugins::SkillsPlugin::_tagUserSkills( $_[1] ) . $end,
          last;

#    /group/ and $out = $start . TWiki::Plugins::SkillsPlugin::Tag::_tagGroupSkills($_[1]) . $end, last; # shows skills for a particular group
        /browse/
          and $out =
            $start
          . TWiki::Plugins::SkillsPlugin::_tagBrowseSkills( $_[1] )
          . $end, last;
        /edit/
          and $out =
          $start . TWiki::Plugins::SkillsPlugin::_tagEditSkills( $_[1] ) . $end,
          last;
        /showskill/
          and $out =
          $start . TWiki::Plugins::SkillsPlugin::_tagShowSkills( $_[1] ) . $end,
          last;
        /showcat/
          and $out =
            $start
          . TWiki::Plugins::SkillsPlugin::_tagShowCategories( $_[1] )
          . $end, last;    # show all categories in a format
        /^search$/
          and $out =
          $start . TWiki::Plugins::SkillsPlugin::_tagSearchForm( $_[1] ) . $end,
          last;            # creates a search form
        /searchresults/
          and $out = $start . '<div id="search-skill-results"></div>' . $end,
          last;            # container for the results

        # action not valid
        $out =
          "<span class='twikiAlert'>Error: Unknown action ('$action')</span>",
          last;
    }

    #$allowedit = 0;

    return $out;
}

# allows the user to print all categories in format of their choice
sub _tagShowCategories {
    my $params = shift;

    return _showCategories( $params->{format}, $params->{separator} );
}

sub _tagShowSkills {
    my $params = shift;

    return _showSkills(
        $params->{category}, $params->{format}, $params->{separator},
        $params->{prefix},   $params->{suffix}
    );
}

# creates a form allowing users to edit their skills
sub _tagEditSkills {
    my $user = TWiki::Func::getWikiName();

    my $out = TWiki::Func::readTemplate('skillsedit');

    # expand our variables in template
    my $formDef = 'name="addedit-skill-form" id="addedit-skill-form"';
    $out =~ s/%FORMDEFINITION%/$formDef/g;

    my $messageContainerDef =
      'id="addedit-skills-message-container"  style="display:none;"';
    $out =~ s/%SKILLMESSAGECONTAINERDEF%/$messageContainerDef/g;
    my $messagePic = _getImages()->{info};
    my $message    = "$messagePic <span id='addedit-skills-message'></span>";
    $out =~ s/%SKILLMESSAGE%/$message/g;

    # get categories
    my $catSelect =
      '<select name="category" id="addedit-category-select"></select>';
    $out =~ s/%CATEGORYSELECT%/$catSelect/g;

    my $skillSelect =
      '<select name="skill" id="addedit-skill-select"></select>';
    $out =~ s/%SKILLSELECT%/$skillSelect/g;

    $out =~
s!%RATINGSELECT\{1\}%!<input type="radio" name="addedit-skill-rating" value="1" />!g;
    $out =~
s!%RATINGSELECT\{2\}%!<input type="radio" name="addedit-skill-rating" value="2" />!g;
    $out =~
s!%RATINGSELECT\{3\}%!<input type="radio" name="addedit-skill-rating" value="3" />!g;
    $out =~
s!%RATINGSELECT\{4\}%!<input type="radio" name="addedit-skill-rating" value="4" />!g;
    $out =~
s!%RATINGSELECT\{0\}%!<input type="radio" name="addedit-skill-rating" value="0" />!g;

    my $comment = 'id="addedit-skill-comment" type="text" name="comment"';
    $out =~ s/%SKILLCOMMENTDEF%/$comment/g;

    # to clear textbox
    my $clearPic = _getImages()->{clear};
    my $clear =
"<span id='addedit-skill-comment-clear' style='display:none;'>$clearPic</span>";
    $out =~ s/%SKILLCOMMENTCLEAR%/$clear/g;

    my $submit =
'<input name="skill-submit" id="addedit-skill-submit" type="button" value="Add/Edit" class="twikiSubmit">';
    $out =~ s/%SKILLSUBMIT%/$submit/g;

    my $jsVars =
'SkillsPlugin.vars.addEditSkills = 1; SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";';
    _addHeads($jsVars);

    return $out;
}

sub _tagUserSkills {

    my $params = shift;

    my $user   = $params->{user}   || TWiki::Func::getWikiName();
    my $twisty = $params->{twisty} || 'closed';

    my $out        = TWiki::Func::readTemplate('skillsuserview');
    my $tmplRepeat = TWiki::Func::readTemplate('skillsuserviewrepeated');

    my (
        undef,           $tmplCat,      $tmplSkillContStart,
        $tmplSkillStart, $tmplSkill,    $tmplRating,
        $tmplComment,    $tmplSkillEnd, $tmplSkillContEnd
    ) = split( /%SPLIT%/, $tmplRepeat );

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = TWiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $skillPic       = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $jsVars =
      "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "
      ;    # create namespace in JS

    my $repeatedLine;

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catDone  = 0;
        my $skillOut = 0;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            # does user have this skill?
            if ( my $obj_userSkill =
                $userSkills->getSkillForUser( $user, $skill->name, $cat->name )
              )
            {

                # produce output line
                # add to array/string which will be output in %REPEAT%
                my $lineOut;

                $skillOut = 1;

                # category
                unless ( $catDone == 1 ) {
                    $lineOut .= $tmplCat;
                    $lineOut .= $tmplSkillContStart;
                }
                $catDone = 1;

                $lineOut .= $tmplSkillStart;

                # skill
                $lineOut .= $tmplSkill;

                # rating
                my $i = 1;
                while ( $i < $obj_userSkill->rating ) {
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i++;
                }
                my $ratingOut = $tmplRating;
                $ratingOut =~ s/%RATING%/$ratingPic/g;
                $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
                $lineOut .= $ratingOut;
                $i++;
                while ( $i <= 4 ) {
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i++;
                }

                # comment
                $lineOut .= $tmplComment;

                $lineOut .= $tmplSkillEnd;

                # subsitutions
                my $skillName = $skill->name;
                $lineOut =~ s/%SKILL%/$skillName/g;
                $lineOut =~ s/%SKILLICON%/$skillPic/g;
                if ( $obj_userSkill->comment ) {
                    my $url = TWiki::Func::getScriptUrl(
                        'Main', 'WebHome', 'oops',
                        template => 'oopsgeneric',
                        param1   => 'Skills Plugin Comment',
                        param2   => "Comment for skill '"
                          . $skill->name
                          . "' by $user",
                        param3 =>
"$user has logged the following comment next to skill '"
                          . $skill->name . "'.",
                        param4 => $obj_userSkill->comment
                    );
                    $url .= ';cover=skills';
                    my $commentLink =
                        "<a id='comment|"
                      . $cat->name . "|"
                      . $skill->name
                      . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
                    $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
                }
                else {
                    $lineOut =~ s/%COMMENTLINK%//g;
                    $lineOut =~ s/%COMMENTOUT%//g;
                }

                $repeatedLine .= $lineOut;
            }
        }

        # subsitutions
        my $catTwist =
            '<span id="'
          . _urlEncode( $cat->name )
          . '_twistyImage" class="SkillsPlugin-twisty-image"> '
          . $twistyCloseImg
          . '</span>';
        $repeatedLine =~ s!%SKILLTWISTY%!$catTwist!g;
        my $catLink =
            '<span id="'
          . _urlEncode( $cat->name )
          . '_twistyLink" class="SkillsPlugin-twisty-link">'
          . $cat->name
          . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        my $skillContDef = 'class="' . _urlEncode( $cat->name ) . '_twist"';
        $repeatedLine =~ s/%SKILLCONTDEF%/$skillContDef/g;

        $repeatedLine .= $tmplSkillContEnd unless ( $skillOut == 0 );
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;
    $out =~ s/%SKILLUSER%/$user/g;

    $jsVars .= "SkillsPlugin.vars.twistyState = '$twisty';";
    my $twistyOpenImgSrc = _getImagesSrc()->{twistyopen};
    $jsVars .= "SkillsPlugin.vars.twistyOpenImgSrc = \"$twistyOpenImgSrc\";";
    my $twistyCloseImgSrc = _getImagesSrc()->{twistyclose};
    $jsVars .= "SkillsPlugin.vars.twistyCloseImgSrc = \"$twistyCloseImgSrc\";";
    $jsVars .= 'SkillsPlugin.vars.viewUserSkills = 1;';
    _addHeads($jsVars);

    return $out;
}

sub _tagSearchForm {
    my $out = TWiki::Func::readTemplate('skillssearchform');

    # expand our variables in template
    my $formDef = 'name="search-skill-form" id="search-skill-form"';
    $out =~ s/%FORMDEFINITION%/$formDef/g;

    my $messageContainerDef =
      'id="search-skills-message-container"  style="display:none;"';
    $out =~ s/%SKILLMESSAGECONTAINERDEF%/$messageContainerDef/g;
    my $messagePic = _getImages()->{info};
    my $message    = "$messagePic <span id='search-skills-message'></span>";
    $out =~ s/%SKILLMESSAGE%/$message/g;

    # get categories
    my $catSelect =
      '<select name="category" id="search-category-select"></select>';
    $out =~ s/%CATEGORYSELECT%/$catSelect/g;

    my $skillSelect = '<select name="skill" id="search-skill-select"></select>';
    $out =~ s/%SKILLSELECT%/$skillSelect/g;

    my $submit =
'<input name="skill-submit" id="search-skill-submit" type="button" value="Search" class="twikiSubmit">';
    $out =~ s/%SKILLSUBMIT%/$submit/g;

    my $jsVars =
'SkillsPlugin.vars.searchSkills = 1; SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";';
    _addHeads($jsVars);

    return $out;
}

sub _tagBrowseSkills {

    my $params = shift;

    my $twisty = $params->{twisty} || 'closed';

    my $out        = TWiki::Func::readTemplate('skillsbrowseview');
    my $tmplRepeat = TWiki::Func::readTemplate('skillsbrowseviewrepeated');

    my (
        undef,           $tmplCat,     $tmplCatContStart,
        $tmplSkillStart, $tmplSkill,   $tmplSkillEnd,
        $tmplUserStart,  $tmplUser,    $tmplRating,
        $tmplComment,    $tmplUserEnd, $tmplCatContEnd
    ) = split( /%SPLIT%/, $tmplRepeat );

    # loop over all skills from skills.txt
    # if a user has this skill, output them

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = TWiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $open           = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $repeatedLine;

    # loop over all users that have skills
    # if they do, store in hash/array ## CANT cos C++, etc
    # loop over array and do the output

# my $allUserSkills = $userSkills->allUsers();
#
# my $outSkills;
#
# # each user with skills
# for my $user( sort keys %{ $allUserSkills } ){
#
# # loop over all this users skills
# for my $user_obj( @{ $allUserSkills->{ $user } } ){
#
# next unless( $skills->categoryExists( $user_obj->category ) );
# next unless( $skills->getCategoryByName( $user_obj->category )->skillExists( $user_obj->name ) );
#
# # category
# $outSkills->{ $user_obj->category } = {} unless $outSkills->{ $user_obj->category };
# # skill
# $outSkills->{ $user_obj->category }->{ $user_obj->name } unless $outSkills->{ $user_obj->category }->{ $user_obj->name };
#
# #%outSkills->{ $user_obj->category }->{ $user_obj->name }->{ $user } = $user_obj;
#
# # check the category and skill is defined
# # add to hash
# }
#
# return $user;
# }
#
# return "hi" . $allUserSkills->{'AndrewJones'}[0]->name;
#return "hi";

    my $allUsers = $userSkills->allUsers();

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catName = $cat->name;

        $repeatedLine .= $tmplCat;

        $repeatedLine .= $tmplCatContStart;
        my $contId = 'class="' . _urlEncode($catName) . '_twist"';
        $repeatedLine =~ s/%CATEGORYCONTDEF%/$contId/g;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            my $skillName = $skill->name;

            $repeatedLine .= $tmplSkillStart;
            $repeatedLine .= $tmplSkill;
            $repeatedLine .= $tmplSkillEnd;

# now need to iterate over users and find out if they have this skill
# if so, output
# users should only be loaded the first time, the rest is in memory
# if this was an iterator of each user with skills
#my $users = TWiki::Plugins::SkillsPlugin::UserSkills->new()->getUsersForSkill( $skillName, $catName );

            #for my $user ( sort keys %{ $users } ) {
            #my $obj_userSkill = $allUsers->{ $user };
            for my $user ( sort keys %{$allUsers} ) {
                for my $obj_userSkill ( @{ $allUsers->{$user} } ) {

                    next
                      unless ( $obj_userSkill->category eq $catName
                        and $obj_userSkill->name eq $skillName );

                    $repeatedLine .= $tmplUserStart;
                    $repeatedLine .= $tmplUser;

                    my $skillTwist =
                        'class="'
                      . _urlEncode($catName)
                      . _urlEncode($skillName)
                      . '_twist"';
                    $repeatedLine =~ s/%SKILLTWISTDEF%/$skillTwist/g;
                    $repeatedLine =~ s/%USERROWDEF%/class="userRow"/g;
                    $repeatedLine =~ s/%SKILLUSER%/[[%MAINWEB%.$user][$user]]/g;
                    $repeatedLine =~ s/%USERICON%/$open/g;

                    # rating
                    my $i = 1;
                    while ( $i < $obj_userSkill->rating ) {
                        my $ratingOut = $tmplRating;
                        $ratingOut =~ s/%RATING%/&nbsp;/g;
                        $ratingOut =~ s/%RATINGDEF%//g;
                        $repeatedLine .= $ratingOut;
                        $i++;
                    }
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/$ratingPic/g;
                    $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
                    $repeatedLine .= $ratingOut;
                    $i++;
                    while ( $i <= 4 ) {
                        my $ratingOut = $tmplRating;
                        $ratingOut =~ s/%RATING%/&nbsp;/g;
                        $ratingOut =~ s/%RATINGDEF%//g;
                        $repeatedLine .= $ratingOut;
                        $i++;
                    }

                    # comment
                    $repeatedLine .= $tmplComment;

                    # comment link
                    if ( $obj_userSkill->comment ) {
                        my $url = TWiki::Func::getScriptUrl(
                            'Main', 'WebHome', 'oops',
                            template => 'oopsgeneric',
                            param1   => 'Skills Plugin Comment',
                            param2   => "Comment for skill '"
                              . $obj_userSkill->name
                              . "' by $user",
                            param3 =>
"$user has logged the following comment next to skill '"
                              . $obj_userSkill->name . "'.",
                            param4 => $obj_userSkill->comment
                        );
                        $url .= ';cover=skills';
                        my $commentLink =
                            "<a id='comment|"
                          . $obj_userSkill->category . "|"
                          . $obj_userSkill->name
                          . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
                        $repeatedLine =~ s/%COMMENTLINK%/$commentLink/g;
                    }
                    else {
                        $repeatedLine =~ s/%COMMENTLINK%//g;
                        $repeatedLine =~ s/%COMMENTOUT%//g;
                    }

                    $repeatedLine .= $tmplUserEnd;
                }
            }

            $repeatedLine =~ s/%SKILLICON%/$open/g;
            my $skillLink =
                '<span id="'
              . _urlEncode($catName)
              . _urlEncode($skillName)
              . '_twistyLink" class="SkillsPlugin-twisty-link">'
              . $skillName
              . '</span>';
            $repeatedLine =~ s/%SKILL%/$skillLink/g;
        }

        my $catTwist =
            '<span id="'
          . _urlEncode($catName)
          . '_twistyImage" class="SkillsPlugin-twisty-image"> '
          . $twistyCloseImg
          . '</span>';
        $repeatedLine =~ s/%CATEGORYICON%/$catTwist/g;
        my $catLink =
            '<span id="'
          . _urlEncode($catName)
          . '_twistyLink" class="SkillsPlugin-twisty-link">'
          . $catName
          . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        $repeatedLine .= $tmplCatContEnd;
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;

    my $jsVars           = "SkillsPlugin.vars.twistyState = '$twisty';";
    my $twistyOpenImgSrc = _getImagesSrc()->{twistyopen};
    $jsVars .= "SkillsPlugin.vars.twistyOpenImgSrc = \"$twistyOpenImgSrc\";";
    my $twistyCloseImgSrc = _getImagesSrc()->{twistyclose};
    $jsVars .= "SkillsPlugin.vars.twistyCloseImgSrc = \"$twistyCloseImgSrc\";";
    $jsVars .= 'SkillsPlugin.vars.browseSkills = 1;';
    _addHeads($jsVars);

    return $out;
}

# ========================= REST
sub _restAddNewCategory {

    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: addNewCategory');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    my $newCat = TWiki::Func::getCgiQuery()->param('newcategory');

    unless ( TWiki::Func::isAnAdmin() ) {
        if ( my $pref = TWiki::Func::getPreferencesValue('ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = TWiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding category '$newCat' - You are not permitted to add categories or skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $error =
      TWiki::Plugins::SkillsPlugin::SkillsStore->new()->addNewCategory($newCat);
    return _returnFromRest( $web, $topic,
        "Error adding category '$newCat' - $error" )
      if $error;

    _Log("Category $newCat added");

    # success
    return _returnFromRest( $web, $topic, "New category '$newCat' added." );
}

sub _restRenameCategory {

    _Debug('REST handler: renameCategory');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless TWiki::Func::isAnAdmin();    # check admin

    my $oldCat = TWiki::Func::getCgiQuery()->param('oldcategory')
      || return _returnFromRest( $web, $topic,
        "'oldcategory' parameter is required'" );
    my $newCat = TWiki::Func::getCgiQuery()->param('newcategory')
      || return _returnFromRest( $web, $topic,
        "'newcategory' parameter is required'" );

    # rename in skills.txt
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameSkillsError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameSkillsError" )
      if $renameSkillsError;

    # rename in users
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameUserError" )
      if $renameUserError;

    _Log("Category $oldCat renamed to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$oldCat' has been renamed to '$newCat'." );
}

sub _restDeleteCategory {
    _Debug('REST handler: deleteCategory');

    my $cat = TWiki::Func::getCgiQuery()->param('oldcategory');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless TWiki::Func::isAnAdmin();    # check admin

    # delete in skills.txt
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError =
      TWiki::Plugins::SkillsPlugin::SkillsStore->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError =
      TWiki::Plugins::SkillsPlugin::UserSkills->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteUserError" )
      if $deleteUserError;

    _Log("Category $cat deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$cat' has been deleted, along with its skills." );
}

# adds a new skill
# if the ALLOWADDSKILLS preference is set, only the listed people and admins can add skills
# otherwise everyone can
sub _restAddNewSkill {

    _Debug('REST handler: addNewCategory');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    my $newSkill = TWiki::Func::getCgiQuery()->param('newskill');
    my $cat      = TWiki::Func::getCgiQuery()->param('incategory');

    unless ( TWiki::Func::isAnAdmin() ) {
        if ( my $pref = TWiki::Func::getPreferencesValue('ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = TWiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding skill '$newSkill' to category '$cat' - You are not permitted to add skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $error = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->addNewSkill( $newSkill, $cat );
    return _returnFromRest( $web, $topic,
        "Error adding skill '$newSkill' to category '$cat' - $error" )
      if $error;

    _Log("Skill $newSkill added");

    # success
    return _returnFromRest( $web, $topic, "New skill '$newSkill' added." );
}

# renames a skill
# only admins can do this
sub _restRenameSkill {
    _Debug('REST handler: renameSkill');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless TWiki::Func::isAnAdmin();    # check admin

    my ( $category, $oldSkill ) =
      split( /\|/, TWiki::Func::getCgiQuery()->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill
    my $newSkill = TWiki::Func::getCgiQuery()->param('newskill');

    # rename in skills.txt
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameStoreError"
    ) if $renameStoreError;

    # rename in users
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameUserError"
    ) if $renameUserError;

    _Log("Skill $oldSkill renamed to $newSkill in category $category");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been renamed to '$newSkill'." );
}

# moves a skill from one category to another
# only admins can do this
sub _restMoveSkill {
    _Debug('REST handler: moveSkill');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless TWiki::Func::isAnAdmin();    # check admin

    my ( $oldCat, $skill ) =
      split( /\|/, TWiki::Func::getCgiQuery()->param('movefrom') )
      ;                                   # movefrom looks like Category|Skill
    my $newCat = TWiki::Func::getCgiQuery()->param('moveto');

    _Debug("$skill, $oldCat, $newCat");

    # rename in skills.txt
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $moveStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveStoreError"
    ) if $moveStoreError;

    # rename in users
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $moveUserError = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveUserError"
    ) if $moveUserError;

    _Log("Skill $skill moved from $oldCat to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$skill' has been moved from '$oldCat' to '$newCat'." );
}

# deletes a skill from the skill database
# only admins can do this
sub _restDeleteSkill {
    _Debug('REST handler: deleteSkill');

    my ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( undef,
        TWiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless TWiki::Func::isAnAdmin();    # check admin

    my ( $cat, $oldSkill ) =
      split( /\|/, TWiki::Func::getCgiQuery()->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill

    # delete in skills.txt
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError = TWiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteUserError" )
      if $deleteUserError;

    _Log("Skill $oldSkill deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been deleted from category '$cat'." );
}

# returns all categories in a comma seperated list
sub _restGetCategories {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getCategories');

    return _tagShowCategories( { format => '$category', separator => '|' } );
}

# returns all skills for a particular category in a comma seperated list
sub _restGetSkills {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkills');

    my $cat = TWiki::Func::getCgiQuery()->param('category');
    return _tagShowSkills(
        { category => $cat, format => '$skill', separator => '|' } );
}

# gets all the details for a particular skill for the user logged in
# i.e. rating and comments
sub _restGetSkillDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $cat   = TWiki::Func::getCgiQuery()->param('category');
    my $skill = TWiki::Func::getCgiQuery()->param('skill');

    my $user = TWiki::Func::getWikiName();

    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $obj_userSkill = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getSkillForUser( $user, $skill, $cat );

    unless ($obj_userSkill) {
        return '{ }';
    }

    my $out = '{';
    $out .= _createJSON(
        {
            skill    => $obj_userSkill->name,
            category => $obj_userSkill->category,
            rating   => $obj_userSkill->rating,
            comment  => $obj_userSkill->comment
        }
    );
    $out .= '}';
    return $out;
}

# allows a user to add a new skill or edit an existing one
sub _restAddEditSkill {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $cat     = TWiki::Func::getCgiQuery()->param('category');
    my $skill   = TWiki::Func::getCgiQuery()->param('skill');
    my $rating  = TWiki::Func::getCgiQuery()->param('addedit-skill-rating');
    my $comment = TWiki::Func::getCgiQuery()->param('comment');

    my $user = TWiki::Func::getWikiName();

    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $error = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->addEditUserSkill( $user, $cat, $skill, $rating, $comment );

    my $message;
    if ($error) {
        $message = "Error adding/editing skill '$skill' - $error";
    }
    else {
        $message = "Skill '$skill' added/edited.";
    }

    return $message;
}

sub _restSearch {
    my $cat        = TWiki::Func::getCgiQuery()->param('category');
    my $skill      = TWiki::Func::getCgiQuery()->param('skill');
    my $ratingFrom = TWiki::Func::getCgiQuery()->param('ratingFrom');
    my $ratingTo   = TWiki::Func::getCgiQuery()->param('ratingTo');

    return 'Error: Category and Skill must be defined'
      unless ( $skill and $cat );

    my $out = TWiki::Func::readTemplate('skillssearchresults');

    my $tmplRepeat = TWiki::Func::readTemplate('skillssearchresultsrepeated');

    my ( undef, $tmplUserStart, $tmplUser, $tmplRating, $tmplComment,
        $tmplUserEnd )
      = split( /%SPLIT%/, $tmplRepeat );

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    require TWiki::Plugins::SkillsPlugin::UserSkills;
    my $skills     = TWiki::Plugins::SkillsPlugin::SkillsStore->new();
    my $userSkills = TWiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $skillPic       = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $repeatedLine;

    # hash of UserSkill objects keyed by user name
    my $users = TWiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getUsersForSkill( $skill, $cat );

    for my $user ( sort keys %{$users} ) {
        my $obj_userSkill = $users->{$user};

        my $lineOut;

        $lineOut .= $tmplUserStart;

        # skill
        $lineOut .= $tmplUser;

        # rating
        my $i = 1;
        while ( $i < $obj_userSkill->rating ) {
            my $ratingOut = $tmplRating;
            $ratingOut =~ s/%RATING%/&nbsp;/g;
            $ratingOut =~ s/%RATINGDEF%//g;
            $lineOut .= $ratingOut;
            $i++;
        }
        my $ratingOut = $tmplRating;
        $ratingOut =~ s/%RATING%/$ratingPic/g;
        $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
        $lineOut .= $ratingOut;
        $i++;
        while ( $i <= 4 ) {
            my $ratingOut = $tmplRating;
            $ratingOut =~ s/%RATING%/&nbsp;/g;
            $ratingOut =~ s/%RATINGDEF%//g;
            $lineOut .= $ratingOut;
            $i++;
        }

        # comment
        $lineOut .= $tmplComment;

        $lineOut .= $tmplUserEnd;

        # subsitutions
        my $userLink =
          TWiki::Func::internalLink( undef, TWiki::Func::getMainWebname(),
            $user, $user, undef, '0' );
        $lineOut =~ s/%SKILLUSER%/$userLink/g;

        # comment link
        if ( $obj_userSkill->comment ) {
            my $url = TWiki::Func::getScriptUrl(
                'Main', 'WebHome', 'oops',
                template => 'oopsgeneric',
                param1   => 'Skills Plugin Comment',
                param2   => "Comment for skill '"
                  . $obj_userSkill->name
                  . "' by $user",
                param3 =>
                  "$user has logged the following comment next to skill '"
                  . $obj_userSkill->name . "'.",
                param4 => $obj_userSkill->comment
            );
            $url .= ';cover=skills';
            my $commentLink =
                "<a id='comment|"
              . $obj_userSkill->category . "|"
              . $obj_userSkill->name
              . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
            $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
        }
        else {
            $lineOut =~ s/%COMMENTLINK%//g;
            $lineOut =~ s/%COMMENTOUT%//g;
        }

        $repeatedLine .= $lineOut;
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;

    $out =~ s/%SEARCHCATEGORY%/$cat/g;
    $out =~ s/%SEARCHSKILL%/$skill/g;
    my $matches = keys( %{$users} );
    $out =~ s/%SEARCHMATCES%/$matches/g;

    $out = TWiki::Func::expandCommonVariables($out);

    #$out = TWiki::Func::renderText( $out );

    return $out;
}

# ========================= FUNCTIONS
# returns all the categories in the defined format
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

    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $cats =
      TWiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();
    $text = join(
        $separator,
        map {
            $line = $format;
            $line =~ s/\$category/$_/go;
            $line;
          } @{$cats}
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
sub _showSkills {

    my ( $cat, $format, $separator, $prefix, $suffix, $catSeparator ) = @_;

    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go if $prefix;
    $suffix =~ s/\$n/\n/go if $suffix;

    my $text = '';
    my $line = '';

    # get all skills
    # if category is specified, only show skills in that category
    # else, show them all

    # iterator of all categories
    require TWiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories = TWiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;

    if ($cat) {    # category specified

        my $skills;

        while ( $categories->hasNext() ) {
            my $obj_cat = $categories->next();
            if ( $cat eq $obj_cat->name ) {
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

        while ( $categories->hasNext() ) {
            my $obj_cat    = $categories->next();
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

# ========================= UTILITIES
sub _addHeads {

    return if $doneHeads;
    $doneHeads = 1;

    # js vars
    my $jsVars;
    if ( my $vars = shift ) {
        $jsVars =
          'if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; '
          ;    # create namespace in JS
        $jsVars .= $vars;
    }
    if ( TWiki::Func::isGuest() ) {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 0;';
    }
    else {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 1;';
    }

# yui
# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
    my $yui;
    eval 'use TWiki::Contrib::YahooUserInterfaceContrib';
    if ( !$@ ) {
        _Debug('YahooUserInterfaceContrib is installed, using local files');
        $yui =
'<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/connection/connection-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/element/element-beta-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/json/json-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/animation/animation-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/container/container-min.js"></script>'

          # style
          . '<link rel="stylesheet" type="text/css" href="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/container/assets/skins/sam/container.css" />';
    }
    else {
        _Debug(
            'YahooUserInterfaceContrib is not installed, using Yahoo servers');
        $yui =
'<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/connection/connection-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/element/element-beta-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/json/json-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/animation/animation-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/container/container-min.js"></script>'

          # style
          . '<link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.5.2/build/container/assets/skins/sam/container.css" />';
    }

    # css
    my $css =
'<style type="text/css" media="all">@import url("/twiki/pub/TWiki/SkillsPlugin/style.css");</style>';

    # add to head
    TWiki::Func::addToHEAD( 'SKILLSPLUGIN_JS',
"$css $yui <script language='javascript' type='text/javascript'>$jsVars</script><script src='/twiki/pub/TWiki/SkillsPlugin/main.js' language='javascript' type='text/javascript'></script>"
    );
}

# Taken from TagMePlugin (http://twiki.org/cgi-bin/view/Plugins/TagMePlugin)
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

sub _createJSON {
    my $params = shift;

    # loop over param keys
    # create the JSON
    # "param":"key"
    my $out;
    while ( my ( $key, $value ) = each( %{$params} ) ) {
        $out .= "\"$key\":\"$value\",";
    }
    $out =~ s/,$//;
    return $out;
}

# returns a hash of image html elements
sub _getImages {

    my $docpath = TWiki::Func::getPubUrlPath() . '/' .    # /pub/
      TWiki::Func::getTwikiWebname() . '/' .              # TWiki/
      'TWikiDocGraphics';                                 # doc topic

    my %images = (
        "twistyopen" =>
"<img width='16' alt='twisty open' align='top' src='$docpath/toggleopen.gif' height='16' border='0' />",
        "twistyclose" =>
"<img width='16' alt='twisty close' align='top' src='$docpath/toggleclose.gif' height='16' border='0' />",
        "star" =>
"<img width='16' alt='*' align='top' src='$docpath/stargold.gif' height='16' border='0' />",
        "open" =>
"<img width='16' alt='-' align='top' src='$docpath/dot_ur.gif' height='16' border='0' />",
        "comment" =>
"<img width='16' alt='+' class='SkillsPlugins-comment-img' align='top' src='$docpath/note.gif' height='16' border='0' />",
        "clear" =>
"<img width='16' alt='Clear' align='top' src='$docpath/choice-cancel.gif' height='16' border='0' />",
        "info" =>
"<img width='16' alt='Info' align='top' src='$docpath/info.gif' height='16' border='0' />"
    );
    return \%images;
}

# returns a hash of image paths
sub _getImagesSrc {

    my $docpath = TWiki::Func::getPubUrlPath() . '/' .    # /pub/
      TWiki::Func::getTwikiWebname() . '/' .              # TWiki/
      'TWikiDocGraphics';                                 # doc topic

    my %images = (
        "twistyopen"  => "$docpath/toggleopen.gif",
        "twistyclose" => "$docpath/toggleclose.gif"
    );
    return \%images;
}

# formats a suitible return message from rest functions
sub _returnFromRest {
    my ( $web, $topic, $message ) = @_;

    $message = _urlEncode($message);

    my $url =
        TWiki::Func::getScriptUrl( $web, $topic, 'view' )
      . '?skillsmessage='
      . $message;
    TWiki::Func::redirectCgiQuery( undef, $url );
}

# =========================
sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    TWiki::Func::writeDebug("- TWiki::Plugins::${pluginName}: $text") if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning("- TWiki::Plugins::${pluginName}: $text");
}

# logs actions
# FIXME - should write our own log in work area
sub _Log {
    return;
    my ($message) = @_;

    my $logAction = $TWiki::cfg{Plugins}{$pluginName}{Log} || 1;
    return unless $logAction;

    my $user = TWiki::Func::getWikiName();

    my $out = "| date,time | $user | $message |";

    _Debug("Logged: $out");
}

1;
