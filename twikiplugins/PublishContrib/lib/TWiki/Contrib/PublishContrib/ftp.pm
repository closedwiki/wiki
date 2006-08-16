# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# driver for writing html output to and ftp server, for hosting purposes
# adds sitemap.xml, google site verification file, and alias from index.html to WebHome.html (or other user specified default

use strict;

package TWiki::Contrib::PublishContrib::ftp;

use Error qw( :try );
use TWiki::Contrib::PublishContrib::file;

my $debug = 1;
@TWiki::Contrib::PublishContrib::ftp::ISA = qw( TWiki::Contrib::PublishContrib::file );

sub new {
    my( $class, $path, $web, $genopt, $baseUrl ) = @_;
    my $this = bless( $class->SUPER::new( $path, $web , $genopt, $baseUrl), $class );
    
    return $this;
}

sub addString {
    my( $this, $string, $file) = @_;
    filterHtml(\$string) if( $file =~ /\.html$/ );
    $this->SUPER::addString( $string, $file );
    push( @{$this->{files}}, "$this->{path}/$this->{web}/$file" );
    push( @{$this->{remotefiles}}, "$file" );

    if( $file =~ /(.*)\.html$/ ) {
        my $topic = $1;
        push( @{$this->{urls}}, "$file" );
      
        if ((defined($this->{params}->{defaultpage})) &&
            ($topic eq $this->{params}->{defaultpage})) {
            $this->addString( $string, 'default.htm' );
            $this->addString( $string, 'index.html' );
            print '(default.htm, index.html)';
        }
    }
      
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );
    push( @{$this->{files}}, "$this->{path}/$this->{web}/$to" );
    push( @{$this->{remotefiles}}, "$to" );
}

sub close {
    my $this = shift;

    #write sitemap.xml
    my $sitemap = $this->createSitemap( \@{$this->{urls}} );
    $this->addString($sitemap, 'sitemap.xml');
    print 'Published sitemap.xml<br />';
    #write google verification file
    if (defined($this->{params}->{googlefile})) {
        my $simplehtml = '<html><title>'.$this->{params}->{googlefile}.'</title><body>just for google</body></html>';
        $this->addString($simplehtml, $this->{params}->{googlefile});
        print 'Published googlefile : '.$this->{params}->{googlefile}.'<br />';
    }
    #write link from index.html to actual topic

    $this->SUPER::close();
    
    #use LWP to ftp to server (ftppublish)
    #TODO: clean up ftp site, removing/archiving/backing up old version    
    if ($this->{params}->{ftppublish} eq 'ftp') {
        die "destinationftpserver param not defined" unless (defined($this->{params}->{destinationftpserver}));
        die "destinationftppath param not defined" unless (defined($this->{params}->{destinationftppath}));
        die "destinationftpusername param not defined" unless (defined($this->{params}->{destinationftpusername}));
        die "destinationftppassword param not defined" unless (defined($this->{params}->{destinationftppassword}));
        
        #well, i'd love to use LWP, but it tells me "400 Library does not allow method POST for 'ftp:' URLs"

        require Net::FTP;
        my $ftp = Net::FTP->new($this->{params}->{destinationftpserver}, Debug => 0)
            or die "Cannot connect to $this->{params}->{destinationftpserver}: $@";

        $ftp->login($this->{params}->{destinationftpusername}, $this->{params}->{destinationftppassword})
            or die "Cannot login ", $ftp->message;
            
        $ftp->binary();

        $ftp->mkdir($this->{params}->{destinationftppath}, 1);
        $ftp->cwd($this->{params}->{destinationftppath})
            or die "Cannot change working directory ", $ftp->message;

        for my $remoteFilename (@{$this->{remotefiles}}) {
            my $localfilePath = "$this->{path}/$this->{web}/$remoteFilename";
            if ( $remoteFilename =~ /^(.*\/)([^\/]*)$/ ) {
                $ftp->mkdir($1, 1)
                        or die "Cannot create directory ", $ftp->message;
            }

            $ftp->put($localfilePath, $remoteFilename)
                or die "put failed ", $ftp->message;
            
            print "FTPed $remoteFilename to $this->{params}->{destinationftpserver} <br />";
        }

        $ftp->quit;
    }

    
}

#===============================================================================
sub filterHtml {
    my $string = shift;
    #this is dangerous as heck - it'll remove 'protected script and css' happily
    #$$string =~ s/<!--.*?-->//gs;     # remove all HTML comments
}

sub createSitemap {
    my $this = shift;
    my $filesRef = shift;    #( \@{$this->{files}} )
    my $map = << 'HERE';
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">
%URLS%
</urlset>
HERE

    my $topicTemplatePre = "<url>\n<loc>";
    my $topicTemplatePost = "</loc>\n</url>";

die "relativeurl param not defined" unless (defined($this->{params}->{relativeurl}));

    my $urls = join("\n", 
        map( {$topicTemplatePre.$this->{params}->{relativeurl}.'/'.$_.$topicTemplatePost."\n";}  @$filesRef ));
    
    $map =~ s/%URLS%/$urls/;

    return $map;
}

1;

