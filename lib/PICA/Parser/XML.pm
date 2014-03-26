package PICA::Parser::XML;
# ABSTRACT: PICA+ XML parser
# VERSION

use Carp qw(croak);
use XML::LibXML::Reader;

=head1 SYNOPSIS

L<PICA::Parser::XML> is a parser for PICA+ XML records. 

    use PICA::Parser::XML;

    my $parser = PICA::Parser::XML->new( $filename );

    while ( my $record_hash = $parser->next() ) {
        # do something        
    }

=head1 Arguments

=over

=item C<file>
 
Path to file with PICA XML records.

=item C<fh>

Open filehandle for file with PICA XML records.

=item C<string>

XML string with PICA XML records.

=back

=head1 METHODS

=head2 new($filename | $filehandle | $string)

=cut

sub new {
    my $class = shift;
    my $input = shift;

    my $self = {
        filename    => undef,
        rec_number  => 0,
        xml_reader  => undef,
    };

    # check for file or filehandle
    my $ishandle = eval { fileno($input); };
    if ( !$@ && defined $ishandle ) {
        my $reader = XML::LibXML::Reader->new(IO => $input)
             or croak "cannot read from filehandle $input\n";
        $self->{filename}   = scalar $input;
        $self->{xml_reader} = $reader;
    }
    elsif ( -e $input ) {
        my $reader = XML::LibXML::Reader->new(location => $input)
             or croak "cannot read from file $input\n";
        $self->{filename}   = $input;
        $self->{xml_reader} = $reader;
    }
    elsif ( defined $input && length $input > 0 ) {
        my $reader = XML::LibXML::Reader->new( string => $input )
            or croak "cannot read XML string $input\n";
        $self->{xml_reader} = $reader;
    } 
    else {
        croak "file, filehande or string $input does not exists";
    }
    return ( bless $self, $class );
}

=head2 next()

Reads the next record from PICA+ XML input stream. Returns a Perl hash.

=cut

sub next {
    my $self = shift;
    if ( $self->{xml_reader}->nextElement( 'record' ) ) {
        $self->{rec_number}++;
        my $record = _decode( $self->{xml_reader} );
        my ($id) = map { $_->[-1] } grep { $_->[0] =~ '003@' } @{$record};
        return { _id => $id, record => $record };
    } 
    return;
}

=head2 _decode()

Deserialize a PICA+ XML record to an array of field arrays.

=cut

sub _decode {
    my $reader = shift;
    my @record;

    # get all field nodes from PICA record;
    foreach my $field_node ( $reader->copyCurrentNode(1)->getChildrenByTagName('*') ) {
        my @field;
        
        # get field tag number
        my $tag = $field_node->getAttribute('tag');
        my $occurrence = $field_node->getAttribute('occurrence') // '';
        push(@field, ($tag, $occurrence));
            
            # get all subfield nodes
            foreach my $subfield_node ( $field_node->getChildrenByTagName('*') ) {
                my $subfield_code = $subfield_node->getAttribute('code');
                my $subfield_data = $subfield_node->textContent;
                push(@field, ($subfield_code, $subfield_data));
            }
        push(@record, [@field]);
    };
    return \@record;
}

=head1 SEEALSO

L<PICA::XMLParser>, included in the release of L<PICA::Record> implements
another PICA+ XML format parser, not aligned with the L<Catmandu> framework.

=cut

1; # End of PICA::Parser::XML