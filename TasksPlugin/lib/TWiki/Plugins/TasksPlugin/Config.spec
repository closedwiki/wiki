# ---+ Off-line Tasks
# Settings for the off-line task execution framework
# <P>
# TWiki performs background maintenance tasks using a system daemon.  This section configures the daemon,
# its built-in tasks, as well as add-on tasks supplied by other TWiki plugins/extensions.
#
# <P> <u>Please return to this page after changing any configuration item in this section</u>, 
# as many configuration diagnostics and confirmations are provided.  
#
# <P>Common to all tasks are schedule items, which specify the schedules on which you want these tasks run.  Sechedule
# items use the time spec portion of vixie-cron <b><i>crontab</i></b> format.  <br />You may find more documentation
# of this format using <b><i>man 5 crontab</i></b> on a unix/linux system.
# <p> Although crontab format is used, the fields are displayed in a more intuitive order here.  Note that you can specify
# multiple values in the drop-down controls, except '*', which matches any time and stands alone.
#<p> The next several sections configure the daemon and its sub-components.  If you have a complex environment or need
# to debug the daemon or its add-ons, you may need to adjust the <b>expert</b> settings of this section.
#---++ Task execution environment
# These settings define the execution environment for tasks.
# **STRING 20**
# Login Name (not WikiName) of user under which tasks are scheduled.
$TWiki::cfg{Tasks}{UserLogin} = $TWiki::cfg{AdminUserLogin};
# **STRING 30**
# Task administrator's e-mail address e.g. <code>webmaster@example.com</code> or
# <code>"Web Supervisor" &lt;webmaster@example.com&gt;</code>
# Output from off-line tasks will be e-mailed to this address (like cron).
# <br />If blank, {WebMasterEmail} will be used.  May be over-ridden by task.
# NOTE: must be a single valid email address
$TWiki::cfg{Tasks}{AdministratorEmail} = '';
# **OCTAL EXPERT**
# File security (umask) for files written by tasks.  Should generally prevent world access.
$TWiki::cfg{Tasks}{Umask} = 007;
# **SELECTCLASS TWiki::Tasks::Watchfile::***
# File monitoring can be done by the default polling class or by a system-specific driver 
# that interfaces to the file system's monitoring facilities.  On Linux, this is <i>inotify</i>.  When available, the file
# system's monitoring is more efficient and more timely.
# <p>  Using the file system's monitoring requires installation of a perl interface module and a
# task daemon driver.  <p>The following selection box includes all installed task daemon drivers.
# After selecting one and saving the configuration, run configure again.  Errors will be
# indicated if the one you selected is missing any of its dependencies.
$TWiki::cfg{Tasks}{FileMonitor} = 'TWiki::Tasks::Watchfile::Polled';
#---++ Daemon logging and control
# **PATH**
# Log file for serious errors (what would go to the webserver error log if running under a webserver). %DATE% gets expanded
# to YYYYMM (year, month), allowing you to rotate logs.
$TWiki::cfg{ErrorFileName} = '$TWiki::cfg{DataDir}/error%DATE%.txt';
# **NUMBER EXPERT**
# The Task Framework maintains an event log in memory for status and debugging.  
# Specify the size of the in-memory log (in lines).  Note that this does
# not limit what is written to log files.
$TWiki::cfg{Tasks}{LogBufferSize} = 125;
# **STRING 40 EXPERT**
# File name used in the URL to access the daemon for startup.  The full URL used is {DefaultUrlHost}{ScriptUrlPath}/this item.
$TWiki::cfg{Tasks}{StartupUrlName} = 'TaskDaemon';
# ---++ Daemon Networking
# The daemon contains a built-in webserver, which is used by the TWiki plugin for TWiki topics that allow you to monitor and
# manage the daemon.
# This is <b>not</b> a general purpose webserver, and does not need to be accessible to TWiki users.  
# **STRING 64**
# Hostname & port for daemon control.  This is the address on which the daemon listens,  Specify
# 0.0.0.0:<i>port</i> to listen on all IPV4 addresses, [::]:<i>port</i> to listen on all IPV6 addresses, 
# or use a specific hostname or address to listen on only one.  IPV6 addresses must be in []s.
# The port number must be specified, and the webserver user must be permitted to use it.
# This is used for daemon administration, not general users.  <code>localhost</code> is recommended if http is used, but
# note that this is restrictive.  If https is used, server certificate must match this hostname since clients do host
# verification.
$TWiki::cfg{Tasks}{StatusServerAddr} = 'localhost:1026';
# **STRING 64**
# Hostname and port used to <em>connect to</em> the daemon control port.  Must <em>not</em> be 0.0.0.0,
# and must resolve to one of {Tasks}{StatusServerAddr}'s endpoints.
$TWiki::cfg{Tasks}{StatusAddr} = 'localhost:1026';
# **SELECT https,http**
# Protocol for daemon control.  Use https if at all possible for security - specify server details in the following items.
# Use http only if https is not available - in which case, we recommend setting {Tasks}{StatusServerAddr} to <code>localhost</code>.
$TWiki::cfg{Tasks}{StatusServerProtocol} = 'http';
# **PATH**
# X.509 status server certificate file, only required for https.  Must be in PEM format; can be world readable.
# <p>If your issuer requires an intermediate CA certificate(s), include them in this file after the server's certificate in order from least to most authoritative CA.
$TWiki::cfg{Tasks}{StatusServerCertificate} = '';
# **PATH**
# X.509 status server private key file, only required for https.  Must be in PEM format with strict permissions.
$TWiki::cfg{Tasks}{StatusServerKey} = '';
# **PASSWORD 64**
# X.509 status server private key password, only required for https if {Tasks}{StatusServerKey} is encrypted.  This is does not
# provide much security because (unfortunately) this configuration entry is not encrypted.  
$TWiki::cfg{Tasks}{StatusServerKeyPassword} = '';
# **BOOLEAN**
# Require verification of client certificates by the status server, available and optional for https.  If you enable this
# option, you must provide a <b>client</b> certificate for the daemon and the TasksPlugin to use for management.
# You must also specify either a Certificate Authority file or path in the items after this.  And {Tasks}{StatusAddr}
# needs to be verifiable from {Tasks}{StatusServerCertificate}, unless it is <code>localhost</code>.
$TWiki::cfg{Tasks}{StatusServerVerifyClient} = 0;
# **PATH**
# X.509 client certificate file containing the certificate that the daemon itself uses.  Only required for https with
# client certificate verification enabled.  Must be in PEM format; can be world readable.
$TWiki::cfg{Tasks}{DaemonClientCertificate} = '';
# **PATH**
# X.509 client private key file containing the private key of certificate that the daemon itself uses.  Only required for https with
# client certificate verification enabled.  Must be in PEM format; with strict permissions.
$TWiki::cfg{Tasks}{DaemonClientKey} = '';
# **PASSWORD 64**
# X.509 daemon client private key password, only required for https if {Tasks}{DaemonClientKey} is encrypted.  This is does not
# provide much security because (unfortunately) this configuration entry is not encrypted.  
$TWiki::cfg{Tasks}{DaemonClientKeyPassword} = '';
# **PATH**
# Certificate authority file containing one or more certificates of CAs acceptable for client certificate verification.
$TWiki::cfg{Tasks}{StatusServerCAFile} = '';
# **PATH**
# Directory containing certificates of CAs acceptable for client certificate verification.  May also contain CRLs.
# Must be hashed (see the OpenSSL documentation).  {Tasks}{StatusServerCAFile} is a simpler alternative.
$TWiki::cfg{Tasks}{StatusServerCAPath} = '';
# **BOOLEAN**
# Require client certificate verification to check for revocation using the issuer's CRL.
$TWiki::cfg{Tasks}{StatusServerCheckCRL} = 0;
# **PATH**
# Certificate revocation list file for client certificate verification.  If {Tasks}{StatusServerCAPath} contains CRLs,
# leave this blank.
$TWiki::cfg{Tasks}{StatusServerCrlFile} = '';
# **REGEXP 128**
# If the client certificate must be issued by a particular party, enter a regular expression to specify what issuer(s)
# are acceptable.  The actual issuer string of a certificate can be obtained using <code>openssl x509 -issuer</code>.
# Leave empty if any issuer is acceptable.  Note that this still requires the issuer's certificate to validate.  Also,
# note that the <b>client</b> certificate used by the daemon itself must satisfy this expression.
$TWiki::cfg{Tasks}{StatusServerClientIssuer} = '';
# **REGEXP 128**
# If the client certificate's subject must be validated, enter a regular expression to specify what subject(s)
# are acceptable.  The actual subject string of a certificate can be obtained using <code>openssl x509 -subject</code>.
# Leave empty if any subject is acceptable.  Note that this still requires the subject's certificate to validate.  Also,
# note that the <b>client</b> certificate used by the daemon itself must satisfy this expression.
$TWiki::cfg{Tasks}{StatusServerClientSubject} = '';
# **SELECT TLSv1,SSLv3 EXPERT**
# SSL protocol version.  TLSv1 is prefered; SSLv3 may be used for compatibility with some very old web browsers, but is not
# recommended.
$TWiki::cfg{Tasks}{StatusServerSslVersion} = 'TLSv1';
# **STRING 80 EXPERT**
# X.509 status server cipher list.  Specifies the acceptable ciphers for SSL connections.  See the OpenSSL documentation
# (<code>man ciphers</code>) for details.  Default is high security; you would need to adjust only if high security ciphers
# aren't available in your locale.
$TWiki::cfg{Tasks}{StatusServerCiphers} = 'RC4-SHA:AES128-SHA:ALL:!ADH:!EXP:!LOW:!MD5:!SSLV2:!NULL';
# **BOOLEAN EXPERT**
# For debugging tasks (and the daemon itself), this enables a special server that provides a telnet
# command line interface to the running daemon.  <em>Do not enable this on a production system</em>.
# This is an interface for programmers and permits unrestricted access to the webserver account.
# Do <em>not</em> enable this unless you control access to the server, have complete and <em>tested</em>
# backups, and are able to take responsibility for any adverse consequences.
$TWiki::cfg{Tasks}{DebugServerEnabled} = 0;
# **STRING 64 EXPERT**
# Hostname & port for daemon debugging.  This is the address on which the daemon debugger listens,  Specify
# 0.0.0.0:<i>port</i> to listen on all IPV4 addresses, [::]:<i>port</i> to listen on all IPV6 addresses, 
# or use a specific hostname or address to listen on only one.  IPV6 addresses must be in []s.
# The port number must be specified, and the webserver user must be permitted to use it.
# This is used <em>only</em> for programmers, not for administrator or for general users.  
# <code>localhost</code> is <em>strongly</em> recommended.
$TWiki::cfg{Tasks}{DebugServerAddr} = 'localhost:1042';
# **REGEX 64 EXPERT**
# If daemon debugging is enabled, the configure password is required to access the debugger.  
# If you are in a <em>very</em> safe environment (such as an isolated virtual machine on a single-user
# system) you may prefer to eliminate the password requirement when connecting from trusted hosts.
# <p>This amplifies the danger of enabling the debugger since it provides access to the webserver's
# privileges with no password security.  If, despite this warning, you want to trust one or more
# hosts, enter a regular expression for those hosts here.  Note that you must match the remote port number
# as well as the hostname.  E.g. <code>^(?:(?:trusted1|trusted2)\.example\.com|localhost):\d+$</code>
$TWiki::cfg{Tasks}{DebugTrustedHost} = '';
# **STRING EXPERT**
# Group name required to access PTY devices (for debugging).  Only set if necessary, must also put webserver user into
# this group if it is.  Not required for Linux.
$TWiki::cfg{Tasks}{DebugTtyGroup} = '';
# **STRING 80 EXPERT**
# If you need to debug an externally-scripted task (instantiated with <code>command => 'scriptname'</code>)
# using the perl debugger, you may need to specify where the debugger's terminal window is created.
# <p>If you are running a private copy of the daemon (e.g. -f), your terminal window will be used and
# this configuration item will be ignored.
# <p>Otherwise, set this configuration variable according to your operating system:
# <ul>
# <li>  X-window system (most Unix OSs): <code>TERM=xterm|DISPLAY=:0.0</code>.  The value for DISPLAY can
# be any DISPLAY supported by your  system.  Often <code>echo $DISPLAY</code> in a terminal window will provide the value you need.
# Don't forget to set =.Xauthority= for the webserver account.  You can set <code>XAUTHORITY=/path/.Xauthority</code> here if
# necessary, but be careful that permissions are set correctly.
# <li> Apple systems (Leopard or later): <code>TERM_PROGRAM=Apple_Terminal|TERM_PROGRAM_VERSION=237</code>
# Use <code>echo $TERM_PROGRAM;echo $TERM_PROGRAM_VERSION</code> in a terminal window to verify these values for your system.
# </ul>
# You must also activate the perl debugger with <code>-w</code> in the <code>#!</code> line of your script.
$TWiki::cfg{Tasks}{DebugTerminal} = '';
#---++ Built-in tasks
# Tasks included in the base product.
#
# **SCHEDULE**
# Schedule for internal tasks (previously run by tick_twiki) such as expired sessions and edit locks.
# <br />
# Also the cleanup schedule used by simple plugins.
# <br />
# The default is to run at 01:15:14 every 3 days.
$TWiki::cfg{CleanupSchedule} = '1 15 1-31/3 * * 14';
# **SCHEDULE EXPERT**
# Times at which the daemon checks for configuration changes and polls other events when an asynchronous notification
# mechanism is not available.  
$TWiki::cfg{Tasks}{PolledEventsSchedule} = '*/5 * * * * 17';

#---++ Add-on tasks
# Task interface modules supplied by other add-ons/extensions/contribs.<br />
# The following extension interfaces were detected:
# *TASKS* Marker used by bin/configure script.
$TWiki::cfg{Tasks}{Tasks}{NoTaskListMarkerDontDeleteMe}{enabled} = 0;
## The above entry is necessary for the spec parser to work, but since there is
## no file of that name, it doesn't do any harm.

1;
