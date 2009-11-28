use strict;
use XML::Builder;
use Test::More tests => 6;

isa_ok my $xb = XML::Builder->new, 'XML::Builder';
isa_ok my $x  = $xb->null_ns, 'XML::Builder::NS::QNameFactory';

is $x->b->foreach( 'a', 'b' )->as_string, '<b>a</b><b>b</b>', 'simple distributivity';
is $x->p->foreach( $x->b->foreach( 'a', 'b' ) )->as_string, '<p><b>a</b></p><p><b>b</b></p>', 'distributivity w/ nesting';
is $x->p->foreach( { class => 'small' }, 'a', 'b' )->as_string, '<p class="small">a</p><p class="small">b</p>', 'attributes distribute properly';
is $x->p->foreach( { class => 'small', id => 'p1' }, 'a', { class => undef, id => 'p2' }, 'b' )->as_string, '<p class="small" id="p1">a</p><p id="p2">b</p>', 'overriding attribute values during distribution';
