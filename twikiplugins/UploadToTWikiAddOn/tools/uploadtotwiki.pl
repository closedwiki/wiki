#!/usr/bin/perl -w
#
# Quick & dirty utility to attach a local file to a TWiki topic 
# via http.
#
# (Utility for TWiki Enterprise Collaboration Platform, http://TWiki.org/)
#
# Copyright (C) 2007 Peter Thoeny, peter@structuredwikis.com
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

my $toolName = 'uploadtotwiki/2007-02-11';

unless( $ARGV[2] ) {
    print "Usage:    ./uploadtotwiki.pl <TWiki login name> <file> <view url of twiki topic> <optional comment>\n";
    print "Example:  ./uploadtotwiki.pl MyWikiName ./smile.gif http://twiki.org/cgi-bin/view/Sandbox/UploadTest\n";
    exit 1;
}
my $user    = $ARGV[0];
my $file    = $ARGV[1];
my $url     = $ARGV[2];
my $comment = $ARGV[3];
exit uploadFile( $user, $file, $url, $comment );

# =========================
sub uploadFile
{
    my ( $theUser, $theFile, $theUrl, $theComment ) = @_;

    require LWP;
    if ( $@ ) {
        print STDERR "Error: LWP is not installed; cannot upload\n";
        return 0;
    }
    my $ua = UploadToTWiki::UserAgent->new();
    $ua->agent( $toolName );

    unless( -e $theFile ) {
        print STDERR "Error: File $theFile does not exist\n";
        return 0;
    }
    my $fileName = $theFile;
    $fileName =~ s|.*/||;

    my $uploadUrl = $theUrl;
    unless( $uploadUrl =~ /^https?:/ ) {
        print STDERR "Error: Only http and https protocols are supported\n";
        return 0;
    }
    unless( $uploadUrl =~ s|/view|/upload| ) {
        print STDERR "Error: This is not the URL of a TWiki topic\n";
        return 0;
    }
    $theComment = "Uploaded by $toolName" unless( $theComment );

    print "Uploading $theFile to $theUrl\n";

    push @{ $ua->requests_redirectable }, 'POST';
    my $response = $ua->post(
        $uploadUrl,
        [
            'filename' => $fileName,
            'filepath' => [ $theFile ],
            'filecomment' => $theComment
        ],
        'Content_Type' => 'form-data' );

    if ($response->is_success) {
        print "File upload finished.\n";
        return 1;
    } else {
        print STDERR "Error: " . $response->status_line . "\n";
        return 0;
    }
}

# =========================
{
    package UploadToTWiki::UserAgent;

    use base qw(LWP::UserAgent);

    sub new {
        my ($class, $id) = @_;
        my $this = $class->SUPER::new();
        $this->{domain} = $id;
        return $this;
    }

    sub get_basic_credentials {
        my($this, $realm, $uri) = @_;
        local $/ = "\n";
        print "Enter password for $user at " . $uri->host_port() . ": ";
        system('stty -echo');
        my $password = <STDIN>;
        system('stty echo');
        print "\n";
        chomp($password);
        return( $user, $password );
    }
}

# EOF
