use strict;
use XML::Builder;
use Test::More tests => 13;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

# Tag options
is $x->tag( 'br' )->as_string, '<br/>', 'simple closed tag';
is $x->tag( 'b', '' )->as_string, '<b></b>', 'simple forced open-close pair tag';
is $x->tag( 'b', 'a', 'b' )->as_string, '<b>a</b><b>b</b>', 'distributivity';
is $x->tag( 'b', [ 'a', 'b' ] )->as_string, '<b>ab</b>', 'distributivity escape';
is $x->tag( 'p', $x->tag( 'b', 'a', 'b' ) )->as_string, '<p><b>a</b></p><p><b>b</b></p>', 'distributivity w/ nesting';
is $x->tag( 'p', $x->tag( 'b', [ 'a', 'b' ] ) )->as_string, '<p><b>ab</b></p>', 'distributivity escape w/in nesting';

# Attributes
is $x->tag( 'p', { class => 'normal' }, '' )->as_string, '<p class="normal"></p>', 'attributes';
is $x->tag( 'p', { class => 'normal', style => undef }, '' )->as_string, '<p class="normal"></p>', 'skipping undefined attribute values';
is $x->tag( 'p', { class => 'small' }, 'a', 'b' )->as_string, '<p class="small">a</p><p class="small">b</p>', 'attributes distribute properly';
is $x->tag( 'p', { class => 'small', id => 'p1' }, 'a', { class => undef, id => 'p2' }, 'b' )->as_string, '<p class="small" id="p1">a</p><p id="p2">b</p>', 'overriding attribute values during distribution';

# Text
is $x->tag( 'p', 'AT&T >_<' )->as_string, '<p>AT&amp;T &gt;_&lt;</p>', 'automatic entity escaping';
is $x->tag( 'p', $x->unsafe( 'AT&T >_<' ) )->as_string, '<p>AT&T >_<</p>', 'unsafe text';
