# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@googlemail.com
# Copyright (C) 2008-2011 TWiki:TWiki.TWikiContributor
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

use strict;

require TWiki::Plugins::SkillsPlugin::Category;

my @_categories;
my $_loaded = 0;

# Object that handles interaction with the skills data (currently stored in a plain text file in the work area)
sub new {
    my $class = shift;

    my $self = {};

    return bless( $self, $class );
}

# loads the categories and skills from the file
sub _load {
    my $self = shift;

    _Debug('reading skills.txt');

    my $file = TWiki::Func::getWorkArea('SkillsPlugin') . '/skills.txt';
    return 1 unless ( -r $file );    # check file exists

    require TWiki::LineIterator;
    my $it = new TWiki::LineIterator($file);

    unless ( $it->hasNext() ) {
        _Debug('skills.txt is empty');
        return 1;
    }

    # we have elements in iterator
    while ( $it->hasNext() ) {
        my $line = $it->next();
        next if $line =~ /^\#.*/;    # skip any comments

        $line =~ s/(.*)://g;
        my $cat = $1;
        my @skills = split( ',', $line );

        my $obj_cat =
          TWiki::Plugins::SkillsPlugin::Category->new( $cat, \@skills );
        push @_categories, $obj_cat;
    }

    $_loaded = 1;

    return 1;
}

# returns an array of all category names
sub getCategoryNames {
    my $self = shift;

    $self->_load unless $_loaded;

    my @catNames;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        push @catNames, $obj_cat->name;
    }
    return \@catNames;
}

# sorted iterator of category objects
sub eachCat {
    my $self = shift;

    $self->_load unless $_loaded;

    my @sorted = sort { $a->name cmp $b->name } @_categories;

    require TWiki::ListIterator;
    return new TWiki::ListIterator( \@sorted );
}

# saves the skills to file
sub save {
    my $self = shift;

    _Debug('Saving skills.txt');

    my $out =
"# This file is generated. Do NOT edit unless you are sure what your doing!\n";

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        $out .= $obj_cat->name . ':'
          . join( ',', @{ $obj_cat->getSkillNames } ) . "\n";
    }

    my $workArea = TWiki::Func::getWorkArea('SkillsPlugin');

    TWiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

# adds new skill to category
sub addNewSkill {
    my $self = shift;

    my ( $pSkill, $pCat ) = @_;

    my $obj_cat = $self->getCategoryByName($pCat);

    # check category exists and skill does not already exist
    return 'Could not find category/category does not exist.' unless $obj_cat;
    return 'Skill already exists.' if ( $obj_cat->skillExists($pSkill) );

    # add skill to category
    $obj_cat->addSkill($pSkill);

    # save
    $self->save() || return 'Error saving';

    return undef;    # no error
}

sub renameSkill {
    my $self = shift;

    my ( $cat, $oldSkill, $newSkill ) = @_;

    my $obj_cat = $self->getCategoryByName($cat);
    return "Could not find category/category does not exist - '$cat'."
      unless $obj_cat;

    my $er = $obj_cat->renameSkill( $oldSkill, $newSkill );
    return $er if $er;

    $self->save() || return 'Error saving';

    return undef;
}

sub moveSkill {
    my $self = shift;

    my ( $skill, $oldCat, $newCat ) = @_;

    my $obj_oldCat = $self->getCategoryByName($oldCat);
    return "Could not find category/category does not exist - '$oldCat'."
      unless $obj_oldCat;
    my $obj_newCat = $self->getCategoryByName($newCat);
    return "Could not find category/category does not exist - '$newCat'."
      unless $obj_newCat;

    return "Skill '$skill' already exists in category '$newCat'"
      if $obj_newCat->skillExists($skill);

    my $err;

    # add skill to new category
    $obj_newCat->addSkill($skill);

    # delete skill from old category
    $obj_oldCat->deleteSkill($skill);

    $self->save() || return 'Error saving';

    return undef;
}

sub deleteSkill {
    my $self = shift;

    my ( $cat, $skill ) = @_;

    my $obj_cat = $self->getCategoryByName($cat);
    return "Could not find category/category does not exist - '$cat'."
      unless $obj_cat;

    my $er = $obj_cat->deleteSkill($skill);
    return $er if $er;

    $self->save() || return 'Error saving';

    return undef;
}

sub addNewCategory {
    my $self = shift;

    my ($newCat) = @_;

    # check category does not already exist
    return "Category '$newCat' already exists."
      if ( $self->categoryExists($newCat) );

    # create new object and add to array
    my $new_obj_cat = TWiki::Plugins::SkillsPlugin::Category->new($newCat);
    push @_categories, $new_obj_cat;

    # save
    $self->save() || return 'Error saving';

    return undef;    # no error
}

sub renameCategory {
    my $self = shift;

    my ( $oldCat, $newCat ) = @_;

    # check category does not already exist
    return "Category '$newCat' already exists"
      if ( $self->categoryExists($newCat) );

    my $obj_cat = $self->getCategoryByName($oldCat);
    return "Could not find category/category does not exist - '$oldCat'."
      unless $obj_cat;

    # change the name
    $obj_cat->name($newCat);

    # save
    $self->save() || return 'Error saving';

    return undef;
}

sub deleteCategory {
    my $self = shift;

    my ($cat) = @_;

    return "$cat does not exist" unless $self->categoryExists($cat);

    my @newCategories;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        next if $obj_cat->name eq $cat;    # skip if it is cat to delete
        push( @newCategories, $obj_cat );
    }

    # replace the categories with the ones we want to keep
    @_categories = @newCategories;

    $self->save() || return 'Error saving';

    return undef;
}

sub categoryExists {
    my $self = shift;

    if ( $self->getCategoryByName(shift) ) {
        return 1;
    }
    else {
        return undef;
    }
}

# returns the category obj for the particular category
sub getCategoryByName {
    my $self = shift;

    my $cat = shift || return undef;

    # ensure loaded
    $self->_load unless $_loaded;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        if ( $obj_cat->name eq $cat ) {
            return $obj_cat;
        }
    }
    return undef;
}

sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{SkillsPlugin}{Debug} || 0;
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::SkillsPlugin::SkillsStore: $text")
      if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning(
        "- TWiki::Plugins::SkillsPlugin::SkillsStore: $text");
}

1;
