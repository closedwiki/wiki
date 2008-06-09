<?php

define('UNARY_OPERATOR_PLUS', 1);
define('UNARY_OPERATOR_MINUS', 2);

define('OPERATOR_SLASH', 1);
define('OPERATOR_COMMA', 2);
define('OPERATOR_EMPTY', 3);

define('COMBINATOR_PLUS', 1);
define('COMBINATOR_GREATER', 2);
define('COMBINATOR_EMPTY', 3);

define('ATTRIB_OP_EQUAL', 1);
define('ATTRIB_OP_INCLUDES', 2);
define('ATTRIB_OP_DASHMATCH', 3);

// Token codes

define('CSS_TOKEN_IDENT', 1);
define('CSS_TOKEN_ATKEYWORD', 2);
define('CSS_TOKEN_STRING', 3);
define('CSS_TOKEN_INVALID', 4);
define('CSS_TOKEN_HASH', 5);
define('CSS_TOKEN_NUMBER', 6);
define('CSS_TOKEN_PERCENTAGE', 7);
define('CSS_TOKEN_DIMENSION', 8);
define('CSS_TOKEN_URI', 9);
define('CSS_TOKEN_UNICODE_RANGE', 10);
define('CSS_TOKEN_CDO', 11);
define('CSS_TOKEN_CDC', 12);
define('CSS_TOKEN_SEMICOLON', 13);
define('CSS_TOKEN_LBRACE', 14);
define('CSS_TOKEN_RBRACE', 15);
define('CSS_TOKEN_LPAREN', 16);
define('CSS_TOKEN_RPAREN', 17);
define('CSS_TOKEN_LBRACK', 18);
define('CSS_TOKEN_RBRACK', 19);
define('CSS_TOKEN_SPACE', 20);
define('CSS_TOKEN_COMMENT', 21);
define('CSS_TOKEN_FUNCTION', 22);
define('CSS_TOKEN_INCLUDES', 23);
define('CSS_TOKEN_DASHMATCH', 24);
define('CSS_TOKEN_DELIM', 25);

// (mostly) LL1-grammar for lexer:
/*

<IDENT_URI_FUNCTION_UNICODE> :: u<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: u
<IDENT_URI_FUNCTION_UNICODE> :: -<!IDENT_FUNCTION_CDC> :: -
<IDENT_URI_FUNCTION_UNICODE> :: [_a-z][^u] <!IDENT_FUNCTION_EMPTY> :: [_a-z][^u] 
<IDENT_URI_FUNCTION_UNICODE> :: [^\0-\177]<!IDENT_FUNCTION_EMPTY> :: [^\0-\177]
<IDENT_URI_FUNCTION_UNICODE> :: <!ESCAPE><!IDENT_FUNCTION_EMPTY> :: \

<ATKEYWORD> :: @<IDENT><?TOKEN_ATKEYWORD> :: @

<STRING_OR_INVALID> :: <!STRING1_START><!STRING_OR_INVALID_1_END> :: "
<STRING_OR_INVALID> :: <!STRING2_START><!STRING_OR_INVALID_2_END> :: '

<HASH> :: #<!NAME><?TOKEN_HASH> :: #

<NUM_PERC_DIM> :: <!NUM><!NUM_PERC_DIM_END> :: [0-9] | .

<CDO> :: <!--<?TOKEN_CDO> :: <

<SEMICOLON> :: ;<?TOKEN_SEMICOLON> :: ;

<LBRACE> :: {<?TOKEN_LBRACE> :: {

<RBRACE> :: }<?TOKEN_RBRACE> :: }

<LPAREN> :: (<?TOKEN_LPAREN> :: (

<RPAREN> :: )<?TOKEN_RPAREN> :: )

<LBRACK> :: [<?TOKEN_LBRACK> :: [

<RBRACK> :: ]<?TOKEN_RBRACK> :: ]

<SPACE> :: [ \t\r\n\f]<!W><?TOKEN_SPACE> :: [ \t\r\n\f]

<COMMENT> :: /*<!NOT_STAR_SEQ_OR_EMPTY><!STAR_SEQ><!COMMENT_CONTENT_SEQ_OR_EMPTY>/<?TOKEN_COMMENT> :: /

<INCLUDES> :: ~= :: ~

<DASHMATCH> :: |= :: |

<!IDENT_FUNCTION_CDC> :: <!NMSTART><!IDENT_FUNCTION_EMPTY> :: [_a-z] | [^\0-\177] | \
<!IDENT_FUNCTION_CDC> :: <!CDC2> :: -

<!CDC2> :: -><?TOKEN_CDC> :: -

<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: +<!UNICODE_RANGE> :: +
<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: r<!IDENT_URI_FUNCTION_EMPTY> :: r
<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: [_a-z0-9-][^r]<!IDENT_FUNCTION_EMPTY> :: [_a-z0-9-][^r] 
<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: [^\0-\177]<!IDENT_FUNCTION_EMPTY> :: [^\0-\177]
<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: <!ESCAPE><!IDENT_FUNCTION_EMPTY> :: \
<!IDENT_URI_FUNCTION_UNICODE2_EMPTY> :: <!FUNCTION_EMPTY> :: ( | END/OTHER

<!IDENT_URI_FUNCTION_EMPTY> :: l<!IDENT_URI_FUNCTION2_EMPTY> :: l
<!IDENT_URI_FUNCTION_EMPTY> :: [_a-z0-9-][^l]<!IDENT_FUNCTION_EMPTY> :: [_a-z0-9-][^l]
<!IDENT_URI_FUNCTION_EMPTY> :: [^\0-\177]<!IDENT_FUNCTION_EMPTY> :: [^\0-\177]
<!IDENT_URI_FUNCTION_EMPTY> :: <!ESCAPE><!IDENT_FUNCTION_EMPTY> :: \
<!IDENT_URI_FUNCTION_EMPTY> :: <!FUNCTION_EMPTY> :: ( | END/OTHER

<!IDENT_URI_FUNCTION2_EMPTY> :: (<!W><!URI2> :: (
<!IDENT_URI_FUNCTION2_EMPTY> :: <!NMCHAR><!IDENT_FUNCTION_EMPTY> :: [_a-z0-9-] | [^\0-\177] | \
<!IDENT_URI_FUNCTION2_EMPTY> :: <!EMPTY><?TOKEN_IDENT> :: END/OTHER

<!IDENT_FUNCTION_EMPTY> :: <!NMCHAR_SEQ><!FUNCTION_EMPTY> :: [_a-z0-9-] | [^\0-\177] | \
<!IDENT_FUNCTION_EMPTY> :: <!FUNCTION_EMPTY> :: ( | END/OTHER

<!FUNCTION_EMPTY> :: (<?TOKEN_FUNCTION> :: (
<!FUNCTION_EMPTY> :: <!EMPTY><?TOKEN_IDENT> :: END/OTHER

<!UNICODE-RANGE> :: [0-9a-f?]{1,6}(-[0-9a-f]{1,6})?<?TOKEN_UNICODE_RANGE> :: [0-9a-f?]

<!URI2> :: <!STRING><!W>)<?TOKEN_URI> :: "'
<!URI2> :: <!URI2_SEQ_OR_EMPTY><!W>)<?TOKEN_URI> :: [!#$%&*-~] | [^\0-\177] | \
<!URI2> :: <!BROKEN_URI_STRING><!W>)<?TOKEN_URI> :: OTHER

<!BROKEN_URI_STRING> :: [^)]<!BROKEN_URI_STRING> :: [^)]
<!BROKEN_URI_STRING> :: <EMPTY> :: ) | [ \t\r\n\f]

<!URI2_SEQ_OR_EMPTY> :: [!#$%&*-~]<!URI2_SEQ_OR_EMPTY> :: [!#$%&*-~]
<!URI2_SEQ_OR_EMPTY> :: <!NONASCII><!URI2_SEQ_OR_EMPTY> :: [^\0-\177]
<!URI2_SEQ_OR_EMPTY> :: <!ESCAPE><!URI2_SEQ_OR_EMPTY> :: \
<!URI2_SEQ_OR_EMPTY> :: <!EMPTY> :: [ \t\r\n\f] | ) | "' | [!#$%&*-~] | [^\0-\177] | \ 

<!COMMENT_CONTENT_SEQ_OR_EMPTY> :: [^/*]<!NOT_STAR_SEQ_OR_EMPTY><!STAR_SEQ><!COMMENT_CONTENT_SEQ_OR_EMPTY> :: [^/*]
<!COMMENT_CONTENT_SEQ_OR_EMPTY> :: <!EMPTY> :: /

<!NOT_STAR_SEQ_OR_EMPTY> :: [^*]<!NOT_STAR_SEQ_OR_EMPTY> :: [^*]
<!NOT_STAR_SEQ_OR_EMPTY> :: <!EMPTY> :: *

<!STAR_SEQ> :: *<STAR_SEQ2> :: *

<!STAR_SEQ2> :: *<STAR_SEQ2> :: *
<!STAR_SEQ2> :: <!EMPTY> :: [^/*] | /

<!W> :: [ \t\r\n\f]<!W> :: [ \t\r\n\f]
<!W> :: <!EMPTY> :: ) | "' | [!#$%&*-~] | [^\0-\177] | \ 
 
<!NUM_PERC_DIM_END> :: <!IDENT><?TOKEN_DIMENSION> :: - | [_a-z0-9] | [^\0-\177] | \
<!NUM_PERC_DIM_END> :: %<?TOKEN_PERCENTAGE> :: %
<!NUM_PERC_DIM_END> :: <!EMPTY><?TOKEN_NUMBER> :: END/OTHER

<!STRING> :: <!STRING1_START><!STRING1_END> :: "
<!STRING> :: <!STRING2_START><!STRING2_END> :: '

<!STRING1_START> :: \"<!STRING_CONTENT> :: "

<!STRING2_START> :: \'<!STRING_CONTENT> :: '

<!STRINT_CONTENT> :: [^\n\r\f\\"']<!STRING_CONTENT> :: [^\n\r\f\\"']
<!STRINT_CONTENT> :: \<!STRING_ESCAPE_OR_NL><!STRING_CONTENT> :: \
<!STRINT_CONTENT> :: <!EMPTY> :: " | ' | END/OTHER

<!STRING_OR_INVALID_1_END> :: <!STRING1_END> :: "
<!STRING_OR_INVALID_1_END> :: <!EMPTY><?TOKEN_INVALID> :: END/OTHER

<!STRING1_END> :: "<?TOKEN_STRING> :: "

<!STRING_OR_INVALID_2_END> :: <!STRING2_END> :: '
<!STRING_OR_INVALID_2_END> :: <!EMPTY><?TOKEN_INVALID> :: END/OTHER

<!STRING2_END> :: '<?TOKEN_STRING> :: '

<!STRING_ESCAPE_OR_NL> :: <!NL> :: \n|\r|\f
<!STRING_ESCAPE_OR_NL> :: <!ESCAPE2> :: [^\n\r\f0-9a-f] | [0-9a-f]
<!STRING_ESCAPE_OR_NL> :: <!EMPTY> :: ' | " | END/OTHER

<!NAME> :: <!NMCHAR_SEQ> :: [_a-z0-9-] | [^\0-\177] | \

<!IDENT> :: <!NMSTART><!NMCHAR_SEQ_EMPTY> :: [_a-z] | [^\0-\177] | \

<!NMSTART> :: [_a-z] :: [_a-z] 
<!NMSTART> :: <!NONASCII> :: [^\0-\177]
<!NMSTART> :: <!ESCAPE> :: \

<!NMCHAR_SEQ> :: <!NMCHAR><!NMCHAR_SEQ_EMPTY> :: [_a-z0-9-] | [^\0-\177] | \

<!NMCHAR_SEQ_EMPTY> :: <!NMCHAR><!NMCHAR_SEQ_EMPTY> :: [_a-z0-9-] | [^\0-\177] | \
<!NMCHAR_SEQ_EMPTY> :: <!EMPTY> :: END/OTHER

<!NMCHAR> :: [_a-z0-9-] :: [_a-z0-9-]
<!NMCHAR> :: <!NONASCII> :: [^\0-\177]
<!NMCHAR> :: <!ESCAPE> :: \

<!NONASCII> :: [^\0-\177] :: [^\0-\177]

<!ESCAPE> :: \<!ESCAPE2> :: \

<!ESCAPE2> :: [^\n\r\f0-9a-f] :: [^\n\r\f0-9a-f]
<!ESCAPE2> :: [0-9a-f]{1,6}(\r\n|[ \n\r\t\f])? :: [0-9a-f]

<!NL> :: \n :: \n
<!NL> :: \r<!NL2> :: \r
<!NL> :: \f :: \f

<!NL2> :: \n :: \n
<!NL2> :: <!EMPTY> :: [^\n\r\f\\"] | \ | ' | " | END/OTHER

<!NUM> :: [0-9]<!NUM2> :: [0-9]
<!NUM> :: .[0-9]<!NUM_END> :: .

<!NUM2> :: [0-9]<!NUM2> :: [0-9]
<!NUM2> :: .[0-9]<!NUM_END> :: .
<!NUM2> :: <!EMPTY> :: - | [_a-z] | [^\0-\177] | \ | % | END\OTHER

<!NUM_END> :: [0-9]<!NUM_END> :: [0-9]
<!NUM_END> :: <!EMPTY> :: - | [_a-z] | [^\0-\177] | \ | % | END\OTHER

*/

// (mostly) LL1-grammar for parser

/*

-- STYLESHEET :: ATKEYWORD["@charset"] | SPACE | ATKEYWORD["@import"] | HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | EOF
<STYLESHEET> :: ATKEYWORD["@charset"] <S_SEQ_EMPTY> STRING SEMICOLON <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET2> :: ATKEYWORD["@charset"]
<STYLESHEET> :: <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET2> :: ATKEYWORD["@import"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | IDENT | LBRACK | SPACE | EOF

-- STYLESHEET2 :: ATKEYWORD["@import"] | HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | EOF
<STYLESHEET2> :: <IMPORT> <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET2> :: ATKEYWORD["@import"]
<STYLESHEET2> :: <STYLESHEET3> :: ATKEYWORD["@media"] | ATKEYWORD["@page"] | DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | IDENT | LBRACK | EOF

-- STYLESHEET3 :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | EOF
<STYLESHEET3> :: <RULESET> <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET3> :: DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | IDENT | LBRACK 
<STYLESHEET3> :: <MEDIA> <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET3> :: ATKEYWORD["@media"]
<STYLESHEET3> :: <PAGE> <S_CDO_CDC_SEQ_EMPTY> <STYLESHEET3> :: ATKEYWORD["@page"]
<STYLESHEET3> :: <EMPTY> :: EOF

-- IMPORT :: ATKEYWORD["@import"]
<IMPORT> :: ATKEYWORD["@import"] <S_SEQ_EMPTY> <IMPORT2> :: ATKEYWORD["@import"]

-- IMPORT2 :: STRING | URI
<IMPORT2> :: STRING <S_SEQ_EMPTY> <IMPORT3> :: STRING
<IMPORT2> :: URI <S_SEQ_EMPTY> <IMPORT3> :: URI

-- IMPORT3 :: IDENT | SEMICOLON
<IMPORT3> :: <MEDIUM_SEQ> <IMPORT4> :: IDENT
<IMPORT3> :: <IMPORT4> :: SEMICOLON

-- IMPORT4 :: SEMICOLON
<IMPORT4> :: SEMICOLON <S_SEQ_EMPTY> :: SEMICOLON

-- MEDIA :: ATKEYWORD["@media"]
<MEDIA> :: ATKEYWORD["@media"] <S_SEQ_EMPTY> <MEDIUM_SEQ> LBRACE <S_SEQ_EMPTY> <RULESET_SEQ_EMPTY> RBRACE <S_SEQ_EMPTY> :: ATKEYWORD["@media"]

-- MEDIUM :: IDENT
<MEDIUM> :: IDENT <S_SEQ_EMPTY> :: IDENT

-- PAGE :: ATKEYWORD["@page"]
<PAGE> :: ATKEYWORD["@page"] <S_SEQ_EMPTY> <PAGE2>

-- PAGE2 :: DELIM[":"] | LBRACE
<PAGE2> :: DELIM[":"] IDENT <S_SEQ_EMPTY> <PAGE3> :: DELIM[":"]
<PAGE2> :: <PAGE3> :: LBRACE

-- PAGE3 :: LBRACE
<PAGE3> :: LBRACE <S_SEQ_EMPTY> <DECLARATION_SEQ> RBRACE <S_SEQ_EMPTY> :: LBRACE

-- OPERATOR :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION | DELIM["/"] | DELIM[","]
<OPERATOR> :: DELIM["/"] <S_SEQ_EMPTY> :: DELIM["/"]
<OPERATOR> :: DELIM[","] <S_SEQ_EMPTY> :: DELIM[","]
<OPERATOR> :: <EMPTY> :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION

-- COMBINATOR :: DELIM["+"] | DELIM[">"] | DELIM["*"] | DELIM["."] | DELIM[":"] | HASH | LBRACK | IDENT
<COMBINATOR> :: DELIM["+"] <S_SEQ_EMPTY> :: DELIM["+"]
<COMBINATOR> :: DELIM[">"] <S_SEQ_EMPTY> :: DELIM[">"]
<COMBINATOR> :: <EMPTY> :: DELIM["*"] | DELIM["."] | DELIM[":"] | HASH | LBRACK | IDENT

-- UNARY_OPERATOR :: DELIM["-"] | DELIM["+"]
<UNARY_OPERATOR> :: DELIM["-"] :: DELIM["-"]
<UNARY_OPERATOR> :: DELIM["+"] :: DELIM["+"]

-- PROPERTY :: IDENT
<PROPERTY> :: IDENT <S_SEQ_EMPTY> :: IDENT

-- RULESET :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"]
<RULESET> :: <SELECTOR_SEQ> LBRACE <S_SEQ_EMPTY> <DECLARATION_SEQ> RBRACE <S_SEQ_EMPTY> :: DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | IDENT | LBRACK 

-- SELECTOR :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"]
<SELECTOR> :: <SIMPLE_SELECTOR> <SELECTOR2> :: DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | IDENT | LBRACK 

-- SELECTOR2 :: DELIM["+"] | DELIM[">"] | DELIM["+"] | DELIM[">"] | DELIM["*"] | DELIM["."] | DELIM[":"] | HASH | LBRACK | IDENT | DELIM[","] | LBRACE
<SELECTOR2> :: <COMBINATOR> <SIMPLE_SELECTOR> <SELECTOR2> :: DELIM["+"] | DELIM[">"] | DELIM["+"] | DELIM[">"] | DELIM["*"] | DELIM["."] | DELIM[":"] | HASH | LBRACK | IDENT
<SELECTOR2> :: <EMPTY> :: DELIM[","] | LBRACE

-- SIMPLE_SELECTOR :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"]
<SIMPLE_SELECTOR> :: <ELEMENT_NAME> <SIMPLE_SELECTOR3> :: DELIM["*"] | IDENT 
<SIMPLE_SELECTOR> :: <SIMPLE_SELECTOR_2> :: DELIM["."] | DELIM[":"] | HASH | LBRACK

-- SIMPLE_SELECTOR2 :: HASH | DELIM["."] | LBRACK | DELIM[":"]
<SIMPLE_SELECTOR2> :: HASH <SIMPLE_SELECTOR3> :: HASH
<SIMPLE_SELECTOR2> :: <CLASS> <SIMPLE_SELECTOR3> :: DELIM["."]
<SIMPLE_SELECTOR2> :: <ATTRIB> <SIMPLE_SELECTOR3> :: LBRACK
<SIMPLE_SELECTOR2> :: <PSEUDO> <SIMPLE_SELECTOR3> :: DELIM[":"]
 
-- SIMPLE_SELECTOR3 :: HASH | DELIM["."] | LBRACK | DELIM[":"] | DELIM["+"] | DELIM[">"] | SPACE | DELIM[","] | LBRACE
<SIMPLE_SELECTOR3> :: HASH <SIMPLE_SELECTOR3> :: HASH
<SIMPLE_SELECTOR3> :: <CLASS> <SIMPLE_SELECTOR3> :: DELIM["."]
<SIMPLE_SELECTOR3> :: <ATTRIB> <SIMPLE_SELECTOR3> :: LBRACK
<SIMPLE_SELECTOR3> :: <PSEUDO> <SIMPLE_SELECTOR3> :: DELIM[":"]
<SIMPLE_SELECTOR3> :: <S_SEQ_EMPTY> :: DELIM["+"] | DELIM[">"] | DELIM[","] | SPACE | LBRACE

-- CLASS :: DELIM["."]
<CLASS> :: DELIM["."] IDENT :: DELIM["."]

-- ELEMENT_NAME :: IDENT | DELIM["*"]
<ELEMENT_NAME> :: IDENT :: IDENT
<ELEMENT_NAME> :: DELIM["*"] :: DELIM["*"]

-- ATTRIB :: LBRACK
<ATTRIB> :: LBRACK <S_SEQ_EMPTY> IDENT <S_SEQ_EMPTY> <ATTRIB2> :: LBRACK

-- ATTRIB2 :: DELIM["=" | INCLUDES | DASHMATCH | RBRACK
<ATTRIB2> :: <ATTRIB_OP> <S_SEQ_EMPTY> <ATTRIB_VALUE> <S_SEQ_EMPTY> RBRACK :: DELIM["="] | INCLUDES | DASHMATCH
<ATTRIB2> :: RBRACK :: RBRACK

-- PSEUDO :: DELIM[":"]
<PSEUDO> :: DELIM[":"] <PSEUDO2> :: DELIM[":"]

-- PSEUDO2 :: IDENT | FUNCTION
<PSEUDO2> :: IDENT :: IDENT
<PSEUDO2> :: FUNCTION <S_SEQ_EMPTY> <PSEUDO3> :: FUNCTION

-- PSEUDO3 :: IDENT SPACE RPAREN
<PSEUDO3> :: IDENT <S_SEQ_EMPTY> RPAREN :: IDENT
<PSEUDO3> :: <S_SEQ_EMPTY> RPAREN :: SPACE RPAREN

-- DECLARATION :: IDENT | SEMICOLON | RBRACE
<DECLARATION> :: <PROPERTY> DELIM[":"] <S_SEQ_EMPTY> <EXPR> <DECLARATION2> :: IDENT
<DECLARATION> :: <EMPTY> :: SEMICOLON | RBRACE

-- DECLARATION2 :: DELIM["!"] | SEMICOLON | RBRACE
<DECLARATION2> :: <PRIO> :: DELIM["!"]
<DECLARATION2> :: <EMPTY> :: SEMICOLON | RBRACE

-- PRIO :: DELIM["!"]
<PRIO> :: DELIM["!"] IDENT["important"] <S_SEQ_EMPTY> :: DELIM["!"]

-- EXPR :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION
<EXPR> :: <TERM> <EXPR2> :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION

-- EXPR2 :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION | DELIM["/"] | DELIM[","] | DELIM["!"] | SEMICOLON | BRACE | RPAREN
<EXPR2> :: <OPERATOR> <TERM> <EXPR2> :: DELIM["-"] | DELIM["+"] | DELIM["/"] | DELIM[","] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION
<EXPR2> :: <EMPTY> :: DELIM["!"] | SEMICOLON | RBRACE | RPAREN

-- TERM :: DELIM["-"] | DELIM["+"] | NUMBER | PERCENTAGE | DIMENSION | STRING | IDENT | URI | HASH | FUNCTION
<TERM> :: <UNARY_OPERATOR> <TERM2> :: DELIM["-"] | DELIM["+"]
<TERM> :: <TERM2> :: NUMBER | PERCENTAGE | DIMENSION
<TERM> :: STRING <S_SEQ_EMPTY> :: STRING
<TERM> :: IDENT <S_SEQ_EMPTY> :: IDENT
<TERM> :: URI <S_SEQ_EMPTY> :: URI
<TERM> :: <HEXCOLOR> :: HASH
<TERM> :: <FUNCTION> :: FUNCTION

-- TERM2 :: NUMBER | PERCENTAGE | DIMENSION
<TERM2> :: NUMBER <S_SEQ_EMPTY> :: NUMBER
<TERM2> :: PERCENTAGE <S_SEQ_EMPTY> :: PERCENTAGE
<TERM2> :: DIMENSION <S_SEQ_EMPTY> :: DIMENSION

-- FUNCTION :: FUNCTION
<FUNCTION> :: FUNCTION <S_SEQ_EMPTY> <EXPR> RPAREN <S_SEQ_EMPTY> :: FUNCTION

-- HEXCOLOR :: HASH
<HEXCOLOR> :: HASH <S_SEQ_EMPTY> :: HASH

-- sequences

-- S_CDO_CDC_SEQ :: SPACE | CDO | CDC
<S_CDO_CDC_SEQ> :: SPACE <S_CDO_CDC_SEQ_EMPTY> :: SPACE
<S_CDO_CDC_SEQ> :: CDO <S_CDO_CDC_SEQ_EMPTY> :: CDO
<S_CDO_CDC_SEQ> :: CDC <S_CDO_CDC_SEQ_EMPTY> :: CDC

-- S_CDO_CDC_SEQ_EMPTY :: SPACE | CDO | CDC | ATKEYWORD["@import"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"] | EOF
<S_CDO_CDC_SEQ_EMPTY> :: SPACE <S_CDO_CDC_SEQ_EMPTY> :: SPACE
<S_CDO_CDC_SEQ_EMPTY> :: CDO <S_CDO_CDC_SEQ_EMPTY> :: CDO
<S_CDO_CDC_SEQ_EMPTY> :: CDC <S_CDO_CDC_SEQ_EMPTY> :: CDC
<S_CDO_CDC_SEQ_EMPTY> :: <EMPTY> :: ATKEYWORD["@import"] | ATKEYWORD["@media"] | ATKEYWORD["@page"] | DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | LBRACK | IDENT | EOF

<S_SEQ_EMPTY> :: SPACE <S_SEQ_EMPTY> :: SPACE
<S_SEQ_EMPTY> :: <EMPTY> :: - basically, anything except SPACE -

-- MEDIUM_SEQ :: IDENT
<MEDIUM_SEQ> :: <MEDIUM> <MEDIUM_SEQ_END> 

-- MEDIUM_SEQ_END :: SPACE | DELIM[","] | SEMICOLON | LBRACE
<MEDIUM_SEQ_END> :: DELIM[","] <S_SEQ_EMPTY> <MEDIUM> <MEDIUM_SEQ_END> :: DELIM[","]
<MEDIUM_SEQ_END> :: <S_SEQ_EMPTY> :: SPACE | SEMICOLON | LBRACE

-- RULESET_SEQ_EMPTY :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"] | RBRACE
<RULESET_SEQ_EMPTY> :: <RULESET> <RULESET_SEQ_EMPTY> :: DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | LBRACK | IDENT
<RULESET_SEQ_EMPTY> :: <EMPTY> :: RBRACE

-- DECLARATION_SEQ :: IDENT | SEMICOLON | RBRACE
<DECLARATION_SEQ> :: <DECLARATION> <DECLARATION_SEQ_END> :: IDENT | SEMICOLON | RBRACE

-- DECLARATION_SEQ_END :: SEMICOLON | RBRACE
<DECLARATION_SEQ_END> :: SEMICOLON <S_SEQ_EMPTY> <DECLARATION> <DECLARATION_SEQ_END> :: SEMICOLON
<DECLARATION_SEQ_END> :: <EMPTY> :: RBRACE

-- SELECTOR_SEQ :: HASH | DELIM["."] | LBRACK | DELIM[":"] | IDENT | DELIM["*"]
<SELECTOR_SEQ> :: <SELECTOR> <SELECTOR_SEQ_END> :: DELIM["."] | DELIM[":"] | DELIM["*"] | HASH | LBRACK | IDENT 

-- SELECTOR_SEQ_END :: DELIM[","] | LBRACE
<SELECTOR_SEQ_END> :: DELIM[","] <S_SEQ_EMPTY> <SELECTOR> <SELECTOR_SEQ_END> :: DELIM[","]
<SELECTOR_SEQ_END> :: <EMPTY> :: LBRACE

-- ATTRIB_OP :: DELIM["="] | INCLUDES | DASHMATCH
<ATTRIB_OP> :: DELIM["="] :: DELIM["="]
<ATTRIB_OP> :: INCLUDES :: INCLUDES
<ATTRIB_OP> :: DASHMATCH :: DASHMATCH

-- ATTRIB_VALUE :: IDENT | STRING
<ATTRIB_VALUE> :: IDENT :: IDENT
<ATTRIB_VALUE> :: STRING :: STRING

*/

?>
