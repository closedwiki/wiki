# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@googlemail.com
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

package TWiki::Plugins::SkillsPlugin::UserSkills;

use strict;

require TWiki::Plugins::SkillsPlugin::UserSkill;

my %_userSkills;    # contains an array of UserSkill objects keyed by user

# Object that handles interaction with the user data (currently stored in the meta or the users topic)
sub new {

    my $class = shift;

    #my ($class, $name, $cat, $rating, $comment) = @_;

    my $self = bless( {}, $class );

    return $self;
}

# loads the skills for a particular user
# gets it from the meta of the topic and stores in global hash
sub _loadUserSkills {
    my $self = shift;

    my $user = shift;

    _Debug("Loading skills for $user");

    my $mainWeb = TWiki::Func::getMainWebname();

    my ( $meta, undef ) = TWiki::Func::readTopic( $mainWeb, $user );
    my @skillsMeta = $meta->find('SKILLS');

    my @userSkills;
    for my $skillMeta (@skillsMeta) {
        my $obj_userSkill = TWiki::Plugins::SkillsPlugin::UserSkill->new(
            $skillMeta->{name},   $skillMeta->{category},
            $skillMeta->{rating}, $skillMeta->{comment}
        );
        push @userSkills, $obj_userSkill;
    }

    $_userSkills{$user} = \@userSkills;
}

# gets the particular skill for a particular user. Returns undef if skill not set
sub getSkillForUser {
    my $self = shift;

    my ( $user, $skill, $cat ) = @_;

    $self->_loadUserSkills($user) unless $_userSkills{$user};

    my $it = $self->eachUserSkill($user);
    return undef unless $it;
    while ( $it->hasNext() ) {
        my $obj_userSkill = $it->next();
        if (   $cat
            && $obj_userSkill->category
            && $cat eq $obj_userSkill->category
            && $skill
            && $obj_userSkill->name
            && $skill eq $obj_userSkill->name )
        {
            return $obj_userSkill;
        }
    }
    return undef;
}

# returns all the users skills in array of UserSkill objects
sub getUserSkills {
    my $self = shift;

    my $user = shift || return undef;

    $self->_loadUserSkills($user) unless $_userSkills{$user};

    return ( $_userSkills{$user} );
}

# iterate over each of the skills for a particular user
sub eachUserSkill {
    my $self = shift;

    my $user = shift;
    return undef unless $user;

    $self->_loadUserSkills($user) unless $_userSkills{$user};

    require TWiki::ListIterator;
    return new TWiki::ListIterator( $_userSkills{$user} );
}

# gets each user that has skills
# returns a hash keyed by user name that has an array of thier UserSkill objects
# i.e. {username}->[ UserSkill-1, UserSkill-2, UserSkill-3 ]
sub allUsers {
    my $self = shift;

    my %allUsers = {};    # hash of user skill objects keyed by user name

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my $userSkills = $self->getUserSkills($user);
        if ($userSkills) {
            $allUsers{$user} = $userSkills;
        }
    }

    return \%allUsers;
}

sub addEditUserSkill {
    my $self = shift;

    my ( $user, $cat, $skill, $rating, $comment ) = @_;

    my $edited;
    my $it = $self->eachUserSkill($user);
    return undef unless $it;
    while ( $it->hasNext() ) {
        my $obj_userSkill = $it->next();
        if (   $cat eq $obj_userSkill->category
            && $skill eq $obj_userSkill->name )
        {
            $obj_userSkill->rating($rating);
            $obj_userSkill->comment($comment);
            $edited = 1;
            last;
        }
    }

    # new skill
    unless ($edited) {
        my $obj_newUserSkill =
          TWiki::Plugins::SkillsPlugin::UserSkill->new( $skill, $cat, $rating,
            $comment );
        push @{ $_userSkills{$user} }, $obj_newUserSkill;
    }

    # save skills
    my $error = $self->_saveUserSkills($user);

    return $error;
}

# renames the category in all of the user records
sub renameCategory {
    my $self = shift;

    my ( $cat, $newCat ) = @_;

    # all users
    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my $changed = 0;

        # all skills for this user
        my $userSkills = $self->eachUserSkill($user);
        while ( $userSkills->hasNext() ) {
            my $obj_userSkill = $userSkills->next();

            # renamed?
            if ( $cat eq $obj_userSkill->category ) {
                $changed = 1;
                $obj_userSkill->category($newCat);
            }
        }

        # save if anything changed
        if ($changed) {
            $self->_saveUserSkills($user);
        }
    }

    # no error
    return undef;
}

sub renameSkill {
    my $self = shift;

    my ( $cat, $skill, $newSkill ) = @_;

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my $changed = 0;

        # all skills for this user
        my $userSkills = $self->eachUserSkill($user);
        while ( $userSkills->hasNext() ) {
            my $obj_userSkill = $userSkills->next();

            # renamed?
            if (   $cat eq $obj_userSkill->category
                && $skill eq $obj_userSkill->name )
            {
                $changed = 1;
                $obj_userSkill->name($newSkill);
            }
        }

        # save if anything changed
        if ($changed) {
            $self->_saveUserSkills($user);
        }
    }

    # no error
    return undef;
}

sub deleteCategory {
    my $self = shift;

    my ($cat) = @_;

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my @newSkills;
        my $changed = 0;

        # all skills for this user
        my $userSkills = $self->eachUserSkill($user);
        while ( $userSkills->hasNext() ) {
            my $obj_userSkill = $userSkills->next();

            # delete?
            if ( $cat eq $obj_userSkill->category ) {
                $changed = 1;
                next;
            }
            push @newSkills, $obj_userSkill;
        }

        if ($changed) {
            $_userSkills{$user} = \@newSkills;
            $self->_saveUserSkills($user);
        }
    }

    return undef;
}

sub deleteSkill {
    my $self = shift;

    my ( $cat, $skill ) = @_;

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my @newSkills;
        my $changed = 0;

        # all skills for this user
        my $userSkills = $self->eachUserSkill($user);
        while ( $userSkills->hasNext() ) {
            my $obj_userSkill = $userSkills->next();

            # delete?
            if ( $skill eq $obj_userSkill->name ) {
                $changed = 1;
                next;
            }
            push @newSkills, $obj_userSkill;
        }

        if ($changed) {
            $_userSkills{$user} = \@newSkills;
            $self->_saveUserSkills($user);
        }
    }

    return undef;
}

sub moveSkill {
    my $self = shift;

    my ( $skill, $oldCat, $newCat ) = @_;

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        my $changed = 0;

        # all skills for this user
        my $userSkills = $self->eachUserSkill($user);
        while ( $userSkills->hasNext() ) {
            my $obj_userSkill = $userSkills->next();

            if (   $oldCat eq $obj_userSkill->category
                && $skill eq $obj_userSkill->name )
            {
                $changed = 1;
                $obj_userSkill->category($newCat);
            }
        }

        if ($changed) {
            $self->_saveUserSkills($user);
        }
    }

    return undef;
}

# returns all the users with the particular skill
sub getUsersForSkill {
    my $self = shift;

    my ( $skill, $cat ) = @_;

    my %usersWithSkill;

    my $users = TWiki::Func::eachUser();
    while ( $users->hasNext() ) {
        my $user = $users->next();

        if ( my $obj_userSkill = $self->userHasSkill( $user, $skill, $cat ) ) {
            $usersWithSkill{$user} = $obj_userSkill;
        }
    }

    return \%usersWithSkill;
}

# returns the user skill obj if user has the skill
# undef if not
sub userHasSkill {
    my $self = shift;

    my ( $user, $skill, $cat ) = @_;

    # all skills for this user
    my $userSkills = $self->eachUserSkill($user);
    while ( $userSkills->hasNext() ) {
        my $obj_userSkill = $userSkills->next();

# trying to stop the 'Use of uninitialized value in string' warnings in Apache log file
        if (   $cat
            && $obj_userSkill->category
            && $cat eq $obj_userSkill->category
            && $skill
            && $obj_userSkill->name
            && $skill eq $obj_userSkill->name )
        {
            return $obj_userSkill;
        }
    }

    return undef;
}

# saves the skills for the particular user
sub _saveUserSkills {
    my $self = shift;
    my ($user) = @_;

    _Debug("Save user skills - $user");

    my $mainWeb = TWiki::Func::getMainWebname();

    my ( $meta, $text ) = TWiki::Func::readTopic( $mainWeb, $user );

    $meta->remove('SKILLS');
    my $it = $self->eachUserSkill($user);
    return undef unless $it;
    while ( $it->hasNext() ) {
        my $obj_userSkill = $it->next();
        $meta->putKeyed(
            'SKILLS',
            {
                name     => $obj_userSkill->name,
                category => $obj_userSkill->category,
                rating   => $obj_userSkill->rating,
                comment  => $obj_userSkill->comment
            }
        );
    }
    my $error =
      TWiki::Func::saveTopic( $mainWeb, $user, $meta, $text,
        { dontlog => 1, comment => 'SkillsPlugin', minor => 1 } );
    if ($error) {
        _Warn("saveUserSkills error - $error");
    }
    return $error;
}

sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{SkillsPlugin}{Debug} || 0;
    TWiki::Func::writeDebug("- TWiki::Plugins::SkillsPlugin::UserSkills: $text")
      if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning(
        "- TWiki::Plugins::SkillsPlugin::UserSkills: $text");
}

1;
