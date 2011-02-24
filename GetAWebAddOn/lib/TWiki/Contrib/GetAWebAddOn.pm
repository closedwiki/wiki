# Add-on for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Will Norris
# Copyright (C) 2004-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
# NOTE: Please extend that file, not this notice.
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

package TWiki::Contrib::GetAWebAddOn;

use vars qw( $VERSION );
$VERSION = '$Rev$';

use Cwd qw( cwd );
use Archive::Tar;
use TWiki::Func;

sub getaweb
{
    my $session = shift;

    $TWiki::Plugins::SESSION = $session;

    my $query = $session->{request};
    my $webName  = $session->{webName};

    die unless $query;
    my $error = '';

    ($webName = $query->path_info()) =~ s|^/?(.*?)[\/\.](.*)\.(tar)$|$1|;
    my $saveasweb = $query->param('saveasweb' ) || $webName;

    my $dataDir;
    my $pubDir;
    my $templateDir;
    if (defined(%TWiki::cfg)) {
        $dataDir = $TWiki::cfg{DataDir};
        $pubDir = $TWiki::cfg{PubDir};
        $templateDir = $TWiki::cfg{TemplateDir};
    }
    #pre configure settings
    $dataDir = $TWiki::dataDir if (!defined($dataDir) && defined($TWiki::dataDir));
    $pubDir = $TWiki::pubDir if (!defined($pubDir) && defined($TWiki::pubDir));
    $templateDir = $TWiki::templateDir if (!defined($templateDir) && defined($TWiki::templateDir));

    $error .= qq{web "$webName" doesn't exist<br/>} unless TWiki::Func::webExists( $webName );
    $error .= qq{data dir "$dataDir" doesn't exist<br/>} unless -d $dataDir;
    $error .= qq{pub dir "$pubDir" doesn't exist<br/>} unless -d $pubDir;
    $error .= qq{template dir "$templateDir" doesn't exist<br/>} unless -d $templateDir;

    # TODO: use oops stuff
    if ( $error ) 
    {
    	print "Content-type: text/html\n\n";
	print $error;
	return;
    }
	
    # sets response header
    print CGI::header( -TYPE => 'application/x-tar',
                       -Content_Disposition => "filename=TWiki-$webName-web.tar",
                       -expire => 'now' );

    my $tar = Archive::Tar->new() or die $!;
    foreach my $dirEntry ( 
			   { dir => $dataDir, name => 'data' },
			   { dir => $pubDir, name => 'pub' },
			   { dir => $templateDir, name => 'templates' },
			   )
    {
	next unless -d "$dirEntry->{dir}/$webName";
	my $pushd = cwd();
	chdir "$dirEntry->{dir}/$webName" or die $!;

	# CODE SMELL: the archive will fail if no topics end up being exported
	my @files = grep { !/(\.htpasswd|\.htaccess|.*\.lock|~$)/ } <* */*>;		# HACK: make true recursive thingee
	foreach my $file ( @files )
	{
	    next if( -d $file || $file =~ /\.lease$/ );
	    local( $/, *FH ) ;
	    open( FH, $file ) or die $!;
	    my $contents = <FH>;
	    
	    $tar->add_data( "$dirEntry->{name}/$saveasweb/$file", $contents );	# or die ???
	}
	chdir $pushd;
    }

    my $io = IO::Handle->new() or die $!;
    $io->fdopen(fileno(STDOUT), "w") or die $!;
    $tar->write( $io ) or die $!;
    $io->close() or die $!;
}

1;
