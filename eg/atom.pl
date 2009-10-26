use 5.010;
use strict;
use lib 'lib';
use XML::Builder;

my $xb = XML::Builder->new;
my $a = $xb->register_ns( 'http://www.w3.org/2005/Atom' => '' );

my $hb = XML::Builder->new;
my $h = $hb->register_ns( 'http://www.w3.org/1999/xhtml' => '' );

say $xb->document(
	$a->feed(
		$a->title( 'dive into mark' ),
		$a->subtitle( { type => 'html' }, 'a <em>lot</em> of effort went into making this effortless' ),
		$a->updated( '2005-07-31T12:29:29Z' ),
		$a->id( 'tag:example.org,2003:3' ),
		$a->link( { rel => 'alternate', type => 'text/html', hreflang => 'en', href => 'http://example.org/' } ),
		$a->link( { rel => 'self', type => 'application/atom+xml', href => 'http://example.org/feed.atom' } ),
		$a->rights( 'Copyright (c) 2003, Mark Pilgrim' ),
		$a->generator( { uri => 'http://www.example.com/', version => '1.0' }, 'Example Toolkit' ),
		$a->entry(
			$a->title( 'Atom draft-07 snapshot' ),
			$a->link( { rel => 'alternate', type => 'text/html', href => 'http://example.org/2005/04/02/atom' } ),
			$a->link( { rel => 'enclosure', type => 'audio/mpeg', length => 1337, href => 'http://example.org/audio/ph34r_my_podcast.mp3' } ),
			$a->id( 'tag:example.org,2003:3.2397' ),
			$a->updated( '2005-07-31T12:29:29Z' ),
			$a->published( '2003-12-13T08:29:29-04:00' ),
			$a->author(
				$a->name( 'Mark Pilgrim' ),
				$a->uri( 'http://example.org/' ),
				$a->email( 'f8dy@example.com' ),
			),
			$a->contributor->foreach(
				$a->name( 'Sam Ruby' ),
				$a->name( 'Joe Gregorio' ),
			),
			$a->content( { type => 'xhtml', 'xml:lang' => 'en', 'xml:base' => 'http://diveintomark.org/' },
				$hb->root( $h->div( $h->p( $h->i( '[Update: The Atom draft is finished.]' ) ) ) ),
			),
		),
	),
);
