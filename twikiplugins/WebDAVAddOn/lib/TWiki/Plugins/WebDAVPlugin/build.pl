#!/usr/bin/perl -w
#
# Build class for WebDAVPlugin
# Requires the environment variable TWIKI_LIBS to be
# set to point at the AttrsContrib code repository root

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
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
  $this->cd("$this->{basedir}/$this->{libdir}/WebDAVPlugin/test");
  $this->sys_action("gcc access_check.c -I ../../../../twiki_dav -g -o accesscheck -ltdb");
  $this->SUPER::target_test;
}

# Override the build target to build the twiki_dav C code
sub target_build {
  my $this = shift;

  $this->SUPER::target_build();

  $this->cd($this->{basedir}."/lib/twiki_dav");
  if (! -f 'Makefile') {
	$this->sys_action("./configure");
  }
  $this->sys_action("make");
}

# Override the install target to install twiki_dav
sub target_install {
  my $this = shift;

  $this->SUPER::target_install();

  if (-w "/usr/lib/apache/libdav.so") {
	$this->cd($this->{basedir}."/lib/twiki_dav");
	$this->sys_action("make install");
  } else {
	warn "No privilege to make install";
  }
}

$build = new WebDAVPluginBuild();

$build->build($build->{target});
