#!/usr/bin/perl -w
BEGIN {
  use File::Spec;
  my $cwd = `dirname $0`; chop($cwd);
  my $basedir = File::Spec->rel2abs("../../../..", $cwd);
  unshift @INC, $basedir;
  unshift @INC, $cwd;
}

use Build;

{ package WebDAVPluginBuild;

  @WebDAVPluginBuild::ISA = ( "Build" );

  sub new {
	my $class = shift;
	return bless( $class->SUPER::new( "WebDAVPlugin" ), $class );
  }

  # Override the build target to build the twiki_dav C code
  sub target_build {
	my $this = shift;
	$this->SUPER::target_build();

	$this->cd($this->{basedir}."/lib/twiki_dav");
	$this->sys_action("./configure");
	$this->sys_action("make");
	if (-w "/usr/lib/apache/libdav.so") {
	  $this->sys_action("make install");
	} else {
	  warn "No privilege to make install";
	}
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
}

$build = new WebDAVPluginBuild();

$build->build($build->{target});
