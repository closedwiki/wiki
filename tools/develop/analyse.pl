# Analyse who fixed what
use strict;

my $REPOS = '/home/svn/repos';
my $BUGS = '/home/twiki4/twikisvn/data/Bugs';
my $verbose = 0;

my %rename = (
    peterthoeny => "PeterThoeny",
    pthoeny => "PeterThoeny",
    thoeny => "PeterThoeny",
    svenud => "SvenDowideit",
    sdowideit => "SvenDowideit",
    rdonkin => "RichardDonkin",
    wbniv => "WillNorris",
    mrjc => "MartinCleaver",
    aclemens => "ArthurClemens",
    maphew => "MattWilkie",
    ethermage => "WalterMundt",
    wmundt => "WalterMundt",
    sterbini => "AndreaSterbini",
    soronthar => "RafaelAlvarez",
    terceiro => "AntonioTerceiro",
    crawfordcurrie => "CrawfordCurrie",
    talintj => "JohnTalintyre",
    dabright => "DavidBright",
   );

my $coreExt = qr/ClassicSkin|CommentPlugin|EditTablePlugin|EmptyPlugin|InterwikiPlugin|JSCalendarContrib|MailerContrib|PatternSkin|TwistyContrib|BehaviourContrib|TwistyPlugin|PreferencesPlugin|RenderListPlugin|SlideShowPlugin|SmiliesPlugin|SpreadSheetPlugin|TablePlugin|TipsContrib|WysiwygPlugin/;

# First load and update WhoDunnit.dat, the list of checkers-in for each rev
my $topSid = `svnlook youngest $REPOS`;
my $maxSid = 0;
my %sid2who;
if (open(F, "<WhoDunnit.sid2cin")) {
    local $/ = "\n";
    while (<F>) {
        if (/(\S+) (\S+)$/) {
            $sid2who{$2} = $1;
            $maxSid = $2 if $2 > $maxSid;
        }
    }
}
close(F);
$maxSid++;
if ($maxSid < $topSid) {
    print "Refreshing $maxSid..$topSid\n" if $verbose;
    open(F, ">>WhoDunnit.sid2cin") || die $!;
    for ($maxSid..$topSid) {
        my $who = `svnlook author -r $_ $REPOS`;
        chomp($who);
        $sid2who{$_} = $who;
        print F "$who $_\n";
        print "$_ $who            \r" if $verbose;
    }
    close(F);
}
print "\n" if $verbose;

# Now determine which bug(s) are closed, and what checkins contributed
# have to do this every time, as the bugs web changes constantly
my %zappedBy;
my %reportedBy;
my %contributedBy;
opendir(D, $BUGS) || die "$!";
foreach my $item (sort { $a <=> $b }
                      grep { s/^Item(\d+)\.txt$/$1/ }
                               readdir(D)) {
    print "Item$item      \r";
    open(F, "<$BUGS/Item$item.txt") || next;
    local $/ = undef;
    my $bug = <F>;
    close(F);
    my %field;
    while ($bug =~ s/^%META:FIELD.*name="(\w+)".*value="(.*?)".*%$//m) {
        $field{$1} = $2;
    }
    if ($field{Priority} !~ /Enhancement/ &&
          ($field{AppliesTo} eq "Engine" ||
             $field{Extension} =~ /\b($coreExt)\b/)) {
        foreach my $cin (split(/\s+/, $field{Checkins})) {
            #print "$cin Zapped by $sid2who{$cin}\n";
            $zappedBy{$sid2who{$cin}}{$item} = 1;
            $contributedBy{$sid2who{$cin}}{$item} = 1;
        }
        if ($field{ReportedBy} =~ /Main\.(.*)$/) {
            $reportedBy{$1}++;
        }
    } else {
        foreach my $cin (split(/\s+/, $field{Checkins})) {
            $contributedBy{$sid2who{$cin}}{$item} = 1;
        }
    }

}
closedir(D);
my %counts;
foreach my $zapper (keys %zappedBy) {
    $counts{$zapper} = scalar(keys %{$zappedBy{$zapper}}), "\n";
}
print "\n" if $verbose;
open(F, ">$BUGS/HallOfFame.txt") || die $!;
print F <<HEADING;
The following tables show contributions to the TWiki core since the
inception of this database. The tables are refreshed once a week
by a cron job. *THIS TOPIC IS AUTO_GENERATED*. Do not attempt to edit it!
%TOC%
---+ Bug Zapping Summary
This table shows the top 5 most active contributors to the
TWiki core since the inception of this database. 

The count is of the number of closed bugs (not enhancements) where a checkin
was done by the person (i.e. they contributed to the fix).
%STARTINCLUDE%
| *Who* | *Bugs fixed* |
HEADING
my $n = 0;
foreach my $zapper (sort { $counts{$b} <=> $counts{$a} } keys %counts) {
    next unless $zapper;
    print F "| [[TWiki:Main.$zapper][$zapper]] | $counts{$zapper} |\n";
    last if ++$n == 5;
}
print F "%STOPINCLUDE%\n";
print F <<STUFF;
---+ Bug Zapping Full Story
Here's the full story of core bug zapper contributions
| *Who* | *Bugs reported* | *Core bugs fixed* |
STUFF
$n = 0;
foreach my $zapper (sort { $counts{$b} <=> $counts{$a} } keys %counts) {
    next unless $zapper;
    print F "| [[TWiki:Main.$zapper][$zapper]] | $reportedBy{$zapper} | $counts{$zapper} |\n";
}

print F <<STUFF;
---+ Contributions
Here's a full breakdown of individual contributions. The counts are the number
of items (all priorities) in the database where the person contributed a
checkin. This covers bugs, enhancements, core and all plugins.
| *Who* | *Contributions* |
STUFF
my %dumps;
foreach my $contributor (keys %contributedBy) {
    $dumps{$contributor} = scalar(keys %{$contributedBy{$contributor}}), "\n";
}
foreach my $zapper (sort { $dumps{$b} <=> $dumps{$a} } keys %dumps) {
    next unless $zapper;
    print F "| [[TWiki:Main.$zapper][$zapper]] | $dumps{$zapper} |\n";
}

print F <<STUFF;
---+ Everyone who ever checked in anything
For completeness, here's a full list of everyone who has ever
contributed a checkin (all time contributions) since TWiki started using
revision control.
| *Who* | *Checkins* |
STUFF
my %sins;
foreach my $who (values %sid2who) {
    $who = $rename{$who} || $who;
    $sins{$who}++;
}

foreach my $zapper (sort { $sins{$b} <=> $sins{$a} } keys %sins) {
    print F "| [[TWiki:Main.$zapper][$zapper]] | $sins{$zapper} |\n";
}
close(F);
