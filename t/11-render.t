use strict;
use XML::Builder;
use Test::More tests => 2;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

my $arg = [ 'p', { class => 'normal' }, '' ];

is $x->render( $arg )->as_string, $x->tag( @$arg )->as_string, 'render results identical with tag';
