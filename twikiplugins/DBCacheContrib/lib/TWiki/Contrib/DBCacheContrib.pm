#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004 - All rights reserved
#
use strict;

use TWiki::Contrib::DBCacheContrib::Archive;
use TWiki::Contrib::DBCacheContrib::Array;
use TWiki::Contrib::DBCacheContrib::FileTime;
use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Attrs;

=begin text

---++ class DBCacheContrib

General purpose cache that treats TWiki topics as hashes. Useful for
rapid read and search of the database. Only works on one web.

Typical usage:
<verbatim>
  use TWiki::Contrib::DBCacheContrib;

  $db = new TWiki::Contrib::DBCacheContrib( $web ); # always done
  $db->load(); # may be always done, or only on demand when a tag is parsed that needs it

  # the DB is a hash of topics keyed on their name
  foreach my $topic ($db->getKeys()) {
     my $attachments = $db->get($topic)->get("attachments");
     # attachments is an array
     foreach my $val ($attachments->getValues()) {
       my $aname = $attachments->get("name");
       my $acomment = $attachments->get("comment");
       my $adate = $attachments->get("date");
       ...
     }
  }
</verbatim>
As topics are loaded, the readTopicLine method gives subclasses an opportunity to apply special processing to indivual lines, for example to extract special syntax such as %ACTION lines, or embedded tables in the text. See FormQueryPlugin for an example of this.

=cut

package TWiki::Contrib::DBCacheContrib;

# A DB is a hash keyed on topic name

@TWiki::Contrib::DBCacheContrib::ISA = ("TWiki::Contrib::DBCacheContrib::Map");

use vars qw( $initialised $storable $VERSION $RELEASE );

$initialised = 0; # Not initialised until the first new
# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$storable = 1;

=begin text

---+++ =new($dataDir, $web)=
   * =$dataDir= location of cache file
   * =$web= name of web to create the object for.
Construct a new DBCache object.

=cut

sub new {
    my ( $class, $web, $cacheName ) = @_;
    my $this = bless( $class->SUPER::new(), $class );
    $this->{_web} = $web;
    $this->{loaded} = 0;
	$this->{_cachename} = $cacheName || "_DBCache";

    eval 'use Storable';

    if ( $@ ) {
        print STDERR "WARNING: Cannot use Storable: $@";
        $storable = 0;
    }

    return $this;
}

# PRIVATE write a new cache of the listed files.
sub _writeCache {
    my ( $this, $cache ) = @_;
    my $mayBeArchive = 1;

    if ( $storable ) {
        eval {
            $mayBeArchive = 0 if (Storable::lock_store( $this, $cache ));
        };

        if ( $@ ) {
            print STDERR "Write of Storable $cache failed with $@\n";
            $mayBeArchive = 1;
        }
    }

    if ( $mayBeArchive ) {
        eval {
            my $archive = new TWiki::Contrib::DBCacheContrib::Archive( $cache, "w" );
            $archive->writeObject( $this );
            $archive->close();
        };
        if ( $@ ) {
            print STDERR "Write of Archive $cache failed with $@\n";
        }
    }
}

# PRIVATE read from cache file.
# May throw an exception.
sub _readCache {
	my ( $this, $cache ) = @_;
	my $data;

	return undef unless ( -e $cache );

    my $mayBeArchive = 1;

    if ( $storable ) {
        eval {
            $data = Storable::lock_retrieve( $cache );
        };
        if ( $@ ) {
            print STDERR "Retrieve of Storable $cache failed with $@\n";
        } elsif ( $data ) {
            $mayBeArchive = 0;
        }
	}

    if ( $mayBeArchive ) {
        eval {
            my $archive = new TWiki::Contrib::DBCacheContrib::Archive( $cache, "r" );
            $data = $archive->readObject();
            $archive->close();
        };
        if ( $@ ) {
            print STDERR "Retrieve of Archive $cache failed with $@\n";
            $data = undef;
        }
	}

	return $data;
}

# PRIVATE load a single topic from the given data directory. This
# ought to be replaced by TWiki::Func::readTopic -> {$meta, $text) but
# this implementation is more efficient for just now.
sub _loadTopic {
    my ( $this, $dataDir, $topic ) = @_;
    my $filename = "$dataDir/$topic.txt";
	my $fh;

    open( $fh, "<$filename" )
      or die "Failed to open $dataDir/$topic.txt";
    my $meta = new TWiki::Contrib::DBCacheContrib::Map();
    $meta->set( "name", $topic );
    $meta->set( "topic", $topic );
    $meta->set( ".cache_time", new TWiki::Contrib::DBCacheContrib::FileTime( $filename ));
	
    my $line;
	my $text = "";
	my $form;
    my $tailMeta = 0;
    local $/ = "\n";
    while ( $line = <$fh> ) {
        if ( $line =~ m/^%META:FORM{name=\"([^\"]*)\"}%/o ) {
            $form = new TWiki::Contrib::DBCacheContrib::Map() unless $form;
            my( $web, $name ) = TWiki::Func::normalizeWebTopicName('', $1);
            $form->set( "name", $name );
            $form->set( "_up", $meta );
            $meta->set( "form", $name );
            $meta->set( $name, $form );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICPARENT{name=\"([^\"]*)\"}%/o ) {
            $meta->set( "parent", $1 );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICINFO{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( "_up", $meta );
            $meta->set( "info", $att );
        } elsif ( $line =~ m/^%META:TOPICMOVED{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( "_up", $meta );
            $meta->set( "moved", $att );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FIELD{(.*)}%/o ) {
            my $fs = new TWiki::Attrs($1);
            $form = new TWiki::Contrib::DBCacheContrib::Map() unless $form;
            $form->set( $fs->get("name"), $fs->get("value"));
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FILEATTACHMENT{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( "_up", $meta );
            my $atts = $meta->get( "attachments" );
            if ( !defined( $atts )) {
                $atts = new TWiki::Contrib::DBCacheContrib::Array();
                $meta->set( "attachments", $atts );
            }
            $atts->add( $att );
            $tailMeta = 1;
        } else {
            $line = $this->readTopicLine( $topic, $meta, $line, $fh );
            $text .= $line if ( $line );
        }
    }
    close( $fh );
    $text =~ s/\n$//s if $tailMeta;
    $meta->set( "text", $text );
    $this->set( $topic, $meta );
}

=begin text

---+++ readTopicLine($topic, $meta, $line, $fh) --> text
   * $topic - name of the topic being read
   * $meta - reference to the hash object for this topic
   * line - the line being read
   * $fh - the file handle of the file
   * __return__ text to insert in place of _line_ in the text field of the topic
Called when reading a topic that is being cached, this method is invoked on each line
in the topic. It is designed to be overridden by subclasses; the default implementation
does nothing. The sort of expected activities will be (for example) reading tables and
adding them to the hash for the topic.

=cut

sub readTopicLine {
    #my ( $this, $topic, $meta, $line, $fh ) = @_;
    return $_[3];
}

=begin text

---+++ onReload($topics)
   * =$topics= - perl array of topic names that have just been loaded (or reloaded)
Designed to be overridden by subclasses. Called when one or more topics had to be
read from disc rather than from the cache. Passed a list of topic names that have been read.

=cut

sub onReload {
	#my ( $this, $@topics) = @_;
}

sub _onReload {
    my ( $this ) = @_;

    # Fill in parent relations
    foreach my $topic ( $this->getValues() ) {
        unless ( $topic->get( "_up" )) {
            my $parent = $topic->get( "parent" );
            $topic->set( "_up", $this->get( $parent ));
        }
    }

    onReload( @_ );
}

=begin text

---+++ load()

Load the web into the database.
Returns a string containing 3 numbers that give the number of topics
read from the cache, the number read from file, and the number of previously
cached topics that have been removed.

=cut

sub load {
    my $this = shift;

    return "0 0 0" if ( $this->{loaded} );

    my $web = $this->{_web};
    my @topics = TWiki::Func::getTopicList( $web );
    my $dataDir = TWiki::Func::getDataDir() . "/$web";
    my $cacheFile = $dataDir . "/" . $this->{_cachename};

    my $time;

    my $writeCache = 0;
    my $cache = $this->_readCache( $cacheFile );

    my $readFromCache = 0;
    my $readFromFile = 0;
    my $removed = 0;

    if ( $cache ) {
        eval {
            ( $readFromCache, $readFromFile, $removed ) =
              $this->_updateCache( $cache, $dataDir, \@topics );
        };

        if ( $@ ) {
            TWiki::Func::writeWarning("DBCache: Cache read failed: $@");
            $cache = undef;
        }

        if ( $readFromFile || $removed ) {
            $writeCache = 1;
        }
    }

    if ( !$cache ) {
        my @readTopic;
        foreach my $topic ( @topics ) {
            $this->_loadTopic( $dataDir, $topic );
            $readFromFile++;
            push( @readTopic, $topic );
        }
        $this->_onReload( \@readTopic );
        $writeCache = 1;
    }

    if ( $writeCache ) {
        $this->_writeCache( $cacheFile );
    }

    $this->{loaded} = 1;

    return "$readFromCache $readFromFile $removed";
}

# PRIVATE update the cache from files
# return the number of files changed in a tuple
sub _updateCache {
    my ( $this, $cache, $dataDir, $topics ) = @_;

    my $topic;
    my %tophash;

    foreach $topic ( @$topics ) {
        $tophash{$topic} = 1;
    }

    my $removed = 0;
    my @remove;
    my $readFromCache = $cache->size();
    foreach my $cached ( $cache->getValues()) {
        $topic = $cached->fastget( "name" );
        if ( !$tophash{$topic} ) {
            # in the cache but are missing from @topics
            push( @remove, $topic );
            $removed++;
        } elsif ( !$cached->fastget( ".cache_time" )->uptodate() ) {
            push( @remove, $topic );
        }
    }

    # remove bad topics
    foreach $topic ( @remove ) {
        $cache->remove( $topic );
        $readFromCache--;
    }

    my $readFromFile = 0;
	my @readTopic;

    # load topics that are missing from the cache
    foreach $topic ( @$topics ) {
        if ( !defined( $cache->fastget( $topic ))) {
            $cache->_loadTopic( $dataDir, $topic );
            $readFromFile++;
            push( @readTopic, $topic );
        }
    }
    $this->{keys} = $cache->{keys};

    if ( $readFromFile || $removed ) {
        # refresh relations
        $this->onReload( \@readTopic );
    }

    return ( $readFromCache, $readFromFile, $removed );
}

=begin text

---+++ write($archive)
   * =$archive= - the TWiki::Contrib::DBCacheContrib::Archive being written to
Writes this object to the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

sub write {
    my ( $this, $archive ) = @_;
    $archive->writeString( $this->{_web} );
    $this->SUPER::write( $archive );
}

=begin text

---+++ read($archive)
   * =$archive= - the TWiki::Contrib::DBCacheContrib::Archive being read from
Reads this object from the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

sub read {
    my ( $this, $archive ) = @_;
    $this->{_web} = $archive->readString();
    $this->SUPER::read( $archive );
}

1;
