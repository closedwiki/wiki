package URIre;

# $Id: URIre.pm 18 2003-02-24 20:05:31Z nodine $

BEGIN {
    $digit = "\\d";
    $alpha = "[a-zA-Z]";
    $alphanum = "(?:$alpha|$digit)";
    $hex = "[0-9a-fA-F]";
    $escaped = "\%$hex$hex";
    $mark = "[-_.!~*\'()]";
    $unreserved = "(?:$alphanum|$mark)";
    $reserved = "[;/?:\@&=+\$,]";
    $uric = "(?:$reserved|$unreserved|$escaped)";
    $fragment = "(?:$uric)*";
    $query = "(?:$uric)*";
    $pchar = "(?:$unreserved|$escaped|[:\@&=+\$,])";
    $param = "(?:$pchar)*";
    $segment = "(?:$pchar)*(?:;$param)*";
    $path_segments = "$segment(?:/$segment)*";
    $port = "(?:$digit)*";
    $IPv4address = "$digit\\.$digit\\.$digit\\.$digit";
    $IPv6address = "\\[(?:$hex*:)+$hex*\\]";
    $toplabel = "(?:$alpha|$alpha(?:$alphanum|-)*$alphanum)";
    $domainlabel = "(?:$alphanum|$alphanum(?:$alphanum|-)*$alphanum)";
    $hostname = "(?:$domainlabel\\.)*$toplabel\\.?";
    $host = "(?:$hostname|$IPv4address|$IPv6address)";
    $hostport  = "$host(?::$port)?";
    $userinfo = "(?:$unreserved|$escaped|[;:&=+\$,])*";
    $server = "(?:(?:$userinfo\@)?$hostport)?";
    $reg_name = "(?:$unreserved|$escaped|[\$,;:\@&=+])";
    $authority = "(?:$server|$reg_name)";
    $scheme = "$alpha(?:$alpha|$digit|[+.-])*";
    $rel_segment = "(?:$unreserved|$escaped|[;\@&=+\$,])";
    $abs_path = "/$path_segments";
    $rel_path = "$rel_segment(?:$abs_path)?";
    $net_path  = "//$authority(?:$abs_path)?";
    $uric_no_slash = "(?:$unreserved|$escaped|[;?:\@&=+\$,])";
    $opaque_part   = "$uric_no_slash(?:$uric)*";
    $path = "(?:$abs_path|$opaque_part)?";
    $hier_part = "(?:$net_path|$abs_path)(?:\\?$query)?";
    $absoluteURI = "(?:$scheme:(?:$hier_part|$opaque_part))";
    $relativeURI = "(?:$net_path|$abs_path|$rel_path)(?:\\?$query)?";
    $URI_reference = "(?:$absoluteURI|$relativeURI)(?:$fragment)?";
}

1;
