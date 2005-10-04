#
# Copyright (C) 2004 Crawford Currie, cc@c-dot.co.uk
#
# TWiki plugin-in module for Form Query Plugin
#
use strict;

use TWiki;
use TWiki::Func;

package TWiki::Plugins::FormQueryPlugin;

use vars qw(
            $web $topic $user $installWeb $VERSION $pluginName
            $debug %db
           );

$VERSION = '$Rev$';
$pluginName = 'FormQueryPlugin';
$debug = 0;

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    if ( defined( $WebDB::storable ) &&
           TWiki::Func::getPreferencesFlag( "\U$pluginName\E_STORABLE" )) {
        $WebDB::storable = 1;
    } else {
        $WebDB::storable = 0;
    }

    # Get plugin debug flag
    $debug = ( $debug || TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" ));

    TWiki::Func::registerTagHandler( 'FQPDEBUG', \&_handleFQPInfo,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'FORMQUERY', \&_handleFormQuery,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'WORKDAYS', \&_handleWorkingDays,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'SUMFIELD', \&_handleSumQuery,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'ARITH', \&_handleCalc,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'TABLEFORMAT', \&_handleTableFormat,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'SHOWQUERY', \&_handleShowQuery,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'TOPICCREATOR', \&_handleTopicCreator,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'PROGRESS', \&_handleProgress,
                                     'context-free' );

    return 1;
}

sub _handleFQPInfo {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit($web) );
    return $db{$web}->getInfo( $params );
}

sub _handleFormQuery {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit($web) );
    return $db{$web}->formQuery( 'FORMQUERY', $params );
}

sub _handleTableFormat {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit($web) );
    return $db{$web}->tableFormat( 'TABLEFORMAT', $params );
}

sub _handleShowQuery {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit() );
    return $db{$web}->showQuery( 'SHOWQUERY', $params );
}

sub _handleTopicCreator {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'TOPICCREATOR REMOVED - use XXXXXXXXXX');
}

sub _handleSumQuery {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit($web) );
    return $db{$web}->sumQuery( 'SUMQUERY', $params );
}

sub _handleCalc {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'ARITH REMOVED - use SpreadSheetPlugin');
}

sub _handleWorkingDays {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'WORKDAYS REMOVED - use SpreadSheetPlugin');
}

sub _handleProgress {
    my($session, $params, $topic, $web) = @_;
    return CGI::span({class=>'twikiAlert'}, 'FQP init failed')
      unless ( _lazyInit() );
    return  TWiki::Plugins::FormQueryPlugin::ReqDBSupport::progressBar(
        'PROGRESSBAR', $params, $web, $topic );
}

sub _lazyInit {

    return 1 if $db{$web};

    # FQP_ENABLE must be set globally or in this web!
    return 0 unless TWiki::Func::getPreferencesFlag( "\U$pluginName\E_ENABLE" );

    eval <<'HERE';
use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Plugins::FormQueryPlugin::ReqDBSupport;
use TWiki::Plugins::FormQueryPlugin::Arithmetic;
HERE
    die $@ if $@;

    $db{$web} = new  TWiki::Plugins::FormQueryPlugin::WebDB( $web );

    return 0 unless $db{$web};

    return 1;
}

1;
