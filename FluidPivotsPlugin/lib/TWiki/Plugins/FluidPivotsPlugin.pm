package TWiki::Plugins::FluidPivotsPlugin;
use strict;
use Math::Round qw (nearest);
use String::CRC32;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC);

$VERSION = '$Rev: 10613 (11 Mar 2007) $';
$RELEASE = 'Dakar';
$SHORTDESCRIPTION = 'FluidPivots';
$pluginName = 'FluidPivotsPlugin';


sub initPlugin 
{
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    my $setting = $TWiki::cfg{Plugins}{FluidPivotsPlugin}{FluidPivotsSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{FluidPivotsPlugin}{Debug} || 0;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::FluidPivotsPlugin::initPlugin($web.$topic) is OK" ) if $debug;

    # Plugin correctly initialized
    return 1;
}

sub FluidPivotsPlugin
{
    my ($currentTopic, $currentWeb, $currentTopicContents) = @_;
    my $this = {};
    bless $this;
    $$this{"CURRENT_TOPIC"} = $currentTopic;
    $$this{"CURRENT_WEB"} = $currentWeb;
    $$this{"CURRENT_TOPICONTENTS"} = $currentTopicContents;
    return $this;
}

# Setter for storing the Table object
sub _setTables { my ($this, $table) = @_; $$this{"TABLES"} = $table; }
# Getter for Table object
sub _tables { my ($this) = @_; return $$this{"TABLES"}; }

# Setter for storing the Parameters object
sub _setParameters
{
    my ($this, $args) = @_;
    $$this{"PARAMETERS"} = TWiki::Plugins::FluidPivotsPlugin::Parameters->new($args);
}

# Getter for Parameters object
sub _Parameters { my ($this) = @_; return $$this{"PARAMETERS"}; }

# This routine sets the specified web.topic as the location from where to
# get the table information.  If the specified web.topic happen to be the
# same as the web.topic from which the %FLUIDPIVOTS% was found, then the
# web.topic contents is already part of the FluidPivotsPlugin object so there is
# nothing to do.  Otherwise, this routine will read in the specified
# web.topic getting its contents and using that as the source to parse out
# table information.
sub _setTopicContents
{
    my ($this, $inWeb, $inTopic) = @_;
    my $topicContents;
    # If $inWeb and $inTopic match the current web/topic, then we already
    # have the topic contents in the object so there is nothing to do.
    # Otherwise, we need to open the specified web/topic and read in its
    # contents.
    if ( ($inWeb eq $$this{"CURRENT_WEB"}) && ($inTopic eq $$this{"CURRENT_TOPIC"}) ) {
    $topicContents = $$this{"CURRENT_TOPICONTENTS"};
    } else {
    # A difference, so read in the topic.
    (my $meta, $topicContents) = TWiki::Func::readTopic( $inWeb, $inTopic );
    # Check to make sure the web.topic actually exists.  If not, return
    # undef so the caller can catch the error.
    return undef if ($topicContents eq "");
    $topicContents = TWiki::Func::expandCommonVariables($topicContents, $inTopic, $inWeb);
    }

    # Lets parse the specified topic contents looking for tables.
    $this->_setTables(TWiki::Plugins::FluidPivotsPlugin::Table->new($topicContents));
    return 1;
}

# This routine returns an red colored error message.
sub _make_error
{
    my ( $msg ) = @_;
    return "<font color=red>FluidPivotsPlugin error: $msg</font>";
}

sub _makePivot
{
    my ( $this, $args, $topic, $web ) = @_;

    $this->_setParameters ($args);

    # See if the parameter 'web' is available.  If not, then default to
    # looking for tables in the current web.
    my $inWeb = $this->_Parameters->getParameter( "web", $web);

    # See if the parameter 'topic' is available.  If not, then default to
    # looking for tables in the current topic.
    my $inTopic = $this->_Parameters->getParameter( "topic", $topic);

    # See if the parameter 'rows' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $rows = $this->_Parameters->getParameter( "rows", undef);
    return _make_error("parameter *rows* must be specified") if( ! defined $rows );

    # See if the parameter 'columns' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $columns = $this->_Parameters->getParameter( "columns", undef);
    return _make_error("parameter *columns* must be specified") if( ! defined $columns );

    # See if the parameter 'data' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $data = $this->_Parameters->getParameter( "data", undef);
    return _make_error("parameter *data* must be specified") if( ! defined $data );

    # See if the parameter 'operation' is available.
    my $operation = $this->_Parameters->getParameter( "operation", "count");

    # See if the parameter 'name' is available.
    my $name = $this->_Parameters->getParameter( "name", "pivot");

    # See if the parameter 'visible' is available.
    my $visible = $this->_Parameters->getParameter( "visible", "all");

    # See if the parameter 'maxrow' is available.
    my $maxRow = $this->_Parameters->getParameter( "maxrow", 0);

    # See if the parameter 'maxcol' is available.
    my $maxCol = $this->_Parameters->getParameter( "maxcol", 0);

    # See if the parameter 'order' is available.
    my $order = $this->_Parameters->getParameter( "order", "max");

    # See if the parameter 'cachetime' is available.
    my $cacheTime = $this->_Parameters->getParameter( "cachetime", 0);

    # See if the parameter 'ignorecache' is available.
    my $ignoreCache = $this->_Parameters->getParameter( "ignorecache", 1209600);

    # Determine which table the user wants to use
    my $tableName = $this->_Parameters->getParameter( "table", 1);


    # Cache
    my ($dir, $filename) = _make_filename($name,$topic,$web);
    
    my $noCacheFile = 0;
    open(TABLE, "$dir/$filename") or $noCacheFile = 1;
    my $actualCRCArg = crc32("$inWeb$inTopic$rows$columns$data$operation$name$visible$maxRow$maxCol$order$tableName");;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $actualTimeStamp = $sec+60*$min+3600*$hour+86400*$yday;
    my $actualCRCData = 0;
    my @fileData = ();

    if ( $noCacheFile eq 0 )
    {
        @fileData = <TABLE>;
        
        my $lastTimeStamp = $fileData[0];
        my $lastCRCArg = $fileData[1];

        $lastTimeStamp += 0; # Perl Sucks!
        $lastCRCArg += 0; # Perl Sucks! (This is to avoid the problem of the \n at the end of the line.)

        if ($actualCRCArg == $lastCRCArg)
        {
            if ((($lastTimeStamp <  $actualTimeStamp) and ($lastTimeStamp + $cacheTime > $actualTimeStamp)) or
                (($lastTimeStamp >= $actualTimeStamp) and ($lastTimeStamp - 86400*366 + $cacheTime > $actualTimeStamp)))
            {
                # Using Cache
                close(TABLE);
                my $fileDataString = "<!--- Time Cache --->\n";
                for my $i ( 3..@fileData-1 ){ $fileDataString = "$fileDataString$fileData[$i]";}
                return $fileDataString;
            }   
        }
    }
    
    # Before we parse any further parameters, lets get the contents of the
    # specified web/topic.
    if (! $this->_setTopicContents($inWeb, $inTopic)) {
    return _make_error("Error retrieving TWiki topic $inWeb<nop>.$inTopic");
    }

    # Verify that the table name is valid.
    if (! $this->_tables->checkTableExists($tableName) ) {
    return _make_error("parameter *table* is not valid table; the specified table '$tableName' does not exist.");
    }

    # Build columns range.
    my $colNumber = $this->_tables->getNumColsInTable($tableName);
    my $sourceColRange = "R1:C1..R1:C$colNumber";
    my @sourceColData = $this->_tables->getDataColumns($tableName,$sourceColRange);
    
    # Build rows range.
    my $rowNumber = $this->_tables->getNumRowsInTable($tableName);
    my $sourceDataRange = "R1:C1..R$rowNumber:C$colNumber";
    
    # This array is [column][row].
    my @sourceData = $this->_tables->getDataColumns($tableName,$sourceDataRange); 

    my $tableDataString = "";
    
    for my $r ( 0..@sourceColData-1 )
    {
        for my $c ( 0..@{@sourceColData[$r]}-1)
        {
            $tableDataString = "$tableDataString;;;$sourceColData[$r][$c]";
        }                
    }

    for my $r ( 0..@sourceData-1 )
    {
        for my $c ( 0..@{@sourceData[$r]}-1)
        {
            $tableDataString = "$tableDataString;;;$sourceData[$r][$c]";
        }                
    } 

    $actualCRCData = crc32($tableDataString);


    if ( $noCacheFile eq 0 )
    {
        my $lastTimeStamp = $fileData[0];
        my $lastCRCData = $fileData[2];
        my $lastCRCArg = $fileData[1];

        $lastTimeStamp += 0; # Perl Sucks!
        $lastCRCData += 0; # Perl Sucks!
        $lastCRCArg += 0; # Perl Sucks! (This is to avoid the problem of the \n at the end of the line.)

        if (($lastCRCData == $actualCRCData ) and ( $lastCRCArg == $actualCRCArg ) and 
        ((($lastTimeStamp <  $actualTimeStamp) and ($actualTimeStamp < $lastTimeStamp + $ignoreCache)) or
         (($lastTimeStamp >= $actualTimeStamp) and ($actualTimeStamp < $lastTimeStamp - 86400*366 + $ignoreCache))))
        {
            # Using Cache
            close(TABLE);
            
            my $fileDataString = "<!--- Data Cache --->\n";
            for my $i ( 3..@fileData-1 ){ $fileDataString = "$fileDataString$fileData[$i]";}

            # Save table to file
            #umask( 002 );
            #open(TABLE, ">$dir/$filename") or return "Can't create file '$dir/$filename: $!";
            #print TABLE "$actualTimeStamp\n";
            #print TABLE "$actualCRCArg\n";
            #print TABLE "$actualCRCData\n";
            #for my $i ( 3..@fileData-1 ){ print TABLE "$fileData[$i]";}
            #close TABLE;

            return $fileDataString;
        }
    }
    close(TABLE);

    # Searching position of col and row data.
    my $posColData = -1;
    my $posRowData = -1;
    my $posData = -1;

    for my $r ( 0..$rowNumber - 1 )
    {
        if ($sourceColData[$r][0] eq $columns)
        {
            $posColData = $r + 1;
        }
        if ($sourceColData[$r][0] eq $rows)
        {
            $posRowData = $r + 1;
        }
        if ($sourceColData[$r][0] eq $data)
        {
            $posData = $r + 1;
        }

    }

    # Get unique elements in row and col data.
    undef my %saw;
    my @uniqRows; for my $r ( 1..$rowNumber-1 ) { push( @uniqRows, $sourceData[$posRowData-1][$r] ); } 
    @uniqRows = grep !$saw{$_}++, @uniqRows;
    @uniqRows = sort @uniqRows;
    my %dictRows; for my $r ( 0..@uniqRows-1 ){ $dictRows{$uniqRows[$r]} = $r; }
    
    undef my %saw;
    my @uniqCols; for my $r ( 1..$rowNumber-1 ) { push( @uniqCols, $sourceData[$posColData-1][$r] ); } 
    @uniqCols = sort grep !$saw{$_}++, @uniqCols;
    @uniqCols = sort @uniqCols;
    my %dictCols; for my $r ( 0..@uniqCols-1 ){ $dictCols{$uniqCols[$r]} = $r; }

    my @countRows = ();
    my @countCols = ();
    my @totalRows = ();
    my @totalCols = ();
    
    for my $d ( 1..$rowNumber-1 )
    {
        my $row = $sourceData[$posRowData-1][$d];
        my $r = $dictRows{$row};

        my $col = $sourceData[$posColData-1][$d];
        my $c = $dictCols{$col};
        
        push( @{$totalRows[$r]} , $sourceData[$posData-1][$d]);
        push( @{$totalCols[$c]} , $sourceData[$posData-1][$d]);
    }
    
    for my $r ( 0..@uniqRows-1 ) { $countRows[$r] = $this->doOperation( $operation, @{$totalRows[$r]} ); }
    for my $c ( 0..@uniqCols-1 ) { $countCols[$c] = $this->doOperation( $operation, @{$totalCols[$c]} ); }
   
    if ($order eq "max")
    {
        @uniqCols = cosort(@countCols, @uniqCols);
        @uniqRows = cosort(@countRows, @uniqRows);
    }
    if ($order eq "min")
    {
        @uniqCols = reverse cosort(@countCols, @uniqCols);
        @uniqRows = reverse cosort(@countRows, @uniqRows);

    }


    my $changeTitleRow=0;
    if (($maxRow eq 0) or ($maxRow eq @uniqRows)) {$maxRow = @uniqRows;}else{$changeTitleRow=1;}
    for my $r ( 0..$maxRow-1 ){ $dictRows{$uniqRows[$r]} = $r; }
    for my $r ( $maxRow..@uniqRows-1 ){ $dictRows{$uniqRows[$r]} = $maxRow-1; }
    @uniqRows = @uniqRows[0..$maxRow-1];

    my $changeTitleCol=0;
    if (($maxCol eq 0) or ($maxCol eq @uniqCols)) {$maxCol = @uniqCols;}else{$changeTitleCol=1;}
    for my $r ( 0..$maxCol-1 ){ $dictCols{$uniqCols[$r]} = $r; }
    for my $r ( $maxCol..@uniqCols-1 ){ $dictCols{$uniqCols[$r]} = $maxCol-1; }
    @uniqCols = @uniqCols[0..$maxCol-1];


    # Pivot Table
    my @pivotTable = ();
    for my $r ( 0..@uniqRows+2 )
    {
        for my $c ( 0..@uniqCols+1 )
        {
            $pivotTable[$r][$c]="";
        }
    }

    $pivotTable[0][0] = " *$data - $operation* ";
    $pivotTable[0][1] = " *$columns* ";
    $pivotTable[1][0] = " *$rows* ";

    for my $r ( 0..@uniqRows-1 ) { $pivotTable[$r+2][0] = " *$uniqRows[$r]* ";  }
    for my $c ( 0..@uniqCols-1 ) { $pivotTable[1][$c+1] = " *$uniqCols[$c]* ";  }
    $pivotTable[@uniqRows+2][0] = " *Totals* ";
    $pivotTable[1][@uniqCols+1] = " *Totals* ";
    if($changeTitleRow eq 1){$pivotTable[@uniqRows+1][0]=" *Otros* ";}
    if($changeTitleCol eq 1){$pivotTable[1][@uniqCols]=" *Otros* ";}

    my @tempPivotTable = ();
    my @totalRows = ();
    my @totalCols = ();
    my @totals = ();


    for my $d ( 1..$rowNumber-1 )
    {
        my $row = $sourceData[$posRowData-1][$d];
        my $r = $dictRows{$row};

        my $col = $sourceData[$posColData-1][$d];
        my $c = $dictCols{$col};
       
        push( @{$tempPivotTable[$r][$c]} , $sourceData[$posData-1][$d]);
        push( @{$totalRows[$r]} , $sourceData[$posData-1][$d]);
        push( @{$totalCols[$c]} , $sourceData[$posData-1][$d]);
        push( @totals , $sourceData[$posData-1][$d]);

    }
    
    
    for my $r ( 0..@uniqRows-1 )
    {
        for my $c ( 0..@uniqCols-1 )
        {  
            $pivotTable[$r + 2][$c +1 ] = $this->doOperation( $operation, @{$tempPivotTable[$r][$c]}) ;
        }
    }

    # Totals
    for my $r ( 0..@uniqRows-1 ) { $pivotTable[$r + 2][@uniqCols+1] = $this->doOperation( $operation, @{$totalRows[$r]} ); }
    for my $c ( 0..@uniqCols-1 ) { $pivotTable[@uniqRows+2][$c +1 ] = $this->doOperation( $operation, @{$totalCols[$c]} ); }
    $pivotTable[@uniqRows+2][@uniqCols+1] = $this->doOperation( $operation, @totals );

    # Build Table.
    my $maxRow = @pivotTable - 1;
    my $tableText = "%TABLE{name=\"$name\"}%\n";
    use Switch;
    switch($visible)
    {
        case "data"
        {
            for my $r ( 0..$maxRow-1 )
            {
                my $maxCol = @{$pivotTable[$r]} - 1;
                $tableText = "$tableText | ";
                for my $c (0..$maxCol-1)
                {
                    $tableText = "$tableText$pivotTable[$r][$c]|";
                }
                $tableText = "$tableText \n";
            }
        }
        case "col"
        {
            for my $r ( 0..$maxRow-1 )
            {
                my $maxCol = @{$pivotTable[$r]} - 1;
                $tableText = "$tableText | ";
                for my $c (0,$maxCol)
                {
                    if(($r eq 0) and ($c eq $maxCol))
                    {
                        $tableText = "$tableText *$columns* |";
                    }
                    else
                    {
                        $tableText = "$tableText$pivotTable[$r][$c]|";
                    }
                }
                $tableText = "$tableText \n";
            }
        }
        case "row"
        {
            for my $r (0,1,$maxRow )
            {
                my $maxCol = @{$pivotTable[$r]} - 1;
                $tableText = "$tableText | ";
                for my $c (0..$maxCol-1)
                {
                    $tableText = "$tableText$pivotTable[$r][$c]|";
                }
                $tableText = "$tableText \n";
            }
        }
        else
        {
            for my $r ( 0..$maxRow )
            {
                my $maxCol = @{$pivotTable[$r]} - 1;
                $tableText = "$tableText | ";
                for my $c (0..$maxCol)
                {
                    $tableText = "$tableText$pivotTable[$r][$c]|";
                }
                $tableText = "$tableText \n";
            }
        }
    }

    # Save table to file
    umask( 002 );
    open(TABLE, ">$dir/$filename") or return "Can't create file '$dir/$filename: $!";
    print TABLE "$actualTimeStamp\n";
    print TABLE "$actualCRCArg\n";
    print TABLE "$actualCRCData\n";
    print TABLE $tableText;
    close TABLE;

    return "<!--- No Cache --->\n$tableText";
}


sub doOperation
{
    my ( $this, $operation, @list) = @_;

    my $n = @list;


    if ( $n < 1 )
    {
        return " 0 ";
    }
    else
    {
        use Switch;

        switch( $operation )
        {
            case "count"
            {   
                return " $n ";
            }
            case "sum"
            {
                my $val = 0;
                for my $d ( 0..$n-1 ) { $val += $list[$d]; }
                $val = nearest(0.001,$val);
                return " $val ";
            }
            case "average"
            {
                my $val = 0;
                for my $d ( 0..$n-1 ) { $val += $list[$d]; }
                $val = nearest(0.001,$val/$n);
                return " $val ";
            }
            case "max"
            {
                my $val =  $list[0];
                for my $d ( 0..$n-1 ) { $val = $list[$d] if ($list[$d] > $val); }
                $val = nearest(0.001,$val);
                return " $val ";
            }
            case "min"
            {
                my $val =  $list[0];
                for my $d ( 0..$n-1 ) { $val = $list[$d] if ($list[$d] < $val); }
                $val = nearest(0.001,$val);
                return " $val ";
            }
            case "var"
            {
                my $val = 0;
                my $var = 0;
                
                for my $d ( 0..$n-1 ) { $val += $list[$d]; }
                $val = $val/$n;

                for my $d ( 0..$n-1 ) { $var += ($list[$d] - $val)*($list[$d] - $val); }
                $var = nearest( 0.001, $var/$n );
                return " $var ";
            }
            case "dev"
            {
                my $val = 0;
                my $var = 0;
                
                for my $d ( 0..$n-1 ) { $val += $list[$d]; }
                $val = $val/$n;

                for my $d ( 0..$n-1 ) { $var += ($list[$d] - $val)*($list[$d] - $val); }
                $var = nearest( 0.001,sqrt($var/$n)) ;
                return " $var ";
            }
            else
            {
                return " $n ";
            }
        }
    }
}

sub cosort
{
    #my (@a,@b) = @_; !!!!!PERL SUCKS
   
    my $n = @_/2;


    my @a = @_[0..$n-1];
    my @b = @_[$n..2*$n-1];


    for my $i ( 0..@a-1)
    {
        for my $j ( reverse( $i..@a-1 ))
        {
            if ( $a[$j-1] < $a[$j] )
            {
                @a[$j-1,$j] = @a[$j,$j-1];
                @b[$j-1,$j] = @b[$j,$j-1];
            }
        }
    }
    return @b;
}


sub commonTagsHandler
{
    my $text  = $_[0];
    my $topic = $_[1];
    my $web = $_[2];

    if ( $text !~ m/%FLUIDPIVOTS{.*}%/)
    {
        return;
    }


    require TWiki::Plugins::FluidPivotsPlugin::Parameters;
    require TWiki::Plugins::FluidPivotsPlugin::Table;
    
    my $pivot = FluidPivotsPlugin($topic, $web, $text);
    $text =~ s/%FLUIDPIVOTS{(.*?)}%/$pivot->_makePivot($1, $topic, $web)/eog;

    # This help us to create the offline page of FluidPivotsPlugin.
    #open(TOP,">/tmp/data");
    #print TOP $text;
    #close(TOP);
    
    $_[0] = $text
}


# Generate the file name in which the table file will be placed.  Also
# make sure that the directory in which the table file will be placed
# exists.  If not, create it.
sub _make_filename
{
    my ( $name, $topic, $web ) = @_;
    # Generate the file name to be created
    my $fullname;
    $fullname = "_FluidPivotsPlugin_${name}.txt";

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = TWiki::Func::getPubDir() . "/$web";
    if( ! -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if( ! -e "$tempPath" ) {
        umask( 002 );
        mkdir( $tempPath, 0775 );
    }
    # Return both the directory and the filename
    return ($tempPath, $fullname);
}



1;
