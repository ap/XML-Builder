use 5.010;
use strict;
use lib 'lib';
use XML::Builder;

my $xb = XML::Builder->new;
my $a = $xb->register_ns( 'http://www.w3.org/2005/Atom' => '' );
my $h = $xb->register_ns( 'http://www.w3.org/1999/xhtml' => 'h' );

say $xb->root( $a->feed, [
	$xb->tag( $a->title, 'dive into mark' ),
	$xb->tag( $a->subtitle, { type => 'html' }, 'a <em>lot</em> of effort went into making this effortless' ),
	$xb->tag( $a->updated, '2005-07-31T12:29:29Z' ),
	$xb->tag( $a->id, 'tag:example.org,2003:3' ),
	$xb->tag( $a->link, { rel => 'alternate', type => 'text/html', hreflang => 'en', href => 'http://example.org/' } ),
	$xb->tag( $a->link, { rel => 'self', type => 'application/atom+xml', href => 'http://example.org/feed.atom' } ),
	$xb->tag( $a->rights, 'Copyright (c) 2003, Mark Pilgrim' ),
	$xb->tag( $a->generator, { uri => 'http://www.example.com/', version => '1.0' }, 'Example Toolkit' ),
] );
__END__
     <entry>
       <title>Atom draft-07 snapshot</title>
       <link rel="alternate" type="text/html" href="http://example.org/2005/04/02/atom"/>
       <link rel="enclosure" type="audio/mpeg" length="1337" href="http://example.org/audio/ph34r_my_podcast.mp3"/>
       <id>tag:example.org,2003:3.2397</id>
       <updated>2005-07-31T12:29:29Z</updated>
       <published>2003-12-13T08:29:29-04:00</published>
       <author>
         <name>Mark Pilgrim</name>
         <uri>http://example.org/</uri>
         <email>f8dy@example.com</email>
       </author>
       <contributor>
         <name>Sam Ruby</name>
       </contributor>
       <contributor>
         <name>Joe Gregorio</name>
       </contributor>
       <content type="xhtml" xml:lang="en" xml:base="http://diveintomark.org/">
         <div xmlns="http://www.w3.org/1999/xhtml">
           <p><i>[Update: The Atom draft is finished.]</i></p>
         </div>
       </content>
     </entry>
