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

#use fields qw(CATS LOADED);

use strict;

# IDEAS:
# - don't always have to read from file; could get from memory if we already have it
# - provide an iterator? could use TWiki::ListIterator and TWiki::LineIterator...
# - sort categories

my @_categories;
my $_loaded = 0;

# Object that handles interaction with the skills data (currently stored in a plain text file in the work area)
sub new {
    my $class = shift;
    
    my $self = {};
    
    return bless ( $self, $class);
}

# loads the categories and skills from the file
sub _load {
    my $self = shift;
    
    _Debug( 'reading skills.txt' );
    
    my $file = TWiki::Func::getWorkArea( 'SkillsPlugin' ) . '/skills.txt';
    return 1 unless( -r $file ); # check file exists
    
    require TWiki::LineIterator;
    my $it = new TWiki::LineIterator( $file );
    
    unless( $it->hasNext() ){
        _Debug( 'skills.txt is empty' );
        return 1;
    }
    
    # we have elements in iterator
    while( $it->hasNext() ){
        my $line = $it->next();
        next if $line =~ /^\#.*/; # skip any comments
        
        $line =~ s/(.*)://g;
        my $cat = $1;
        my @skills = split(',', $line);
        
        my $obj_cat = TWiki::Plugins::SkillsPlugin::Category->new($cat, \@skills);
        push @_categories, $obj_cat;
    }
    
    $_loaded = 1;
    
    return 1;
}

# gets all the categories and skills
# could get from memory if we already have it
sub getAll {
    my $self = shift;
    
    $self->_load unless $_loaded;
    
    return \@_categories;
    
    # return in a way that we can display
    # could be sorted
}

# returns a list of all categories
sub getCategoryNames {
    my $self = shift;
    
    $self->_load unless $_loaded;
    
    my @cats;
    
    for my $obj_cat ( @_categories ){
        push @cats, $obj_cat->name;
    }
    return \@cats;
}

sub eachCat {
    my $self = shift;
    # iterator of category objects (sorted?)
}

# saves the skills to file
sub save {
    my $self = shift;
    
    my $out = "# This file is generated. Do NOT edit!\n";

    foreach my $obj_cat ( @_categories ){
        $out .= $obj_cat->name . ':' . join(',', @{ $obj_cat->getSkills } ) . "\n";
    }

    my $workArea =  TWiki::Func::getWorkArea( 'SkillsPlugin' );

    TWiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

# adds new skill to category
sub addNewSkill {
    my $self = shift;
    
    my( $pSkill, $pCat ) = @_;
    
    # TODO: Permissions
    
    my $obj_cat = $self->getCategoryByName( $pCat );
    
    # check cat exists and skill does not already exist
    return 'Could not find category/category does not exist.' unless $obj_cat;
    return 'Skill already exists.' if( $obj_cat->skillExists( $pSkill ) );
    
    # replace category
    $obj_cat->addSkill( $pSkill );
    
    # save
    $self->save() || return 'Error saving';
    
    return undef; # no error
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

sub categoryExists {
    my $self = shift;
    
    if( $self->getCategoryByName( shift ) ){
        return 1;
    } else {
        return undef;
    }
}

# returns the category obj for the particular category
sub getCategoryByName {
    my $self = shift;
    
    my $cat = shift || return undef;
    
    # ensure loaded
    $self->_load unless $_loaded;
    
    foreach my $obj_cat( @_categories ){
        if( lc$obj_cat->name eq lc$cat ){
            return $obj_cat;
        }
    }
    return undef;
}

# replaces the category object for the specified category
sub replaceCategory {
    my $self = shift;
    
    #my $obj_cat = shift || return 0;
    
    
}

sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{SkillsPlugin}{Debug} || 0;
    TWiki::Func::writeDebug( "- TWiki::Plugins::SkillsPlugin::SkillsStore: $text" ) if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning( "- TWiki::Plugins::SkillsPlugin::SkillsStore: $text" );
}

1;