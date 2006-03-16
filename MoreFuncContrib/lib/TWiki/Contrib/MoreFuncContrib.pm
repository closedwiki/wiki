use TWiki::Plugins;
use strict;

# Copyright (C) Meredith Lesly 2006
# Some functionality that should be added to TWiki::Func
#

package TWiki::Contrib::MoreFuncContrib;
use TWiki::Meta;

use vars qw( $VERSION );
$VERSION = '1.000';

#
# This is yucky, since what we really want is for Store.pm to have a function that
# returns only the $meta.
#
sub readTopicMeta {
    my( $web, $topic, $rev ) = @_;

    my ($meta, $text) =  $TWiki::Plugins::SESSION->{store}->readTopic( undef, @_ );
    return $meta;
}

sub getTopicPreferenceValue {
    my ($web, $topic, $prefName) = @_;

    my $meta = readTopicMeta($web, $topic);
    my $prefHash = $meta->get($prefName);

    return $prefHash->{value} if $prefHash;
    return 0;
}

sub readWorkFile {
    my ($pluginName, $fileName) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return readFile("$workArea/$fileName") if $workArea and ( -r "$workArea/$fileName");
    return 0;
}

sub saveWorkFile {
    my ($pluginName, $fileName, $text) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return saveFile("$workArea/$fileName", $text) if $workArea and ( -w "$workArea/$fileName");
    return 0;
}

sub deleteWorkFile {
    my ($pluginName, $fileName, $text) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return unlink("$workArea/$fileName", $text) if $workArea and ( -w "$workArea/$fileName");
    return 0;
}

1;
