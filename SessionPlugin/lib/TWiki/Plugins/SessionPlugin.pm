package TWiki::Plugins::SessionPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $doOldInclude $renderingWeb $noAutoLink;
        $query $sessionId $initcookie $sessionDir %sessionInfo $doneInit
    );
    
use strict;

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between DefaultPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SESSIONPLUGIN_DEBUG" );

    $renderingWeb = $web;
    
    _init();
    

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SessionPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub _init
{
    if( $doneInit ) {
        return;
    } else {
        $doneInit = 1;
    }
    
    $query = &TWiki::Func::getCgiQuery();
    
    return 0 if( ! $query );
    
    %sessionInfo = ();
    $sessionDir = &TWiki::Func::getDataDir() . "/.session";
    if ( ! -e $sessionDir ) {
        umask( 0 );
        mkdir( $sessionDir, 0777 );        
    }

    $sessionId = $query->cookie( 'twikisession' );    
    if( $sessionId ) {
        &TWiki::Func::writeDebug( "- TWiki::Plugins::SessionPlugin sessionId from cookie = $sessionId" ) if $debug;
        if( -e "$sessionDir/$sessionId" ) {
            my $text = &TWiki::Func::readFile( "$sessionDir/$sessionId" );
            %sessionInfo = map { split( /\|/, $_, 2 ) }
                           grep { /[^\|]*\|[^\|]*$/ }
                           split( /\n/, $text );
        } else {
            $sessionId = "";
        }
    }
    if( ! $sessionId ) {
        do {
            $sessionId = _makeSessionId();
        } until ( ! -e "$sessionDir/$sessionId" );
        $initcookie = $query->cookie(
                  -name=>    'twikisession',
                  -value=>   $sessionId,
                  -expires=> '', # leave this blank, so expires with browser
                  -secure=>0
                  );
        _saveSession();
    } else {
    }
    
    my $stickskin = $query->param( 'stickskin' );
    if( $stickskin ) {
        setSessionValueHandler( "SKIN", $stickskin );
    }
}

# =========================
sub _makeSessionId
{
    # FIXME would be nice to have something more definate e.g a seq number
    my $randNum = int( rand( "1000000" ) );
    my $sessionId = time() . "-" . $randNum;
    return $sessionId;
}

# =========================
sub _saveSession
{
    # Write out session file
    my $text = "";
    foreach my $k (keys %sessionInfo) {
        $text .= "$k|$sessionInfo{$k}\n";
    }

    my $file = "$sessionDir/$sessionId";
    $file =~ /^(.*)$/;
    $file = $1; #untaint
    &TWiki::Func::saveFile( $file, $text );
    chmod( 0777, $file );
}

# =========================
sub writeHeaderHandler
{
    if( $initcookie ) {
        print $query->header(-cookie=>$initcookie);
        return 1;
    } else {
        return 0;
    }
}

# =========================
sub redirectCgiQueryHandler
{
    my( $query, $url ) = @_;
    
    if( $initcookie ) {
        print $query->redirect( -uri=>$url,
                                -cookie=>$initcookie );
        return 1;
    } else {
        return 0;
    }
}

# =========================
sub initializeUserHandler
{
    my( $user ) = @_;
    
    $doneInit = "";
    _init();
    
    if( ! $user || $user eq &TWiki::Func::getDefaultUserName() ) {
        if( $sessionInfo{"user"} ) {
            $user = $sessionInfo{"user"};
        }
    } else {
        setSessionValueHandler( "user", $user );
    }
    
    return $user;
}

# =========================
sub getSessionValueHandler
{
    my( $key ) = @_;
    
    return $sessionInfo{$key} || "";
}

# =========================
sub setSessionValueHandler
{
    my( $key, $value ) = @_;
    
    if( $sessionInfo{$key} ne $value ) {
        $sessionInfo{$key} = $value;
        _saveSession();
    }
    
    return 1;
}

# =========================
sub _dispLogon
{   
    my $logon = "<a class=warning href=\"" .
                &TWiki::Func::getScriptUrl( $web, $topic, "logon" ) .
                "\">Logon&gt;&gt;</a>";
    
    return $logon;
}

# =========================
sub _skinSelect
{
    my $html = "<select name=\"stickskin\">\n";
    my $skins = &TWiki::Func::getPreferencesValue( "SKINS" );
    my $skin = &TWiki::Func::getSkin();
    my @skins = split( /,/, $skins );
    unshift @skins, "default";
    foreach my $askin ( @skins ) {
        $askin =~ s/\s//go;
        my $selection = "";
        $selection = "selected" if( $askin eq $skin );
        my $name = $askin;
        $name = "." if( $name eq "default" );
        $html .= "   <option $selection name=\"$askin\">$askin</option>\n";
    }
    $html .= "</select>\n";
    return $html;
}

# =========================
sub endRenderingHandler
# this MUST render after TigerSkinPlugin commonTagsHandler does TIGERLOGON
{
    $_[0] =~ s/%SESSIONLOGON%/&_dispLogon()/geo;
    $_[0] =~ s/%SKINSELECT%/&_skinSelect()/geo;
}

# =========================

1;
