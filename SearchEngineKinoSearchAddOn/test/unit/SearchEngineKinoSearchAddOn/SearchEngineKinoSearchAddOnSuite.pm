package SearchEngineKinoSearchAddOnSuite;
use base qw(Unit::TestSuite);

sub include_tests {
    qw( KinoSearchTests IndexTests DocTests XlsTests PdfTests TxtTests HtmlTests);
};

1;
