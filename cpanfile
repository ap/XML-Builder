requires 'perl', '5.008001';
requires 'strict';
requires 'warnings';
requires 'overload';
requires 'Encode';
requires 'Scalar::Util';

requires 'Carp::Clan';
requires 'Object::Tiny::Lvalue';

on test => sub {
	requires 'Test::More';
};

# vim: ft=perl
