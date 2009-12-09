use strict;

package XML::Builder::Util;

use Scalar::Util ();
use Encode ();
use Carp::Clan '^XML::Builder(?:\z|::)';

sub is_raw_hash {
	my ( $scalar ) = @_;
	return
		'HASH' eq ref $scalar
		and not Scalar::Util::blessed $scalar;
}

sub is_raw_array {
	my ( $scalar ) = @_;
	return
		'ARRAY' eq ref $scalar
		and not Scalar::Util::blessed $scalar;
}

sub is_raw_scalar {
	my ( $scalar ) = @_;
	return
		'SCALAR' eq ref $scalar
		and not Scalar::Util::blessed $scalar;
}

sub merge_param_hash {
	my ( $cur, $param ) = @_;

	return if not ( @$param and is_raw_hash $param->[0] );

	my $new = shift @$param;

	@{ $cur }{ keys %$new } = values %$new;
	while ( my ( $k, $v ) = each %$cur ) {
		delete $cur->{ $k } if not defined $v;
	}
}

#######################################################################

package XML::Builder;

use Object::Tiny::Lvalue qw( nsmap default_ns encoding );

our $VERSION = '1.0001';
$VERSION = eval $VERSION;

# these aren't constants, they need to be overridable in subclasses
sub ns_class       { 'XML::Builder::NS' }
sub fragment_class { 'XML::Builder::Fragment' }
sub qname_class    { 'XML::Builder::Fragment::QName' }
sub tag_class      { 'XML::Builder::Fragment::Tag' }
sub unsafe_class   { 'XML::Builder::Fragment::Unsafe' }
sub root_class     { 'XML::Builder::Fragment::Root' }
sub doc_class      { 'XML::Builder::Fragment::Document' }

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	$self->encoding ||= 'us-ascii';
	$self->nsmap ||= {};
	return $self;
}

sub register_ns {
	my $self = shift;
	my ( $uri, $pfx ) = @_;

	my $nsmap = $self->nsmap;

	$uri = $self->stringify( $uri );

	if ( exists $nsmap->{ $uri } ) {
		my $ns = $nsmap->{ $uri };
		my $registered_pfx = $ns->prefix;

		XML::Builder::Util::croak( "Namespace '$uri' being bound to '$pfx' is already bound to '$registered_pfx'" )
			if defined $pfx and $pfx ne $registered_pfx;

		return $ns;
	}

	if ( not defined $pfx ) {
		my %pfxmap = map {; $_->prefix => $_ } values %$nsmap;

		if ( $uri eq '' and not exists $pfxmap{ '' } ) {
			return $self->register_ns( '', '' );
		}

		my $counter;
		my $letter = ( $uri =~ m!([[:alpha:]])[^/]*/?\z! ) ? lc $1 : 'ns';
		do { $pfx = $letter . ++$counter } while exists $pfxmap{ $pfx };
	}

	# FIXME needs proper validity check per XML TR
	XML::Builder::Util::croak( "Invalid namespace prefix '$pfx'" )
		if length $pfx and $pfx !~ /[\w-]/;

	my $ns = $self->ns_class->new(
		builder => $self,
		uri     => $uri,
		prefix  => $pfx,
	);

	$self->default_ns = $uri if '' eq $pfx;
	return $nsmap->{ $uri } = $ns;
}

sub ns { my $self = shift; $self->register_ns( @_ )->factory }
sub null_ns { shift->ns( '', '' ) }

sub qname {
	my $self   = shift;
	my $ns_uri = shift;
	return $self->register_ns( $ns_uri )->qname( @_ );
}

sub parse_qname {
	my $self = shift;
	my ( $name ) = @_;

	my $ns_uri = '';
	$ns_uri = $1 if $name =~ s/\A\{([^}]+)\}//;

	return $self->qname( $ns_uri, $name );
}

sub nsmap_to_attr {
	my $self = shift;
	my ( $attr ) = @_;

	$attr ||= {};

	while ( my ( $uri, $ns ) = each %{ $self->nsmap } ) {
		my $pfx = $ns->prefix;
		next if '' eq $pfx;
		$attr->{ 'xmlns:' . $pfx } = $uri;
	}

	# make sure to always declare the default NS (if not bound to a URI, by
	# explicitly undefining it) to allow embedding the XML easily without
	# having to parse the fragment
	# [in 5.10: $attr->{ xmlns } = $map->default_ns // '';]
	$attr->{ xmlns } = $self->default_ns;
	$attr->{ xmlns } .= '';

	return $attr;
}

sub root {
	my $self = shift;
	my ( $tag ) = @_;
	return $self->root_class->adopt( $tag );
}

sub document {
	my $self = shift;
	my ( $tag ) = @_;
	return $self->doc_class->adopt( $tag );
}

sub unsafe {
	my $self = shift;
	my ( $string ) = @_;
	return $self->unsafe_class->new( builder => $self, content => $string );
}

sub render {
	my $self = shift;
	return XML::Builder::Util::is_raw_scalar( $_[0] )
		? $self->qname( ${$_[0]}, @_[ 1 .. $#_ ] )
		: $self->fragment_class->new( builder => $self, content => [ @_ ] );
}

{
	my %XML_NCR = map eval "qq[$_]", qw(
		\xA &#10;  \xD &#13;
		&   &amp;  <   &lt;   > &gt;
		"   &#34;  '   &#39;
	);

	my %type = (
		encode      => undef,
		escape_text => qr/([<>&'"])/,
		escape_attr => qr/([<>&'"\xA\xD])/,
	);

	# using eval instead of closures to avoid __ANON__
	while ( my ( $subname, $specials_rx ) = each %type ) {
		my $esc = '';

		$esc = sprintf '$str =~ s{ %s }{ $XML_NCR{$1} }gex', $specials_rx
			if defined $specials_rx;

		eval sprintf 'sub %s {
			my $self = shift;
			my $str = $self->stringify( shift );
			%s;
			return Encode::encode $self->encoding, $str, Encode::HTMLCREF;
		}', $subname, $esc;
	}
}

sub stringify {
	my $self = shift;
	my ( $thing ) = @_;

	return if not defined $thing;

	return $thing if not Scalar::Util::blessed $thing;

	my $conv = $thing->can( 'as_string' ) || overload::Method( $thing, '""' );
	return $conv->( $thing ) if $conv;

	XML::Builder::Util::croak( 'Unstringifiable object ', $thing );
}

sub preamble { qq(<?xml version="1.0" encoding="${\shift->encoding}"?>\n) }

#######################################################################

package XML::Builder::NS;

use Object::Tiny::Lvalue qw( builder uri prefix qname_for_localname );
use overload '""' => 'uri';

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	$self->qname_for_localname ||= {};
	Scalar::Util::weaken $self->builder;
	return $self;
}

sub qname {
	my $self = shift;
	my $name = shift;

	my $builder = $self->builder
		|| XML::Builder::Util::croak( 'XML::Builder for this NS object has gone out of scope' );

	my $qname = $self->qname_for_localname->{ $name } ||= $builder->qname_class->new(
		name    => $name,
		ns      => $self,
		builder => $builder,
	);

	return @_ ? $qname->tag( @_ ) : $qname;
}

sub factory { bless \shift, 'XML::Builder::NS::QNameFactory' }

#######################################################################

package XML::Builder::NS::QNameFactory;

sub AUTOLOAD { my $self = shift; $$self->qname( ( our $AUTOLOAD =~ /.*::(.*)/ ), @_ ) }
sub _qname   { my $self = shift; $$self->qname(                                  @_ ) }
sub DESTROY  {}

#######################################################################

package XML::Builder::Fragment;

use Object::Tiny::Lvalue qw( builder content );

sub depends_ns_scope { 0 }

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	my $builder = $self->builder;
	my $content = $self->content;

	my ( @gather, @take );

	for my $r ( XML::Builder::Util::is_raw_array( $content ) ? @$content : $content ) {
		@take = $r;

		if ( not Scalar::Util::blessed $r ) {
			@take = $builder->render( @_ ) if XML::Builder::Util::is_raw_array $r;
			next;
		}

		if ( not $r->isa( $builder->fragment_class ) ) {
			@take = $builder->stringify( $r );
			next;
		}

		next if $builder == $r->builder;

		XML::Builder::Util::croak( 'Cannot merge XML::Builder fragments built with different namespace maps' )
			if $r->depends_ns_scope;

		@take = $r->flatten;

		my ( $self_enc, $r_enc ) = map { lc $_->encoding } $builder, $r->builder;
		next
			if $self_enc eq $r_enc
			# be more permissive: ASCII is one-way compatible with UTF-8 and Latin-1
			or 'us-ascii' eq $r_enc and grep { $_ eq $self_enc } 'utf-8', 'iso-8859-1';

		XML::Builder::Util::croak(
			'Cannot merge XML::Builder fragments with incompatible encodings'
			. " (have $self_enc, fragment has $r_enc)"
		);
	}
	continue {
		push @gather, @take;
	}

	$self->content = \@gather;

	return $self;
}

sub as_string {
	my $self = shift;
	my $builder = $self->builder;
	return join '', map { ref $_ ? $_->as_string : $builder->escape_text( $_ ) } @{ $self->content };
}

sub flatten {
	my $self = shift;
	return @{ $self->content };
}

#######################################################################

package XML::Builder::Fragment::Unsafe;

use parent -norequire => 'XML::Builder::Fragment';

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	$self->content = $self->builder->stringify( $self->content );
	return $self;
}

sub as_string {
	my $self = shift;
	return $self->builder->encode( $self->content );
}

sub flatten { shift }

#######################################################################

package XML::Builder::Fragment::QName;

use Object::Tiny::Lvalue qw( builder ns name as_qname as_attr_qname as_clarkname as_string );

use parent -norequire => 'XML::Builder::Fragment';
use overload '""' => 'as_clarkname';

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;

	my $uri = $self->ns->uri;
	my $pfx = $self->ns->prefix;
	Scalar::Util::weaken $self->ns; # really don't even need this any more
	Scalar::Util::weaken $self->builder;

	# NB.: attributes without a prefix not in a namespace rather than in the
	# default namespace, so attributes without a namespace never need a prefix

	my $name = $self->name;
	$self->as_qname      = ( '' eq $pfx               ) ? $name : "$pfx:$name";
	$self->as_attr_qname = ( '' eq $pfx or '' eq $uri ) ? $name : "$pfx:$name";
	$self->as_clarkname  = (               '' eq $uri ) ? $name : "{$uri}$name";
	$self->as_string     = '<' . $self->as_qname . '/>';

	return $self;
}

sub tag {
	my $self = shift;

	if ( 'SCALAR' eq ref $_[0] and 'foreach' eq ${$_[0]} ) {
		shift @_; # throw away
		return $self->foreach( @_ );
	}

	# has to be written this way so it'll drop undef attributes
	my $attr = {};
	XML::Builder::Util::merge_param_hash( $attr, \@_ );

	my $builder = $self->builder
		|| XML::Builder::Util::croak( 'XML::Builder for this QName object has gone out of scope' );

	return $builder->tag_class->new(
		qname   => $self,
		attr    => $attr,
		content => [ map $builder->render( $_ ), @_ ],
		builder => $builder,
	);
}

sub foreach {
	my $self = shift;

	my $attr = {};
	my @out  = ();

	my $builder = $self->builder
		|| XML::Builder::Util::croak( 'XML::Builder for this QName object has gone out of scope' );

	do {
		XML::Builder::Util::merge_param_hash( $attr, \@_ );
		my $content = XML::Builder::Util::is_raw_hash( $_[0] ) ? undef : shift;
		push @out, $builder->tag_class->new(
			qname   => $self,
			attr    => {%$attr},
			content => $builder->render( $content ),
			builder => $builder,
		);
	} while @_;

	return $builder->fragment_class->new( builder => $builder, content => \@out )
		if @out > 1 and not wantarray;

	return @out[ 0 .. $#out ];
}

#######################################################################

package XML::Builder::Fragment::Tag;

use parent -norequire => 'XML::Builder::Fragment';
use Object::Tiny::Lvalue qw( qname attr );

sub depends_ns_scope { 1 }

sub as_string {
	my $self = shift;

	my $builder = $self->builder;
	my $qname   = $self->qname->as_qname;
	my $attr    = $self->attr || {};

	my $tag = join ' ', $qname,
		map { sprintf '%s="%s"', $builder->parse_qname( $_ )->as_attr_qname, $builder->escape_attr( $attr->{ $_ } ) }
		sort keys %$attr;

	my $content = @{ $self->content } ? $self->SUPER::as_string : undef;
	return defined $content
		? "<$tag>$content</$qname>"
		: "<$tag/>";
}

sub append {
	my $self = shift;
	return $self->builder->fragment_class->new(
		builder => $self->builder,
		content => [ $self, $self->builder->render( @_ ) ],
	);
}

sub flatten { shift }

#######################################################################

package XML::Builder::Fragment::Root;

use parent -norequire => 'XML::Builder::Fragment::Tag';
use overload '""' => 'as_string';

sub depends_ns_scope { 0 }

sub adopt {
	my $class = shift;
	my ( $obj ) = @_;
	$obj->builder->nsmap_to_attr( $obj->attr ||= {} );
	return bless $obj, $class;
}

#######################################################################

package XML::Builder::Fragment::Document;

use parent -norequire => 'XML::Builder::Fragment::Root';

sub as_string {
	my $self = shift;
	return $self->builder->preamble . $self->SUPER::as_string( @_ );
}

#######################################################################

1;
