use strict;
use XML::Builder;
use Test::More tests => 5;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

is $x->tag_foreach( 'b', 'a', 'b' )->as_string, '<b>a</b><b>b</b>', 'simple distributivity';
is $x->tag_foreach( 'p', $x->tag_foreach( 'b', 'a', 'b' ) )->as_string, '<p><b>a</b></p><p><b>b</b></p>', 'distributivity w/ nesting';
is $x->tag_foreach( 'p', { class => 'small' }, 'a', 'b' )->as_string, '<p class="small">a</p><p class="small">b</p>', 'attributes distribute properly';
is $x->tag_foreach( 'p', { class => 'small', id => 'p1' }, 'a', { class => undef, id => 'p2' }, 'b' )->as_string, '<p class="small" id="p1">a</p><p id="p2">b</p>', 'overriding attribute values during distribution';
