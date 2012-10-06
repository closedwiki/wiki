# Module for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 TWiki:Main.MahiroAndo
# Copyright (C) 2012 TWiki Contributors
# All Rights Reserved.
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

use strict;
package TWiki::Plugins::JiraPlugin::Field;

my %simpleNames = map {$_ => 1} qw(
    project id key
    type status priority resolution
    summary description environment votes
    assignee reporter
    created updated duedate
);

my %urlparamMap = qw(
    key             issuekey
    id              issuekey
    attachmentNames attachments
    fixVersions     fixVersions
    affectsVersions versions
);

# Ref: http://confluence.atlassian.com/display/JIRA/Displaying+Search+Results+in+XML

sub new {
    my ($class, $input) = @_;
    my ($option, $canonical, $urlparam, $is_html);
    
    my $name = $input;
    $name =~ s/^\$//;
    $name =~ s/^\{|\}$//g;

    if ($name =~ /(.*)_(id|raw|mixed|url|href|icon|text|name|date|long|full|ts)$/) {
        $name = $1;
        $option = $2;
    } else {
        $option = '';
    }
    
    if ($simpleNames{lc $name}) {
        $canonical = lc $name;
    } elsif ($name =~ /^pid$/i) {
        $canonical = 'project';
    } elsif ($name =~ /^assign(ed)?(To)?$/i) {
        $canonical = 'assignee';
    } elsif ($name =~ /^votes?$/i) {
        $canonical = 'votes';
    } elsif ($name =~ /^report(s|er|ed)?(By)?$/i) {
        $canonical = 'reporter';
    } elsif ($name =~ /^creat(e|ed|es|ion)(Date)?(Time)?$/i) {
        $canonical = 'created';
    } elsif ($name =~ /^update[ds]?(Date)?(Time)?$/i) {
        $canonical = 'updated';
    } elsif ($name =~ /^resolve[ds]?(Date)?(Time)?$/i) {
        $canonical = 'resolved';
    } elsif ($name =~ /^due(date)?$/i) {
        $canonical = 'duedate';
    } elsif ($name =~ /^attachment(Name)?s?$/i) {
        $canonical = 'attachmentNames';
    } elsif ($name =~ /^(component|label)s?$/i) {
        $canonical = lc($1).'s';
    } elsif ($name =~ /^fix(Versions?|ed)?$/i) {
        $canonical = 'fixVersions';
    } elsif ($name =~ /^(affect(s|ed)?(Versions?)?|versions?)$/i) {
        $canonical = 'affectsVersions';
    } elsif ($name =~ /^customfield_\d+$/i) {
        $canonical = lc $name;
    } elsif ($name =~ /^(aggregate)?Time(Remaining)?Estimate$/i) {
        $canonical = $1 ? 'aggregateTimeEstimate' : 'timeEstimate';
    } elsif ($name =~ /^(aggregate)?TimeOriginalEstimate$/i) {
        $canonical = $1 ? 'aggregateTimeOriginalEstimate' : 'timeOriginalEstimate';
    } elsif ($name =~ /^(aggregate)?TimeSpent$/i) {
        $canonical = $1 ? 'aggregateTimeSpent' : 'timeSpent';
    }
    
    if ($canonical) {
        $urlparam = $urlparamMap{$canonical} || lc($canonical);
        $is_html = ($canonical =~ /^((description|comment)$|customfield_)/) ? 1 : 0;
    }
    
    return bless {
        input     => $input,
        name      => $name,
        option    => $option,
        canonical => $canonical,
        urlparam  => $urlparam,
        is_html   => $is_html,
    }, $class;
}

sub input {
    my ($self) = @_;
    return $self->{input};
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub option {
    my ($self) = @_;
    return $self->{option};
}

sub canonical {
    my ($self) = @_;
    return $self->{canonical};
}

sub urlparam {
    my ($self) = @_;
    return $self->{urlparam};
}

sub is_html {
    my ($self) = @_;
    return $self->{is_html};
}

1;
