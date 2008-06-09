<?php
// $Header: /cvsroot/html2ps/css.page-break-after.inc.php,v 1.3 2007/01/09 20:13:48 Konstantin Exp $

class CSSPageBreakAfter extends CSSPageBreak {
  function get_property_code() {
    return CSS_PAGE_BREAK_AFTER;
  }

  function get_property_name() {
    return 'page-break-after';
  }
}

CSS::register_css_property(new CSSPageBreakAfter);

?>