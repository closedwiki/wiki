#! /usr/bin/perl -w

use strict;
use FileHandle;
use FileDigest;
use Common;

package IndexDistributions;

sub indexDistribution {
    my ($distribution, $distributionLocation, $excludeFilePattern, $pathPrefix) = @_;
    use File::Find;
    unless (defined $pathPrefix) {$pathPrefix =""};

    my $preprocessCallback = sub {
	return grep {! /$excludeFilePattern/ } @_;
    };

    my $findCallback = sub {
	my $pathname = $File::Find::name; #  complete pathname to the file. 
	Common::debug "$pathname\n";
	return unless -f $pathname;
        return if -z $pathname;
	Common::debug "$pathname\n";
        indexFile($distribution, $distributionLocation, $pathname, $pathPrefix);
    };
    find({ wanted => $findCallback, preprocess => $preprocessCallback, follow => 0 }, $distributionLocation);  
}

sub indexFile {
    my ($distribution, $distributionLocation, $file, $pathPrefix) = @_;
    my $digest = digestForFile($file);
    my $relativePath = Common::relativeFromPathname($file, $distributionLocation);
    Common::debug $digest."\n";
    FileDigest::addOccurance($distribution, $pathPrefix.$relativePath, $digest);
}

sub digestForFile {
    my ($file) = @_;
    my $fh = new FileHandle $file, "r";
    unless (defined $fh) {
        return "$!"
    };
    unless (-s $fh) {
        return "EMPTY";
    }
    use Digest::MD5;
    my $ctx = Digest::MD5->new;
    $ctx->addfile($fh);
    return $ctx->hexdigest();
}

1;
