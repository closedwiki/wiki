#please output results and errors to the dir specified on the command line

print "running tests\n";

cd unit
date=`date | sed -e s/[ \t\n]//g``
perl ../bin/TestRunner.pl TWikiUnitTestSuite > $1/unit$date
