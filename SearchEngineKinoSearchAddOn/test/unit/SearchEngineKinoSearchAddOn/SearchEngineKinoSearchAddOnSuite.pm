package SearchEngineKinoSearchAddOnSuite;
use base qw(Unit::TestSuite);

sub include_tests {
    qw( KinoSearchTests IndexTests SearchTests DocTests XlsTests PdfTests TxtTests HtmlTests PptTests);
};

1;
