# Install script for BatchUploadPlugin
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# NOTE TO THE DEVELOPER: THIS FILE IS GENERATED AUTOMATICALLY
# BY THE BUILD PROCESS DO NOT EDIT IT - IT WILL BE OVERWRITTEN
#
use strict;
use Socket;

my $noconfirm = 0;

BEGIN {
	 unless ( -d "lib" &&
				 -d "bin" &&
				 -e "lib/TWiki.pm" ) {
		  die "This installer must be run from the root directory of a TWiki installation";
	 }
	 # Add the TWiki lib dir to the include path to get Algorithm::Diff
	 unshift @INC, "lib";
	 eval 'use TWiki::Plugins;';
}

# Satisfy dependencies on modules, by checking:
# 1. If the module is a perl module, then:
#	 1. If the module is loadable in the current environment
#	 2. If the dependency has specified a version constraint, then
#		 the module must have a top-level variable VERSION which satisfies
#		 the constraint.
#		 Note that all TWiki modules are perl modules - even non-perl
#		 distributions have a perl "stub" module that carries the version info.
# 2. If the module is _not_ perl, then we can't check it.
sub satisfy {
	 my $dep = shift;
	 my $msg = "";
	 my $ok = 1;
	 my $result = 1;
	 my $trig = eval $dep->{trigger};

	 return 1 unless ( $trig );

	 print "##########################################################\n";
	 print "Checking dependency on $dep->{name}....\n";
	 if( $dep->{type} eq "perl" ) {
		  # Try to 'use' the perl module
		  eval "use $dep->{name}";
		  if( $@ ) {
				$msg = $@;
				$msg =~ s/ in .*$/\n/s;
				$ok = 0;
		  } else {
				# OK, it was loaded. See if a version constraint is specified
				if( defined( $dep->{version} ) ) {
					 my $ver;
					 # check the $VERSION variable in the loaded module
					 eval "\$ver = \$$dep->{name}::VERSION;";
					 if( $@ ) {
						  $msg .= "The VERSION of the package could not be found: $@";
						  $ok = 0;
					 } else {
						  # The version variable exists
						  eval "\$ok = ( \$ver $dep->{version} )";
						  if( $@ || ! $ok ) {
								# The version variable fails the constraint
								$msg .= " $ver is currently installed: $@";
								$ok = 0;
						  }
					 }
				}
		  }
	 } else {
		  # This module has no perl interface, and can't be checked
		  $ok = 0;
		  $msg = "Module is type $dep->{type}, and cannot be automatically checked.\nPlease check it manually and install if necessary.\n";
	 }

	 unless ( $ok ) {
		  print "*** BatchUploadPlugin depends on package $dep->{name} $dep->{version},\n";
		  print "which is described as \"$dep->{description}\"\n";
		  print "But when I tried to find it I got this error:\n\n$msg\n";
		  $result = 0;
	 }

	 if( !$ok && $dep->{name} =~ m/^TWiki::(Contrib|Plugins)::(\w*)/ ) {
		  my $pack = $1;
		  my $packname = $2;
		  my $reply = "y";
		  $packname .= $pack if( $pack eq "Contrib" && $packname !~ /Contrib$/);
		  unless ( $noconfirm ) {
				print "Would you like me to try to download and install the latest version of $packname from twiki.org? [y/n] ";
				while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
					 print "Please answer yes or no\n";
				}
		  }
		  if( $reply =~ /^y/i ) {
				$result = download( $packname );
		  }
	 }

	 return $result;
}

# Try and download a zip
sub getzip {
	 my ( $pack, $zip ) = @_;

	 if ( -e $zip ) {
		  my $ans = "y";

		  unless ( $noconfirm ) {
				print "An existing $zip exists; would you like me to use it? [y/n]\n";
				while (( $ans = <STDIN> ) !~ /^[yn]/i ) {
					 print "Please answer yes or no\n";
				}
		  }

		  return 1 if ( $ans =~ /^y/i );

		  unless ( unlink( $zip )) {
				print STDERR "Could not remove old $zip\n";
				return 0;
		  }
	 }

	 print "Waiting for twiki.org.....\n";
	 my $step = "socket";
	 if ( socket( SOCK, PF_INET, SOCK_STREAM, getprotobyname( 'tcp' ))) {
		  my $paddr = sockaddr_in( 80, inet_aton( "twiki.org" ));
		  $step = "connect";
		  if ( connect( SOCK, $paddr )) {
				select( SOCK );
				$| = 1;
				print SOCK "GET /p/pub/Plugins/$pack/$zip HTTP/1.0\r\nHost: twiki.org\r\n\r\n";
				my $sep = $/;
				undef $/;
				my $result = <SOCK>;
				$/ = $sep;
				$step = "close";
				if ( close( SOCK )) {
					 select( STDOUT );
					 if ( $result =~ /^HTTP\/1.1 200 OK/ ) {
						  $step = "open";
						  if ( open( ZF, ">$zip" )) {
								$result =~ s/^.*?Content-Type: application\/zip\s*//s;
								print ZF $result;
								close( ZF );
								return 1;
						  }
					 } else {
						  print $result;
					 }
				}
		  }
	 }
	 print STDERR "Could not download $zip: $step $!";
	 return 0;
}

# Download the zip file for the given package from twiki.org.
sub download {
	 my $packname = shift;
	 my $zip = "$packname.zip";

	 return 0 unless getzip( $packname, $zip );

	 eval 'use Archive::Zip';
	 unless ( $@ ) {
		  my $zip = new Archive::Zip( $zip );
		  unless ( $zip ) {
				print STDERR "Could not open downloaded file $zip\n";
				return 0;
		  }

		  my @members = $zip->members();
		  foreach my $file ( @members ) {
				my $err = $zip->extractMember( $file );
				my $fn = $file->fileName();
				if ( $err ) {
					 print STDERR "Failed to extract $fn from zip file $zip. Archive may be corrupt.\n";
					 return 0;
				} else {
					 print "\t$fn\n";
				}
		  }
	 } else {
		  print STDERR "Archive::Zip is not installed; trying unzip\n";
		  print `unzip $zip`;
		  if ( $! ) {
				print STDERR "Unzip failed: $!\n";
				return 0;
		  }
	 }

	 if( -e "${packname}_installer.pl" ) {
		  print `perl ${packname}_installer.pl install`;
		  if ( $? ) {
				print STDERR "Installation of $packname failed\n";
				return 0;
		  }
	 }

	 # Tidy up
	 unlink( $zip );
	 return 1;
}

# Do your best to check in, despite the fact that the apache user
# has everything checked out :-(
sub checkin {
	 my $file = shift;

	 print STDERR "I can't automatically update the revision history for\n";
	 print STDERR "$file.\nPlease ";
	 if ( $file =~ /^data/ ) {
		  print STDERR "edit the topic in TWiki and Save without changing it";
	 } elsif( $file =~ /^pub/ ) {
		  print STDERR "upload the file in TWiki";
	 }
	 print STDERR " to update the history.\n";
}

# Print a useful message
sub usage {
	 print STDERR "Usage:\tBatchUploadPlugin_installer [-a] install\n";
	 print STDERR "\tBatchUploadPlugin_installer uninstall\n";
	 print STDERR "Install or uninstall BatchUploadPlugin. Default is to install. Should be run\n";
	 print STDERR "from the top level of your TWiki installation.\n";
	 print STDERR "Options:\n";
	 print STDERR "\t-a Don't prompt for confirmations\n";
}

unshift( @INC, "lib" );

print "\n### BatchUploadPlugin Installer ###\n\n";
my $n = 0;
my $install = 1;
while ( $n < scalar( @ARGV ) ) {
	 if( $ARGV[$n] eq "-a" ) {
		  $noconfirm = 1;
	 } elsif( $ARGV[$n] eq "install" ) {
		  $install = 1;
	 } elsif( $ARGV[$n] eq "uninstall" ) {
		  $install = 0;
	 } else {
		  usage( );
		  die "Bad parameter $ARGV[$n]";
	 }
	 $n++;
}

print "This installer must be run from the root directory of your TWiki\n";
print "installation.\n";
if( $install && !$noconfirm ) {
	 print "\t* The script will not do anything without asking you for\n";
	 print "\t  confirmation first.\n";
}
print "\t* You can abort the script at any point and re-run it later\n";
print "\t* If you answer 'no' to any questions you can always re-run\n";
print "\t  the script again later\n";

my @manifest = ( 	"./data/TWiki/BatchUploadPlugin.txt", # 
	"./lib/TWiki/Plugins/BatchUploadPlugin/build.pl", # 
	"./lib/TWiki/Plugins/BatchUploadPlugin.pm", # 
	"BatchUploadPlugin_installer.pl", # Install script
 );

if( $install ) {
	 # No PREINSTALL script;
	 unless ( $noconfirm ) {
		  print "Hit <Enter> to proceed with installation\n";
			 <STDIN>;
	 }
	 my $unsatisfied = 0;
	 foreach my $dep ( (  ) ) {
		  unless ( satisfy( $dep ) ) {
				$unsatisfied++;
		  }
	 }

	 # For each file in the MANIFEST, check to see if it is targeted
	 # at pub or data. If it is, then add a call to "checkin" for the
	 # file.
	 my @checkin;
	 foreach my $file ( @manifest ) {
		  if( $file =~ /^data\/\w+\/\w+.txt$/ ) {
				checkin( $file );
		  } elsif( $file =~ /^pub\/\w+\/\w+\/[^\/]+$/ ) {
				checkin( $file );
		  }
	 }

	 print "\n### BatchUploadPlugin installed";
	 print " with $unsatisfied unsatisfied dependencies" if ( $unsatisfied );
	 print " ###\n";
	 # No POSTINSTALL script;
} else {
	 my $file;
	 my @dead;
	 foreach $file ( @manifest ) {
		  if( -e $file ) {
				push( @dead, $file );
		  }
	 }
	 unless ( $#dead > 1 ) {
		  die "No part of BatchUploadPlugin is installed";
	 }
	 print "To uninstall BatchUploadPlugin, the following files will be deleted:\n";
	 print join( ", ", @dead );
	 my $reply;
	 print "\nAre you SURE you want to uninstall BatchUploadPlugin? [y/n] ";
	 while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
		  print "Please answer yes or no\n";
	 }
	 if( $reply =~ /^y/i ) {
		  # No PREUNINSTALL script;
		  foreach $file ( @manifest ) {
				if( -e $file ) {
					 unlink( $file );
				}
		  }
		  # No POSTUNINSTALL script;
	 }
	 print "### BatchUploadPlugin uninstalled ###\n";
}
<!-- Do _not_ attempt to edit this topic; it is auto-generated. Please add comments/questions/remarks to the Dev topic instead. -->
