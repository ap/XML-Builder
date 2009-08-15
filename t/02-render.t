use strict;
use XML::Builder;
use Test::More tests => 4;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

my $arg = [ 'p', { class => 'normal' }, '' ];

{
package Mock::XML::Builder;
our @ISA = 'XML::Builder';
sub tag {
	my $self = shift;
	Test::More::is_deeply \@_, $arg, 'render passes through to tag';
	return $self->SUPER::tag( @_ );
}
}

isa_ok my $mx = Mock::XML::Builder->new, 'Mock::XML::Builder';
is $mx->render( \$arg )->as_string, $x->tag( @$arg )->as_string, 'render results identical with tag';
