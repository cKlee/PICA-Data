use strict;
use warnings;
use Test::More;
use utf8;

use PICA::Data qw(pica_parser pica_writer pica_value);
use PICA::Parser::XML;

foreach my $type (qw(Plain Plus XML Binary)) {
    my $module = "PICA::Parser::$type";
    my $file   = 't/files/pica.' . lc($type);

    note $module;
    my $parser = pica_parser( $type => $file );
    is ref($parser), "PICA::Parser::$type", "parser from file";

    my $record = $parser->next;
    isnt ref($record), 'PICA::Data', 'not blessed by default';

    ok $record->{_id} eq '12345', 'record _id';
    ok $record->{record}->[0][0] eq '002@', 'tag from first field';
    is_deeply $record->{record}->[1], ['003@', '', 0 => '12345'], 'second field';
    is_deeply $record->{record}->[4], ['012X', '', 0 => '0', x => '', y => ''], 'empty subfields';
    is $record->{record}->[6]->[7], '柳经纬主编;', 'Unicode';
    is_deeply $record->{record}->[11],
        [ '145Z', '40', 'a', '$', 'b', 'test$', 'c', '...' ], 'sub field with $';

    ok $parser->next()->{_id} eq '67890', 'next record';
    ok !$parser->next, 'parsed all records';

    foreach my $mode ( '<', '<:utf8' ) {
        next
            if ( $mode eq '<' and $type ne 'XML' )
            or ( $mode eq '<:utf8' and $type eq 'XML' );
        open( my $fh, $mode, $file );
        my $record = pica_parser( $type => $fh )->next;
        is_deeply pica_value( $record, '021A$h' ), '柳经纬主编;',
            'read from handle';
    }


    my $data = do { local (@ARGV,$/) = $file; <> };

    # read from string reference
    $parser = eval "PICA::Parser::$type->new(\\\$data, bless => 1 )";
    isa_ok $parser, "PICA::Parser::$type";
    $record = $parser->next;
    isa_ok $record, 'PICA::Data';
    is $record->{record}->[6]->[7], '柳经纬主编;', 'Unicode';

}

note 'PICA::Parser::PPXML'; 
{
    use PICA::Parser::PPXML;
    my $parser = PICA::Parser::PPXML->new('./t/files/ppxml.xml');
    is ref($parser), "PICA::Parser::PPXML", "parser from file";
    my $record = $parser->next;
    isnt ref($record), 'PICA::Data', 'not blessed by default';
    ok $record->{_id} eq '1027146724', 'record _id';
    ok $record->{record}->[0][0] eq '001@', 'tag from first field';
    is_deeply $record->{record}->[7], ['003@', '', '0', '1027146724'], 'id field';
    ok $parser->next()->{_id} eq '988352591', 'next record';
    ok !$parser->next, 'parsed all records';
}

# TODO: dump.dat, bgb.example, sru_picaxml.xml
# test XML with BOM

my $xml = q{<record xmlns="info:srw/schema/5/picaXML-v1.0"><datafield tag="003@"><subfield code="0">1234€</subfield></datafield></record>};
my $record = pica_parser( 'xml', $xml )->next;
is_deeply $record->{record}, [ [ '003@', '', '0', '1234€'] ], 'xml from string'; 


note 'error handling';

ok pica_parser('plus', \"003@ \x{1F}01")->next;
foreach ("0033 \x{1F}01", "003@/0 \x{1F}01") {
    eval { pica_parser('plus', \$_)->next };
    ok $@, 'invalid PICA field structure in PICA plus';
    my  $field = $_; $field =~ s/\x{1F}/\$/g;
    eval { pica_parser('plain', \$field)->next };
    ok $@, 'invalid PICA field structure in PICA plain';
}

eval { pica_parser('doesnotexist') };
ok $@, 'unknown parser';

eval { pica_parser( xml => '' ) };
ok $@, 'invalid handle';

eval { pica_parser( plus => [] ) };
ok $@, 'invalid handle';

eval { pica_parser( plain => bless({},'MyFooBar') ) };
ok $@, 'invalid handle';


SKIP: {
my $str = '003@ '.PICA::Parser::Plus::SUBFIELD_INDICATOR.'01234'
        . PICA::Parser::Plus::END_OF_FIELD
        . '021A '.PICA::Parser::Plus::SUBFIELD_INDICATOR.'aHello $¥!'
        . PICA::Parser::Plus::END_OF_RECORD;

    skip "utf8 is driving me crazy", 1;
    # TODO: why UTF-8 encoded while PICA plain is not?
    # See https://travis-ci.org/gbv/PICA-Data/builds/35711139
    use Encode;
    $record = [
         [ '003@', '', '0', '1234' ],
        # ok in perl <= 5.16
         [ '021A', '', 'a', encode('UTF-8',"Hello \$\N{U+00A5}!") ]
        # ok in perl >= 5.18  
        # [ '021A', '', 'a', 'Hello $¥!' ]
        ];
     
    open my $fh, '<', \$str;
    is_deeply pica_parser( plus => $fh )->next, { 
        _id => 1234, record => $record
    }, 'Plus format UTF-8 from string';
};

done_testing;
