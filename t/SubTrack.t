#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use File::Temp;

use Test::More;
use Test::File;
use Test::Exception;

#use Devel::Cover;

# -----
# checks if the module can load
# -----

use_ok('EGTrackHubs::SubTrack');

# -----
# test constructor
# -----

my $st_obj = EGTrackHubs::SubTrack->new(
    "SRR351196",  "SAMN00728445", "bigdata url", "short label",
    "long label", "cram",         "on"
);

isa_ok( $st_obj, 'EGTrackHubs::SubTrack',
    'The object constructed is of my class type' );
dies_ok( sub { EGTrackHubs::SubTrack->new("blabla") },
    'Wrong object construction dies' );

# -----
# test print_track_stanza method
# -----
my $test_file = File::Temp->new();

{
    open( my $fh, '>', $test_file );
    $st_obj->print_track_stanza($fh);
    close($fh);

    file_exists_ok( ($test_file), "File I wrote exists" );
    file_readable_ok( $test_file, "File is readable" );
    file_not_empty_ok( $test_file, "File is not empty" );

    open( my $test_fh, $test_file );
    my @file_lines = readline $test_fh;
    close($test_fh);
    my $string_content = join( "", @file_lines );
    is(
        $string_content,
        "\ttrack SRR351196\n\tparent SAMN00728445\n\tbigDataUrl bigdata url\n\tshortLabel short label\n\tlongLabel long label\n\ttype cram\n\tvisibility pack\n\n",
        "test_file has the expected content"
    );
}

{
    $st_obj = EGTrackHubs::SubTrack->new(
        "SRR351196",  "SAMN00728445", "bigdata url", "short label",
        "long label", "cram",         "off"
    );

    open( my $fh, '>', $test_file );
    $st_obj->print_track_stanza($fh);
    close($fh);

    open( my $test_fh, $test_file );
    my @file_lines = readline $test_fh;
    close($test_fh);

    my $string_content = join( "", @file_lines );
    is(
        $string_content,
        "\ttrack SRR351196\n\tparent SAMN00728445\n\tbigDataUrl bigdata url\n\tshortLabel short label\n\tlongLabel long label\n\ttype cram\n\tvisibility hide\n\n",
        "test_file has the expected content"
    );
}

done_testing();
