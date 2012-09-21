use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 27;

use Test::Deep;
use TWiki::Plugins::JiraPlugin::Field;

sub make_field {
    my ($input) = @_;
    return TWiki::Plugins::JiraPlugin::Field->new($input);
}

subtest project => sub {
    plan tests => 3;
    
    for my $input (qw(project Project PID)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'project', urlparam => 'project', is_html => 0,
        ), $input);
    }
};

subtest id => sub {
    plan tests => 3;
    
    for my $input (qw(id ID Id)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'id', urlparam => 'issuekey', is_html => 0,
        ), $input);
    }
};

subtest type => sub {
    plan tests => 2;
    
    for my $input (qw(type Type)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'type', urlparam => 'type', is_html => 0,
        ), $input);
    }
};

subtest status => sub {
    plan tests => 2;
    
    for my $input (qw(status Status)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'status', urlparam => 'status', is_html => 0,
        ), $input);
    }
};

subtest priority => sub {
    plan tests => 2;
    
    for my $input (qw(priority Priority)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'priority', urlparam => 'priority', is_html => 0,
        ), $input);
    }
};

subtest resolution => sub {
    plan tests => 2;
    
    for my $input (qw(resolution Resolution)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'resolution', urlparam => 'resolution', is_html => 0,
        ), $input);
    }
};

subtest summary => sub {
    plan tests => 2;
    
    for my $input (qw(summary Summary)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'summary', urlparam => 'summary', is_html => 0,
        ), $input);
    }
};

subtest description => sub {
    plan tests => 2;
    
    for my $input (qw(description Description)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'description', urlparam => 'description', is_html => 1,
        ), $input);
    }
};

subtest environment => sub {
    plan tests => 2;
    
    for my $input (qw(environment Environment)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'environment', urlparam => 'environment', is_html => 0,
        ), $input);
    }
};

subtest votes => sub {
    plan tests => 3;
    
    for my $input (qw(votes Votes VOTE)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'votes', urlparam => 'votes', is_html => 0,
        ), $input);
    }
};

subtest assignee => sub {
    plan tests => 5;
    
    for my $input (qw(assignee Assignee ASSIGN AssignedTo assignTo)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'assignee', urlparam => 'assignee', is_html => 0,
        ), $input);
    }
};

subtest reporter => sub {
    plan tests => 5;
    
    for my $input (qw(reporter Reporter REPORT ReportedBy reportBy)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'reporter', urlparam => 'reporter', is_html => 0,
        ), $input);
    }
};

subtest created => sub {
    plan tests => 6;
    
    for my $input (qw(created Created CREATION CreateDate creationDateTime CreatedTime)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'created', urlparam => 'created', is_html => 0,
        ), $input);
    }
};

subtest updated => sub {
    plan tests => 6;
    
    for my $input (qw(updated Updated UPDATE UpdateDate updateDateTime updatedTime)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'updated', urlparam => 'updated', is_html => 0,
        ), $input);
    }
};

subtest duedate => sub {
    plan tests => 4;
    
    for my $input (qw(duedate DueDate DUE due)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'duedate', urlparam => 'duedate', is_html => 0,
        ), $input);
    }
};

subtest attachmentNames => sub {
    plan tests => 4;
    
    for my $input (qw(attachmentNames attachments ATTACHMENT AttachmentName)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'attachmentNames', urlparam => 'attachments', is_html => 0,
        ), $input);
    }
};

subtest components => sub {
    plan tests => 4;
    
    for my $input (qw(components Components COMPONENT component)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'components', urlparam => 'components', is_html => 0,
        ), $input);
    }
};

subtest labels => sub {
    plan tests => 3;
    
    for my $input (qw(labels Labels LABEL)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'labels', urlparam => 'labels', is_html => 0,
        ), $input);
    }
};

subtest fixVersions => sub {
    plan tests => 5;
    
    for my $input (qw(fixVersions FixVersion FIX Fixed fixVersion)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'fixVersions', urlparam => 'fixVersions', is_html => 0,
        ), $input);
    }
};

subtest affectsVersions => sub {
    plan tests => 5;
    
    for my $input (qw(affectsVersions AffectsVersions AffectedVersion VERSION Versions)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'affectsVersions', urlparam => 'versions', is_html => 0,
        ), $input);
    }
};

subtest customfield => sub {
    plan tests => 2;
    
    for my $input (qw(customfield_1234 CustomField_1234)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'customfield_1234', urlparam => 'customfield_1234', is_html => 1,
        ), $input);
    }
};

subtest timeEstimate => sub {
    plan tests => 3;
    
    for my $input (qw(timeEstimate TimeEstimate timeestimate)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'timeEstimate', urlparam => 'timeestimate', is_html => 0,
        ), $input);
    }
};

subtest aggregateTimeEstimate => sub {
    plan tests => 4;
    
    for my $input (qw(aggregateTimeEstimate AggregateTimeEstimate
            aggregatetimeestimate aggregatetimeremainingestimate)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'aggregateTimeEstimate', urlparam => 'aggregatetimeestimate', is_html => 0,
        ), $input);
    }
};

subtest timeOriginalEstimate => sub {
    plan tests => 3;
    
    for my $input (qw(timeOriginalEstimate TimeOriginalEstimate timeoriginalestimate)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'timeOriginalEstimate', urlparam => 'timeoriginalestimate', is_html => 0,
        ), $input);
    }
};

subtest aggregateTimeOriginalEstimate => sub {
    plan tests => 3;
    
    for my $input (qw(aggregateTimeOriginalEstimate AggregateTimeOriginalEstimate aggregatetimeoriginalestimate)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'aggregateTimeOriginalEstimate', urlparam => 'aggregatetimeoriginalestimate', is_html => 0,
        ), $input);
    }
};

subtest timeSpent => sub {
    plan tests => 3;
    
    for my $input (qw(timeSpent TimeSpent timespent)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'timeSpent', urlparam => 'timespent', is_html => 0,
        ), $input);
    }
};

subtest aggregateTimeSpent => sub {
    plan tests => 3;
    
    for my $input (qw(aggregateTimeSpent AggregateTimeSpent aggregatetimespent)) {
        cmp_deeply(make_field($input), methods(
            input => $input, canonical => 'aggregateTimeSpent', urlparam => 'aggregatetimespent', is_html => 0,
        ), $input);
    }
};
