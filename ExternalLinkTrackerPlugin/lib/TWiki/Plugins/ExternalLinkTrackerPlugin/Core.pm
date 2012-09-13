# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Nuclearconst.net, http://nuclearconst.net/
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::ExternalLinkTrackerPlugin::Core;

use strict;

our $defTopic = 'ExternalLinkTrackerDefinition';

#==================================================================
sub new {
    my ( $class, $this ) = @_;

    $this->{Debug}        = $TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{Debug} || 0;
    $this->{ExternalIcon} = $TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{ExternalIcon} || 0;;
    $this->{ForceAuth}    = $TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{ForceAuth} || 0;
    $this->{AdminGroup}   = $TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{AdminGroup} || '';

    bless( $this, $class );

    $this->_loadLinkDefinition();
    $this->{LogDir} = TWiki::Func::getWorkArea( 'ExternalLinkTrackerPlugin' );
    $this->_writeDebug( "constructor" );

    return $this;
}

#==================================================================
sub _loadLinkDefinition {
    my( $this ) = @_;

    my $text = TWiki::Func::readTopic( $TWiki::cfg{UsersWebName}, $defTopic );
    foreach my $line ( split ( /\n/, $text ) ) {
        if( $line =~ /^ *\| *([A-Za-z0-9\-_\.]+) * \| *(.*?) *\| *(.*?) *\|/ ) {
            my $id = lc( $1 );
            $this->{Def}{$id}{Name} = $2;
            $this->{Def}{$id}{URL} = $3;
        }
    }
    if( $this->{Debug} ) {
        require Data::Dumper;
        $this->_writeDebug( 'Link definition: ' . Data::Dumper::Dumper( $this->{Def} ) );
    }
}

#==================================================================
sub EXLINK {
    my( $this, $params, $topic, $web ) = @_;

    my $action = $params->{action} || '';
    my $text = '';

    if( ! $action ) {
        # Create redirect link based on ID

        my $id = lc( $params->{_DEFAULT} );
        if( $this->{Def}{$id} ) {
            # Link to redirect URL
            $text = '[[%SCRIPTURL{view';              # view script
            $text .= 'auth' if( $this->{ForceAuth} ); # viewauth script
            $text .= '}%/%SYSTEMWEB%/ExternalLinkTrackerPlugin?'
                  . 'exlink_action=redirect;'
                  . "exlink_id=$id;"
                  . "exlink_web=$web;"
                  . "exlink_topic=$topic"
                  . ']['
                  . $this->{Def}{$id}{Name};
            $text .= '%ICON{external}%' if( $this->{ExternalIcon} );
            $text .= ']]';
            $this->_writeDebug( " Link changed to '$text'" );

        } else {
            $text = '(EXLINK: ID "' . $id . '" not found)';
            $this->_writeDebug($text );
        }

    } elsif( $action eq 'redirect' ) {
        # Record link action and redirect to external site

        my $id = $params->{exlink_id} || '';
        $this->_writeDebug( "action: 'redirect', id: '$id'" );

        if( $id && $this->{Def}{$id} ) {
            # Record link action
            $this->_writeClickLog( $params->{exlink_web}, $params->{exlink_topic},
              $id, $this->{Def}{$id}{URL} );
            # Redirect to link target
            $text = "DEBUG: Redirect to '" . $this->{Def}{$id}{URL} . "'";
            $this->_writeDebug( $text );
            unless( $this->{Debug} ) {
                TWiki::Func::redirectCgiQuery( undef, $this->{Def}{$id}{URL} );
            }
        } else {
            $text = "EXLINK: id '$id' not found for action 'redirect'";
        }

    } elsif( $action eq 'statistics' ) {
        # Show link action statistics

        my $hasGroup = $this->{AdminGroup} && TWiki::Func::isGroup( $this->{AdminGroup} );

        if( ( $hasGroup && TWiki::Func::isGroupMember( $this->{AdminGroup} ) )
            || ! $hasGroup
            || TWiki::Func::isAnAdmin() ) {

            my $period = $params->{period} || '';
            if( $period =~ /^2[0-9]{3}(-[0-1][0-9])?$/ ) {
                my $stats = $this->_readClickLog( $period );
                $text = $stats->{Msg};
                if( ! $stats->{Msg} || $this->{Debug} ) {
                    $text .= $this->_formatStats( $stats );
                }
            } else {
                $text = "EXLINK: Period must be of format YYYY-MM or just YYYY";
            }
        } else {
                $text = "EXLINK: Only members of the "
                      . $TWiki::cfg{UsersWebName} . '.' . $this->{AdminGroup}
                      . " can view the external link statistics.";
        }
    }
    return $text;
}

#==================================================================
sub _writeClickLog {
    my( $this, $web, $topic, $id, $url ) = @_;
    my( $sec, $min, $hour, $day, $mon, $year ) = localtime( time() );
    my $date = sprintf( "%.4u", $year + 1900 ) . '-'
             . sprintf( "%.2u", $mon + 1 );
    my $user = TWiki::Func::getWikiName();
    my $text = "$date-$day, $user, $web, $topic, $id, $url\n";
    my $file = $this->{LogDir} . "/log-$date.txt";
    if( open( FILE, ">>$file" ) ) {
        print FILE $text;
        close( FILE );
    } else {
        $this->_writeDebug( "Can't write to $file" );
    }
}

#==================================================================
sub _readClickLog {
    my( $this, $period ) = @_;

    my $stats;
    $stats->{Msg} = '';

    unless( opendir( DIR, $this->{LogDir} ) ) {
        $this->_writeDebug( "Can't open log directory - $!" );
        $stats->{Msg} = "EXLINK: Can't open log directory - $!";
        return $stats;
    }
    my @files =
      sort
      grep{ /log-$period/ }
      grep{ /log-[0-9]{4}-[0-9]{2}\.txt/ }
      readdir( DIR );
    closedir( DIR );

    unless( @files ) {
        $stats->{Msg} = "EXLINK: No logs found for period $period.";
        return $stats;
    }

    foreach my $name ( @files ) {
        my $file = $this->{LogDir} . "/$name";
        unless( open( IN_FILE, "<$file" ) ) {
            $stats->{Msg} = "EXLINK: Can't open log file $name.";
            return $stats;
        }
        foreach my $line ( <IN_FILE> ) {
            # line format: date, user, web, topic, id, url
            # Example: 2012-09-11, PeterThoeny, TWiki, ExternalLinkTrackerPlugin, twiki, http://twiki.org/
            my @items = split( /, */, $line );
            if( $items[5] ) {
                 my $user = $TWiki::cfg{UsersWebName} . '.' . $items[1];
                 my $webTopic = $items[2] . '.' . $items[3];
                 my $url = $items[5];
                 $url =~ s/[ \n\r]//gs;
                 $stats->{Users}{$user}{$url}{Count} += 1;
                 $stats->{Users}{$user}{$url}{Topics}{$webTopic} += 1;
                 $stats->{Users}{$user}{$url}{Access} = $items[0];
                 $stats->{Links}{$url}{Count} += 1;
                 $stats->{Links}{$url}{Users}{$user} += 1;
                 $stats->{Links}{$url}{Access} = $items[0];
                 $stats->{Msg} .= "$line <br />\n" if( $this->{Debug} );
            }
        }
        close( IN_FILE );
    }
    # $this->_writeDebug( 'Stats: ' . Data::Dumper::Dumper( $stats ) );
    return $stats;
}

#==================================================================
sub _formatStats {
    my( $this, $stats ) = @_;

    my $text = "__Statistics by Users:__\n";
    $text .= "| *User* | *External Link* | *In Topic* | *&#8470;* | *<span style='white-space: nowrap;'>Last Access</span>* |\n";
    foreach my $user ( sort keys %{$stats->{Users}} ) {
        foreach my $url ( sort keys %{$stats->{Users}{$user}} ) {
            $text .= "| $user | $url";
            $text .= " | " . join( ', ', sort keys %{$stats->{Users}{$user}{$url}{Topics}} );
            $text .= " |  " . $stats->{Users}{$user}{$url}{Count};
            $text .= " | " . $stats->{Users}{$user}{$url}{Access} . " |\n";
        }
    }

    $text .= "\n__Statistics by External Links:__\n";
    $text .= "| *External Link* | *Users* | *&#8470;* | *<span style='white-space: nowrap;'>Last Access</span>* |\n";
    foreach my $url ( sort keys %{$stats->{Links}} ) {
        $text .= "| $url";
        $text .= " | " . join( ', ', sort keys %{$stats->{Links}{$url}{Users}} );
        $text .= " |  " . $stats->{Links}{$url}{Count};
        $text .= " | " . $stats->{Links}{$url}{Access} . " |\n";
    }

    return $text;
}

#==================================================================
sub _writeDebug {
    my( $this, $text ) = @_;

    return unless( $this->{Debug} );
    if( $this->{ScriptType} eq 'cli' ) {
        print "DEBUG ExternalLinkTrackerPlugin: $text\n";
    } else {
        TWiki::Func::writeDebug( "- ExternalLinkTrackerPlugin: $text" );
    }
}

#==================================================================
1;
