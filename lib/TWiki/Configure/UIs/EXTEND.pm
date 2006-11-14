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
use strict;

package TWiki::Configure::UIs::EXTEND;

use TWiki::Configure::UI;

use base 'TWiki::Configure::UI';
use File::Temp;
use Archive::Tar;

sub new {
    my $class = shift;
    my $this = bless($class->SUPER::new(@_), $class);

    push(@{$this->{repositories}},
         { data => 'http://twiki.org/cgi-bin/view/Plugins/',
           pub => 'http://twiki.org/p/pub/Plugins/' } );

    $this->{bin} = $FindBin::Bin;
    my @root = File::Spec->splitdir($this->{bin});
    pop(@root);
    $this->{root} = File::Spec->catfile(@root, '');

    return $this;
}

sub ui {
    my $this = shift;
    my $query = $TWiki::query;
    my $tgz;
    my $extension = $query->param('extension');
    my $tgzf = $query->param('pub').$extension.'/'.$extension.'.tgz';

    print "<br/>Fetching $tgzf...<br />\n";
    eval {
        $tgz = $this->getUrl($tgzf);
    };
    if ($@) {
        return $this->ERROR(<<HERE);
Sorry, I can't install $extension because of the following error:
<pre>$@</pre>
Please follow the published process for manual installation from the
command line.
HERE
    }

    unless ($tgz =~ s#^.*Content-Type: application/x-gzip\r\n\r\n##is) {
        return $this->ERROR(<<HERE);
Sorry, I can't install $extension because I don't recognise the download
as a gzip file.
Please follow the published process for manual installation from the
command line.
HERE
    }

    # Save it somewhere it will be cleaned up
    my $tmp = new File::Temp(SUFFIX => '.tgz', UNLINK=>1);
    binmode($tmp);
    print $tmp $tgz;
    $tmp->close();
    print 'Unpacking...<br />'."\n";
    my $tar = new Archive::Tar();
    unless ($tar->read($tmp->filename(), 1)) {
        return $this->ERROR(<<HERE);
Archive is unreadable. It's possible that the archive is corrupt.
Try following  the published process for manual installation from the
command line.
HERE
    }
    my @names = $tar->list_files();
    # unzip the contents
    unless ($query->param('confirm')) {
        my $sawInstaller = 0;
        foreach my $file (@names) {
            my $ef = $this->_findTarget($file);
            if (-e $ef && !-d $ef) {
                print $this->WARN(
                    "Existing $file overwritten<br />");
            } else {
                print $this->NOTE("$file<br />");
            }
            if( $file =~ /^${extension}_installer.pl/) {
                $sawInstaller = 1;
            }
        }
        unless ($sawInstaller) {
            print $this->WARN(
                "No ${extension}_installer.pl script found in archive");
        }
    }
    foreach my $file (@names) {
        my $ef = $this->_findTarget($file);
        if (-e $ef && !-d $ef && !-w $ef) {
            print $this->ERROR("No permission to write to $ef");
        } else {
            eval {
                unless ($tar->extract_file($file, $ef)) {
                    print $this->ERROR("Failed to extract file '$file' to $ef");
                }
            };
            die "$@ on $ef" if $@;
        }
    }
    if (-e "$this->{root}/${extension}_installer.pl") {
        # invoke the installer script. Not sure yet how to handle
        # interaction if the script ignores -a. At the moment it
        # will just hang :-(
        chdir($this->{root});
        unshift(@ARGV, '-a');
        eval {
            do '$this->{root}/${extension}_installer.pl';
            die $@ if $@; # propagate
        };
        if ($@) {
            print $this->ERROR(<<HERE);
${extension}_installer.pl returned errors:
<pre>$@</pre>
You may be able to resolve these errors and complete the installation
from the command line, so I will leave the installed files where they are.
HERE
        } else {
            print $this->NOTE("${extension}_installer.pl ran without errors");
        }
        chdir($this->{bin});
    }
    if ($this->{warnings}) {
        print $this->NOTE(
            "Installation finished with $this->{errors} error".
              ($this->{errors}==1?'':'s').
                " and $this->{warnings} warning".
                  ($this->{warnings}==1?'':'s'));
    } else {
        print 'Installation finished.';
    }
    if ($extension =~ /Plugin$/) {
        print $this->WARN(<<HERE);
Before you can use newly installed plugins, you must enable them in the
"Plugins" section in the main page.
HERE
    }
    return '';
}

# Find the installation target of a single file. This involves remapping
# through the settings in LocalSIte.cfg. If the target is not remapped, then
# the file is installed relative to the root, which is the directory
# immediately above bin.
sub _findTarget {
    my ($this, $file) = @_;

    if ($file =~ s#^data/#$TWiki::cfg{DataDir}/#) {
    } elsif ($file =~ s#^pub/#$TWiki::cfg{PubDir}/#) {
    } elsif ($file =~ s#^templates/#$TWiki::cfg{TemplateDir}/#) {
    } elsif ($file =~ s#^locale/#$TWiki::cfg{LocalesDir}/#) {
    } elsif ($file =~ s#^(bin/\w+)$#$1$TWiki::cfg{ScriptSuffix}#) {
    } else {
        $file = File::Spec->catfile($this->{root}, $file);
    }
    $file =~ /^(.*)$/;
    return $1;
}

1;
