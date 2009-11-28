use strict;
use XML::Builder;
use Test::More tests => 7;

isa_ok my $xb = XML::Builder->new, 'XML::Builder';

is $xb->escape_text( qq(<\x{FF34}\x{FF25}\x{FF33}\x{FF34} "&' d\xE3t\xE3>) ),
                     qq(&lt;&#65332;&#65317;&#65331;&#65332; &#34;&amp;&#39; d&#227;t&#227;&gt;),
	'text is properly encoded';

is $xb->escape_attr( qq(<\x{FF34}\x{FF25}\x{FF33}\x{FF34}\n"&'\rd\xE3t\xE3>) ),
                     qq(&lt;&#65332;&#65317;&#65331;&#65332;&#10;&#34;&amp;&#39;&#13;d&#227;t&#227;&gt;),
	'attribute values are properly encoded';

is $xb->flatten_cdata( qq(Test <![CDATA[<CDATA>]]> sections) ),
                       qq(Test &lt;CDATA&gt; sections),
	'CDATA sections are properly flattened';


isa_ok my $x = $xb->null_ns, 'XML::Builder::NS::QNameFactory';
is $x->p( 'AT&T >_<' )->as_string, '<p>AT&amp;T &gt;_&lt;</p>', 'automatic entity escaping';
is $x->p( $xb->unsafe( 'AT&T >_<' ) )->as_string, '<p>AT&T >_<</p>', 'unsafe text';
