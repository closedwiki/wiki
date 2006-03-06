#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use Time::ParseDate;
use Benchmark;

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;

use TWiki::Plugins::FormQueryPlugin::ColourMap;
use TWiki::Plugins::FormQueryPlugin::Relation;
use TWiki::Plugins::FormQueryPlugin::TableFormat;
use TWiki::Plugins::FormQueryPlugin::TableDef;

package  TWiki::Plugins::FormQueryPlugin::WebDB;

# A DB is a hash keyed on topic name

@TWiki::Plugins::FormQueryPlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

my %prefs;
my @relations;
my $colourmap;

# PUBLIC
sub new {
    my ( $class, $web ) = @_;
    my $this = bless( $class->SUPER::new($web, "_FormQueryCache"), $class );

    # Note: queries are not cached. If performance really stinks
    # we could, I suppose.
    $this->{_queries} = undef;
    $this->{_topiccreator} = 0;
	$this->{_tables} = undef;

    $this->init( $web ) if ( defined( $web ));
    return $this;
}

# PUBLIC late initialisation of this object, used when serialising
# from a file where the web is not known at the time the object
# is created.
sub init {
    my ( $this, $web ) = @_;

    $this->{_web} = $web;

    my $rtext = TWiki::Func::getPreferencesValue( "FQRELATIONS" ) ||
      "ReQ%Ax%B SubReq ReQ%A; TiT%An%B TestItem ReQ%A";
    my $tablenames = TWiki::Func::getPreferencesValue( "FQTABLES" ) ||
      "TaskTable";
    my $hmap = TWiki::Func::getPreferencesValue( "FQHIGHLIGHTMAP" ) ||
	  "HighlightMap";

    foreach my $relation ( split( /;/, $rtext )) {
        push( @relations, new  TWiki::Plugins::FormQueryPlugin::Relation( $relation ));
    }

    my @tables;
    foreach my $table ( split( /\s*,\s*/, $tablenames )) {
        my( $tableweb,$tablename ) =
          TWiki::Func::normalizeWebTopicName($web, $table);
        if ( !(TWiki::Func::topicExists( $tableweb, $tablename ))) {
            TWiki::Func::writeWarning( "No such table template topic '$table'" );
        } else {
            my $text = TWiki::Func::readTopicText( $tableweb, $tablename );
            my $ttype = new  TWiki::Plugins::FormQueryPlugin::TableDef( $text );
            if ( defined( $ttype )) {
                $this->{_tables}{$tablename} = $ttype;
                push(@tables, $tablename);
            } else {
                TWiki::Func::writeWarning( "Error in table template topic '$table'" );
            }
        }
    }
    $this->{_tableRE} = join('|', @tables);
	
    if ( defined( $hmap )) {
        if ( !(TWiki::Func::topicExists( $web, $hmap ))) {
            TWiki::Func::writeWarning( "No such highlight map topic '$hmap'" );
        } else {
            my $text = TWiki::Func::readTopicText( $web, $hmap );
            $colourmap = new  TWiki::Plugins::FormQueryPlugin::ColourMap( $text );
        }
    }
}

# Invoked by superclass for each line in a topic.
sub readTopicLine {
    my ( $this, $topic, $meta, $line, $fh ) = @_;
	my $re = $this->{_tableRE};

    return $line unless ( defined( $re ));

	my $text = $line;

	while ( $line =~ s/%EDITTABLE{\s*include=\"(.*?)\"\s*}%//o ) {
        my( $tableweb, $tablename ) =
             TWiki::Func::normalizeWebTopicName($this->{_web},$1);
        my $ttype = $this->{_tables}{$tablename};
        if ( defined( $ttype )) {
            # TimSlidel: collapse multiple instances
            # of the same table type into a single table
            # my $table = new TWiki::Contrib::DBCacheContrib::Array();
            my $table = $meta->fastget( $tablename );
            if ( !defined( $table )) {
                $table = new TWiki::Contrib::DBCacheContrib::Array();
            }
            my $lc = 0;
            my $row = "";
            while ( $line = <$fh> ) {
                if ( $line =~ s/\\\s*$//o ) {
                    $text .= $line;
                    # This row is continued on the next line
                    $row .= $line;
                } elsif ( $line =~ m/\|\s*$/o ) {
                    $text .= $line;
                    # This line terminates a row
                    $row .= $line;
                    if ( $lc == 0 ) {
                        # It's the header, ignore it
                    } else {
                        # Load the row
                        my $rowmeta =
                          $ttype->loadRow( $row, "TWiki::Contrib::DBCacheContrib::Map" );
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
	}
	return $text;
}

# PROTECTED called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
    my ( $this, $topics ) = @_;

	$this->_extractRelations();
}

# PRIVATE Remove a topic from the db, unlinking all the relations
sub remove {
    my ( $this, $topic ) = @_;
    my $meta = $this->SUPER::remove( $topic );
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
                        $known = new TWiki::Contrib::DBCacheContrib::Array();
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
    my $text = "WebDB for web " . $this->{_web} . "\n";

    $text .= $this->SUPER::toString( @_ );

    return $text;
}

# PUBLIC STATIC generate error message unless moan is off
sub moan {
    my ( $macro, $attrs, $message, $nomess ) = @_;

    return $nomess if( $attrs->{moan} && $attrs->{moan} eq 'off' );

    return ' '.CGI::span(
        {class=>'twikiAlert'},
        $message.' in '.$macro.'{'.$attrs->stringify().'}').' ';
}

# PUBLIC
# Run a query on the DB.
# It may optionally have the following field:
# form   Name f the form type to run the query on
# It must has the field
# search Boolean expression for the query
sub formQuery {
    my ( $this, $macro, $attrs ) = @_;

    my $name = $attrs->{name};
    if ( !defined( $name )) {
        return moan( $macro, $attrs, "'name' not defined", "" );
    }

    my $search;
    eval {
        $search = new TWiki::Contrib::DBCacheContrib::Search( $attrs->{search} );
    };
    if ( !defined( $search )) {
        return moan( $macro, $attrs,
                     "'search' not defined, or invalid search expression", "" );
    }

    # Make sure the DB is loaded
    $this->load();

    my $queryname = $attrs->{query};
    my $query;
    if ( defined( $queryname )) {
        $query = $this->{_queries}{$queryname};
    } else {
        $queryname = "ROOT";
        $query = $this;
    }

    if ( !defined( $query )) {
        return moan( $macro, $attrs, "Query '$queryname' not defined", "" );
    }

    if ( $query->size() == 0 ) {
        return moan( $macro, $attrs, "Query '$queryname' returned no values", "" );
    }

    delete( $this->{_queries}{$name} );

    my $matches = $query->search( $search );

    my $extract = $attrs->{extract};
    if ( defined( $extract ) && $matches->size() > 0) {
        # Extract a defined subfield and make the query result an
        # array of the subfield. If the subfield is an array, flatten out
        # the array.
        my $realMatches = new TWiki::Contrib::DBCacheContrib::Array();
        foreach my $match ( $matches->getValues() ) {
            my $subfield = $match->get( $extract );
            if ( defined( $subfield )) {
                if ( $subfield->isa( "TWiki::Contrib::DBCacheContrib::Array" )) {
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
        return moan( $macro, $attrs, "No values returned", "" );
    }
    $this->{_queries}{$name} = $matches;

    return "";
}

# PUBLIC
sub tableFormat {
    my ( $this, $macro, $attrs ) = @_;

    my $name = $attrs->{name};
    if ( !defined( $name )) {
        return moan( $macro, $attrs, "'name' not defined", "" );
    }

    my $format = $attrs->{format};
    if ( !defined( $format )) {
        return moan( $macro, $attrs, "'format' not defined", "" );
    }

    my $fmt = new  TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs, $colourmap );

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
# row_from  (optional) Render rows starting from row_from (1st row == 1)
# row_count (optional) Render a maximum of row_count rows
sub showQuery {
    my ( $this, $macro, $attrs ) = @_;

    my $name = $attrs->{query};
    if ( !defined( $name )) {
        return moan( $macro, $attrs, "'query' not defined", "" );
    }

    my $format = $attrs->{format};
    if ( !defined( $format )) {
        return moan( $macro, $attrs, "'format' not defined", "" );
    }
    $format = new  TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs, $colourmap );

    if ( !defined( $format )) {
        return moan( $macro, $attrs, "Table format not defined", "" );
    }

    my $matches = $this->{_queries}{$name};
    if ( !defined( $matches ) || $matches->size() == 0 ) {
        return moan( $macro, $attrs, "Query '$name' returned no values", "" );
    }

    ## get finished html or twiki format table as string
    # Patch from SimonHardyFrancis
    
    return $format->formatTable( $matches, $colourmap,
								 $attrs->{row_from},
								 $attrs->{row_count});
}

# PUBLIC return the sum of all occurrences of a numeric
# field in a query
sub sumQuery {
    my ( $this, $macro, $attrs ) = @_;

    my $name = $attrs->{query};
    if ( !defined( $name )) {
        return moan( $macro, $attrs, "'query' not defined", 0 );
    }

    my $field = $attrs->{field};
    if ( !defined( $field )) {
        return moan( $macro, $attrs, "'field' not defined", 0 );
    }

    my $matches = $this->{_queries}{$name};
    if ( !defined( $matches ) || $matches->size() == 0 ) {
        return moan( $macro, $attrs, "Query '$name' returned no values", 0 );
    }

    return $matches->sum( $field );
}

# PUBLIC generate HTML to generate a new topic according to the rules
# given in the relation
sub createNewTopic {
    my ( $this, $macro, $attrs, $web, $topic ) = @_;

    my $relation = $attrs->{relation};
    if ( !defined( $relation )) {
        return moan( $macro, $attrs, "'relation' not defined", "" );
    }

    my $base = $attrs->{base};
    $base = $topic unless ( defined( $base ));

    # Optional
    my $text = $attrs->{text} || "";
    # Optional
    my $formtype = $attrs->{form};
    # Optional
    my $template = $attrs->{template};

    my $tc = $this->{_topiccreator}++;
    my $child;

    my $form = "<form name=\"topiccreator$tc\" ";
    $form .= "action=\"%SCRIPTURL%/autocreate/$web/";
    $form .= "$base\">";
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

sub getInfo {
    my ( $this, $attrs ) = @_;

    $this->SUPER::load();
    my $topic = $attrs->{topic};

    if (!defined($topic) || $topic eq '') {
        return $this->toString();
    } else {
        my $ti = $this->get( $topic );
        if (defined($ti)) {
            return $ti->toString($attrs->{limit});
        }
        return CGI::span({class=>'twikiAlert'}, $topic.' not known');
    }
}

1;
