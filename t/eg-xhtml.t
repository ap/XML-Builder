use strict;
use XML::Builder;
use Test::More tests => 3;

isa_ok my $xb = XML::Builder->new, 'XML::Builder';
isa_ok my $h = $xb->ns( 'http://www.w3.org/1999/xhtml' => '' ), 'XML::Builder::NS::QNameFactory';

chomp( my $expected = <<'' );
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Sample page</title></head><body>
<h1 class="main">Sample page</h1>
<p>H&#8364;llo, World</p>
<p class="detail">Second para</p>
<p>3rd &gt; 2nd</p>
</body></html>

my $result = $xb->root(
	$h->html(
		$h->head( $h->title( 'Sample page' ) ),
		$h->body(
			"\n", $h->h1( { class => 'main' }, 'Sample page' ), "\n",
			map { $_, "\n" } $h->p->foreach(
				"H\x{20AC}llo, World",
				{ class => 'detail' }, 'Second para',
				{ class => undef }, '3rd > 2nd',
			),
		),
	),
)->as_string;

is $result, $expected, 'example XHTML document';
