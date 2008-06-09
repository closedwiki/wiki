<?php
/**
 * Handle  @page rules  in  current CSS  media  As parse_css_media  is
 * called for  selected media  only, we can  store data to  global CSS
 * state - no data should be ignored
 *
 * at-page rules will be removed after parsing
 *
 * @param $css String contains raw CSS data to be processed
 * @return String CSS text without at-page rules
 */
function parse_css_atpage_rules($css, &$css_ruleset) {
  while (preg_match('/^(.*?)@page(.*)/is', $css, $matches)) {
    $data = $matches[2];
    $css = $matches[1].parse_css_atpage_rule(trim($data), $css_ruleset);
  };
  return $css;
}

function parse_css_atpage_rule($css, &$css_ruleset) {
  /**
   * Extract selector and left bracket
   */
  if (!preg_match('/^(.*?){(.*)$/is', $css, $matches)) {
    error_log('No selector and/or open bracket found in @page rule');
    return $css;
  };
  $raw_selector = trim($matches[1]);
  $css          = trim($matches[2]);

  $selector =& parse_css_atpage_selector($raw_selector);
  $at_rule =& new CSSAtRulePage($selector, $css_ruleset);

  /**
   * The body of @page rule may contain declaraction (detected by ';'),
   * margin box at-rule (detected by @top and similar tokens) or } indicating termination of
   * @page rule
   */
  while (preg_match('/^(.*?)(;|@|})(.*)$/is', $css, $matches)) {
    $raw_prefix = trim($matches[1]);
    $raw_token  = trim($matches[2]);
    $raw_suffix = trim($matches[3]);

    switch ($raw_token) {
    case ';':
      /**
       * Normal declaration (text contained in $raw_prefix
       */
      parse_css_atpage_declaration($raw_prefix, $at_rule, $css_ruleset);
      $css = $raw_suffix;
      break;

    case '@':
      /**
       * Margin box at-rule
       */
      $css = parse_css_atpage_margin_box($raw_suffix, $at_rule, $css_ruleset);
      break;

    case '}':
      /**
       * End-of-rule
       */
      $css_ruleset->add_at_rule_page($at_rule);
      return $raw_suffix;
    };
  };

  /**
   * Note that we should normally exit via '}' token handler above
   */
  error_log('No close bracket found in @page rule');
  $css_ruleset->add_at_rule_page($at_rule);
  return $css;
}

/**
 * Parses CSS at-page rule selector; syntax of this selector can be seen in
 * CSS 3 specification at http://www.w3.org/TR/css3-page/#syntax-page-selector
 *
 *
 */
function &parse_css_atpage_selector($selector) {
  switch ($selector) {
  case '':
    $selector =& new CSSPageSelectorAll();
    return $selector;
  case ':first':
    $selector =& new CSSPageSelectorFirst();
    return $selector;
  case ':left':
    $selector =& new CSSPageSelectorLeft();
    return $selector;
  case ':right':
    $selector =& new CSSPageSelectorRight();
    return $selector;
  default:
    if (CSS::is_identifier($selector)) {
      $selector =& new CSSPageSelectorNamed($selector);
      return $selector;
    } else {
      error_log(sprintf('Unknown page selector in @page rule: \'%s\'', $selector));
      $selector =& new CSSPageSelectorAll();
      return $selector;
    };
  };
}

function parse_css_atpage_margin_box($css, &$at_rule, &$pipeline) {
  if (!preg_match("/^([-\w]*)\s*{(.*)/is",$css,$matches)) {
    error_log("Invalid margin box at-rule format");
    return $css;
  };

  $raw_margin_box_selector = trim($matches[1]);
  $css                     = trim($matches[2]);

  $margin_box_selector = parse_css_atpage_margin_box_selector($raw_margin_box_selector);
  $at_rule_margin_box = new CSSAtRuleMarginBox($margin_box_selector, $pipeline);

  /**
   * The body of margin box at-rule may contain declaraction (detected
   * by ';'), or } indicating termination of at-rule
   */
  while (preg_match('/^(.*?)(;|})(.*)$/is', $css, $matches)) {
    $raw_prefix = trim($matches[1]);
    $raw_token  = trim($matches[2]);
    $raw_suffix = trim($matches[3]);

    switch ($raw_token) {
    case ';':
      /**
       * Normal declaration (text contained in $raw_prefix
       */
      parse_css_atpage_margin_box_declaration($raw_prefix, $at_rule_margin_box, $pipeline);
      $css = $raw_suffix;
      break;

    case '}':
      /**
       * End-of-rule
       */
      $at_rule->addAtRuleMarginBox($at_rule_margin_box);
      return $raw_suffix;
    };
  };

  /**
   * Note that we should normally exit via '}' token handler above
   */
  error_log('No close bracket found in margin box at-rule');
  $at_rule->addAtRuleMarginBox($at_rule_margin_box);
  return $css;
}

function parse_css_atpage_margin_box_selector($css) {
  switch ($css) {
  case 'top':
    return CSS_MARGIN_BOX_SELECTOR_TOP;
  case 'top-left-corner':
    return CSS_MARGIN_BOX_SELECTOR_TOP_LEFT_CORNER;
  case 'top-left':
    return CSS_MARGIN_BOX_SELECTOR_TOP_LEFT;
  case 'top-center':
    return CSS_MARGIN_BOX_SELECTOR_TOP_CENTER;
  case 'top-right':
    return CSS_MARGIN_BOX_SELECTOR_TOP_RIGHT;
  case 'top-right-corner':
    return CSS_MARGIN_BOX_SELECTOR_TOP_RIGHT_CORNER;
  case 'bottom':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM;
  case 'bottom-left-corner':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM_LEFT_CORNER;
  case 'bottom-left':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM_LEFT;
  case 'bottom-center':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM_CENTER;
  case 'bottom-right':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM_RIGHT;
  case 'bottom-right-corner':
    return CSS_MARGIN_BOX_SELECTOR_BOTTOM_RIGHT_CORNER;
  case 'left-top':
    return CSS_MARGIN_BOX_SELECTOR_LEFT_TOP;
  case 'left-middle':
    return CSS_MARGIN_BOX_SELECTOR_LEFT_MIDDLE;
  case 'left-bottom':
    return CSS_MARGIN_BOX_SELECTOR_LEFT_BOTTOM;
  case 'right-top':
    return CSS_MARGIN_BOX_SELECTOR_RIGHT_TOP;
  case 'right-middle':
    return CSS_MARGIN_BOX_SELECTOR_RIGHT_MIDDLE;
  case 'right-bottom':
    return CSS_MARGIN_BOX_SELECTOR_RIGHT_BOTTOM;
  default:
    error_log(sprintf('Unrecognized margin box selector: \'%s\'', $css));
    return CSS_MARGIN_BOX_SELECTOR_TOP;
  }
};

function parse_css_atpage_declaration($css, &$at_rule, &$pipeline) {
  $parsed =& parse_css_property($css, $pipeline);

  if (!is_null($parsed)) {
    $properties = $parsed->getPropertiesSortedByPriority();
    foreach ($properties as $property) {
      $at_rule->setCSSProperty($property);
    };
  };
}

function parse_css_atpage_margin_box_declaration($css, &$at_rule, &$pipeline) {
  $parsed =& parse_css_property($css, $pipeline);

  if (!is_null($parsed)) {
    $properties = $parsed->getPropertiesSortedByPriority();
    foreach ($properties as $property) {
      $at_rule->setCSSProperty($property);
    };
  };
}
?>
