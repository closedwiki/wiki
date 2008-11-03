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

package TWiki::Plugins::SkillsPlugin::SkillsStore;


# Object that handles interaction with the user data (currently stored in the meta or the users topic)
sub new {
    
    #my ($class, $name, $cat, $rating, $comment) = @_;
    
    my $self = bless ( {}, $class );
    
    return $self;
}

# gets all the categories and skills
sub getAll {
    my $self = shift;
}

# saves the skills to file - need?
sub save {
    my $self = shift;
}

# adds new skill to category
sub addNewSkill {
    my $self = shift;
}

sub renameSkill {
    my $self = shift;
}

sub moveSkill {
    my $self = shift;
}

sub deleteSkill {
    my $self = shift;
}

sub addNewCategory {
    my $self = shift;
}

sub renameSkill {
    my $self = shift;
}

sub deleteSkill {
    my $self = shift;
}

# returns the category obj - do we need?
sub getCategoryByName {
    my $self = shift;
}

1;