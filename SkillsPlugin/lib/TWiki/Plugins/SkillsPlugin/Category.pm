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

package TWiki::Plugins::SkillsPlugin::Category;

use strict;

require TWiki::Plugins::SkillsPlugin::Skill;

my $totalCategories;

sub new {
    my ($class, $name, $skills) = @_;
    
    my $self = {};
    
    #$self->{NAME} = undef;
    #$self->{SKILLS} = [];
    $self->{"_TOTAL"} = \$totalCategories;
    
    bless ( $self, $class);
    
    $self->name( $name );
    $self->populateSkills( $skills );
    
    ++ ${ $self->{"_TOTAL"} };
    
    return $self;
}

# name of category
sub name {
    my $self = shift;
    if (@_) { $self->{NAME} = shift }
    return $self->{NAME};
}

# return SKILLS array
sub getSkillNames {
    my $self = shift;
    my @skillNames;
    
    my $it = $self->eachSkill;
    while( $it->hasNext() ){
        my $obj_skill = $it->next();
        push @skillNames, $obj_skill->name;
    }
    return \@skillNames;
}

# returns an iterator over each skill
sub eachSkill {
    my $self = shift;
    
    require TWiki::ListIterator;
    return new TWiki::ListIterator( $self->{SKILLS} );
}

# populate SKILLS array
sub populateSkills {
    my ( $self, $skills) = @_;
    
    if ($skills) {
        for my $skill ( sort @$skills ){
            my $obj_skill = TWiki::Plugins::SkillsPlugin::Skill->new($skill);
            #$obj_skill->name( $skill );
            push @{ $self->{SKILLS} }, $obj_skill;
        }
    }
}

# append skill to SKILLS array
sub addSkill {
    my ( $self, $skill) = @_;
    my $obj_skill = TWiki::Plugins::SkillsPlugin::Skill->new($skill);
    push @{ $self->{SKILLS} }, $obj_skill;
}

sub renameSkill {
    my( $self, $oldSkill, $newSkill ) = @_;
    
    return "Skill '$newSkill' already exists in category '" . $self->name . "'." if( $self->skillExists( $newSkill ) );
    
    my $skills = $self->eachSkill;
    while( $skills->hasNext() ){
        my $obj_skill = $skills->next();
        
        if( $oldSkill eq $obj_skill->name ){
            $obj_skill->name( $newSkill );
            last;
        }
    }
    
    return undef;
}

sub deleteSkill {
    my ( $self, $skill) = @_;
    
    my @newSkills;
    
    my $skills = $self->eachSkill;
    while( $skills->hasNext() ){
        my $obj_skill = $skills->next();
        
        next if $skill eq $obj_skill->name;
        
        push @newSkills, $obj_skill;
    }
    
    # replace skills
    $self->{SKILLS} = \@newSkills;
    
    return undef;
}

sub skillExists {
    my ( $self, $skill) = @_;
    
    if( getSkillByName( $self, $skill ) ){
        return 1;
    } else {
        return undef;
    }
}

sub getSkillByName {
    my ( $self, $skill) = @_;
    
    foreach my $obj_skill( @{ $self->{SKILLS} } ){
        if( $obj_skill->name eq $skill ){
            return $obj_skill;
        }
    }
    return undef;
}

sub getSkillsCount {
    my $self = shift;
    return @{ $self->{SKILLS} };
}

1;
