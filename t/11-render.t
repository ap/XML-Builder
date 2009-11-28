use strict;
use XML::Builder;
use Test::More tests => 2;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

my @arg = ( \'', 'p', { class => 'normal' }, '' );

my $explicit = $x->ns( ${$arg[0]} )->_qname( $arg[1] )->tag( @arg[ 2 .. $#arg ] )->as_string;
my $render = $x->render( @arg )->as_string;
is $render, $explicit, 'render results identical with tag';
