require 5.006;

package WysiwygPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'WysiwygPluginTests' };

sub include_tests {
    qw(TranslatorTests);
};

1;
