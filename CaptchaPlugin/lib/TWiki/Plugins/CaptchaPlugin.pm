# Visual Confirmation Plugin for TWiki Collaboration 
# Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 Koen Martens, kmartens@sonologic.nl
# Copyright (C) 2007 KwangErn Liew, kwangern@musmo.com
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

# =========================
package TWiki::Plugins::CaptchaPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.5-pre4';
$RELEASE = 'Dakar';
$SHORTDESCRIPTION = 'To prevent automated bots from spamming';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'CaptchaPlugin';

# =========================


# TODO: in preferences
my $chars;

sub randomTxt(@) {
  my $chars=shift;
  my $len=shift;
  my $i;
  my $str="";

  for $i (0..$len-1) {
    $str.=substr($chars,rand()*(length($chars)),1);
  }
  return $str;
}

sub createImage(@) {
    my $filename=shift;
    my $txt=shift;
    my $width=220;
    my $height=60;

    # create a new image
	my $im = GD::Image->newTrueColor($width,$height);

	# we need background colour
	my $background;

	if ( $TWiki::cfg{Plugins}{CaptchaPlugin}{ColourSafe} ) {
		# ColourSafe please
		$background = $im->colorAllocate(0,0,0);
	} else {
		my $grey = int(rand(150));
		my @bgcolour;

		for my $i (0..2) {
			push ( @bgcolour, $grey );
			$i++;
		}

		$background = $im->colorAllocate( $bgcolour[0], $bgcolour[1], $bgcolour[2] );
	}

	$im->fill( 0, 0, $background ); 

	# random angles
	my @rndangle = ();
	
	for my $i (0..length($txt)-1) {
		$rndvalues = rand(-0.4+rand(0.4-(rand(-0.4))));
		push ( @rndangle, $rndvalues );
	}

    # add crazy text
    for my $i (0..length($txt)-1) {

		# we need some values
		my $fontcolours;
		my @fonts = glob( TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/fonts/*.ttf" );
		my $rndfont = rand @fonts;
		my $rndsize = int(rand(18))+14;
		my $x = (($width/(length($txt)+1))*$i)+(($width/(length($txt)))-10);
		my $y = $height/(rand(1.1)+1);

		# are we ColourSafe?
		if ( $TWiki::cfg{Plugins}{CaptchaPlugin}{ColourSafe} ) {
			# we only need light colours against the black
			my $shade = int(rand(155))+100;
			my @shadecolours;
			for my $i (0..2) {
				push ( @shadecolours, $shade );
				$i++;
			}

			$fontcolours = $im->colorAllocate( $shadecolours[0], $shadecolours[1], $shadecolours[2] );
		} else {
			$fontcolours = $im->colorAllocate(int(rand(255)), int(rand(255)), int(rand(255)));
		}

		# let's boogey
		$im->stringFT($fontcolours,$fonts[$rndfont],$rndsize,$rndangle[$i],$x,$y,substr($txt,$i,1));
    }

    # write out image file
    open(IMGFILE,">$filename");
    binmode IMGFILE;
    print IMGFILE $im->png;
    close(IMGFILE);
}

sub expire(@) {
  my $explicit=shift;
  $explicit='' unless($explicit);

  TWiki::Func::writeDebug("expire called with explicit '$explicit'") if $debug;

  my $dbpath=TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/_db/hashes";
  my $imgdir=TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/img/";

  my $expiry=$TWiki::cfg{Plugins}{CaptchaPlugin}{Expiry} || 3600;
  $expiry=int($expiry);
  my $now=time();

  open(LOCKFILE,">".$dbpath.".lock");

  dbmopen(%database, $dbpath, 0644);

  my @dbkeys=keys(%database);
  for my $key (@dbkeys) {
    TWiki::Func::writeDebug("checking $key") if $debug;
	my $value=$database{$key};
	my ($time,$txt)=split(",",$value);
	if( ($key eq $explicit) || ($now>=$time+$expiry) ) {
	  TWiki::Func::writeDebug(" expiring") if debug;
	  delete($database{$key});
	  my $tainted="$imgdir/$key.png";
	  $tainted=~/^(.*)$/;
	  my $untainted=$1;
	  TWiki::Func::writeDebug(" unlinking $untainted") if $debug;
	  unlink($untainted);
	}
  }
  dbmclose(%database);

  close(LOCKFILE);
}

sub storeHash(@) {
  my $filepath=shift;
  my $imgpath=shift;
  my $hash=shift;
  my $txt=shift;

  expire(undef);

  my $now=time();

  open(LOCKFILE,">".$filepath.".lock");
  flock(LOCKFILE,2);

  dbmopen(%database, $filepath, 0644);

  $database{$hash}="$now,$txt";

  dbmclose(%database);

  close(LOCKFILE);
}

# =========================
# twiki hooks

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" ) || 0;

    $initialised=0;
    
    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub commonTagsHandler
{
    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    if($_[0] =~ /%CAPTCHAURL%/) {
    TWiki::Func::writeDebug( "action" ) if $debug;
      eval {
        require Digest::MD5;
        require GD;

	# we check, but normally this happens once only anyway
	if($initialised==0) {

        my $numChars = $TWiki::cfg{Plugins}{CaptchaPlugin}{NumberOfCharacters};
        my $chars = $TWiki::cfg{Plugins}{CaptchaPlugin}{Characters};

        $txt=randomTxt($chars,$numChars);
        $hash=Digest::MD5->md5_hex($txt.time().rand());
        $imgfile="$hash.png";

        $imgpath=TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/img/".$imgfile;
        $imgdir=TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/img/";
        $dbpath=TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/_db/hashes";
        $imgurl=TWiki::Func::getPubUrlPath()."/TWiki/CaptchaPlugin/img/".$imgfile;

		$initialised=1;
	}

        createImage($imgpath,$txt);
     
        storeHash($dbpath,$imgdir,$hash,$txt); 

        $_[0] =~ s/%CAPTCHAURL%/$imgurl/g;
        $_[0] =~ s/%CAPTCHAHASH%/$hash/g;
      }
    }
    
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.
=cut

sub beforeSaveHandler {
	return unless($TWiki::cfg{Plugins}{CaptchaPlugin}{EnableSave});

	my $query = TWiki::Func::getCgiQuery();
	my $check_user = TWiki::Func::getWikiName();

    if ( $check_user eq "TWikiRegistrationAgent" ) { return }

    if ( $check_user eq $TWiki::cfg{DefaultUserWikiName} || $TWiki::cfg{Plugins}{CaptchaPlugin}{SaveForAll}) {

		my %database;
		my $vcHash = $query->param('Twk1CaptchaHash');
		my $vcTxt = $query->param('Twk1CaptchaString');

		open(LOCKFILE,">".TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/_db/hashes.lock");
		flock(LOCKFILE,2);

	    dbmopen(%database, TWiki::Func::getPubDir()."/TWiki/CaptchaPlugin/_db/hashes",0644);

	    my ($time,$txt) = split(',',$database{$vcHash});

			if ( not(lc($txt) eq lc($vcTxt)) || $txt eq '' ) {
				dbmclose(%database);
				close(LOCKFILE);
				throw TWiki::OopsException( 'captcha',
				                            web => $web,
				                            topic => $topic,
						                    def => 'invalid_vcstr',
							                params => [ "wrong" ] );
			}

		dbmclose(%database);
		close(LOCKFILE);

		if($TWiki::cfg{Plugins}{CaptchaPlugin}{DeleteAfterSave}) {
			expire($vcHash);
		}
	}
}

1;
