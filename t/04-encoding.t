use strict;
use XML::Builder;
use Test::More tests => 4;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

is $x->escape_text( qq(<\x{FF34}\x{FF25}\x{FF33}\x{FF34} "&' d\xE3t\xE3>) ),
	                qq(&lt;&#65332;&#65317;&#65331;&#65332; &#34;&amp;&#39; d&#227;t&#227;&gt;),
	'text is properly encoded';

is $x->escape_attr( qq(<\x{FF34}\x{FF25}\x{FF33}\x{FF34}\n"&'\rd\xE3t\xE3>) ),
	                qq(&lt;&#65332;&#65317;&#65331;&#65332;&#10;&#34;&amp;&#39;&#13;d&#227;t&#227;&gt;),
	'attribute values are properly encoded';

is $x->flatten_cdata( qq(Test <![CDATA[<CDATA>]]> sections) ),
	                  qq(Test &lt;CDATA&gt; sections),
	'CDATA sections are properly flattened';
