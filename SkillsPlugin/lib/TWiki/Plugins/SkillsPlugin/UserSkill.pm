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

package TWiki::Plugins::SkillsPlugin::UserSkill;

use strict;

# Object to represent the skill as stored in users meta data
sub new {
    
    my ($class, $name, $cat, $rating, $comment) = @_;
    
    my $self = bless ( {}, $class);
    
    $self->name($name);
    $self->category($cat);
    $self->rating($rating);
    $self->comment($comment);
    
    return $self;
}

sub name {
    my $self = shift;
    if (@_) { $self->{NAME} = shift }
    return $self->{NAME};
}

sub category {
    my $self = shift;
    if (@_) { $self->{CATEGORY} = shift }
    return $self->{CATEGORY};
}

sub rating {
    my $self = shift;
    if (@_) { $self->{RATING} = shift }
    return $self->{RATING};
}

sub comment {
    my $self = shift;
    if (@_) { $self->{COMMENT} = shift }
    return $self->{COMMENT};
}

1;