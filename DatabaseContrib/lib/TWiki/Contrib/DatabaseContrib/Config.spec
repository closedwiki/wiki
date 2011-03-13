#---+ DatabaseContrib
# **TEXT 20**
# <h2>Setup for Local databases table</h2>
# Table of configuration info for all the databases you might access.
# This structure is a hash of connection definitions. Each connection
# is defined using a hash reference where the fields are:
# <ol>
# <li> description - Symbolic name for this database</li>
# <li> driver - DB driver - values like: mysql, Oracle, etc.</li>
# <li> host - DB host</li>
# <li> database - DB name</li>
# <li> user - DB username</li>
# <li> password - DB password</li>
# <li> codepage - character information, such as utf8</li>
# <li> allow_do - hash reference of TWiki topics that contain data base access to lists of allowed users</li>
# </ol>
$TWiki::cfg{Plugins}{DatabaseContrib}{connections} =
  (
	message_board => {
	    user => 'dbuser',
	    password => 'dbpasswd',
	    driver => 'mysql',
	    database => 'message_board',
	    codepage => 'utf8',
	    allow_do => {
		default => [qw(TWikiAdminGroup)],
		'Sandbox.CommonDiscussion' => [qw(TWikiGuest)],
	    },
	    # host => 'localhost',
	},
  );
