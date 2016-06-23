#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;
use Data::Dumper;
use Test::Exception;
use Test::File;
use File::Temp;

# -----
# checks if the modules can load
# -----
use_ok('EGTrackHubs::TrackHubCreation');
use_ok('EGTrackHubs::ArrayExpress');

# -----
# test constructor
# -----

my $study_id  = "DRP000391";
my $tmpdir    = File::Temp->newdir();
my $study_dir = "$tmpdir/$study_id";

my $trackHubCreator_obj = EGTrackHubs::TrackHubCreation->new($study_id, $tmpdir);

isa_ok($trackHubCreator_obj, 'EGTrackHubs::TrackHubCreation', 'the object constructed is of my class type');
dies_ok(sub{EGTrackHubs::TrackHubCreation->new($study_dir)},'Construction from wrong object should die');

# -----
# test make_study_dir method
# -----

my $plant_names_response_href= EGTrackHubs::ArrayExpress::get_plant_names_AE_API();
my $study_obj = EGTrackHubs::AEStudy->new($study_id, $plant_names_response_href);

$trackHubCreator_obj->make_study_dir($tmpdir,$study_obj);
dir_exists_ok( "$study_dir" , "Check that the directory exists" );

# -----
# test make_assemblies_dirs method
# -----
my $assembly_id  = "IRGSP-1.0";
my $assembly_dir = "$study_dir/$assembly_id";

$trackHubCreator_obj->make_assemblies_dirs($tmpdir,$study_obj);
dir_exists_ok( $assembly_dir , "Check that the assembly directory exists" );

# -----
# test make_hubtxt_file method
# -----
my $hub_file   = "$study_dir/hub.txt";
my $hub_format = qr/^hub\s$study_id\nshortLabel.+\nlongLabel.+\ngenomesFile\sgenomes.txt\nemail\s.+\n/;

my $return1 = EGTrackHubs::TrackHubCreation->make_hubtxt_file($tmpdir, $study_obj);
file_exists_ok($hub_file, "The file hub.txt was created");
file_contains_like( $hub_file, $hub_format, "content of file hub.txt is as expected" );

# -----
# test make_genomestxt_file method
# -----
my $genome_file   = "$study_dir/genomes.txt";
my $genome_format = qr/^genome\sIRGSP-1\.0\ntrackDb\sIRGSP-1\.0\/trackDb\.txt\n/;

$trackHubCreator_obj->make_genomestxt_file($tmpdir,$study_obj);
file_exists_ok($genome_file, "the file hub.txt was created");
file_contains_like($genome_file, $genome_format, "content of file genomes.txt is as expected" );


# -----
# test make_trackDbtxt_file method
# -----
my $trackdb_file   = "$study_dir/$assembly_id/trackDb.txt";
my $trackdb_format = qr/^track.+\nsuperTrack on show\n+/;

my $return = $trackHubCreator_obj->make_trackDbtxt_file($tmpdir, $study_obj, $assembly_id);
file_exists_ok($trackdb_file, "The file trackDb.txt was created");
file_contains_like($trackdb_file, $trackdb_format, "content of file trackDb.txt is as expected" );


# -----
# test printlabel_key method
# -----

{
  my $new_label = EGTrackHubs::TrackHubCreation::printlabel_key("electra tapanari");
  is($new_label,"electra_tapanari", 'replace string 1 underscore by 1 space in string');

  $new_label = EGTrackHubs::TrackHubCreation::printlabel_key("electra_tapanari");
  is($new_label, "electra_tapanari", 'no change in string with underscore and no space');

  $new_label=EGTrackHubs::TrackHubCreation::printlabel_key("electra");
  is($new_label,"electra", 'no change in string with no underscore or space');

  $new_label=EGTrackHubs::TrackHubCreation::printlabel_key("electra tapanari of angelos");
  is($new_label, "electra_tapanari_of_angelos", 'replace all spaces with underscores in string');
}

# -----
# test printlabel_value method
# -----
{
  my $new_label = EGTrackHubs::TrackHubCreation::printlabel_value("electra tapanari");
  is($new_label,"\"electra tapanari\"",'put quotes to string with 1 space');

  $new_label=EGTrackHubs::TrackHubCreation::printlabel_value("electra");
  is($new_label,"electra", "don't put quotes to string without space");

  $new_label=EGTrackHubs::TrackHubCreation::printlabel_value("electra tapanari of angelos");
  is($new_label,"\"electra tapanari of angelos\"", "put quotes to string with several spaces");
}

# -----
# test get_ENA_biorep_title method
# -----
my $biorep_id            = "E-MTAB-2037.biorep4";
my $expected_short_label = "ArrayExpress:E-MTAB-2037.biorep4";
my $expected_title       = "Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs generated from mRNAs_retro_PAAF";

my $ena_biorep_title = EGTrackHubs::TrackHubCreation::get_ENA_biorep_title($study_obj, $biorep_id);
is($ena_biorep_title, $expected_title, "ENA biorep title as expected currently") ;

# -----
# test make_biosample_super_track_obj method
# -----

my $sample_id  = "SAMD00008650";
my $expected_long_label = "Total mRNAs from callus, leaf, panicle before flowering, panicle after flowering, root, seed, and shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) ; <a href=\"http://www.ebi.ac.uk/ena/data/view/SAMD00008650\">SAMD00008650</a>";
my $expected_metadata_pattern =  qr/".+BST" biosample_id=SAMD00008650 germline=N description=\"Total mRNAs from callus, leaf, panicle before flowering, panicle after flowering, root, seed, and shoot of rice \(Oryza sativa ssp. Japonica cv. Nipponbare\)\" accession=SAMD00008650 environmental_sample=N scientific_name=\"Oryza sativa Japonica Group\" sample_alias=SAMD00008650 tax_id=39947 center_name=BIOSAMPLE secondary_sample_accession=DRS000668 first_public=2011-12-21/;

my $super_track_obj = $trackHubCreator_obj->make_biosample_super_track_obj($sample_id);
is($super_track_obj->{track_name}, $sample_id ,                "super track name is as expected");
is($super_track_obj->{long_label}, $expected_long_label,       "super track long label is as expected");
like($super_track_obj->{metadata}, $expected_metadata_pattern, "super track metadata string is as expected");

# -----
# test make_biosample_sub_track_obj method
# -----
my $expected_data_url = "ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-2037/E-MTAB-2037.biorep4.cram";
my $expected_track_long_label = "Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs generated from mRNAs_retro_PAAF;<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-MTAB-2037.bioreps.txt\">E-MTAB-2037.biorep4</a>";
my $expected_file_type  = 'cram';
my $expected_visibility = 'on';

my $sub_track_obj = $trackHubCreator_obj->make_biosample_sub_track_obj(
  $study_obj,
  $biorep_id,
  $sample_id,
  "on"
);
is($sub_track_obj->{track_name},   $biorep_id,                 "sub track name is as expected");
is($sub_track_obj->{parent_name},  $sample_id,                 "sub track parent name is as expected");
is($sub_track_obj->{big_data_url}, $expected_data_url,         "sub track cram url location is as expected");
is($sub_track_obj->{short_label},  $expected_short_label,      "sub track short label is as expected");
is($sub_track_obj->{long_label},   $expected_track_long_label, "sub track long label is as expected");
is($sub_track_obj->{file_type},    $expected_file_type,        "sub track file type is as expected");
is($sub_track_obj->{visibility},   $expected_visibility,       "sub track visibility is as expected");

done_testing();

