use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 1;

use TWiki::Plugins::JiraPlugin::Client;

use Encode;
use File::Basename;
use Test::Deep;

my $client = TWiki::Plugins::JiraPlugin::Client->new();

my $xml = do {
    my $file = dirname(__FILE__).'/data/issues.xml';
    local $/;
    open(my $in, $file) or die "$file: $!";
    my $cont = <$in>;
    close $in;
    $cont;
};

my $issues = $client->parseXML($xml);

cmp_deeply($issues, [
    noclass({
        'id' => '15431',
        'project' => 'MAHIRO',
        'description' => 'Test description',
        'environment' => 'Blah blah blah environment',
        'key' => 'MAHIRO-6',
        'summary' => 'test html tag <a>...</a>',
        'type' => '3',
        'priority' => '4',
        'status' => '1',
        'resolution' => '-1',
        'assignee' => 'mahiro',
        'reporter' => 'mahiro',
        'labels' => ['testlabel', 'testlabel2'],
        'created' => 'Fri, 6 Jul 2012 08:12:30 -0400',
        'updated' => 'Tue, 31 Jul 2012 03:13:45 -0400',
        'affectsVersions' => ['1.0', '1.1'],
        'fixVersions' => ['1.2', '1.3'],
        'components' => ['comp1', 'comp2'],
        'duedate' => 'Tue, 31 Jul 2012 00:00:00 -0400',
        'votes' => '0',
        'timeOriginalEstimate' => '2 hours',
        'timeEstimate' => '1 week, 3 days, 2 hours',
        'timeSpent' => '4 weeks, 4 hours',
        'aggregateTimeOriginalEstimate' => '2 days, 2 hours',
        'aggregateTimeEstimate' => '2 days, 3 hours',
        'aggregateTimeSpent' => '1 week, 4 days',
        'customFieldValues' => [
            noclass({
                'customfieldId' => 'customfield_10055',
                'values' => ['Test bu'],
                'customfieldName' => 'BU',
                'key' => 'com.atlassian.jira.plugin.system.customfieldtypes:textfield'
            }),
            noclass({
                'customfieldId' => 'customfield_10054',
                'values' => ['Test bu contact'],
                'customfieldName' => 'BU contact',
                'key' => 'com.atlassian.jira.plugin.system.customfieldtypes:textfield'
            }),
        ],
    }),
    noclass({
        'id' => '13443',
        'project' => 'MAHIRO',
        'description' => Encode::encode_utf8("\x{3042}\x{3044}\x{3046}\x{3048}\x{304a}
<br/>
\x{65e5}\x{672c}\x{8a9e}
<br/>
hello world
<br/>
\x{30cf}\x{30ed}\x{30fc}\x{30ef}\x{30fc}\x{30eb}\x{30c9}"),
        'environment' => 'dev',
        'key' => 'MAHIRO-5',
        'summary' => Encode::encode_utf8("\x{65e5}\x{672c}\x{8a9e}\x{30c6}\x{30b9}\x{30c8}"),
        'type' => '3',
        'priority' => '4',
        'status' => '1',
        'resolution' => '-1',
        'assignee' => 'mahiro',
        'reporter' => 'mahiro',
        'labels' => ['label'],
        'created' => 'Thu, 10 Nov 2011 04:23:39 -0500',
        'updated' => 'Tue, 22 Nov 2011 06:54:32 -0500',
        'affectsVersions' => ['1.0', '1.2'],
        'fixVersions' => ['1.0', '1.1'],
        'components' => ['comp1'],
        'duedate' => '',
        'votes' => '0',
        'customFieldValues' => [
            noclass({
                'customfieldId' => 'customfield_10054',
                'values' => ['ien-help'],
                'customfieldName' => 'BU contact',
                'key' => 'com.atlassian.jira.plugin.system.customfieldtypes:textfield'
            }),
            noclass({
                'customfieldId' => 'customfield_10030',
                'values' => ['true'],
                'customfieldName' => 'Perforce job',
                'key' => 'com.atlassian.jirafisheyeplugin:jobcheckbox'
            }),
            noclass({
                'customfieldId' => 'customfield_10435',
                'values' => ['custom_label'],
                'customfieldName' => 'TWikiPlugin Labels',
                'key' => 'com.atlassian.jira.plugin.system.customfieldtypes:labels'
            }),
            noclass({
                'customfieldId' => 'customfield_10425',
                'values' => ['1 week, 2 days ago'],
                'customfieldName' => 'TWikiPlugin Days since last comment',
                'key' => 'com.atlassian.jira.toolkit:dayslastcommented'
            }),
        ],
    }),
]);
