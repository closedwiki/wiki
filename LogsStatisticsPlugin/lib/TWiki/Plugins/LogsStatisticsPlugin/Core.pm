use strict;


package TWiki::Plugins::LogsStatisticsPlugin::Core;
require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version
use Time::Local;
use List::Util qw[min max];
use Date::Manip; 
use Data::Dumper;
use Storable;
use Date::Calc qw( Days_in_Month );

use vars qw( $par_base_directory $par_indexedlogs_directory $cache_currentdate_results $cache_currentmonth_results $cache_old_results $allow_usage $debug $pluginName 
			$remove_daily_files $date_format
);

BEGIN {    
    $pluginName = 'LogsStatisticsPlugin';
}

sub _setDefaults {
	$debug = TWiki::Func::getPreferencesValue( 'LOGSSTATISTICSPLUGIN_DEBUG') || 0;
	$par_base_directory = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_LOGSDIRECTORY') || $TWiki::cfg{LogFileName};
	$cache_currentdate_results = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_CACHECURRENTDATERESULTS') eq "all" ? 1 : 0;
	$cache_currentmonth_results = (TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_CACHECURRENTDATERESULTS') eq "all" or TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_CACHECURRENTDATERESULTS') eq "months") ? 1 : 0;
	$cache_old_results = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_CACHEOLDRESULTS') eq "yes" ? 1 : 0;
	$allow_usage = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_ALLOWUSAGE') || '';
	$par_indexedlogs_directory = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_CACHEDIR') || TWiki::Func::getWorkArea( $pluginName )."/";
	$par_indexedlogs_directory .= "/" if (substr $par_indexedlogs_directory,-1,1) ne "/";
	$remove_daily_files = TWiki::Func::getPreferencesValue('LOGSSTATISTICSPLUGIN_REMOVEDAILYFILES') eq "yes" ? 1 : 0;
	$date_format = $TWiki::cfg{DefaultDateFormat};


	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( debug:$debug )" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( par_base_directory:$par_base_directory )" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( cache_currentdate_results:$cache_currentdate_results)" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( cache_currentmonth_results:$cache_currentmonth_results)" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( cache_old_results:$cache_old_results)" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( allow_usage:$allow_usage )" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( par_indexedlogs_directory:$par_indexedlogs_directory )" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_setDefaults( date_format:$date_format )" ) if $debug;
}

sub _logsStatistics{
	my($session, $params, $theTopic, $theWeb) = @_;

	#Set configuration variables	
	_setDefaults();
	
	my %accessParameters = ();
	#Check if the user has rights to use the plugin
	my $usageRightsResult = _chechUsageRights(\%accessParameters);
	if ($usageRightsResult == 1){
		return "No rights to use plugin.";
	}elsif($usageRightsResult == 2){
		return "Wrong access details";
	}
	
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
#	Something prevents me from removing files	
#	if($remove_daily_files && $dayOfMonth==1){		
#		_removeDailyFiles();
#		TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Daily files have been removed)" ) if $debug;
#	}

	
	#Get and set lists of parameters
	my %callParameters = ();
	$callParameters{'date'} = $params->{date} || 'today';
	$callParameters{'type'} = $params->{type} || 'top5 users';
	$params->{web} =~ s/\s//g;
	$callParameters{'web'} = [sort(split(',', $params->{web}))];
	$params->{topic} =~ s/\s//g;
	$callParameters{'topic'} = [sort(split(',', $params->{topic}))];
	$params->{user} =~ s/\s//g;
	$callParameters{'user'} = [sort(split(',', $params->{user}))];
	$params->{action} =~ s/\s//g;
	$callParameters{'action'} = [sort(split(',', $params->{action}))];
	$params->{ip} =~ s/\s//g;
	$callParameters{'ip'} = [sort(split(',', $params->{ip}))];
	$callParameters{'output'} = $params->{output} || '';
	$callParameters{'description'} = 0;
	$callParameters{'resultNumber'}=5;
	$callParameters{'coversToday'}=0;
	
	
	#Analyze parameters
	my $returned_analyzeParameters = _analyzeParameters( \%callParameters, \%accessParameters );
	return $returned_analyzeParameters unless $returned_analyzeParameters eq 0;
		
	my @datesPeriods;
	#Analyze and prepare dates
	my $returned_analyzeDates = _analyzeDates( \%callParameters, \@datesPeriods );
	return $returned_analyzeDates unless $returned_analyzeDates eq 0;

	my $cachResultsFileName;
	#If caching old result and the date period doesn't cover today then set a file name and read results if the file exists
	if(($cache_old_results) && $callParameters{'coversToday'}!=1 ){
		$cachResultsFileName = $par_indexedlogs_directory."r".$callParameters{'date'}.$callParameters{'type'}.join("|",@{$callParameters{'web'}}).join("|",@{$callParameters{'topic'}}).join("|",@{$callParameters{'user'}}).join("|",@{$callParameters{'action'}}).join("|",@{$callParameters{'ip'}});
		if(-e  $cachResultsFileName){		
			TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Loaded results from the file - nothing else to do)" ) if $debug;
			return _returnResults(\%callParameters, retrieve($cachResultsFileName));

		}
	}
	
	#Get data from log files/cache
	my %resultData =();						#Hash holding results
	my %tempData =();
	
	
	for (my $i=0; $i < (scalar (@datesPeriods)); $i++)	{
		my $isData = 0;
		my $cacheMonthlyResultsFileName= $par_indexedlogs_directory."m".$datesPeriods[$i]{'year'}.$datesPeriods[$i]{'month'}.$datesPeriods[$i]{'days'}.$callParameters{'resultType2'}.join("|",@{$callParameters{'web'}}).join("|",@{$callParameters{'topic'}}).join("|",@{$callParameters{'user'}}).join("|",@{$callParameters{'action'}}).join("|",@{$callParameters{'ip'}});
				#If caching and not a current month
		if($callParameters{'coversToday'}==1 && ($cache_currentmonth_results) && !(($datesPeriods[$i]{'year'}==$year) && ($datesPeriods[$i]{'month'}==($month+1)))){	
			#Read data if they exists
			if(-e $cacheMonthlyResultsFileName ){
				_sumData(\%resultData, \%{retrieve($cacheMonthlyResultsFileName)}); 
				$isData =1; 
				TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Read from file monthly data: $datesPeriods[$i]{'year'}.$datesPeriods[$i]{'month'}.$datesPeriods[$i]{'days'})" ) if $debug;
			}
		}
		unless($isData){ #Data for this month doesn't exist, we need to generate it
			my $returned_analyzeLog =  _analyzeLog($datesPeriods[$i]{'year'},$datesPeriods[$i]{'month'},$datesPeriods[$i]{'days'},\%callParameters,\%tempData);
			return $returned_analyzeLog if ($returned_analyzeLog!=0);
			#Cache te results
			if($callParameters{'coversToday'}==1 && ($cache_currentmonth_results) && !(($datesPeriods[$i]{'year'}==$year) && ($datesPeriods[$i]{'month'}==$month+1))){
				store \%tempData, $cacheMonthlyResultsFileName;
				TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Save to file monthly data: $datesPeriods[$i]{'year'}.$datesPeriods[$i]{'month'}.$datesPeriods[$i]{'days'})" ) if $debug;
			}
				
			_sumData(\%resultData, \%tempData);
			%tempData=();
		}
		
		
	}


	my @finalData;
	if($callParameters{'resultType1'} eq "top"){
		# sort using foreach, ascending sort
		my $value;
		my @sorted_data;
		foreach  $value ( sort {$resultData{$b} <=> $resultData{$a} } keys %resultData)
		{
	  	   	push(@sorted_data, $value);
		}
		my $size = scalar @sorted_data;
		
		for(my $i=0; $i<min($size, $callParameters{'resultNumber'}) ; $i++){
			push(@finalData,($sorted_data[$i], $resultData{$sorted_data[$i]}));
		}
	}else{
		push(@finalData,scalar keys %resultData);	
		TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Unique keys pushed)" ) if $debug;	
	}
	
	#Caching whole results
	if(($cache_old_results) && $callParameters{'coversToday'}!=1 ){
		store \@finalData, $cachResultsFileName;
		TWiki::Func::writeDebug( "- ${pluginName}::_logsStatistics( Stored whole result)" ) if $debug;
	}


	return _returnResults(\%callParameters, \@finalData);


	return "It shouldn't get so far..";
	
}
=pod
sub _removeDailyFiles{

    opendir(DIR, $par_indexedlogs_directory) or die $!;

    my @dots = grep {/^d/  && -f "$par_indexedlogs_directory/$_"} readdir(DIR);

    closedir(DIR);
    
     # Loop through the array printing out the filenames
    foreach my $file (@dots) {
        unlink ($par_indexedlogs_directory.$file) or TWiki::Func::writeDebug( "- ${pluginName}::_removeDailyFiles( Can't remove file $par_indexedlogs_directory"."$file))" ) if $debug;;
    }
	
}
=cut

=pod
Prepare results to print them to the user
=cut
sub _returnResults{
	my ($callParameters, $finalData) = @_;
	my $return="";	
	
	if($$callParameters{'resultType1'} eq "top"){
		$return.="| *Top $$callParameters{'resultType2'}* | *Number of entires* |\n" if $$callParameters{'output'}==0;
		for(my $i=0; $i<(scalar (@$finalData)) ; $i=$i+2){
			if($$callParameters{'output'}==0){
				$return .= "| ".$$finalData[$i]." | ".$$finalData[$i+1]." |\n";
			}else{			
				$return .= $$finalData[$i].": ".$$finalData[($i+1)]."\n\n";
			}
		}
		
	}else{
		my $size = $$finalData[0];
		
		if($$callParameters{'output'}==0){
			$return .= "| *Number of unique $$callParameters{'resultType2'} *|\n| $size |\n";
		}else{
			
			$return += "$size";
		}
		
		
	}
	my $parameters="";
	if($$callParameters{'description'}){
		$parameters.="Statistics parameters: date=\"$$callParameters{'date'}\" type=\"$$callParameters{'type'}\"";
		$parameters.= " web=\"".join(", ",@{$$callParameters{'web'}})."\"" if $$callParameters{'web'}[0] ne ".*?";
		$parameters.= " topic=\"".join(", ",@{$$callParameters{'topic'}})."\"" if $$callParameters{'topic'}[0] ne ".*?";
		$parameters.= " user=\"".join(", ",@{$$callParameters{'user'}})."\"" if $$callParameters{'user'}[0] ne ".*?";
		$parameters.= " action=\"".join(", ",@{$$callParameters{'action'}})."\"" if $$callParameters{'action'}[0] ne ".*?";
		$parameters.= " ip=\"".join(", ",@{$$callParameters{'ip'}})."\"" if $$callParameters{'ip'}[0] ne ".*?";
		$parameters.="\n";
	}
	
	if($$callParameters{'output'}==0){
		return "\n".$return.$parameters;
	}else{
		return "\n".$return.$parameters;
	}
}


=pod
Function summing data read from different logs. Params are send by the reference - they are hashes and might be to big to send by value
=cut
sub _sumData {
	my ($resultDataRef, $tempDataRef ) = @_;
	foreach my $key (keys %{$tempDataRef}) {
		unless( defined( $$resultDataRef{$key} ) ){
			$$resultDataRef{$key}=0;
		}
		$$resultDataRef{$key} += $$tempDataRef{$key};				
	}			
}	



=pod
Function analyzing log files
	
=cut
sub _analyzeLog {

	my $expression;
	my %hashOfHashes=();	#hash with data read from files
	#Reading parameters	
	my ($parYear, $parMonth, $parDays, $callParameters, $resultData) = @_;
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	#Should we cache daily files?
	my $toCacheOrNotToCache = ($$callParameters{'coversToday'}==1 && ($cache_currentdate_results) && (($parYear==$year) && ($parMonth==$month+1)));
	

	if( ($year == $parYear) && ( ($month+1) == $parMonth) ){
		;
	}else{
		$dayOfMonth = (-1);		#?
	}
			
	my @daysPeriod;					#List of all days to analyze
	my @daysRegex;					#List of days for regex (@daysPeriod - "@cached days")
	my @analyzedDays;			
	
	#Create table with days to analyze
	my $par_exp;
	
	if($toCacheOrNotToCache){			#Cache results using daily files - only if current month
		if($parDays eq ""){
			my $dt = Date::Calc::Days_in_Month($parYear, $parMonth);
			@daysPeriod = (sprintf("%02d", '01')..sprintf("%02d", $dt));
		}elsif($parDays =~ m/^\d{1,2}$/){
			@daysPeriod = (sprintf("%02d", $parDays));
		}elsif($parDays =~ m/(\d{1,2})-(\d{1,2})/){		
			@daysPeriod = (sprintf("%02d", $1)..sprintf("%02d", $2));
		}else{
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Unknown error a?)" ) if $debug;
		}
	}else{											#No result caching
		if($parDays eq ""){
			@daysRegex = '\d\d';
		}elsif($parDays =~ m/^\d{1,2}$/){
			@daysRegex = (sprintf("%02d", $parDays));
		}elsif($parDays =~ m/(\d{1,2})-(\d{1,2})/){		
			@daysRegex = (sprintf("%02d", $1)..sprintf("%02d", $2));
		}else{
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Unknown error b?)" ) if $debug;
		}	
	}
	
	
	#Create second part of regex, thay are not the same (parenthesis + others)
	my $expressionBack;
	if( $$callParameters{'resultType2'} eq "users" ){
		$expressionBack = '.*? \| (('.join("|",@{$$callParameters{'user'}}).')) \| ('.join("|",@{$$callParameters{'action'}}).') \| ('.join("|",@{$$callParameters{'web'}}).')\.('.join("|",@{$$callParameters{'topic'}}).') \| (.*?) \| ('.join("|",@{$$callParameters{'ip'}}).') \|.*';
	}elsif($$callParameters{'resultType2'} eq "topics"){
		$expressionBack = '.*? \| ('.join("|",@{$$callParameters{'user'}}).') \| ('.join("|",@{$$callParameters{'action'}}).') \| (('.join("|",@{$$callParameters{'web'}}).')\.('.join("|",@{$$callParameters{'topic'}}).')) \| (.*?) \| ('.join("|",@{$$callParameters{'ip'}}).') \|.*';
	}elsif($$callParameters{'resultType2'} eq "webs"){
		$expressionBack = '.*? \| ('.join("|",@{$$callParameters{'user'}}).') \| ('.join("|",@{$$callParameters{'action'}}).') \| (('.join("|",@{$$callParameters{'web'}}).'))\.('.join("|",@{$$callParameters{'topic'}}).') \| (.*?) \| ('.join("|",@{$$callParameters{'ip'}}).') \|.*';
	}elsif($$callParameters{'resultType2'} eq "crawlers"){
		$expressionBack = '.*? \| ('.join("|",@{$$callParameters{'user'}}).') \| ('.join("|",@{$$callParameters{'action'}}).') \| ('.join("|",@{$$callParameters{'web'}}).')\.('.join("|",@{$$callParameters{'topic'}}).') \| ((.*?bot.*?)) \| ('.join("|",@{$$callParameters{'ip'}}).') \|.*';
	}			
			

	#Creating string to the log file
	my $datafile= $par_base_directory;
	$datafile =~ s/%DATE%/$parYear$parMonth/;
	TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Datafile: $datafile)" ) if $debug;
	
	
	#Checking if the log file exists	
	if (-e $datafile){
		open(FILE, $datafile) || return "Could not open file!";
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( reDate: $par_exp, parYear: $parYear, parMonth: $parMonth)" ) if $debug;
		
		#Log file exists and opened, checking for cached results:
		my $day;
		#Looking for existing files
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( daysPeriod: @daysPeriod )" ) if $debug;
		if($toCacheOrNotToCache){
			foreach $day (@daysPeriod) {
	 			if((-e $par_indexedlogs_directory."d".$parYear.$parMonth.$day.$expressionBack) && ($day < $dayOfMonth || $dayOfMonth==-1) ){
								#Add data cached in the file
	 				_sumData($resultData, \%{retrieve($par_indexedlogs_directory."d".$parYear.$parMonth.$day.$expressionBack)}); 	
	 			}else{
	 				push(@daysRegex, $day);
	 			}
	 		} 	
		}
 		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( @daysRegex )" ) if $debug;	
		
		#Cache checked, generating missing data + caching
		my $searchId;
		my $i=0;		#Iteration counter
		my $line;
		my $count=0;	#Matches counter
		my $dateChecker=0;
		if(scalar @daysRegex==0){	#Return result if no other reading is neccessary
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( No need to analyze log file - all informations read from datafiles)" ) if $debug;	
			return 0;
		}
		
		TWiki::Func::writeDebug( "- ${pluginName}::date_format( ".$date_format.")" ) if $debug;
		#Prepare to handle specific date format
		my $exp = $date_format;
		my $res = "(".join("|",@daysRegex).")";
		$exp =~ s/\$day/$res/gi; 
		$exp =~ s/\$mont?h?/$months[$parMonth-1]/gi;
		$exp =~ s/\$mo/$parMonth/gi;  
		$exp =~ s/\$year?/$parYear/gi;
		$exp =~ s/\$ye/sprintf('%.2u',$parYear%100)/gei;
			
		$expression = '\| '.$exp.$expressionBack;
		
		

		if($$callParameters{'resultType2'} eq "users"){
			
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Used expression: $expression)") if $debug;
			while ( defined($line = <FILE>)  ) { 
				$i++;
				if($line =~ m/$expression/ ){
					$count++;
					if($toCacheOrNotToCache){
						if( ($dateChecker!=$1) && ($dateChecker<$1) ) { #Check if it's next day 
							#Dodaj dane
							unless($dateChecker==0){
								store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
								_sumData($resultData, \%hashOfHashes);
								%hashOfHashes = ();
								push(@analyzedDays, $dateChecker);
							}
							$dateChecker = $1; 
						}
						if( $dateChecker == $1 ){
							unless( defined($hashOfHashes{$3}) ){
								$hashOfHashes{$3}=0;
							}
							$hashOfHashes{$3}++;
						}else{
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Lower date in wrong line, something wrong )") if $debug;
						}				
					}else{
						unless( defined($$resultData{$3}) ){
							$$resultData{$3}=0;
						}
						$$resultData{$3}++;
					}
				}else{
					#print $line;
				}
		
			}
			if($toCacheOrNotToCache){
				store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
				push(@analyzedDays, $dateChecker);
			
			_sumData($resultData, \%hashOfHashes);
			}
			%hashOfHashes = ();
			
		}elsif($$callParameters{'resultType2'} eq "topics"){
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Checking topics)") if $debug;
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Used expression: $expression)") if $debug;
			while ( defined($line = <FILE>)  ) { 
				$i++;
				if($line =~ m/$expression/ ){
					$count++;					
					if($toCacheOrNotToCache){
						if( ($dateChecker!=$1) && ($dateChecker<$1) ) { #Check if it's next day 
							#Dodaj dane
							unless($dateChecker==0){
								store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
								_sumData($resultData, \%hashOfHashes);
								%hashOfHashes = ();
								push(@analyzedDays, $dateChecker);
							}
							$dateChecker = $1; 
						}
						if( $dateChecker == $1 ){
							unless( defined($hashOfHashes{$4}) ){
								$hashOfHashes{$4}=0;
							}
							$hashOfHashes{$4}++;
						}else{
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Lower date in wrong line, something wrong )") if $debug;
						}				
					}else{
						unless( defined($$resultData{$4}) ){
							$$resultData{$4}=0;
						}
						$$resultData{$4}++;
					}			
				}else{
					#print $line;
				}
		
			}
			if($toCacheOrNotToCache){
				store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
				push(@analyzedDays, $dateChecker);
				
				_sumData($resultData, \%hashOfHashes);
			}
			
			%hashOfHashes = ();
		}elsif($$callParameters{'resultType2'} eq "webs"){
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Checking webs)") if $debug;
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Used expression: $expression)") if $debug;
			while ( defined($line = <FILE>)  ) { 
				$i++;
				if($line =~ m/$expression/ ){
					$count++;
					if($toCacheOrNotToCache){
						if( ($dateChecker!=$1) && ($dateChecker<$1) ) { #Check if it's next day 
							#Dodaj dane
							unless($dateChecker==0){
								store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
								_sumData($resultData, \%hashOfHashes);
								%hashOfHashes = ();
								push(@analyzedDays, $dateChecker);
							}
							$dateChecker = $1; 
						}
						if( $dateChecker == $1 ){
							unless( defined($hashOfHashes{$5}) ){
								$hashOfHashes{$5}=0;
							}
							$hashOfHashes{$5}++;
						}else{
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Lower date in wrong line, something wrong )") if $debug;
						}				
					}else{
						unless( defined($$resultData{$5}) ){
							$$resultData{$5}=0;
						}
						$$resultData{$5}++;
					}				
				}else{
					#print $line;
				}
			}
			if($toCacheOrNotToCache){
				store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
				push(@analyzedDays, $dateChecker);
			
				_sumData($resultData, \%hashOfHashes);
			}
			%hashOfHashes = ();
		}elsif($$callParameters{'resultType2'} eq "crawlers"){			
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Checking crawlers)") if $debug;
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Used expression: $expression)") if $debug;
			while ( defined($line = <FILE>)  ) { 
				$i++;
				if($line =~ m/$expression/ ){
					$count++;
					if($toCacheOrNotToCache){
						if( ($dateChecker!=$1) && ($dateChecker<$1) ) { #Check if it's next day 
							#Dodaj dane
							unless($dateChecker==0){
								store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
								_sumData($resultData, \%hashOfHashes);
								%hashOfHashes = ();
								push(@analyzedDays, $dateChecker);
							}
							$dateChecker = $1; 
						}
						if( $dateChecker == $1 ){
							unless( defined($hashOfHashes{$7}) ){
								$hashOfHashes{$7}=0;
							}
							$hashOfHashes{$7}++;
						}else{
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Lower date in wrong line, something wrong )") if $debug;
						}				
					}else{
						unless( defined($$resultData{$7}) ){
							$$resultData{$7}=0;
						}
						$$resultData{$7}++;
					}					
				}else{
					#print $line;
				}
			}
			if($toCacheOrNotToCache){
				store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$dateChecker.$expressionBack;
				push(@analyzedDays, $dateChecker);
			
				_sumData($resultData, \%hashOfHashes);
			}
			%hashOfHashes = ();
		}else{
			close FILE;
			return "Wrong type";
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Wrong type)") if $debug;
		}
		
		

		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Przeanalizowane dni: ".join(", ",@analyzedDays).")") if $debug;	
		close FILE;
		
		if($toCacheOrNotToCache){			#Save empty variables for empty days
			#Diff of 2 arrays
		    my %count = ();
		    my $element;
		    %hashOfHashes = ();
		    if( ($parYear<$year) || ( $parYear==$year && $parMonth<=$month+1) ){
		    			    
			    foreach $element (@daysRegex, @analyzedDays) { $count{$element}++ }
			    foreach $element (keys %count) {
			        if( ($count{$element} == 1) && ($element<$dayOfMonth || $dayOfMonth==-1)){
			        	store \%hashOfHashes, $par_indexedlogs_directory."d".$parYear.$parMonth.$element.$expressionBack;
			        }
			    }
			}

						
		}
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( Read $i lines, $count mached)") if $debug;		
	}else{
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeLog( File $datafile doesn't exist)") if $debug;
	}
	
	return 0;
}

=pod
Check, analyze and set right parameters
=cut
sub _analyzeParameters {

	my ($callParameters, $accessParameters ) = @_;
				

	if(scalar @{$$callParameters{'web'}} ){
		my %availableWebs={};
		foreach my $web (@{$$accessParameters{'web'}}){
			$availableWebs{$web}=1;
		}
		my $isAccessParameter = scalar @{$$accessParameters{'web'}};
		foreach my $web (@{$$callParameters{'web'}}){
			unless($web =~ m/^[a-zA-Z0-9\/]+$/ ){
				return "Wrong web: $web";
			}		

			if( $isAccessParameter ){
				unless($availableWebs{$web}==1){
					return "No access to use web: $web";
				}
				
			}
		}
	}else{
		if(scalar @{$$accessParameters{'web'}}){
			$$callParameters{'web'} = [@{$$accessParameters{'web'}}];
		}else{
			$$callParameters{'web'}=[".*?"];	
		}
	}
	
	
	if(scalar @{$$callParameters{'topic'}} ){
		foreach my $topic (@{$$callParameters{'topic'}}){
			unless($topic =~ m/^[a-zA-Z0-9\/]+$/ ){
				return "Wrong topic: $topic";
			}		
		}
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( topic: ".join(",",@{$$callParameters{'topic'}}).")" ) if $debug;
	}else{
		$$callParameters{'topic'}=[".*?"];
	}
	
	
	

	if(scalar @{$$callParameters{'user'}} ){
		foreach my $user (@{$$callParameters{'user'}}){
			unless($user =~ m/^[a-zA-Z0-9\/.@]+$/ ){
				return "Wrong user: $user";
			}		
		}
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( user: ".join(",",@{$$callParameters{'user'}}).")" ) if $debug;
	}else{
		$$callParameters{'user'}=[".*?"];
	}
	
	if(scalar @{$$callParameters{'action'}} ){
		foreach my $action (@{$$callParameters{'action'}}){
			unless($action =~ m/^[a-zA-Z0-9_]+$/ ){
				return "Wrong action: $action";
			}		
		}
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( action: ".join(",",@{$$callParameters{'action'}}).")" ) if $debug;
	}else{
		$$callParameters{'action'}=[".*?"];
	}

	if(scalar @{$$callParameters{'ip'}} ){
		foreach my $ip (@{$$callParameters{'ip'}}){
			unless($ip =~ m/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ){
				return "Wrong ip: $ip";
			}		
		}
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( ip: ".join(",",@{$$callParameters{'ip'}}).")" ) if $debug;
	}else{
		$$callParameters{'ip'}=[".*?"];
	}
	
	if($$callParameters{'output'} ne ""){
		$$callParameters{'output'} =~ s/\s//g; #remove spaces
	
		my @wholeOutputParameters = split(',', $$callParameters{'output'});
  		foreach my $val (@wholeOutputParameters) {
			if($val eq "table"){
				$$callParameters{'output'}=0;
			}elsif($val eq "list"){
				$$callParameters{'output'}=1;
			}elsif($val eq "description"){
				$$callParameters{'description'}=1;
			}else{
				return "Unknown output parameter $val\n";
			}
  		}
	}else{
		$$callParameters{'output'}=0;
	}
	
	
	if($$callParameters{'type'} =~ m/^(top|unique)(\d*) (users|webs|crawlers|topics)$/){
		if(($2 ne "") && ($2 != 0)){
			$$callParameters{'resultNumber'}=$2;
		}
		$$callParameters{'resultType2'} = $3;		#type_ex
		$$callParameters{'resultType1'} = $1; 	#type
		
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Number of results: $$callParameters{'resultNumber'})" ) if $debug;
	}else {
		TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Wrong type)" ) if $debug;
		return "Wrong type\n";
	}
	
	return 0;
}

=pod
Return hash with current user access rights
=cut
sub _chechUsageRights(){	
	
	my ($accessParameters ) = @_;
	$allow_usage =~ s/\s//g; #remove spaces
	my $group = 0;
	my $parameters;
	
	my @wholeUserAccess = split(';', $allow_usage);
	#First check for a user
  	foreach my $val (@wholeUserAccess) {
  		my @detailedAccess = split(':', $val);
  		
  		if((TWiki::Func::getWikiName() eq $detailedAccess[0])) {
			if(defined($detailedAccess[1])){
				return getAccessParameters($accessParameters,$detailedAccess[1] );
			}else{
				$$accessParameters{'web'} = [];
				return 0;
			}
		}
  		
  		
		if(TWiki::Func::isGroupMember($detailedAccess[0])) {
			$group=1;
			if(defined($detailedAccess[1])){
				$parameters = $detailedAccess[1];
			}
		}	
  	}
  	#Then check for a group
  	if($group==1){
  		if(defined($parameters)){
			return getAccessParameters($accessParameters,$parameters );
		}else{
			$$accessParameters{'web'} = [];
			return 0;
		}
  	}
  	
  	return 1;
  	
}

=pod
Get detailed user access parameters
=cut
sub getAccessParameters(){	
	
	my ($accessParameters, $detailedAccess ) = @_;
	TWiki::Func::writeDebug( "- ${pluginName}::getAccessParameters( $detailedAccess)" ) if $debug;
	if(length($detailedAccess)==0 ){
		return 0;
	}elsif( $detailedAccess =~ m/^web="(.*)"$/ ){
		$$accessParameters{'web'} = [ sort(split(',', $1)) ];
		return 0;
	}else{
		return 2;
	}
  	
}

=pod
Check and analyze date parameters and create date periods
=cut
sub _analyzeDates {
	
	my ($callParameters, $datesPeriods ) = @_;

	#Data for counting parameters
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	my %monthsNo;
	@monthsNo{@months} = (1..12);


	TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Programs parameter: $$callParameters{'date'})" ) if $debug;

	#Parsing parameters and executing ...
	if(defined($$callParameters{'date'})){
		if($$callParameters{'date'} eq 'today'){	#TODAY
			$$callParameters{'coversToday'}=1;
			push(@$datesPeriods, {year => $year,  month  => sprintf("%02d", $month+1),  days  => $dayOfMonth} );
			
			
		}elsif ($$callParameters{'date'} eq 'yesterday') {	#YESTERDAY
			($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime(time - 24 * 60 * 60);
			push(@$datesPeriods, {year => 1900 + $yearOffset,  month  => sprintf("%02d", $month+1),  days  => $dayOfMonth} );
			#change yesterday to date to allow caching whole result
			$$callParameters{'date'} = sprintf("%02d", $dayOfMonth)." ".$months[$month]." ".(1900 + $yearOffset);
			
		}elsif ($$callParameters{'date'} =~ m/^last (\d+) days/) {	#Last X days
			$$callParameters{'coversToday'}=1;
			#Data from last week
			if($1>0){
				my $days;
				$1>999 ? $days = 999 : $days=$1;
				
				#Find a day in the past and prepare a new date format
				my ($second1, $minute1, $hour1, $dayOfMonth1, $month1, $yearOffset1, $dayOfWeek1, $dayOfYear1, $daylightSavings1) = localtime(time - $days *24* 60 * 60);
				my %copyOfCallParameteres = %{$callParameters};				
				$copyOfCallParameteres{'date'}="".sprintf("%02d", $dayOfMonth1)." ".$months[$month1]." ".(1900+$yearOffset1)." - ".sprintf("%02d", $dayOfMonth)." ".$months[$month]." $year";
				return _analyzeDates(\%copyOfCallParameteres, $datesPeriods);
				#return _analyzeDates($callParameters, $datesPeriods);
			}
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( At least one day)" ) if $debug;
			return "At least one day\n";
			
			
				
		}elsif ($$callParameters{'date'} eq 'month'){	#FINISHED
			$$callParameters{'coversToday'}=1;
			push(@$datesPeriods, {year => $year,  month  => sprintf("%02d", $month+1),  days  => ""} );
			
		}elsif ($$callParameters{'date'} =~ m/^(0[1-9]|[12][0-9]|3[01]) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ((19|20)\d\d)$/){	#Specific date dd MMM yyyy
			#check if the date is valid
			if( ParseDate($3.sprintf("%02d", $monthsNo{$2}).$1)){
				if(&Date_Cmp( &ParseDate($3.(sprintf("%02d", $monthsNo{$2})).$1), &ParseDate($year.(sprintf("%02d", ($month+1))).(sprintf("%02d", $dayOfMonth)))) <0){
					push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $monthsNo{$2}),  days  => $1} );
				}elsif(&Date_Cmp( &ParseDate($3.(sprintf("%02d", $monthsNo{$2})).$1), &ParseDate($year.(sprintf("%02d", ($month+1))).(sprintf("%02d", $dayOfMonth)))) ==0){
					$$callParameters{'coversToday'}=1;
					push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $monthsNo{$2}),  days  => $1} );
				}else{
					TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Date in the future)" ) if $debug;
					return 0;
				}
			}else{
				TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Wrong date)" ) if $debug;
				return "	Wrong date\n";
			}

		}elsif ($$callParameters{'date'} =~ m/^(0[1-9]|[12][0-9]|3[01]) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ((19|20)\d\d) \- (0[1-9]|[12][0-9]|3[01]) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ((19|20)\d\d)$/){
			#Data from a specific period dd MMM yyyy - dd MMM yyyy
			
			#Check if the dates are right and in right order
			my $monthNo1=sprintf("%02d", $monthsNo{$2});
			my $monthNo2=sprintf("%02d", $monthsNo{$6});
			if( ParseDate($3.$monthNo1.$1) && ParseDate($7.$monthNo2.$5)){
  				my $flag=&Date_Cmp( &ParseDate($3.$monthNo1.$1), &ParseDate($7.$monthNo2.$5));
  				
  				if($flag<=0){					#Check if any of them is in the future
  													
  					if(&Date_Cmp( &ParseDate($3.$monthNo1.$1), &ParseDate($year.(sprintf("%02d", ($month+1))).(sprintf("%02d", $dayOfMonth)))) >0){
  						$$callParameters{'coversToday'}=1;
						TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Period in the future)" ) if $debug;
						return 0;
					}
					if(&Date_Cmp( &ParseDate($7.$monthNo2.$5), &ParseDate($year.(sprintf("%02d", ($month+1))).(sprintf("%02d", $dayOfMonth)))) >0){
						$$callParameters{'coversToday'}=1;
						TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Part of period in the future - shortening)" ) if $debug;
						
						$$callParameters{'date'}="$1 $2 $3 - ".sprintf("%02d", $dayOfMonth)." ".$months[$month]." $year";
						return _analyzeDates($callParameters, $datesPeriods);
					}elsif(&Date_Cmp( &ParseDate($7.$monthNo2.$5), &ParseDate($year.(sprintf("%02d", ($month+1))).(sprintf("%02d", $dayOfMonth)))) ==0){
						$$callParameters{'coversToday'}=1;
					}
  				}
  				
  				
  				if ($flag<0) {						#Everything OK, Dates are in the right order

					my $yearDifference = $7-$3; 	#Check if we're in the same year
					if($yearDifference>1){			#If not the same year + whole year(s) to cover
						for(my $i=1; $i<$yearDifference; $i++){
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Whole year to cover: ".($3+$i).")" ) if $debug;
							for(my $k=1; $k<13;$k++){
								push(@$datesPeriods, {year => $3+$i,  month  => sprintf("%02d", $k),  days  => ""} );
							}
							
						}
					}

					my @dateToAnylyze;
					#Whole months to cover
					if($yearDifference>0){
													#From the "second" month of the "first" yer to the end of that year
						for(my $searchMonth= $monthsNo{$2}+1;$searchMonth<13;$searchMonth++){
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Whole month to analize: ".$months[$searchMonth-1]." $3)" ) if $debug;
							push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $searchMonth),  days  => ""} );
						}
						
													#From the first month of the last year to the one before last month
						for(my $searchMonth= 1;$searchMonth<$monthsNo{$6};$searchMonth++){
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Whole month to analize: ".$months[$searchMonth-1]." $7)" ) if $debug;
								push(@$datesPeriods, {year => $7,  month  => sprintf("%02d", $searchMonth),  days  => ""} );
						}
					}else{ 						#If both dates are in the same year
												#From the "second" month to the "one before last" month
						for(my $searchMonth= $monthsNo{$2}+1;$searchMonth<$monthsNo{$6};$searchMonth++){
							TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Whole month to analize: ".$months[$searchMonth-1]." $3)" ) if $debug;
							push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $searchMonth),  days  => ""} );
						}
						
					}
					
												#Covering days in a month
												#Checking if the same month
					if( ($yearDifference ==0) && ($monthNo1==$monthNo2) ){
						TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Days are in the same month)" ) if $debug;
						my $days="";
												#Checking if covers the whole month
						my $dt = Date::Calc::Days_in_Month($3,  $monthsNo{$2});
						$days="$1-$5" unless ($1==1 && ($dt==$5) );
						push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $monthsNo{$2}),  days  => $days} );

					}else{						#Different month. Generating dates for RE for the 1st and the last months
						TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Days from two months to cover)" ) if $debug;
						my $days="";
												#First month
												#Checking if covers the whole month
						my $dt = Date::Calc::Days_in_Month($3, $monthsNo{$2});
						$days="$1-".$dt unless( $1==1 );
						push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $monthsNo{$2}),  days  => $days} );

						
												#Last month
												#Checking if covers the whole month
						$days="";
						$dt = Date::Calc::Days_in_Month($7, $monthsNo{$6});
						$days="01-$5" unless ( $5 == $dt);
						push(@$datesPeriods, {year => $7,  month  => sprintf("%02d", $monthsNo{$6}),  days  => $days} );


					}		
  				} elsif ($flag==0) { #Dates cover only one day
  						push(@$datesPeriods, {year => $3,  month  => sprintf("%02d", $monthsNo{$2}),  days  => $1} );

  				} else {
 				TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Dates are in the wrong order)" ) if $debug;
 				return "Dates are in the wrong order";
			  }		
			}else{
				TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Wrong date)" ) if $debug;
				return "Wrong date\n";
			}

		}else{
			TWiki::Func::writeDebug( "- ${pluginName}::_analyzeDates( Wrong parameters)" ) if $debug;
			return "Wrong parameters\n";
		}
	}
		
	return 0;
}







1;
