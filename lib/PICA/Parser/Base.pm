package PICA::Parser::Base;
use strict;
use warnings;

our $VERSION = '0.31';

use Carp qw(croak);

sub new {
    my $class = shift;
    my (%options) = @_ % 2 ? (fh => @_) : @_;

    my $input = $options{fh} || \*STDIN;

    my $self = bless { 
        bless => !!$options{bless},
    }, $class;

    # check for file or filehandle
    my $ishandle = eval { fileno($input); };
    if ( !$@ && defined $ishandle ) {
        $self->{reader} = $input;
    } elsif ( (ref $input and ref $input eq 'SCALAR') or -e $input ) {
        open($self->{reader}, "<:encoding(utf-8)", $input)
            or croak "cannot read from file $input\n";
    } else {
        croak "file or filehandle $input does not exists";
    }

    bless $self, $class;
}

sub next {
    my ($self) = @_;

    # get last subfield from 003@ as id
    while ( my $record = $self->_next_record ) {
        next unless @$record;
        my ($id) = map { $_->[-1] } grep { $_->[0] =~ '003@' } @$record;
        $record = { _id => $id, record => $record };
        bless $record, 'PICA::Data' if $self->{bless};
        return $record;
    }

    return;
}

1;
__END__

=head1 NAME

PICA::Parser::Base - abstract base class of PICA parsers

=head1 SYNOPSIS

    use PICA::Parser::Plain;
    my $parser = PICA::Parser::Plain->new( $filename );

    while ( my $record = $parser->next ) {
        # do something        
    }

    use PICA::Parser::Plus;
    my $parser = PICA::Parser::Plus->new( $filename, bless => 1 );
    ... # records will be instances of PICA::Data

    use PICA::Parser::XML;
    my $parser = PICA::Parser::XML->new( $filename, start => 1 );
    ...

=head1 DESCRIPTION

This abstract base class of PICA+ parsers should not be instantiated directly.
Use one of the following subclasses instead:

=over 

=item L<PICA::Parser::Plain>

=item L<PICA::Parser::Plus>

=item L<PICA::Parser::XML>

=back

=head1 METHODS

=head2 new( [ $input | fh => $input ] [ %options ] )

Initialize parser to read from a given file, handle (e.g. L<IO::Handle>), or
string reference. L<PICA::Parser::XML> also detects plain XML strings. The
common option C<blessed> (disabled by default) can be used to return records as
instances of L<PICA::Data>.

=head2 next

Reads the next PICA+ record. Returns a (optionally blessed) hash with keys
C<_id> and C<record>, as defined in L<PICA::Data>.

=head1 SEE ALSO

See L<Catmandu::Importer::PICA> for usage of this module in L<Catmandu>.

Alternative PICA parsers had been implemented as L<PICA::PlainParser> and
L<PICA::XMLParser> and included in the release of L<PICA::Record> (deprecated).

=cut
