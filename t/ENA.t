#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;
use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

use Test::More;
use Test::Exception;

# -----
# checks if the module can load
# -----
use_ok('EGTrackHubs::ENA');

# -----
# test get_ENA_study_title method
# -----
my $study_id = "DRP000315";

#test4
my $study_title = EGTrackHubs::ENA::get_ENA_study_title($study_id);
is(
    $study_title,
    "Oryza sativa Japonica Group transcriptome sequencing",
    "ENA title of study DRP000315 is as expected"
);

my $wrong_study_id = "DRP0003";
throws_ok {
  my $study_title_wrong_study_title = EGTrackHubs::ENA::get_ENA_study_title($wrong_study_id);
} qr/Can't find in ENA/, "Wrong study id throws";

# -----
# test get_ENA_title method
# -----

my $sample_title = EGTrackHubs::ENA::get_ENA_title("SAMN02666886");
is(
    $sample_title,
    "Arabidopsis thaliana Bur-0 X Col-0 seedling, biological replicate 1",
    "ENA title of sample SAMN02666886 is as expected"
);

{
  throws_ok {
    my $sample_title_wrong_sample_title = EGTrackHubs::ENA::get_ENA_title("SAMN0266688");
  } qr/Can't find in ENA/,
    "Wrong sample id throws";
}

{
  throws_ok {
    my $title = EGTrackHubs::ENA::get_ENA_title("SAMN03782116");
  } qr/Can't get a node/, "Wrong sample id throws";
}

# -----
# test get_all_sample_keys method
# -----

#test10
my $meta_keys_aref = EGTrackHubs::ENA::get_all_sample_keys()
  ;    # array ref that has all the keys for the ENA warehouse metadata
my %meta_keys_hash = map { $_ => 1 } @$meta_keys_aref;

my @meta_keys_to_test =
  ( "accession", "cell_line", "cell_type", "tax_id", "tissue_type", "sex" );

foreach my $meta_key (@meta_keys_to_test) {

    ok( exists $meta_keys_hash{$meta_key}, "\'$meta_key\' exists as a key" );
}

# -----
# test get_sample_metadata_response_from_ENA_warehouse_rest_call method
# -----

my $sample_id = "SAMN02666886";

my $sample_metadata_href =
  EGTrackHubs::ENA::get_sample_metadata_response_from_ENA_warehouse_rest_call( $sample_id,
    $meta_keys_aref );

#test16
ok(
    exists $sample_metadata_href->{scientific_name},
    "\'scientific_name\' exists as a key"
);

#test17
is(
    $sample_metadata_href->{scientific_name},
    "Arabidopsis thaliana",
    "scientic name metakeys is as expected"
);

# -----
# test create_url_for_call_sample_metadata method
# -----

#test18
my $url =
  EGTrackHubs::ENA::create_url_for_call_sample_metadata( "SAMN02666886", $meta_keys_aref );
like(
    $url,
qr/^http:\/\/www.ebi.ac.uk\/ena\/data\/.+accession=SAMN02666886.+sex.+tax_id.*/,
    "REST url to get ENA metadata is as expected"
);

done_testing();
