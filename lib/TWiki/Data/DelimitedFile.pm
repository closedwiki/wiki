package TWiki::Data::DelimitedFile;

use Data::Dumper;

sub read {
    my (%settings) = @_;
    my $filename = $settings{filename};
    my $content = $settings{content};
    my $delimiter = $settings{delimiter} || "\t";
    my $rowstart = $settings{rowstart} || "";
    my $rowend = $settings{rowend} || "\n";
    my %data;
    
    $/ = "\x0d\x0a";
    unless ($content) {
        my $fh   = new FileHandle($filename);
        local $/;
        $content = <$fh>;
        close $fh;
    }
    my @content = split $rowend, $content;
    
    my $headerRow  = shift @content;
    
    $headerRow =~ s/\x0a*//g;
    $headerRow =~ s/\x0d*//g;
    
    @fieldNames = (split /\s*\Q$delimiter\E\s*/, $headerRow); 

    # Target:
    # $data{$rowNumber}{$fieldName} = $fieldValue
    
    # Remove any blank field definitions
    while (!defined($fieldNames[$#fieldNames])) {
        #     print "popping ".pop @fieldNames;
    }
    
    foreach my $rowNumber (0..$#content) {
        my $line = shift @content;
        $line =~ s/\x0a*//;
        $line =~ s/\n*//;
        # not \s - tab delimiter
        my @fieldValues = (split / *\Q$delimiter\E */, $line); 
        
        # print Dumper(\@fieldValues);
        
        foreach my $colNumber (0..$#fieldNames) { #use a counter as incr thru headers
            my $value = $fieldValues[$colNumber] || "";
            my $field = $fieldNames[$colNumber];
            
            $value =~ s/\s+$//;
            $value =~ s/\"//g; #Excel sometimes puts in quotes
            #      print "'$field ($colNumber)'='$value'\n";
            if ($field ne "") {
                $data{$rowNumber}{$field} = $value;
            }
        }
        #  print Dumper(\$data{$rowNumber});
        #  print $rowNumber. "\n";
    }
    
    # now the data is out, only pass valid field names.
    @fieldNames = grep /\S/, @fieldNames; 
    
    return (\@fieldNames, %data);
}

sub save {
    my (%settings) = @_;
    my $filename = $settings{filename} || throw Error::Simple( "Save: filename parameter is mandatory" );
    my $delimiter = $settings{delimiter} || "\t";
    my $rowstart = $settings{rowstart} || "";
    my $rowend = $settings{rowend} || "\n";
    my %data = %{$settings{data} || throw Error::Simple( "Save: data parameter is mandatory" )};
    my @fieldNames = @{$settings{fieldNames} || throw Error::Simple( "Save: fieldNames parameter is mandatory" )};

    my $fh         = new FileHandle("> ".$filename) || throw Error::Simple( "Can't write $filename" );
    my $headerRow = $rowstart.join($delimiter, @fieldNames).$rowend;
    print $fh $headerRow;
    
    foreach my $row (keys %data) {
        print "r=$row\n";
        print Dumper($data{$row});
        print $fh "$rowstart";
        foreach my $field (@fieldNames) {
            my $value = $data{$row}{$field} || "";
            print $fh $value;
            print $fh $delimiter; # SMELL I know this adds an extra delimiter. I don't care.
        }
        print $fh "$rowend";
    }
    close $fh;
}

1;
