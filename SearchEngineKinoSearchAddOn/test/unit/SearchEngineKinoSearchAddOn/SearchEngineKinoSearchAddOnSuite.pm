package SearchEngineKinoSearchAddOnSuite;
use base qw(Unit::TestSuite);

sub include_tests {
    #qw( KinoSearchTests IndexTests SearchTests Doc_antiwordTests XlsTests PdfTests TxtTests HtmlTests PptTests);
    qw( IndexTests );
    #qw( XlsTests );
};

1;
