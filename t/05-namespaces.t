use strict;
use XML::Builder;
use Test::More tests => 13;

isa_ok my $x = XML::Builder->new, 'XML::Builder';
isa_ok my $t = $x->null_ns, 'XML::Builder::QName';

is $x->register_ns('urn:foo')->bar, '{urn:foo}bar', 'qnameification';

# Check that the basics work this way too
is $t->br->as_string, '<br/>', 'simple closed tag';
is $t->b( '' )->as_string, '<b></b>', 'simple forced open-close pair tag';
is $t->b( 'a', 'b' )->as_string, '<b>a</b><b>b</b>', 'distributivity';
is $t->b( [ 'a', 'b' ] )->as_string, '<b>ab</b>', 'distributivity escape';
is $t->p( $t->b( 'a', 'b' ) )->as_string, '<p><b>a</b></p><p><b>b</b></p>', 'distributivity w/ nesting';
is $t->p( $t->b( [ 'a', 'b' ] ) )->as_string, '<p><b>ab</b></p>', 'distributivity escape w/in nesting';
is $t->p( { class => 'normal' }, '' )->as_string, '<p class="normal"></p>', 'attributes';
is $t->p( { class => 'normal', style => undef }, '' )->as_string, '<p class="normal"></p>', 'skipping undefined attribute values';
is $t->p( { class => 'small' }, 'a', 'b' )->as_string, '<p class="small">a</p><p class="small">b</p>', 'attributes distribute properly';
is $t->p( { class => 'small', id => 'p1' }, 'a', { class => undef, id => 'p2' }, 'b' )->as_string, '<p class="small" id="p1">a</p><p id="p2">b</p>', 'overriding attribute values during distribution';
