#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use Time::ParseDate;
use Benchmark;

use TWiki::Plugins::FormQueryPlugin::Archive;
use TWiki::Plugins::FormQueryPlugin::Array;
use TWiki::Plugins::FormQueryPlugin::ColourMap;
use TWiki::Plugins::FormQueryPlugin::FileTime;
use TWiki::Plugins::FormQueryPlugin::Map;
use TWiki::Plugins::FormQueryPlugin::Relation;
use TWiki::Plugins::FormQueryPlugin::Search;
use TWiki::Plugins::FormQueryPlugin::TableDef;
use TWiki::Plugins::FormQueryPlugin::TableFormat;

# A Map keyed on the topic.
{ package FormQueryPlugin::WebDB;

  # A DB is a hash keyed on topic name

  @FormQueryPlugin::WebDB::ISA = ("FormQueryPlugin::Map");

  BEGIN {
    use vars qw( $storable $cacheMonitor );
    $storable = eval { require Storable; };
    $cacheMonitor = 0; # set 1 to get cache handling stats printed to stderr
  }

  my %prefs;
  my @relations;
  my %tables;
  my $tablenames;
  my $colourmap;
  my $tableRE;

  # PUBLIC
  sub new {
    my ( $class, $web ) = @_;
    my $this = bless( $class->SUPER::new(), $class );

    $this->{web} = undef;
    $this->{loaded} = 0;
    # Note: queries are not cached. If performance really stinks
    # we could, I suppose.
    $this->{queries} = undef;
    $this->{topiccreator} = 0;
    $this->init( $web ) if ( defined( $web ));

    return $this;
  }

  # PUBLIC late initialisation of this object, used when serialising
  # from a file where the web is not known at the time the object
  # is created.
  sub init {
    my ( $this, $web ) = @_;

    $this->{web} = $web;

    my $rtext = TWiki::Func::getPreferencesValue( "FQRELATIONS" ) ||
      "ReQ%Ax%B SubReq ReQ%A; TiT%An%B TestItem ReQ%A";
    $tablenames = TWiki::Func::getPreferencesValue( "FQTABLES" ) ||
      "TaskTable";
    my $hmap = TWiki::Func::getPreferencesValue( "FQHIGHLIGHTMAP" ) ||
						 "HighlightMap";
    foreach my $relation ( split( /;/, $rtext )) {
      push( @relations, new FormQueryPlugin::Relation( $relation ));
    }
 
    foreach my $table ( split( /\s*,\s*/, $tablenames )) {
      if ( !(TWiki::Func::topicExists( $web, $table ))) {
	TWiki::Func::writeWarning( "No such table template topic '$table'" );
      } else {
	my $text = TWiki::Func::readTopicText( $web, $table );
	my $ttype = new FormQueryPlugin::TableDef( $text );
	if ( defined( $ttype )) {
	  $tables{$table} = $ttype;
	} else {
	  TWiki::Func::writeWarning( "Error in table template topic '$table'" );
	}
      }
    }
    $tableRE = $tablenames;
    $tableRE =~ s/\s*,\s*/\|/go;

    if ( defined( $hmap )) {
      if ( !(TWiki::Func::topicExists( $web, $hmap ))) {
	TWiki::Func::writeWarning( "No such highlight map topic '$hmap'" );
      } else {
	my $text = TWiki::Func::readTopicText( $web, $hmap );
	$colourmap = new FormQueryPlugin::ColourMap( $text );
      }
    }
  }

  # PRIVATE write a new cache of the listed files.
  sub _writeCache {
    my ( $this, $cache ) = @_;

    if ( $storable ) {
      Storable::lock_store( $this, $cache );
    } else {
      my $archive = new FormQueryPlugin::Archive( $cache, "w" );
      $archive->writeObject( $this );
      $archive->close();
    }
  }

  # PRIVATE compare the file times in the files list (files
  # in $dir) to the cache.
  #
  sub _readCache {
    my ( $this, $cache ) = @_;

    return undef unless ( -r $cache );

    # read the cache, aborting with an exception on error
    my $cached;
    my $archive;
    if ( $storable ) {
      eval { $cached = Storable::lock_retrieve( $cache ) };
    } else {
      $archive = new FormQueryPlugin::Archive( $cache, "r" );
      eval { $cached = $archive->readObject(); };
    }

    # trap a die
    if ( $@ ) {
      # trap; all files inconsistent, nothing loaded
      $archive->close() unless ( $storable );
      return undef;
    }

    $archive->close() unless ( $storable );

    if ( ref( $cached ) ne "FormQueryPlugin::WebDB" ) {
      return undef;
    }

    return $cached;
  }

  sub _loadTopic {
    my ( $this, $dataDir, $topic ) = @_;
    my $filename = "$dataDir/$topic.txt";
    open( FH, "<$filename" )
      or die "Failed to open $dataDir/$topic.txt";
    my $meta = new FormQueryPlugin::Map();
    $meta->set( "topic", $topic );
    $meta->set( ".cache_time", new FormQueryPlugin::FileTime( $filename ));

    my $line;
    while ( $line = <FH> ) {
      while ( $line =~ s/%EDITTABLE{\s*include=\"($tableRE)\"\s*}%//o ) {
	my $tablename = $1;
	my $ttype = $tables{$tablename};
	if ( defined( $ttype )) {
	  my $table = new FormQueryPlugin::Array();
	  my $lc = 0;
	  my $row = "";
	  while ( $line = <FH> ) {
	    if ( $line =~ s/\\\s*$//o ) {
	      # This row is continued on the next line
	      $row .= $line;
	    } elsif ( $line =~ m/\|\s*$/o ) {
	      # This line terminates a row
	      $row .= $line;
	      if ( $lc == 0 ) {
		# It's the header, ignore it
	      } else {
		# Load the row
		my $rowmeta =
		  $ttype->loadRow( $row, "FormQueryPlugin::Map" );
		$rowmeta->set( "topic", $topic );
		$rowmeta->set( "${tablename}_of", $meta ); 
		$table->add( $rowmeta );
	      }
	      $row = "";
	      $lc++;
	    } elsif ( $line !~ m/^\s*\|/o ) {
	      # This is not a valid row start, so must be the
	      # end of the table
	      last;
	    }
	  }
	  $meta->set( $tablename, $table );
	}
	# Fall through to allow further processing on $line
      }
      if ( $line =~ m/%META:/o ) {
	if ( $line =~ m/%META:FORM{name=\"([^\"]*)\"}%/o ) {
	  $meta->set( "form", $1 );
	} elsif ( $line =~ m/%META:FIELD{(.*)}%/o ) {
	  $line =~ m/name=\"(.*?)\"/o;
	  my $name = $1;
	  $line =~ m/value=\"(.*?)\"/o;
	  my $value = $1;
	  $meta->set( $name, $value );
	}
      }
    }
    close( FH );
    $this->set( $topic, $meta );
  }

  sub _tick {
    my ( $time, $message ) = @_;
    my $timenow = new Benchmark;
    my $diff = Benchmark::timediff( $timenow, $time );
    print STDERR "$message ", Benchmark::timestr( $diff ), "\n";
    return $timenow;
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
    my $cacheFile = "$dataDir/_FormQueryCache";

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
	TWiki::writeWarning("Cache read failed: $@");
	$cache = undef;
      }

      if ( $readFromFile || $removed ) {
	$writeCache = 1;
      }
    }

    if ( !$cache ) {
      foreach my $topic ( @topics ) {
	$this->_loadTopic( $dataDir, $topic );
	$readFromFile++;
      }
      $this->_extractRelations();
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
      $cache->_removeTopic( $topic );
      $readFromCache--;
    }
    
    my $readFromFile = 0;
    # load topics that are missing from the cache
    foreach $topic ( @$topics ) {
      if ( !defined( $cache->fastget( $topic ))) {
	$cache->_loadTopic( $dataDir, $topic );
	$readFromFile++;
      }
    }
    $this->{keys} = $cache->{keys};
    
    if ( $readFromFile || $removed ) {
      # refresh relations
      $this->_extractRelations();
    }

    return ( $readFromCache, $readFromFile, $removed );
  }

  # PRIVATE Remove a topic from the db, unlinking all the relations
  sub _removeTopic {
    my ( $this, $topic ) = @_;
    my $meta = $this->remove( $topic );
    foreach my $relation ( @relations ) {
      my $rname = $relation->{relation};
      my $f = $meta->fastget( $relation->childToParent() );
      if ( defined( $f )) {
	# remove back-pointers to this from parent
	my $bp = $f->fastget( $relation->parentToChild() );
	my $i = $bp->find( $meta );
	$bp->remove( $i ) if ( $i >= 0 );
      }
      my $rlist = $meta->fastget( $relation->parentToChild() );
      if ( defined( $rlist ) && $rlist->size() > 0 ) {
	foreach my $child ( $rlist->getValues() ) {
	  $child->set( $relation->childToParent(), undef );
	}
      }
    }
  }

  # PRIVATE extract childof relationships. This is done by applying
  # the relation to each topic to see if another topic exists that has
  # the requested relation to it.
  sub _extractRelations {
    my $this = shift;

    foreach my $relation ( @relations ) {
      foreach my $topic ( $this->getKeys() ) {
	my $parent = $relation->apply( $topic );
	if ( defined( $parent ) ) {
	  my $parentMeta = $this->fastget( $parent );
	  if ( defined( $parentMeta )) {
	    my $childMeta = $this->fastget( $topic );
	    $childMeta->set( $relation->childToParent(), $parentMeta );
	    my $known = $parentMeta->fastget( $relation->parentToChild() );
	    if ( !defined( $known )) {
	      $known = new FormQueryPlugin::Array();
	      $parentMeta->set( $relation->parentToChild(), $known );
	    }
	    if ( !$known->contains( $childMeta )) {
	      $known->add( $childMeta );
	    }
	  }
	}
      }
    }
  }

  # PUBLIC debug print
  sub toString {
    my $this = shift;
    my $text = "WebDB for web " . $this->{web};

    $text .= $this->SUPER::toString();

    return $text;
  }

  # PUBLIC STATIC generate error message unless moan is off
  sub moan {
    my ( $macro, $params, $message, $nomess ) = @_;

    return $nomess if ( $params =~ m/moan=\"?off\"?/o );

    return " <font color=red> $message in $macro\{$params\} </font> ";
  }

  # PUBLIC
  # Run a query on the DB.
  # It may optionally have the following field:
  # form   Name f the form type to run the query on
  # It must has the field
  # search Boolean expression for the query
  sub formQuery {
    my ( $this, $macro, $params ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    my $name = $attrs->fastget( "name" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'name' not defined", "" );
    }

    my $search;
    eval {
      $search = new FormQueryPlugin::Search( $attrs->fastget( "search" ));
    };
    if ( !defined( $search )) {
      return moan( $macro, $params,
		    "'search' not defined, or invalid search expression", "" );
    }

    # Make sure the DB is loaded
    $this->_load();

    my $queryname = $attrs->fastget( "query" );
    my $query;
    if ( defined( $queryname )) {
      $query = $this->{queries}{$queryname};
    } else {
      $queryname = "ROOT";
      $query = $this;
    }

    if ( !defined( $query )) {
      return moan( $macro, $params, "Query '$queryname' not defined", "" );
    }

    if ( $query->size() == 0 ) {
      return moan( $macro, $params, "Query '$queryname' returned no values", "" );
    }

    delete( $this->{queries}{$name} );

    my $matches = $query->search( $search );

    my $extract = $attrs->fastget( "extract" );
    if ( defined( $extract ) && $matches->size() > 0) {
      # Extract a defined subfield and make the query result an
      # array of the subfield. If the subfield is an array, flatten out
      # the array.
      my $realMatches = new FormQueryPlugin::Array();
      foreach my $match ( $matches->getValues() ) {
	my $subfield = $match->get( $extract );
	if ( defined( $subfield )) {
	  if ( $subfield->isa( "FormQueryPlugin::Array" )) {
	    foreach my $entry ( $subfield->getValues() ) {
	      $realMatches->add( $entry );
	    }
	  } else {
	    $realMatches->add( $subfield );
	  }
	}
      }
      $matches = $realMatches;
    }

    if ( !defined( $matches ) || $matches->size() == 0 ) {
      return moan( $macro, $params, "No values returned", "" );
    }
    $this->{queries}{$name} = $matches;

    return "";
  }

  # PUBLIC
  sub tableFormat {
    my ( $this, $macro, $params ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    my $name = $attrs->fastget( "name" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'name' not defined", "" );
    }

    my $format = $attrs->fastget( "format" );
    if ( !defined( $format )) {
      return moan( $macro, $params, "'format' not defined", "" );
    }

    my $fmt = new FormQueryPlugin::TableFormat( $attrs, $colourmap );

    $fmt->addToCache( $name );

    return "";
  }

  # PUBLIC show a previously defined query
  # sort   Comma-separated list of fields to sort on
  # format format of the fields in the table. The format is a text
  #        string which is expanded by replacing occurrences of
  #        $<fieldname>. The special <fieldname> "topic" is supported
  #        to insert the topic name.
  # header header of the table
  # sort   Comma-separated list of fields to sort on
  sub showQuery {
    my ( $this, $macro, $params ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    my $name = $attrs->fastget( "query" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'query' not defined", "" );
    }

    my $format = $attrs->fastget( "format" );
    if ( !defined( $format )) {
      return moan( $macro, $params, "'format' not defined", "" );
    }
    $format = new FormQueryPlugin::TableFormat( $attrs, $colourmap );

    if ( !defined( $format )) {
      return moan( $macro, $params, "Table format not defined", "" );
    }

    my $matches = $this->{queries}{$name};
    if ( !defined( $matches ) || $matches->size() == 0 ) {
      return moan( $macro, $params, "Query '$name' returned no values", "" );
    }

    return $format->formatTable( $matches, $colourmap );
  }

  # PUBLIC return the sum of all occurrences of a numeric
  # field in a query
  sub sumQuery {
    my ( $this, $macro, $params ) = @_;
    my $attrs = new FormQueryPlugin::Map( $params );

    my $name = $attrs->fastget( "query" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'query' not defined", 0 );
    }

    my $field = $attrs->fastget( "field" );
    if ( !defined( $field )) {
      return moan( $macro, $params, "'field' not defined", 0 );
    }

    my $matches = $this->{queries}{$name};
    if ( !defined( $matches ) || $matches->size() == 0 ) {
      return moan( $macro, $params, "Query '$name' returned no values", 0 );
    }

    return $matches->sum( $field );
  }

  # PUBLIC generate HTML to generate a new topic according to the rules
  # given in the relation
  sub createNewTopic {
    my ( $this, $macro, $params, $web, $topic ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    my $relation = $attrs->fastget( "relation" );
    if ( !defined( $relation )) {
      return moan( $macro, $params, "'relation' not defined", "" );
    }

    my $base = $attrs->fastget( "base" );
    $base = $topic unless ( defined( $base ));

    # Optional
    my $text = $attrs->fastget( "text" ) || "";
    # Optional
    my $formtype = $attrs->fastget( "form" );
    # Optional
    my $template = $attrs->fastget( "template" );

    my $tc = $this->{topiccreator}++;
    my $child;

    my $form = "<form name=\"topiccreator$tc\" ";
    $form .= "action=\"%SCRIPTURL%/autocreate/$web/$base\">";
    $form .= "<input type=\"submit\" value=\"$text\" />";
    $form .= "<input type=\"hidden\" name=\"relation\" value=\"$relation\" />";
    if ( defined( $formtype )) {
      $form .= "<input type=\"hidden\" name=\"formtemplate\" value=\"$formtype\" />";
    }
    if ( defined( $template )) {
      $form .= "<input type=\"hidden\" name=\"templatetopic\" value=\"$template\" />";
    }
    return "$form</form>";
  }

  # PUBLIC derive a new topic name according to the rules given in the
  # relation, returning a topic name with a '\n' where the topic number
  # should go. It is the responsibility of the caller to determine if
  # this conflicts with any known topic.
  # This is used by the autocreate script.
  sub deriveNewTopic {
    my ( $this, $relation, $topic ) = @_;
    my $child;

    if ( $relation eq "copy" ) {
      $child = $topic;
      # find the last number in the topic name
      $child =~ s/([^\d])(\d+)([^\d]*)$/$1\n$3/o;
    } else {
      # Find and apply the relation
      foreach my $r ( @relations ) {
	if ( $r->{relation} eq $relation ) {
	  $child = $r->nextChild( $topic, $this );
	  last;
	}
      }
    }

    return $child;
  }

  sub write {
    my ( $this, $archive ) = @_;
    $archive->writeString( $this->{web} );
    $this->SUPER::write( $archive );
  }

  sub read {
    my ( $this, $archive ) = @_;
    $this->{web} = $archive->readString();
    $this->SUPER::read( $archive );
  }

  sub getInfo {
    my ( $this, $params ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    $this->_load();
    my $topic = $attrs->get("topic");

    if (!defined($topic) || $topic eq "") {
      return $this->toString();
    } else {
      my $ti = $this->get( $topic );
      if (defined($ti)) {
	return $ti->toString($attrs->get("limit"));
      }
      return "<font color=red>$topic not known</font>"
    }
  }
}

1;
