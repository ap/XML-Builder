use 5.010;
use strict;
use lib 'lib';
use XML::Builder;

my $xb = XML::Builder->new;
my $a = $xb->register_ns( 'http://www.w3.org/2005/Atom' => 'a' );
my $h = $xb->register_ns( 'http://www.w3.org/1999/xhtml' => '' );

say $xb->root( $a->feed, [
	$xb->tag( $a->title, 'dive into mark' ),
	$xb->tag( $a->subtitle, { type => 'html' }, 'a <em>lot</em> of effort went into making this effortless' ),
	$xb->tag( $a->updated, '2005-07-31T12:29:29Z' ),
	$xb->tag( $a->id, 'tag:example.org,2003:3' ),
	$xb->tag( $a->link, { rel => 'alternate', type => 'text/html', hreflang => 'en', href => 'http://example.org/' } ),
	$xb->tag( $a->link, { rel => 'self', type => 'application/atom+xml', href => 'http://example.org/feed.atom' } ),
	$xb->tag( $a->rights, 'Copyright (c) 2003, Mark Pilgrim' ),
	$xb->tag( $a->generator, { uri => 'http://www.example.com/', version => '1.0' }, 'Example Toolkit' ),
	$xb->tag( $a->entry, [
		$xb->tag( $a->title, 'Atom draft-07 snapshot' ),
		$xb->tag( $a->link, { rel => 'alternate', type => 'text/html', href => 'http://example.org/2005/04/02/atom' } ),
		$xb->tag( $a->link, { rel => 'enclosure', type => 'audio/mpeg', length => 1337, href => 'http://example.org/audio/ph34r_my_podcast.mp3' } ),
		$xb->tag( $a->id, 'tag:example.org,2003:3.2397' ),
		$xb->tag( $a->updated, '2005-07-31T12:29:29Z' ),
		$xb->tag( $a->published, '2003-12-13T08:29:29-04:00' ),
		$xb->tag( $a->author, [
			$xb->tag( $a->name, 'Mark Pilgrim' ),
			$xb->tag( $a->uri, 'http://example.org/' ),
			$xb->tag( $a->email, 'f8dy@example.com' ),
		] ),
		$xb->tag( $a->contributor,
			$xb->tag( $a->name, 'Sam Ruby' ),
			$xb->tag( $a->name, 'Joe Gregorio' ),
		),
		$xb->tag( $a->content, { type => 'xhtml', 'xml:lang' => 'en', 'xml:base' => 'http://diveintomark.org/' }, [
			$xb->tag( $h->div, $xb->tag( $h->p, $xb->tag( $h->i, '[Update: The Atom draft is finished.]' ) ) ),
		] ),
	] ),
] );
