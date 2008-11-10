# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 Andrew Jones, andrewjones86@googlemail.com
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

package TWiki::Plugins::SkillsPlugin::UserSkillsStore;


# Object that handles interaction with the user data (currently stored in the meta or the users topic)
sub new {
    
    #my ($class, $name, $cat, $rating, $comment) = @_;
    
    my $self = bless ( {}, $class);
    
    return $self;
}

# gets the particular skill. Returns undef if skill not set
sub getUserSkill {
    my $self = shift;
}

# returns all the users skills
sub getUserSkills {
    my $self = shift;
}

# gets all the users skills from the topics into memory ready to be repeatably queried
# could this be transparent? I.e, we load when there is a query and save it, then next time we check if its loaded
sub loadAllUsersSkills {
    my $self = shift;
}

# returns all the users with the particular skill
# could this be an object? would need to know user, rating, comment...
# dont do object overkill!!
sub getUsersForSkill {
    my $self = shift;
}

# saves the skills for the particular user
sub saveUserSkills {
    my $self = shift;
    my ( $user, $skills ) = @_; # array of skill obj?
}

1;