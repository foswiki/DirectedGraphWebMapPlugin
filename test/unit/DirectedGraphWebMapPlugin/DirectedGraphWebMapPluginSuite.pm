package DirectedGraphWebMapPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'DirectedGraphWebMapPluginSuite' }

#sub include_tests { qw(DirectedGraphWebMapPluginTests DirectedGraphWebMapPluginPrefsTests) };
sub include_tests { qw(DirectedGraphWebMapPluginTests) }

1;
