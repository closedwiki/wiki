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
	my @ans = grep {! /$excludeFilePattern/ } @_;
	return @ans;
    };

    my $findCallback = sub {
	my $pathname = $File::Find::name; #  complete pathname to the file. 
	Common::debug "$pathname\n";
	my $relativePath = Common::relativeFromPathname($pathname, $distributionLocation);
	#CodeSmell: should be able to do this in preprocessCallback
	if (($relativePath =~ m!twiki/data/(.*)/!) or 
	    ($relativePath =~ m!twiki/pub/(.*)/!)) {
	    my $web = $1;
#	    print "Index web '$web'?" ;
	    if ($web =~ m/$Common::websToIndex/) {
#		print "yes\n";
	    } else {
#		print "no\n";
		return;
	    } 
	}
	return unless -f $pathname;
        return if -z $pathname;
	Common::debug "$pathname\n";
        indexFile($distribution, $distributionLocation, $pathname, $pathPrefix, $relativePath);
    };
    find({ wanted => $findCallback, preprocess => $preprocessCallback, follow => 0 }, $distributionLocation);  
}

sub indexFile {
    my ($distribution, $distributionLocation, $file, $pathPrefix, $relativePath) = @_;
    my $digest = digestForFile($file);
    Common::debug $relativePath." = ".$digest."\n";
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
