use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name        => 'XML::Builder',
	license            => 'perl',
	dist_author        => 'Aristotle Pagaltzis <pagaltzis@gmx.de>',
	requires           => {
		'Scalar::Util'         => 0,
		Encode                 => 0,
		parent                 => 0,
		'Object::Tiny::Lvalue' => 0,
		'Carp::Clan'           => 0,
	},
	build_requires     => { 'Test::More' => 0 },
	add_to_cleanup     => [ 'XML-Builder-*' ],
	create_makefile_pl => 'traditional',
);

$builder->create_build_script();
