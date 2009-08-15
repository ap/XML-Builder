use 5.010;
use strict;
use lib 'lib';
use XML::Builder;

my $xb = XML::Builder->new;
my $h = $xb->register_ns( 'http://www.w3.org/1999/xhtml' => shift );

say $xb->root( $h->html, [
	$xb->tag( $h->head, $xb->tag( $h->title, 'Sample page' ) ),
	$xb->tag( $h->body,
		[
			$xb->tag( $h->h1, { class => 'main' }, 'Sample page' ),
			$xb->tag( $h->p, 'Hello, World', { class => 'detail' }, 'Second para', { class => undef }, '3rd > 2nd', "\x{20AC}" )
		],
	),
] );
