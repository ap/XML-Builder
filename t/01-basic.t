use strict;
use XML::Builder;
use Test::More tests => 11;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

# Tag options

is $x->tag( 'br' ), '<br/>', 'simple closed tag';
is $x->tag( 'b', '' ), '<b></b>', 'simple forced open-close pair tag';
is $x->tag( 'b', 'a', 'b' ), '<b>a</b><b>b</b>', 'distributivity';
is $x->tag( 'b', [ 'a', 'b' ] ), '<b>ab</b>', 'distributivity escape';
is $x->tag( 'p', $x->tag( 'b', 'a', 'b' ) ), '<p><b>a</b></p><p><b>b</b></p>', 'distributivity w/ nesting';
is $x->tag( 'p', $x->tag( 'b', [ 'a', 'b' ] ) ), '<p><b>ab</b></p>', 'distributivity escape w/in nesting';

# Attributes

is $x->tag( 'p', { class => 'normal' }, '' ), '<p class="normal"></p>', 'attributes';
is $x->tag( 'p', { class => 'normal', style => undef }, '' ), '<p class="normal"></p>', 'skipping undefined attribute values';
is $x->tag( 'p', { class => 'small' }, 'a', 'b' ), '<p class="small">a</p><p class="small">b</p>', 'attributes distribute properly';
is $x->tag( 'p', { class => 'small', id => 'p1' }, 'a', { class => undef, id => 'p2' }, 'b' ), '<p class="small" id="p1">a</p><p id="p2">b</p>', 'overriding attribute values during distribution';
