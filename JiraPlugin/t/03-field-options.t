use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 13;

use Test::Deep;
use TWiki::Plugins::JiraPlugin::Field;

sub make_field {
    my ($input) = @_;
    return TWiki::Plugins::JiraPlugin::Field->new($input);
}

subtest none => sub {
    plan tests => 5;
    
    for my $input (qw(project status assignee created customfield_1234)) {
        cmp_deeply(make_field($input), methods(input => $input, option => ''), $input);
    }
};

subtest id => sub {
    plan tests => 5;
    
    for my $input (qw(project_id status_id assignee_id created_id customfield_1234_id)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'id'), $input);
    }
};

subtest raw => sub {
    plan tests => 5;
    
    for my $input (qw(project_raw status_raw assignee_raw created_raw customfield_1234_raw)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'raw'), $input);
    }
};

subtest mixed => sub {
    plan tests => 3;
    
    for my $input (qw(priority_mixed key_mixed assignee_mixed)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'mixed'), $input);
    }
};

subtest url => sub {
    plan tests => 2;
    
    for my $input (qw(key_url reporter_url)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'url'), $input);
    }
};

subtest href => sub {
    plan tests => 2;
    
    for my $input (qw(key_href reporter_href)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'href'), $input);
    }
};

subtest icon => sub {
    plan tests => 2;
    
    for my $input (qw(type_icon status_icon)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'icon'), $input);
    }
};

subtest text => sub {
    plan tests => 3;
    
    for my $input (qw(priority_text key_text assignee_text)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'text'), $input);
    }
};

subtest name => sub {
    plan tests => 3;
    
    for my $input (qw(priority_name key_name assignee_name)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'name'), $input);
    }
};

subtest date => sub {
    plan tests => 3;
    
    for my $input (qw(updated_date creation_date due_date)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'date'), $input);
    }
};

subtest long => sub {
    plan tests => 3;
    
    for my $input (qw(updated_long creation_long due_long)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'long'), $input);
    }
};

subtest full => sub {
    plan tests => 3;
    
    for my $input (qw(updated_full creation_full due_full)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'full'), $input);
    }
};

subtest ts => sub {
    plan tests => 3;
    
    for my $input (qw(updated_ts creation_ts due_ts)) {
        cmp_deeply(make_field($input), methods(input => $input, option => 'ts'), $input);
    }
};
