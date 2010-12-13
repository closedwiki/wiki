#!/usr/bin/perl -wT

use CGI;
use URI::Escape;

my $query = new CGI;
$query->import_names('Q');

if ( $Q::url ) {
  my $url = URI::Escape::uri_unescape($Q::url);
  print "Content-type: text/html


<html>
<head>
  <title>You Are Exiting The TWiki Web Server</title>
  <meta http-equiv=\"refresh\" content=\"0; URL=${url}\"></head>

<body>

<b>
Thank you for visiting.
Click on the following link to go to:
</b>
</p>
<a href=\"${url}\">${url}</a>

<b>
(or you will be taken there immediately)
<hr>
</b>

</body>
</html>
";

} else {

  print "Content-type: text/plain


Bad call to exit.cgi
";

}
