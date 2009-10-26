use strict;
use XML::Builder;
use Test::More tests => 7;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

# Tags
is $x->tag( 'br' )->as_string, '<br/>', 'simple closed tag';
is $x->tag( 'b', '' )->as_string, '<b></b>', 'simple forced open-close pair tag';
is $x->tag( 'b', 'a', )->as_string, '<b>a</b>', 'simple tag';
is $x->tag( 'b', 'a', 'b' )->as_string, '<b>ab</b>', 'simple tag with multiple content';

# Attributes
is $x->tag( 'p', { class => 'normal' }, '' )->as_string, '<p class="normal"></p>', 'attributes';
is $x->tag( 'p', { class => 'normal', style => undef }, '' )->as_string, '<p class="normal"></p>', 'skipping undefined attribute values';
