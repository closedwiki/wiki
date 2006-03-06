#!/usr/bin/perl -w
#
# Build class for WebDAVPlugin

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS} || '')) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

package WebDAVPluginBuild;

@WebDAVPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "WebDAVPlugin" ), $class );
}

# override to build C program in test dir
sub target_test {
    my $this = shift;
    $this->pushd("$this->{basedir}/test/unit/WebDAVPlugin");
    $this->sys_action("gcc access_check.c -I ../lib/twiki_dav -g -o accesscheck -ltdb");
    $this->popd();
    $this->SUPER::target_test;
}

# Override the build target to build the twiki_dav C code
sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    $this->pushd($this->{basedir}."/lib/twiki_dav");
    if (! -f 'Makefile') {
        $this->sys_action("./configure");
    }
    $this->sys_action("make");
    $this->popd();
}

# Override the install target to install twiki_dav
sub target_install {
    my $this = shift;

    $this->SUPER::target_install();

    if (-w "/usr/lib/apache/libdav.so") {
        $this->pushdd($this->{basedir}."/lib/twiki_dav");
        $this->sys_action("make install");
        $this->popd();
    } else {
        warn "No privilege to make install";
    }
}

$build = new WebDAVPluginBuild();

$build->build($build->{target});
