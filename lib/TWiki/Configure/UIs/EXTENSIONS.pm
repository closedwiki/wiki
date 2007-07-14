#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
# As per the GPL, removal of this notice is prohibited.
package TWiki::Configure::UIs::EXTENSIONS;
use base 'TWiki::Configure::UI';

use strict;
use TWiki::Configure::Type;

my @tableHeads =
  qw(image topic description version installedVersion testedOn install );
my %headNames = (
    image => '',
    topic => 'Extension',
    description => 'Description',
    version => 'Most Recent Version',
    installedVersion => 'Installed Version',
    testedOn => 'Tested On TWiki',
    testedOnOS => 'Tested On OS',
    install => 'Action',
   );

# Download the report page from the repository, and extract a hash of
# available extensions
sub _getListOfExtensions {
    my $this = shift;

    if (!$this->{list}) {
        $this->{list} = {};
        foreach my $place ( @{$this->{repositories}} ) {
            print CGI::div("Consulting $place->{name}...");
            my $url = $place->{data}.
                  'FastReport?skin=text&contenttype=text/plain';
            my $response = $this->getUrl($url);
            if (!$response->is_error()) {
                my $page = $response->content();
                $page =~ s/{(.*?)}/$this->_parseRow($1, $place)/ges;
            #} else {
            #    die "$url ".$response->message();
            }
        }
    }
    return $this->{list};
}

sub _parseRow {
    my ($this, $row, $place) = @_;
    my %data;
    return '' unless $row =~ s/^ *(\w+): *(.*?) *$/$data{$1} = $2;''/gem;
    $data{installedVersion} = $this->_getInstalledVersion($data{topic});
    $data{repository} = $place->{name};
    $data{data} = $place->{data};
    $data{pub} = $place->{pub};
    die "$row: ".Data::Dumper->Dump([\%data]) unless $data{topic};
    $this->{list}->{$data{topic}} = \%data;
    return '';
}

sub ui {
    my $this = shift;
    my $table =
      CGI::Tr(join('', map { CGI::th({valign=>'bottom' },
                                     $headNames{$_}) } @tableHeads));

    my $rows = 0;
    my $installed = 0;
    my $exts = $this->_getListOfExtensions();
    foreach my $key (sort keys %$exts) {
        my $ext = $exts->{$key};
        my $row = '';
        foreach my $f (@tableHeads) {
            my $text;
            if ($f eq 'install') {
                my $link = $TWiki::query->url().
                  '?action=InstallExtension'.
                    ';repository='.$ext->{repository}.
                    ';extension='.$ext->{topic};
                $text = 'Install';
                if ($ext->{installedVersion}) {
                    $text = 'Upgrade';
                    $installed++;
                }
                $text = CGI::a({ href => $link }, $text);
            } else {
                $text = $ext->{$f}||'-';
                if ($f eq 'topic') {
                    my $link = $ext->{data}.$ext->{topic};
                    $text = CGI::a({ href => $link }, $text);
                }
            }
            $row .= CGI::td({valign=>'top'}, $text);
        }
        if ($ext->{installedVersion}) {
            $table .= CGI::Tr({class=>'patternAccessKeyInfo'}, $row);
        } else {
            $table .= CGI::Tr($row);
        }
        $rows++;
    }
    $table .= CGI::Tr({class=>'patternAccessKeyInfo'},CGI::td(
        {colspan => 7},
        $installed . ' extension'.
          ($installed==1?'':'s').' out of '.$rows.' already installed'));
    my $page = <<INTRO;
To install an extension from this page, click on the link in the 'Action' column.<p />Note that the webserver user has to be able to
write files everywhere in your TWiki installation. Otherwise you may see
'No permission to write' errors during extension installation.
INTRO
    $page .= CGI::table({class=>'twikiForm'},$table);
    $page .= <<'HELP';
<p />
TWiki exctension repositories are just TWiki webs which contain published
extensions, same as the Plugins web on TWiki.org.

You can add more repositories to the search path by defining the
environment variable <code>$TWIKI_REPOSITORIES</code> in
<tt>bin/LocalLib.cfg</tt>, thus:<br />
<tt>$ENV{TWIKI_REPOSITORIES} = '<i>repositories</i>';</tt><p />
<code>$TWIKI_REPOSITORIES</code> has to be a semicolon-separated list of repository specifications, <i>name=(list,pub)</i>, where:
<ul>
<li><i>name</i> is the symbolic name of the repository e.g. TWiki.org</li>
<li><i>list</i> is the URL of a TWiki page that lists the available
extensions in a special parseable format (see the
<a href="http://twiki.org/cgi-bin/view/Plugins/FastReport?raw=on">Plugins.FastReport</a> page), and</li>
<li><i>pub</i> is the root of a download URL on the repository site.</li>
</ul>
For example,<code>
twiki.org=(http://twiki.org/cgi-bin/view/Plugins/FastReport?skin=text&contenttype=text/plain,http://twiki.org/p/pub/Plugins/);
wikiring.com=(http://wikiring.com/bin/view/Extensions/FastReport?skin=text&contenttype=text/plain,http://wikiring.com/bin/viewfile/Extensions/)</code><p />
Note that you can pass authentication information in the URL, for example: <tt>http://User:password\@the.server.com/</tt>.
HELP
    return $page;
}

sub _getInstalledVersion {
    my ($this, $module) = @_;
    my $lib;

    return undef unless $module;

    if ($module =~ /Plugin$/) {
        $lib = 'Plugins';
    } else {
        $lib = 'Contrib';
    }

    my $path = 'TWiki::'.$lib.'::'.$module;
    my $version;
    my $check = 'use '.$path.'; $version = $'.$path.'::VERSION;';
    eval $check;
    #print STDERR $@ if $@ && DEBUG;
    if ($version) {
        $version =~ s/^\s*\$Rev:\s*(.*?)\s*\$$/$1/;
    }
    return $version;
}

1;
