#
# Copyright (C) Motorola 2003 - All rights reserved
#
#use strict;

use Time::ParseDate;
use Carp;

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
    use vars qw( $storable );
    $storable = eval { require Storable; };
  }

  my %prefs;

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

    my $relations = TWiki::Func::getPreferencesValue( "FQRELATIONS" ) ||
      "ReQ%Ax%B SubReq ReQ%A; TiT%An%B TestItem ReQ%A";
    my $tables = TWiki::Func::getPreferencesValue( "FQTABLES" ) ||
      "TaskTable";
    my $hmap = TWiki::Func::getPreferencesValue( "FQHIGHLIGHTMAP" ) ||
						 "HighlightMap";

    foreach my $relation ( split( /;/, $relations )) {
      push( @{$this->{relations}}, new FormQueryPlugin::Relation( $relation ));
    }
 
    $this->{tablenames} = $tables;
    foreach my $table ( split( /\s*,\s*/, $tables )) {
      if ( !(TWiki::Func::topicExists( $web, $table ))) {
	TWiki::Func::writeWarning( "No such table template topic '$table'" );
      } else {
	my $text = TWiki::Func::readTopicText( $web, $table );
	my $ttype = new FormQueryPlugin::TableDef( $text );
	if ( defined( $ttype )) {
	  $this->{tables}{$table} = $ttype;
	} else {
	  TWiki::Func::writeWarning( "Error in table template topic '$table'" );
	}
      }
    }

    if ( defined( $hmap )) {
      if ( !(TWiki::Func::topicExists( $web, $hmap ))) {
	TWiki::Func::writeWarning( "No such highlight map topic '$hmap'" );
      } else {
	my $text = TWiki::Func::readTopicText( $web, $hmap );
	$this->{colourmap} = new FormQueryPlugin::ColourMap( $text );
      }
    }
  }

  # PRIVATE write a new cache of the listed files.
  sub _writeCache {
    my ( $this, $dir, $files, $cache ) = @_;
    #print STDERR "Writing cache $cache\n";
    FormQueryPlugin::FileTime::setRoot( $dir );
    my $scan = new FormQueryPlugin::Array();
    foreach my $file ( @$files ) {
      $scan->add( new FormQueryPlugin::FileTime( $file ));
    }
    # store the contents, not the WebDB itself
    #print STDERR "Contents at ",$scan->size(),"\n";
    $scan->add( $this );
    if ( $storable ) {
      Storable::lock_store( $scan, $cache );
    } else {
      my $archive = new FormQueryPlugin::Archive( $cache, "w" );
      $archive->writeObject( $scan );
      $archive->close();
    }
    #print STDERR "Wrote ",$storable?"Storable":"Archive"," cache\n";
  }

  # PRIVATE compare the file times in the files list (files
  # in $dir) to the cache. Return 0 if any files have been
  # modified since the cache was written.
  sub _readCache {
    my ( $this, $dir, $files, $cache ) = @_;

    return 0 unless ( -r $cache );

    #print STDERR "Reading cache $cache\n";
    # read the cache, aborting with an exception on error
    my $cached;
    FormQueryPlugin::FileTime::setRoot( $dir );
    if ( $storable ) {
      eval { $cached = Storable::lock_retrieve( $cache ) };
      # trap a die
      if ( $@ ) {
	return 0;
      }
    } else {
      my $archive = new FormQueryPlugin::Archive( $cache, "r" );
      eval { $cached = $archive->readObject(); };
      # trap a die
      if ( $@ ) {
	return 0;
      }
      $archive->close();
    }
    if ( ref( $cached ) ne "FormQueryPlugin::Array" ) {
      # bad cache
      return 0;
    }

    # Check all the cached files were there.
    # This is fatal because relations to the lost files may
    # be in the DB.
    if ( $cached->size() != scalar( @$files ) + 1 ) {
      return 0;
    }

    #print STDERR "Contents at ",$cached->size()-1,"\n";
    my $readWeb = $cached->get( $cached->size() - 1 );
    $this->{keys} = $readWeb->{keys};

    #print STDERR "Read ",$storable?"Storable":"Archive"," cache\n";

    return 1;
  }

  # PUBLIC load the web into the database on demand
  # Return 0 if loaded from file
  # Return 1 if loaded from cache
  # Return 2 if already loaded
  sub _load {
    my ( $this, $cache ) = @_;
    my $source = 2;

    return $source if ( $this->{loaded} );

    my $web = $this->{web};
    my @topics = TWiki::Func::getTopicList( $web );
    my $dataDir = TWiki::Func::getDataDir() . "/$web";
    $cache = "$dataDir/_FormQueryCache";
    my $tableRE = $this->{tablenames};
    $tableRE =~ s/\s*,\s*/\|/go;

    # If the list matches what's in the cache, then load from
    # the cache. Otherwise, refresh the cache.
    if ( $this->_readCache( $dataDir, \@topics, $cache )) {
      $source = 1;
    } else {
      $source = 0;
      # Topics are opened directly because this is much
      # faster than using the TWiki method
      foreach my $topic ( @topics ) {
	open( FH, "<$dataDir/$topic.txt" )
	  or die "Failed $dataDir/$topic.txt";
	my $meta = undef;
	my $line;
	while ( $line = <FH> ) {
	  while ( $line =~ s/%EDITTABLE{\s*include=\"($tableRE)\"\s*}%//o ) {
	    my $tablename = $1;
	    my $ttype = $this->{tables}{$tablename};
	    if ( defined( $ttype )) {
	      $meta = new FormQueryPlugin::Map( ) unless ( $meta );
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
	      $meta->set( "topic", $topic );
	    }
	    # Fall through to allow further processing on $line
	  }
	  if ( $line =~ m/%META:/o ) {
	    if ( $line =~ m/%META:FORM{name=\"([^\"]*)\"}%/o ) {
	      $meta = new FormQueryPlugin::Map() unless ( defined( $meta ));
	      $meta->set( "form", $1 );
	      $meta->set( "topic", $topic );
	    } elsif ( $line =~ m/%META:FIELD{(.*)}%/o ) {
	      $line =~ m/name=\"(.*?)\"/o;
	      my $name = $1;
	      $line =~ m/value=\"(.*?)\"/o;
	      my $value = $1;
	      $meta = new FormQueryPlugin::Map() unless ( defined( $meta ));
	      $meta->set( $name, $value );
	    }
	  }
	}
	if ( defined( $meta )) {
	  $this->set( $topic, $meta );
	}
	close( FH );
      }
      $this->_extractRelations();
      $this->_writeCache( $dataDir, \@topics, $cache );
    }
    $this->{loaded} = 1;
    return $source;
  }

  # PRIVATE extract childof relationships. This is done by applying
  # the relation to each topic to see if another topic exists that has
  # the requested relation to it.
  sub _extractRelations {
    my $this = shift;

    return unless defined( $this->{relations} );
    foreach my $relation ( @{$this->{relations}} ) {
      foreach my $topic ( $this->getKeys() ) {
	my $parent = $relation->apply( $topic );
	if ( defined( $parent ) ) {
	  my $parentMeta = $this->get( $parent );
	  if ( defined( $parentMeta )) {
	    my $childMeta = $this->get( $topic );
	    $childMeta->set( $relation->childToParent(), $parentMeta );
	    my $known = $parentMeta->get( $relation->parentToChild() );
	    if ( !defined( $known )) {
	      $known = new FormQueryPlugin::Array();
	      $parentMeta->set( $relation->parentToChild(), $known );
	    }
	    $known->add( $childMeta );
	  }
	}
      }
    }
  }

  # PUBLIC debug print
  sub toString {
    my $this = shift;
    my $text = "WebDB/" . $this->{web};

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

    my $name = $attrs->remove( "name" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'name' not defined", "" );
    }

    my $search;
    eval {
      $search = new FormQueryPlugin::Search( $attrs->remove( "search" ));
    };
    if ( !defined( $search )) {
      return moan( $macro, $params,
		    "'search' not defined, or invalid search expression", "" );
    }

    # Make sure the DB is loaded

    $this->_load();

    my $queryname = $attrs->remove( "query" );
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

    my $extract = $attrs->remove( "extract" );
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

    my $name = $attrs->remove( "name" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'name' not defined", "" );
    }

    my $format = $attrs->get( "format" );
    if ( !defined( $format )) {
      return moan( $macro, $params, "'format' not defined", "" );
    }

    my $fmt = new FormQueryPlugin::TableFormat( $attrs, $this->{colourmap} );

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

    my $name = $attrs->remove( "query" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'query' not defined", "" );
    }

    my $format = $attrs->get( "format" );
    if ( !defined( $format )) {
      return moan( $macro, $params, "'format' not defined", "" );
    }
    $format = new FormQueryPlugin::TableFormat( $attrs, $this->{colourmap} );

    if ( !defined( $format )) {
      return moan( $macro, $params, "Table format not defined", "" );
    }

    my $matches = $this->{queries}{$name};
    if ( !defined( $matches ) || $matches->size() == 0 ) {
      return moan( $macro, $params, "Query '$name' returned no values", "" );
    }

    return $format->formatTable( $matches, $this->{colourmap} );
  }

  # PUBLIC return the sum of all occurrences of a numeric
  # field in a query
  sub sumQuery {
    my ( $this, $macro, $params ) = @_;
    my $attrs = new FormQueryPlugin::Map( $params );

    my $name = $attrs->get( "query" );
    if ( !defined( $name )) {
      return moan( $macro, $params, "'query' not defined", 0 );
    }

    my $field = $attrs->get( "field" );
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

    my $relation = $attrs->get( "relation" );
    if ( !defined( $relation )) {
      return moan( $macro, $params, "'relation' not defined", "" );
    }

    my $base = $attrs->get( "base" );
    $base = $topic unless ( defined( $base ));

    # Optional
    my $text = $attrs->get( "text" ) || "";
    # Optional
    my $formtype = $attrs->get( "form" );
    # Optional
    my $template = $attrs->get( "template" );

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
      foreach my $r ( @{$this->{relations}} ) {
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

}

1;
