use strict;

package CliRunnerContribTests;

use base qw(TWikiTestCase);

use TWiki::Contrib::CliRunnerContrib;

use File::Temp;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}


# ----------------------------------------------------------------------
# Purpose:  Basic sanity test for the 'no' module.
# Verifies: A plain view returns Main.Webhome
sub test_runner {
    my $this     =  shift;
    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    my $result   =  $runner->run();
    $this->assert_matches(qr/Main.*WebHome/,$result);
}


# ----------------------------------------------------------------------
# Purpose:  Pseudo-remove a module (CGI) which is required by TWiki
# Verifies: Compilation error mentioning the "missing" module
sub test_runner_noCGI {
    my $this     =  shift;
    my $missing  =  'CGI';

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->no($missing);
    my $result   =  $runner->run();
    $this->assert_matches($runner->error_missing_module($missing),$result);
}


# ----------------------------------------------------------------------
# Purpose:  Empty configuration changes should not load the TWikiCfg hack
# Verifies: Command generated by the runner does not contain the module
sub test_runner_noCfg {
    my $this     =  shift;

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->twikiCfg();
    $this->assert($runner->command() !~ /::TWikiCfg/, "Error: Expanded TWikiCfg option");
}


# ----------------------------------------------------------------------
# Purpose:  Basic manipulation of configuration for SuperAdminGroup
# Verifies: Command generated by the runner activates TWikiCfg
#           Command generated points to changed topic
#           Topic TWiki.VarWIKINAME contains the changed value
# Assumes:  Per default, command line scripts run as SuperAdminGroup
sub test_runner_cfgSuperAdminGroup {
    my $this     =  shift;

    my $topic  =  'TWiki.VarUSERNAME';
    my $user   =  'PonderStibbons';

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->twikiCfg(SuperAdminGroup => $user);
    $runner->topic($topic);
    $this->assert_matches(qr/::TWikiCfg/,$runner->command());
    $this->assert_matches(qr/$topic/,$runner->command());
    my $result  =  $runner->run();
    $this->assert_matches(qr/$user/,$result);
}


# ----------------------------------------------------------------------
# Purpose:  Basic manipulation of configuration via Config file
# Verifies: Command generated by the runner activates TWikiCfg
#           Command generated points to changed topic
#           Topic TWiki.VarWIKINAME contains the changed value
# Assumes:  Per default, command line scripts run as SuperAdminGroup
sub test_runner_cfgFile {
    my $this     =  shift;

    my $topic  =  'TWiki.VarUSERNAME';
    my $user   =  'PonderStibbons';

    my ($cfgHandle,$cfgFileName)  =  File::Temp::tempfile();
    print $cfgHandle q($TWiki::cfg{'SuperAdminGroup'}='),$user,q(';);
    close $cfgHandle;

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->twikiCfgFile($cfgFileName);
    $runner->topic($topic);
    $this->assert_matches(qr/::TWikiCfg/,$runner->command());
    $this->assert_matches(qr/$topic/,$runner->command());
    my $result  =  $runner->run();
    $this->assert_matches(qr/$user/,$result);

    unlink $cfgFileName;
}


# ----------------------------------------------------------------------
# Purpose:  Add some options to the script
# Verifies: Presence of options in the command line generated
sub test_runner_addScriptOptions {
    my $this     =  shift;

    my $user   =  'PonderStibbons';

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->addScriptOptions(raw => 'on', user => $user);
    $this->assert_matches(qr/\braw\s+on\b/,$runner->command());
    $this->assert_matches(qr/\buser\s+$user\b/,$runner->command());
}


# ----------------------------------------------------------------------
# Purpose:  Test defaulting of script option
# Verifies: Presence of default script in the command line generated
sub test_runner_noScript {
    my $this     =  shift;

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $this->assert_matches(qr/\bview\b/,$runner->command());
}


# ----------------------------------------------------------------------
# Purpose:  Test initial, and changed perl options
# Verifies: initial option is -T
#           changed option is -yadda
sub test_perlOptions {
    my $this     =  shift;

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    my $default =  $runner->command();
    $this->assert_matches(qr/\s-T\s/,$default);
    my $actual  =  $runner->perlOptions('-yadda');
    $this->assert_equals($actual,'-yadda');
    my $changed =  $runner->command();
    $this->assert_matches(qr/\s-yadda\s/,$changed);
}


# ----------------------------------------------------------------------
# Purpose:  Test syntax for CGI.pm parameter passing
# Verifies: correct path construction
sub test_CGIstyleParams {
    my $this     =  shift;

    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->callingConvention('CGI');
    $this->assert_equals($runner->callingConvention(),'CGI');
    $runner->addScriptOptions(action    => 'InstallExtension');
    $runner->addScriptOptions(cfgAccess => 'Password');
    $this->assert_matches(qr/(\?|;)action=InstallExtension/,$runner->command());
    $this->assert_matches(qr/(\?|;)cfgAccess=Password/,$runner->command());
}


1;
