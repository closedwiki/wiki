#! /usr/local/bin/perl -w

use strict;

BEGIN {
    $Common::excludeFilePattern = 'DEADJOE|.svn|\~$|\,v|.changes|.mailnotify|.session';
    $Common::installationDir = "/home/mrjc/cleaver.org"; #NB. assumes below, e.g. twiki/bin/view, not bin/view
    $Common::downloadDir = "/home/mrjc/twikiplugindev/stage/twikiplugins/shared/tools/download/";
}

1;
