#!/usr/bin/perl -w
#
# Build class for WebDAVPlugin
# Requires the environment variable TWIKI_SHARED to be
# set to point at the shared code repository

# Standard preamble
BEGIN {
  use File::Spec;
  my $cwd = `dirname $0`; chop($cwd);
  my $basedir = File::Spec->rel2abs("../../../..", $cwd);
  die "TWIKI_SHARED not set" unless ($ENV{TWIKI_SHARED});
  unshift @INC, "$ENV{TWIKI_SHARED}/lib";
  unshift @INC, $basedir;
  unshift @INC, $cwd;
}
use TWiki::Plugins::Build;

package WebDAVPluginBuild;

@WebDAVPluginBuild::ISA = ( "TWiki::Plugins::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "WebDAVPlugin" ), $class );
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
