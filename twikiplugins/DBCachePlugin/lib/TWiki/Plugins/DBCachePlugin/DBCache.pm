#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004 - All rights reserved
#
use strict;

use Benchmark;

use TWiki::Plugins::DBCachePlugin::Archive;
use TWiki::Plugins::DBCachePlugin::Array;
use TWiki::Plugins::DBCachePlugin::FileTime;
use TWiki::Plugins::DBCachePlugin::Map;
use TWiki::Plugins::DBCachePlugin::TableDef;

# General purpose cache that treats TWiki topics as hashes. Useful for
# rapid read and search of the database. Only works on one web.
{ package DBCachePlugin::DBCache;

  # A DB is a hash keyed on topic name

  @DBCachePlugin::DBCache::ISA = ("DBCachePlugin::Map");

  BEGIN {
    use vars qw( $storable $cacheMonitor );
    $storable = eval { require Storable; };
    $cacheMonitor = 0; # set 1 to get cache handling stats printed to stderr
  }

  # PUBLIC
  sub new {
    my ( $class, $dataDir, $web ) = @_;
    my $this = bless( $class->SUPER::new(), $class );

    $this->{_web} = $web;
    $this->{loaded} = 0;
	$this->{_cachefile} = "$dataDir/_DBCache" unless ($this->{_cachefile});

    return $this;
  }

  # PRIVATE write a new cache of the listed files.
  sub _writeCache {
    my ( $this, $cache ) = @_;

    if ( $storable ) {
      Storable::lock_store( $this, $cache );
    } else {
      my $archive = new DBCachePlugin::Archive( $cache, "w" );
      $archive->writeObject( $this );
      $archive->close();
    }
  }

  # PRIVATE load a single topic from the given data directory. This
  # could be replaced by TWiki::Func::readTopic -> {$meta, $text) but
  # this implementation is more efficient for just now.
  sub _loadTopic {
    my ( $this, $dataDir, $topic ) = @_;
    my $filename = "$dataDir/$topic.txt";
	my $fh;

    open( $fh, "<$filename" )
      or die "Failed to open $dataDir/$topic.txt";
    my $meta = new DBCachePlugin::Map();
    $meta->set( "topic", $topic );
    $meta->set( ".cache_time", new DBCachePlugin::FileTime( $filename ));
	
    my $line;
	my $text = "";
    while ( $line = <$fh> ) {
      if ( $line =~ m/%META:/o ) {
		if ( $line =~ m/%META:FORM{name=\"([^\"]*)\"}%/o ) {
		  $meta->set( "form", $1 );
		} elsif ( $line =~ m/%META:FIELD{(.*)}%/o ) {
		  my $fs = new TWiki::Attrs($1);
		  $meta->set( $fs->get("name"), $fs->get("value"));
		} elsif ( $line =~ m/%META:FILEATTACHMENT{(.*)}%/o ) {
		  my $att = new DBCachePlugin::Map($1);
		  my $atts = $meta->get( "attachments" );
		  if ( !defined( $atts )) {
			$atts = new DBCachePlugin::Array();
			$meta->set( "attachments", $atts );
		  }
		  $atts->add( $att );
		}
      } else {
		$text .= $this->readTopicLine( $topic, $line, $fh );
	  }
    }
    close( $fh );
    $meta->set( "text", $text );
    $this->set( $topic, $meta );
  }

  # Designed to be overridden by subclasses
  sub readTopicLine {
    #my ( $this, $topic, $line, $fh ) = @_;
  }

  sub _tick {
    my ( $time, $message ) = @_;
    my $timenow = new Benchmark;
    my $diff = Benchmark::timediff( $timenow, $time );
    print STDERR "$message ", Benchmark::timestr( $diff ), "\n";
    return $timenow;
  }

  # PROTECTED Designed to be overridden by subclasses. Called when
  # one or more topics had to be read from disc rather than from the
  # cache. Passed a list of topic names that have been read.
  sub onReload {
	#my ( $this, $@topics) = @_;
  }

  # PUBLIC load the web into the database on demand
  # Return pair representing number of topics loaded from file
  # and number of topics loaded from cache
  # Return value is used in testing.
  sub _load {
    my $this = shift;

    return "0 0 0" if ( $this->{loaded} );

    my $web = $this->{web};
    my @topics = TWiki::Func::getTopicList( $web );
    my $dataDir = TWiki::Func::getDataDir() . "/$web";
    my $cacheFile = $this->{_cachefile};

    my $time;
    $time = new Benchmark if ( $cacheMonitor );

    my $writeCache = 0;
    my $cache = $this->_readCache( $cacheFile );

    $time = _tick($time, "Cache load") if ( $cacheMonitor );

    my $readFromCache = 0;
    my $readFromFile = 0;
    my $removed = 0;

    if ( $cache ) {
      eval {
		( $readFromCache, $readFromFile, $removed ) =
		  $this->_updateCache( $cache, $dataDir, \@topics );
      };

      if ( $@ ) {
		TWiki::writeWarning("DBCachePlugin: Cache read failed: $@");
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
      $this->onReload( \@readTopic );
      $writeCache = 1;
    }

    $time = _tick($time, "Topic read") if ( $cacheMonitor );
    if ( $writeCache ) {
      $this->_writeCache( $cacheFile );
    }

    $this->{loaded} = 1;
    if ( $cacheMonitor ) {
      $time = _tick($time,
				"Cache $readFromCache File $readFromFile Remove $removed\n");
    }
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
      $topic = $cached->fastget( "topic" );
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

  sub write {
    my ( $this, $archive ) = @_;
    $archive->writeString( $this->{_web} );
    $this->SUPER::write( $archive );
  }

  sub read {
    my ( $this, $archive ) = @_;
    $this->{_web} = $archive->readString();
    $this->SUPER::read( $archive );
  }
}

1;
