use lib ('.');
use lib ('../../../..');
use TWiki::Plugins::TocPlugin::Attrs;
use Assert;

{ package AttrsTests;

# Attrs tests
my $attrs = Attrs->new("a");
Assert::assert(__LINE__, defined($attrs->get("a")));
$attrs = Attrs->new("a=b");
Assert::sEquals(__LINE__, $attrs->get("a"), "b");
$attrs = Attrs->new("{a=b,c=\"d\",e=f}");
Assert::sEquals(__LINE__, $attrs->get("a"), "b");
Assert::sEquals(__LINE__, $attrs->get("c"), "d");
Assert::sEquals(__LINE__, $attrs->get("e"), "f");
$attrs = Attrs->new("a==b,c=\"d\",e=f");
Assert::sEquals(__LINE__, $attrs->get("a"), "=b");
Assert::sEquals(__LINE__, $attrs->get("c"), "d");
Assert::sEquals(__LINE__, $attrs->get("e"), "f");
Assert::sEquals(__LINE__, $attrs->set("a", 5), "=b");
Assert::sEquals(__LINE__, $attrs->get("a"), 5);
}
1;
