# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# This plugin allow a selective crypting of topic parts.
# The crypted parts are decrypted before topic viewing and topic editing
# (providing that the user viewing or editing is allowed to decrypt).
# The parts to be crypted are crypted before topic saving, so the topic
# is stored crypted into the twiki filesystem forbiding retrieval by a
# SEARCH directive.
#

# =========================
package TWiki::Plugins::TopicCryptPlugin;

# =========================
use strict;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $privateKeyFile $warningEdit $maxSignatures
    );

# General constants
$VERSION = '1.010';
$pluginName = 'TopicCryptPlugin';

# Crypting constants
my $PRIVKEY_FILE="/var/lib/twiki/cryptkey.priv";
my $MAX_SIGNATURES=5;
my $RC4_KEY_SIZE=16;
my $RIJNDAEL_KEY_SIZE=32;

# Plugin keywords
my $KW_OPTIONS="CRYPT_OPTIONS";
my $KW_TABLE_OPTIONS="CRYPT_TABLE_OPTIONS";
my $KW_BEGIN="CRYPT_BEGIN";
my $KW_END="CRYPT_END";
my $KW_CRYPTED="CRYPTED";
my $KW_VALID_SIGNS="VALID_SIGNATURES";
my $KW_OUTDATED_SIGNS="OUTDATED_SIGNATURES";

# Crypting methods
my $METHOD_CLEAR="clear";
my $METHOD_NONE="base64";
my $METHOD_RSA_RC4="rsa_rc4";
my $METHOD_RSA_RIJNDAEL="rsa_rijndael";

# ACL modes
my $ACL_MODE_APPEND="append";
#$ACL_MODE_OVERRIDE="override";

# Separators and delimitors
my $ACL_SEPARATOR=",";
my $CRYPT_BEGIN_DELIM="{{";
my $CRYPT_END_DELIM="}}";

# Options defaults
my %OPTDEF_ALL=(
  method          => $METHOD_RSA_RC4,
  aclmode         => $ACL_MODE_APPEND,
  allowtextread   => "",
  allowtextchange => "",
  denytextread    => "",
  denytextchange  => "",
  begin           => $CRYPT_BEGIN_DELIM,
  end             => $CRYPT_END_DELIM,
  alt             => "",
  _origopts       => "",
  _origdelims     => "",
  _table          => "",
  );

# Options names
my @OPTNAMES_ALL=keys %OPTDEF_ALL;
my @OPTNAMES_ACL=("allowtextread","allowtextchange",
               "denytextread","denytextchange");

# Actions needing decrypting
my $ACTION_VIEW="view";
my $ACTION_EDIT="edit";

# Default error texts
my $WARNING_EDIT="User %s made an un-authorized attempt to edit".
              " a crypted text\n<br>\n";

# flags for required perl modules
my $Crypt_RC4=0;
my $Crypt_CBC=0;
my $Crypt_OpenSSL_RSA=0;
my $MIME_Base64=0;

#
# Utilities
#

# =========================
sub formatDate
{
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	$month=$month+1;
	return "$dayOfMonth.$month.$year $hour:$minute:$second";
}

# =========================
sub hash2string
{
	my $hash=$_[0];
	my $sep=$_[1];
	my @result;
	my $i=0;
	while(my ($key,$value)=each %$hash){
		$value =~ s/\"/\\\"/g;
		$result[$i++]="$key=\"$value\"";
	}
	return join($sep,@result);
}

# =========================
sub binary2hexa
{
	my ($binary)=@_;
	my $result="";
	for(my $i=0;$i<length($binary);$i++){
		$result .= sprintf("%02x",ord(substr($binary,$i,1)));
	}
	return $result;
}

# =========================
sub hexa2binary
{
	my ($hexa)=@_;
	my $result="";
	for(my $i=0;$i<length($hexa);$i+=2){
		sscanf(substr($hexa,$i,2),"%x",my $byte);
		$result .= chr($byte);
	}
	return $result;
}

# =========================
sub removeLF {
	my $string = shift;
	for ($string) {	s/\n//g; }
	return $string;
}

# =========================
sub randomHexaWord
{
	my ($size)=@_;
	my $result="";
	for (my $i=0;$i<$size;$i++){
		my $byte=rand(256);
		$result .= sprintf("%02x",$byte);
	} 
	return $result;
}

# =========================
sub readRSAKeyFile
{
	open(KEY, $privateKeyFile) or die "can't open $privateKeyFile: $!";
	binmode(KEY);
	binmode(STDOUT);
	my $private_key;
	while (<KEY>){
		$private_key.= $_;
	}
	return $private_key;
}	

# =========================
sub readTopic
{
	my ($web,$topic)=@_;
	if( $TWiki::Plugins::VERSION < 1.1 ) {
		# Cairo
		return TWiki::Store::readTopic($web,$topic);
	} else {
		# Dakar
		return TWiki::Func::readTopic($web,$topic);
	}
}

#
# ACL checking utilities
#

# =========================
sub userIsInGroup
{
	my ($user,$groupName)=@_;
	if( $TWiki::Plugins::VERSION < 1.1 ) {
		# Cairo
		return TWiki::Access::userIsInGroup($user,$groupName);
	} elsif( $TWiki::Plugins::VERSION < 1.2 ) {
		# Dakar
		return $TWiki::Plugins::SESSION->{user}->isInList($groupName);
	} else {
    return TWiki::Func::isGroupMember($groupName,$user);
	}
}

# =========================
sub isUserInList
{
	my ($user,$list)=@_;
	if(!defined($list)){$list="";}
	my @items=split(/$ACL_SEPARATOR/,$list);
	my $login=TWiki::Func::wikiToUserName($user);
	my $found=0;
	foreach(@items){
		# remove spaces surounding the user name
		$_ =~ s/^\s*(.*)\s*$/$1/;
		if($_ eq "*"){ $found=1; } 
		else{ $found=userIsInGroup($user,$_)||userIsInGroup($login,$_); }
		if($found){ return 1; }
	}
	return 0;
} 

# =========================
sub checkDecryptPermission
{
	my ($user,$allow,$deny)=@_;
	if ($user eq "*") { return 1; }
	if(isUserInList($user,$deny)){ return 0; }
	if(isUserInList($user,$allow)){ return 1; }
	if(!defined($allow)){$allow="";}
	if(!defined($deny)){$deny="";}
	TWiki::Func::writeDebug(
	"- ${pluginName}::checkDecryptPermission".
	"($user,$allow,$deny)") if $debug;
	return 0;
}

# =========================
sub getCryptedDirectives
{
	my ($text)=@_;
	my @directives=($text =~ /(%$KW_CRYPTED\{.*?\}%)/g);
	return join("",@directives);
}

# =========================
sub doSecureCrypt
{
	my ($web,$topic,$text)=@_;
	my $fromCrypt=1;
	my (undef,$cryptedOrigText)=readTopic($web,$topic);
	my $origText=doDecrypt($ACTION_EDIT,$cryptedOrigText,$fromCrypt);
	my $directives=getCryptedDirectives($text);
	my $origDirectives=getCryptedDirectives($origText);
	if($directives eq $origDirectives){ return doCrypt($text); }
	else{ return $warningEdit.$cryptedOrigText; }
}

#
# Crypting options utilities
#

# =========================
sub handleOptionsDirective
{
	my ($attributes,$defaults)=@_;
	my %result;
	if($defaults){ %result=%OPTDEF_ALL; }
	foreach(@OPTNAMES_ALL){
		my $value=TWiki::Func::extractNameValuePair($attributes,$_);
		if($value ne ""){ $result{$_}=$value; }
	}
	return %result;
}

# =========================
sub handleTableOptionsDirective
{
	my ($attributes)=@_;
	my %result;
	%result=%OPTDEF_ALL;
	foreach(@OPTNAMES_ALL){
		my $value=TWiki::Func::extractNameValuePair($attributes,$_);
		if($value ne ""){ $result{$_}=$value; }
	}
	$result{"_table"}="1";
	return %result;
}

# =========================
sub optionsMerge
{
	my ($pglobal,$plocal)=@_;
	my %local=%$plocal;
	my %global=%$pglobal;
	my %options;
	while(my($key,$value)=each %OPTDEF_ALL){
		$options{$key}=$local{$key};
		if(!defined $options{$key} || $options{$key} eq ""){
			$options{$key}=$global{$key}; }
		if(!defined $options{$key} || $options{$key} eq ""){
			$options{$key}=$OPTDEF_ALL{$key}; }
	}
	if((defined $local{"aclmode"} && $local{"aclmode"} eq $ACL_MODE_APPEND) ||
	   (!defined $local{"aclmode"} && $global{"aclmode"} eq $ACL_MODE_APPEND)){
		foreach(@OPTNAMES_ACL){
			my @acl=();
			if (defined($options{$_})){
			foreach(split(/$ACL_SEPARATOR/,$options{$_})){ push @acl,$_; }}
			if (defined($global{$_})){
			foreach(split(/$ACL_SEPARATOR/,$global{$_})){ push @acl,$_; }}
			my @acl_sorted=sort @acl;
			my $first=(defined $acl_sorted[0])?$acl_sorted[0]:"";
			my $prev="not equal $first";
			my @acl_final=grep($_ ne $prev && ($prev = $_, 1), @acl_sorted);
			$options{$_}=join($ACL_SEPARATOR,@acl_final);
		}
	}
	return %options;
}

# =========================
sub inlineOptionsMerge
{
	my ($keyword,$poptions,$attributes)=@_;
	my %options=%$poptions;
	my %local=handleOptionsDirective($attributes,0);
	my $result="%$keyword\{";
	%options=optionsMerge(\%options,\%local);
	$options{"_origopts"}=$attributes;
	$options{"_origdelims"}=join(",",$options{"begin"},$options{"end"});
	$result .= hash2string(\%options," ");
	$result .= " }%";
	return $result;
}

#
# Crypting utilities
#

#
# Base64 encoding subroutines
#

# =========================
sub base64Encoding
{
	my ($text)=@_;
	if (!$MIME_Base64){ require MIME::Base64; $MIME_Base64=1; }
	return removeLF(MIME::Base64::encode_base64($text));
}

# =========================
sub base64Decoding
{
	my ($coded)=@_;
	if (!$MIME_Base64){ require MIME::Base64; $MIME_Base64=1; }
	return MIME::Base64::decode_base64($coded);
}

#
# RSA crypting subroutines
#

# =========================
sub encryptUsingRSAPublicKey
{
	my ($text)=@_;
	if (!$Crypt_OpenSSL_RSA){ require Crypt::OpenSSL::RSA; $Crypt_OpenSSL_RSA=1; }
	my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key(readRSAKeyFile);
	my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($rsa_priv->get_public_key_string());
	return $rsa_priv->encrypt($text);	
}

# =========================
sub decryptUsingRSAPrivateKey
{
	my ($crypted)=@_;
	if (!$Crypt_OpenSSL_RSA){ require Crypt::OpenSSL::RSA; $Crypt_OpenSSL_RSA=1; }
	my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key(readRSAKeyFile);
	return $rsa_priv->decrypt($crypted); 
}

#
# RC4 crypting subroutines
#

# =========================
sub generateRandomRC4Key
{
	return randomHexaWord($RC4_KEY_SIZE);
}

# =========================
sub cryptUsingRC4
{
	my ($key,$text)=@_;
	if (!$Crypt_RC4){ require Crypt::RC4; $Crypt_RC4=1; }
	return Crypt::RC4::RC4($key,$text);	
}

# =========================
sub decryptUsingRC4
{
	my ($key,$crypted)=@_;
	if (!$Crypt_RC4){ require Crypt::RC4; $Crypt_RC4=1; }
	return Crypt::RC4::RC4($key,$crypted);
}

#
# Rijndael crypting subroutines
#

# =========================
sub encryptUsingRijndael
{
	my ($key,$text)=@_;
	if (!$Crypt_CBC){ require Crypt::CBC; $Crypt_CBC=1; }
	my $cipher = Crypt::CBC->new(	-key	=> $key,
					-salt	=> 1,
					-cipher	=> "Crypt::Rijndael_PP");
	return $cipher->encrypt($text);
}

# =========================
sub decryptUsingRijndael
{
	my ($key,$crypted)=@_;
	if (!$Crypt_CBC){ require Crypt::CBC; $Crypt_CBC=1; }
	my $cipher = Crypt::CBC->new(	-key	=> $key,
					-cipher	=> "Crypt::Rijndael_PP");
	return $cipher->decrypt($crypted);
}

#
# General crypting utilities (results presentation)
#

# =========================
sub cryptedTextInfos
{
	my ($poptions)=@_;
	my %options=%$poptions;
	my @items=();
	foreach(@OPTNAMES_ACL){ push @items,$options{$_}; }
	foreach(("alt","_origopts","_origdelims","_table")){ push @items,$options{$_}; }
	return join(";",@items);
}

# =========================
sub cryptedTextFormatting
{
	my ($action,$user,$attributes,$infos,$text)=@_;
	my @tab=split(/;/,$infos);
	my %items=();
	my ($allow,$deny);
	my $i;

	TWiki::Func::writeDebug(
	"- ${pluginName}::cryptedTextFormatting".
	"($action,$user,$attributes,$infos,...) is OK") if $debug;

	if(!defined($text)){$text="";}

	for($i=0;$i<scalar(@OPTNAMES_ACL);$i++){
		$items{$OPTNAMES_ACL[$i]}=$tab[$i]; 
	}
	foreach(("alt","_origopts","_origdelims","_table")){ $items{$_}=$tab[$i++]; }

	if($action eq $ACTION_VIEW){
		$allow=$items{"allowtextread"}; $deny=$items{"denytextread"}; 
		if(checkDecryptPermission($user,$allow,$deny)){ return $text; }
		else{ return $items{"alt"}; }
	}
	if($action eq $ACTION_EDIT){
		$allow=$items{"allowtextchange"}; $deny=$items{"denytextchange"};
		if(checkDecryptPermission($user,$allow,$deny)){
			if(!defined($items{"_origopts"})){$items{"_origopts"}="";}
			if($items{"_origopts"} eq ""){
				if(!defined($items{"_origdelims"})){$items{"_origdelims"}="";}
				my ($begin,$end)=split(/,/,$items{"_origdelims"});
				if(!defined($begin)){$begin="";} if(!defined($end)){$end="";}
				if($text ne ""){ $text="$begin$text$end"; }
			}
			else{
				my $origattrs=$items{"_origopts"};
				if($text eq ""){
					if(!defined($items{"_table"})){$items{"_table"}=0;}
					if($items{"_table"} eq 1){ $text="%$KW_TABLE_OPTIONS\{$origattrs\}%"; }
					else{ $text="%$KW_OPTIONS\{$origattrs\}%"; }
				}else{ $text="\%$KW_BEGIN\{$origattrs\}\%$text\%$KW_END\%"; }
			}
			return $text;
		}
		else{ return "%$KW_CRYPTED\{$attributes\}%"; }
	}
}

#
# Crypting subroutines for "clear" method
#

# =========================
sub cryptClear
{
	my ($poptions,$text)=@_;
	my $infos=cryptedTextInfos($poptions);
	return $infos.",".$text;
}

# =========================
sub decryptClear
{
	my ($action,$user,$coded,$attributes)=@_;
	my ($infos,$text)=split(/,/,$coded);
	return cryptedTextFormatting($action,$user,$attributes,$infos,$text);
}

#
# Crypting subroutines for "base64" method
#

# =========================
sub cryptBase64
{
	my ($poptions,$text)=@_;
	my $infos=cryptedTextInfos($poptions);
	return base64Encoding($infos).",".base64Encoding($text);
}

# =========================
sub decryptBase64
{
	my ($action,$user,$coded,$attributes)=@_;
	my ($coded_infos,$coded_text)=split(/,/,$coded);
	my $infos=base64Decoding($coded_infos);
	my $text=base64Decoding($coded_text);
	return cryptedTextFormatting($action,$user,$attributes,$infos,$text);
}

#
# Crypting subroutines for "rsa_rca4" method
#

# =========================
sub cryptRC4
{
	my ($poptions,$text)=@_;
	my $infos=cryptedTextInfos($poptions);
	my $key=generateRandomRC4Key();
	my $crypted_key=encryptUsingRSAPublicKey($key);
	my $crypted_infos=cryptUsingRC4($key,$infos);
	my $crypted_text=cryptUsingRC4($key,$text);
	my $coded_key=base64Encoding($crypted_key);
	my $coded_infos=base64Encoding($crypted_infos);
	my $coded_text=base64Encoding($crypted_text);
	my @result=();
	foreach(($coded_key,$coded_infos,$coded_text)){ push @result,$_; }
	return join(",",@result);
}

# =========================
sub decryptRC4
{
	my ($action,$user,$coded,$attributes)=@_;
	my ($coded_key,$coded_infos,$coded_text)=split(/,/,$coded);
	my $crypted_key=base64Decoding($coded_key);
	my $crypted_infos=base64Decoding($coded_infos);
	my $crypted_text=base64Decoding($coded_text);
	my $key=decryptUsingRSAPrivateKey($crypted_key);
	my $infos=decryptUsingRC4($key,$crypted_infos);
	my $text=decryptUsingRC4($key,$crypted_text);
	cryptedTextFormatting($action,$user,$attributes,$infos,$text);
}

#
# Crypting subroutines for "rsa_rijndael" method
#

# =========================
sub encryptRijndael
{
	my ($poptions,$text)=@_;
	my $infos=cryptedTextInfos($poptions);
	if (!$Crypt_CBC){ require Crypt::CBC; $Crypt_CBC=1; }
	my $key=Crypt::CBC->random_bytes(32);
	my $crypted_key=encryptUsingRSAPublicKey($key);
	my $crypted_infos=encryptUsingRijndael($key,$infos);
	my $crypted_text=encryptUsingRijndael($key,$text);
	my $coded_key=base64Encoding($crypted_key);
	my $coded_infos=base64Encoding($crypted_infos);
	my $coded_text=base64Encoding($crypted_text);
	my @result=();
	foreach(($coded_key,$coded_infos,$coded_text)){ push @result,$_; }
	return join(",",@result);
}

# =========================
sub decryptRijndael
{
	my ($action,$user,$coded,$attributes)=@_;
	my ($coded_key,$coded_infos,$coded_text)=split(/,/,$coded);
	my $crypted_key= base64Decoding($coded_key);
	my $crypted_infos=base64Decoding($coded_infos);
	my $crypted_text=base64Decoding($coded_text);
	my $key=decryptUsingRSAPrivateKey($crypted_key);
	my $infos=decryptUsingRijndael($key,$crypted_infos);
	my $text=decryptUsingRijndael($key,$crypted_text);
	cryptedTextFormatting($action,$user,$attributes,$infos,$text);
}

#
# Digital signature part
#

# =========================
sub computeSHA1Signature
{
	my ($text)=@_;
	if (!$Crypt_OpenSSL_RSA){ require Crypt::OpenSSL::RSA; $Crypt_OpenSSL_RSA=1; }
	my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key(readRSAKeyFile);
	return $rsa_priv->sign($text);
}

# =========================
sub verifySHA1Signature
{
	my ($text,$signature)=@_;
	if (!$Crypt_OpenSSL_RSA){ require Crypt::OpenSSL::RSA; $Crypt_OpenSSL_RSA=1; }
	my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key(readRSAKeyFile);
	return $rsa_priv->verify($text,$signature);
}

# =========================
sub encryptSignature
{
	my ($user,$text)=@_;
	my $userAndDate="$user(".formatDate.")";
	my $hash=computeSHA1Signature($text);
	my ($key)=generateRandomRC4Key();
	my $crypted_key=encryptUsingRSAPublicKey($key);
	my $crypted_user=cryptUsingRC4($key,$userAndDate);
	my $crypted_hash=cryptUsingRC4($key,$hash);
	my $coded_key=base64Encoding($crypted_key);
	my $coded_user=base64Encoding($crypted_user);
	my $coded_hash=base64Encoding($crypted_hash);
	my @result=();
	foreach(($coded_key,$coded_user,$coded_hash)){ push @result,$_; }
	return join(",",@result);
}

# =========================
sub decryptSignature
{
	my ($coded,$text_to_check)=@_;
	my ($coded_key,$coded_user,$coded_hash)=split(/,/,$coded);
	my $crypted_key=base64Decoding($coded_key);
	my $crypted_user=base64Decoding($coded_user);
	my $crypted_hash=base64Decoding($coded_hash);
	my $key=decryptUsingRSAPrivateKey($crypted_key);
	my $user=decryptUsingRC4($key,$crypted_user);
	my $hash=decryptUsingRC4($key,$crypted_hash);
	my $isSignatureOk=verifySHA1Signature($text_to_check,$hash);
	return ($user,$isSignatureOk);	
}

# =========================
sub listSignatures
{
	my ($text_to_check, $valid) = @_;
	my $text = TWiki::Func::readTopicText($web,$topic);
	my $list="";
        if ($text =~ /%META:TOPICSIGNATURE\{signature="(.*?)"\}%/){
		if ($valid){ $list="Valid Signatures: "; } 
		else { $list="Outdated Signatures: "; }
		my @items=split(";",$1);		
		foreach(@items){
			my ($user,$isSignatureOk) = decryptSignature($_,$text_to_check);
			if ($isSignatureOk == $valid){ $list.=" $user;"; }
	}}
	return $list;	
}

# =========================
sub insertSignForm
{
	my ($text,$topic) = @_;
	my $user=TWiki::Func::getWikiName();
	my $form="<!--REMOVENEXTLINES-->
---
<form method=\"get\" action=\"$topic\" > 
<input type=\"submit\"  name=\"sign\" value=\"Sign\">
</form>
<!--UNTILHERE-->";
	return $form;
}

# =========================
sub getTextToSign
{
	my ($topic,$web)=@_;

        my (undef,$text_to_sign)=readTopic($web,$topic);
	my @block=extractBlocks($text_to_sign);
	my $result="";
	#Interpret crypted parts in non verbatim blocks
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){
			#Decrypt all the sections delimited by ad hoc directive
			$block[$i] =~ s/\n\s*<!--REMOVENEXTLINES-->(.*\n)*<!--UNTILHERE-->//g;
			$block[$i] =~ s/%$KW_CRYPTED\{(.*?)\}%/&doTextDecrypt($ACTION_VIEW,$1,1)/ge;
		}
		$result .= $block[$i];
	}
	$result =~ s/<joinline>\n//g;
	$result =~ s/&lt;joinline&gt;\n//g;
	return $result;
}

# =========================
sub signPage
{
	my ($topic,$web)=@_;

	my $text=TWiki::Func::readTopicText($web,$topic);
	my $user=TWiki::Func::getWikiName();
	my $text_to_sign=getTextToSign($topic,$web);
	my $value.=encryptSignature($user,$text_to_sign);

        if ($text =~ /%META:TOPICSIGNATURE\{signature="(.*?)"\}%/){
		my $signatures = $1;
		my @items=split(";",$signatures);
		if ($#items > $maxSignatures-2){
			for (my $i=$#items;$i>=$#items-3;$i--){
				$value = "$items[$i];$value";
			}
		} else {
			$value = "$1;$value";
		}
		$text =~ s/%META:TOPICSIGNATURE\{signature="(.*?)"\}%/"\%META:TOPICSIGNATURE{signature=\"".$value."\"}%"/ge;
	} else {
		$text .= "\%META:TOPICSIGNATURE{signature=\"".$value."\"}%\n";
	}
	# Extract verbatim blocks of text
	my @block=extractBlocks($text);
	$text="";	
	# remove the form that generates the sign button
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){
			$block[$i] =~ s/<!--REMOVENEXTLINES-->(.*\n)*<!--UNTILHERE-->//g;
		}
		$text.=$block[$i];
	}
	$text =~ s/<joinline>\n//g;
	$text =~ s/&lt;joinline&gt;\n//g;
	$text=doDecrypt($ACTION_EDIT,$text);
	my $oopsUrl = TWiki::Func::saveTopicText( $web, $topic, $text );
}

#
# crypt tables routines
#

# =========================
sub generateOptions
{
	my ($usernames,$attributes) = @_;
	if (!defined($usernames)) {$usernames="";}
	my %options=handleOptionsDirective($attributes,0);
	$options{"allowtextread"}="$usernames";
	my $origattrs=$options{"_origopts"};
	if (defined($origattrs)){	
        if( $origattrs =~ /(^|[^\S])alt\s*=\s*\"([^\"]*)\"/ ) {
		my $alt=TWiki::Func::extractNameValuePair($origattrs,"alt");
		$options{"alt"}=$alt;
	}} else {
		$options{"alt"}= " ";
	}
	return %options;
}

# =========================
sub encryptRow
{
	my ( $thePre, $theRow, $insideTABLE, $userCol, $tableAttrs) = @_;
	my $text=$thePre."|";
	my $col=0;
	my $doShowRow=0;
	my %options;
	my $attributes="";
	my $users="";
	
	$theRow =~ s/\s*$//;    # remove trailing spaces

	if (($userCol!=-1) || ($insideTABLE==0)){
	foreach( split( /\|/, $theRow ) ) {
		if ($insideTABLE==0){
			if( /<!--UserIDCol-->/i ) {
				$userCol=$col;
				last;
			} 			
		} else {
			if ($col==$userCol){
				$users = $_;
				$users =~ s/^\s*(.*?)\s*$/$1/g;
				if ($users eq "") { $users = "*";}
				last;
			}
		}
		$col++;
	}}
	$col=0;
	if ($userCol!=-1){
		%options=generateOptions($users,$tableAttrs);
		my $begin=$OPTDEF_ALL{"begin"};
		my $end=$OPTDEF_ALL{"end"};
		my $esc_begin=$begin;
		my $esc_end=$end;
		$esc_begin =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
		$esc_end =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;

		foreach( split( /\|/, $theRow ) ) {
			if ($insideTABLE==0){
				if( /<!--UserIDCol-->/ ) {
					$text.=doTextCrypt($tableAttrs, $_)."|";
				} else {
					$text.=$_."|";
				}			
			} else {

				if ($col==$userCol){
					$text.=doTextCrypt($tableAttrs, $_)."|";
				}else{
					s/\"$esc_begin\"/ESCAPED_BEGIN/g; s/\"$esc_end\"/ESCAPED_END/g;
					s/$esc_begin/%$KW_BEGIN\{\}%/g; s/$esc_end/%$KW_END%/g; 
					s/ESCAPED_BEGIN/\"$begin\"/g; s/ESCAPED_END/\"$end\"/g;
					s/%$KW_BEGIN\{(.*?)\}%/&inlineOptionsMerge($KW_BEGIN,\%options,$1)/ge;
					$text.=$_."|";
				}
			}
			$col++;
		}
		$text =~ s/%$KW_BEGIN\{(.*?)\}%(.*?)%$KW_END%/&doTextCrypt($1,$2)/ge;
	} else {
		$text.=$theRow;
	}
	return ($text,$userCol);
}

#
# Main crypting subroutines
#

# =========================

my %cryptmethods=(
	$METHOD_CLEAR		=> [ \&cryptClear, \&decryptClear ],
	$METHOD_NONE		=> [ \&cryptBase64, \&decryptBase64 ],
	$METHOD_RSA_RC4		=> [ \&cryptRC4, \&decryptRC4 ],
	$METHOD_RSA_RIJNDAEL	=> [ \&encryptRijndael, \&decryptRijndael ]
	);

# =========================
sub doTextCrypt
{
	my ($attributes,$text) = @_;
	my %options=handleOptionsDirective($attributes,1);
	my $result="%$KW_CRYPTED\{";
	my $method=$options{"method"};
	my $cryptfct=$cryptmethods{$method}[0];
	my $crypted;
	if(! defined &$cryptfct){ $cryptfct=$cryptmethods{$METHOD_CLEAR}[0]; }
	$crypted=&$cryptfct(\%options,$text);
	$result .= "method=\"$method\"";
	$result .= " crypted=\"$crypted\"";
	$result .= "\}%";
	return $result;
}

# =========================
sub extractBlocks
{
	my ($text) = @_;
	my @block=();
	my $result="";
	my $insidePRE=(-1);
	my $index=(-1);
	
	# Some global text processing
	# supress carriage return
	$text =~ s/\r//go;	
	# join lines ending in "\"
	$text =~ s/\\\n//go;
	# do not allow two verbatim tags in a same line
	$text =~ s/([^\n])<(pre|verbatim)>/$1<joinline>\n<$2>/gi ;
	$text =~ s/([^\n])&lt;(pre|verbatim)&gt;/$1<joinline>\n<$2>/gi ;
	$text =~ s/([^\n])<\/(pre|verbatim)>/$1<joinline>\n<\/$2>/gi ;
	$text =~ s/([^\n])&lt;\/(pre|verbatim)&gt;/$1<joinline>\n<\/$2>/gi ;
	$text =~ /^(\s|\n)*<(pre|verbatim)>/i && ( $index++, $block[$index]="");
	$text =~ /^(\s|\n)*&lt;(pre|verbatim)&gt;/i && ( $index++, $block[$index]="");
	# Parse line by line
	foreach(split(/\n/,$text)){
	
		my $start=0;
	
		# Select blocks of verbatim or plain texts
		$insidePRE!=1 && /<(pre|verbatim)>/i   && ( $insidePRE=1, $start=1 );
		$insidePRE!=1 && /&lt;(pre|verbatim)&gt;/i   && ( $insidePRE=1, $start=1 );
		$insidePRE!=0 && /<\/(pre|verbatim)>/i && ( $insidePRE=0, $start=1 );
		$insidePRE!=0 && /&lt;\/(pre|verbatim)&gt;/i && ( $insidePRE=0, $start=1 );
		$insidePRE<0  && ( $insidePRE=0, $start=1 );
		if($start==1){ $index++; $block[$index]=""; }
		$block[$index] .= "$_\n";
	}
	return @block;
}

# =========================
sub compactOutsidePreBlocks
{
	my ($text) = @_;
	my $textWithoutPre="";
	
	my @block=extractBlocks($text);
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){ $textWithoutPre.=$block[$i]; }
	}
	$textWithoutPre =~ s/<joinline>\n/<joinline>/g;
	$textWithoutPre =~ s/&lt;joinline&gt;\n/&lt;joinline&gt;/g;
	return $textWithoutPre;
}

# =========================
sub reExtractBlocks
{
	my ($text) = @_;
	my @block=();
	my $index=(0);

	$text =~ s/<joinline>/<joinline>\n/gi ;
	$text =~ s/&lt;joinline&gt;/&lt;joinline&gt;\n/gi ;
	$text =~ s/([^\n])<\/(pre|verbatim)>/$1\n<\/$2>/gi ;
	$text =~ s/([^\n])&lt;\/(pre|verbatim)&gt;/$1\n<\/$2>/gi ;

	foreach(split(/\n/,$text)){	
		my $start=0;
		/<\/(pre|verbatim)>/i && ($start=1);
		/&lt;\/(pre|verbatim)&gt;/i && ($start=1);
		if($start==1){ $index++; $block[$index]=""; }
		$block[$index] .= "$_\n";
	}
	return @block;
}

# =========================
sub cryptEverything
{
	my ($text)=@_;

	my %global_options=%OPTDEF_ALL;
	my %options=%OPTDEF_ALL;
	my %table_options=();
	my %local_options=();
	my $begin=$options{"begin"};
	my $end=$options{"end"};
	my @block;
	my $signed=0;
	my $result="";	

	my $insideTABLE=0;
	my $row="";
	my $userCol=-1;
	my $tableAttributes="";

	# Split lines with more than one crypt options directive
	$text =~ s/(.)%($KW_OPTIONS\{.*?\}%)/$1<joinline>\n$2/g;

	my $btext="";
	if ($text =~ s/%SIGNPAGE%//g){
		$signed = 1;	
	}
	foreach(split(/\n/,$text)){
		if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
			my $oldRow=$_;
			$row="";
			if (%table_options){
				$tableAttributes=hash2string(\%table_options," ");
			} else {
				$tableAttributes=hash2string(\%global_options," ");
			}
			$oldRow =~ /^(\s*)\|(.*)/;
			($row, $userCol) = encryptRow($1,$2,$insideTABLE,$userCol,$tableAttributes);
			if (!defined($row)) {$row="";}
			$oldRow =~ s/(.*)/$row/e;
			$_=$oldRow;
			$insideTABLE++;
		} elsif( $insideTABLE ) {
			%table_options=();
			$insideTABLE = 0;
			$tableAttributes = "";
			$userCol=-1;
		}
		if($userCol==-1){
			if(/^%$KW_OPTIONS\{(.*?)\}%/){
				%local_options=handleOptionsDirective($1,0);
				%options=optionsMerge(\%global_options,\%local_options);
				$begin=$options{"begin"};
				$end=$options{"end"};
			}
			if(/%$KW_TABLE_OPTIONS\{(.*?)\}%/){
				%table_options=handleTableOptionsDirective($1);
				%table_options=optionsMerge(\%global_options,\%table_options);
			}
			my $esc_begin=$begin;
			my $esc_end=$end;
			$esc_begin =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
			$esc_end =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
			s/\"$esc_begin\"/ESCAPED_BEGIN/g; s/\"$esc_end\"/ESCAPED_END/g;
			s/$esc_begin/%$KW_BEGIN\{\}%/g; s/$esc_end/%$KW_END%/g; 
			s/ESCAPED_BEGIN/\"$begin\"/g; s/ESCAPED_END/\"$end\"/g;

			if(scalar(keys(%local_options))>0 && ! /%$KW_BEGIN\{.*?\}%/){
				%global_options=%options;
			}
			if (%local_options){
				s/%$KW_BEGIN\{(.*?)\}%/&inlineOptionsMerge($KW_BEGIN,\%options,$1)/ge;
				s/%$KW_OPTIONS\{(.*?)\}%/&inlineOptionsMerge($KW_OPTIONS,\%options,$1)/ge;
				%local_options=();
				%options=%OPTDEF_ALL;
			} else {
				s/%$KW_BEGIN\{(.*?)\}%/&inlineOptionsMerge($KW_BEGIN,\%global_options,$1)/ge;
				s/%$KW_OPTIONS\{(.*?)\}%/&inlineOptionsMerge($KW_OPTIONS,\%global_options,$1)/ge;
			}
			if (%table_options){
				s/%$KW_TABLE_OPTIONS\{(.*?)\}%/&inlineOptionsMerge($KW_TABLE_OPTIONS,\%table_options,$1)/ge;
			}
		}
		$btext .= "$_\n";
	}
	# Do crypt the sections delimited by ad hoc directives
	$btext =~ s/%$KW_BEGIN\{(.*?)\}%((.|\n)*?)%$KW_END%/&doTextCrypt($1,$2)/ge;
	$btext =~ s/%$KW_OPTIONS\{(.*?)\}%/&doTextCrypt($1,"")/ge;
	$btext =~ s/%$KW_TABLE_OPTIONS\{(.*?)\}%/&doTextCrypt($1,"")/ge;
	$btext =~ s/<joinline>\n//g;
	$btext =~ s/&lt;joinline&gt;\n//g;
	if ($signed){ $btext.=insertSignForm($btext,$topic);}

	return $btext;
}

# =========================
sub doCrypt
{
	my ($text)=@_;
	my $result="";	
	my $compactText = compactOutsidePreBlocks($text);
	my $cryptedTablesText = cryptEverything($compactText);	
	my @cryptedTablesBlocks=reExtractBlocks($cryptedTablesText);	
	my @block=extractBlocks($text);	
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){ $block[$i]=$cryptedTablesBlocks[$i/2]; }
		$result .= $block[$i];
	}
	$result =~ s/<joinline>\n//g;
	$result =~ s/&lt;joinline&gt;\n//g;
	return $result;
}

#
# Main decrypting subroutines
#

# =========================
sub doTextDecrypt
{
	my ($action,$attributes,$all) = @_;
	my $result="";
	my $user="*";
	if(!defined($all)){ $user=TWiki::Func::getWikiName(); }
	my $method=TWiki::Func::extractNameValuePair($attributes,"method");
	my $crypted=TWiki::Func::extractNameValuePair($attributes,"crypted");
	my $decrypt=$cryptmethods{$method}[1];
	if(defined &$decrypt){
		$result=&$decrypt($action,$user,$crypted,$attributes); 
	}
	return $result;
}

# =========================
sub doDecrypt
{	
	my ($action,$text,$fromCrypt,$topic,$web)=@_;
	my @block;
	my $result="";
	my $sign=0;
	my $signed=0;
	
	# check to see if we're beeing called by pressing the "Sign page" button
	if (defined($fromCrypt)){
	if ($fromCrypt == 0){
		my $query = TWiki::Func::getCgiQuery();
		if(defined( $query )){ $sign = $query->param( 'sign' ); }
	}}
	
	# Extract verbatim blocks of text
	@block=extractBlocks($text);

	# sign the page if requested
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){
			if ($sign){
			if ($block[$i] =~ s/<!--REMOVENEXTLINES-->(.*\n)*<!--UNTILHERE-->//g){
				if (!$signed){ $signed=1; last; }
	}}}}
	if ($signed){ signPage($topic,$web); }
	
	# Interpret crypted parts in non verbatim blocks
	for(my $i=0;$i<=$#block;$i++){
		if($i%2==0){
			# Do decrypt the sections delimited by ad hoc directives
			$block[$i] =~ s/%$KW_CRYPTED\{(.*?)\}%/&doTextDecrypt($action,defined($1) ? $1 : "")/ge;
			# insert the list of valid/outdated signatures
			if (defined($fromCrypt)){ if ($fromCrypt == 0){
			if (($block[$i] =~ /%$KW_VALID_SIGNS%/) || ($block[$i] =~ /%$KW_OUTDATED_SIGNS%/)) {
				my $topicText = getTextToSign($topic,$web);
				$block[$i] =~ s/%$KW_VALID_SIGNS%/&listSignatures($topicText,1)/ge;
				$block[$i] =~ s/%$KW_OUTDATED_SIGNS%/&listSignatures($topicText,0)/ge;
		}}}}
		$result .= $block[$i];
	}
	$result =~ s/<joinline>\n//g;
	$result =~ s/&lt;joinline&gt;\n//g;
	return $result;
}

#
# Plugin Handlers
#

# =========================
sub initPlugin
{
	( $topic, $web, $user, $installWeb ) = @_;
	
	# check for Plugins.pm versions
	if( $TWiki::Plugins::VERSION < 1 ) {
		TWiki::Func::writeWarning(
		"Version mismatch between $pluginName and Plugins.pm" );
		return 0;
	}
	
	# Get plugin debug flag
	$debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
	
	# Set default for ACLs using current username
	my $username=TWiki::Func::getWikiName();
	$OPTDEF_ALL{"allowtextread"}=$username;
	$OPTDEF_ALL{"allowtextchange"}=$username;
	
	# Get the private key file path
	$privateKeyFile=$PRIVKEY_FILE;
  if ($TWiki::cfg{Plugins}{TopicCryptPlugin}{PRIVKEY_FILE}) {
       $privateKeyFile = "$TWiki::cfg{Plugins}{TopicCryptPlugin}{PRIVKEY_FILE}"
  }

	my $method =
		TWiki::Func::getPluginPreferencesValue( "DEFAULT_METHOD" );
	if($method){ $OPTDEF_ALL{"method"}=$method; }

	$warningEdit =
		TWiki::Func::getPluginPreferencesValue( "WARNING_EDIT" );
	if(!$warningEdit){ $warningEdit=sprintf($WARNING_EDIT,$username); }

	$maxSignatures = 
		TWiki::Func::getPluginPreferencesValue( "MAX_SIGNATURES" );
	if(!$maxSignatures){ $maxSignatures=$MAX_SIGNATURES; }
	
	# Plugin correctly initialized
	TWiki::Func::writeDebug(
	"- ${pluginName}::initPlugin($web.$topic) is OK")
	if $debug;

	return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;

	TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler($_[2].$_[1])")
		if $debug;

	# Decrypt texts the user is allowed to see
	$_[0]=doDecrypt($ACTION_VIEW,$_[0],0,$_[1],$_[2]);
}

# =========================
sub beforeEditHandler
{
### my ( $text, $topic, $web ) = @_; 

	TWiki::Func::writeDebug("- ${pluginName}::beforeEditHandler($_[2].$_[1])")
		if $debug;
	
	# Decrypt texts the user is allowed to edit
	# Keep hidden text as CRYPTED directive
	$_[0]=doDecrypt($ACTION_EDIT,$_[0]);
}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;

	TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler($_[2].$_[1])")
		if $debug;
	
	# Verify the user has not modified a CRYPTED directive (ie text he cannot
	# edit) and crypt text parts that are to be crypted.
	$_[0]=doSecureCrypt($_[2],$_[1],$_[0]);
}


1;
