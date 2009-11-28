use strict;
use XML::Builder;
use Test::More tests => 8;

isa_ok my $xb = XML::Builder->new, 'XML::Builder';
isa_ok my $x  = $xb->null_ns, 'XML::Builder::NS::QNameFactory';

# Tags
is $x->br->as_string, '<br/>', 'simple closed tag';
is $x->b( '' )->as_string, '<b></b>', 'simple forced open-close pair tag';
is $x->b( 'a', )->as_string, '<b>a</b>', 'simple tag';
is $x->b( 'a', 'b' )->as_string, '<b>ab</b>', 'simple tag with multiple content';

# Attributes
is $x->p( { class => 'normal' }, '' )->as_string, '<p class="normal"></p>', 'attributes';
is $x->p( { class => 'normal', style => undef }, '' )->as_string, '<p class="normal"></p>', 'skipping undefined attribute values';
