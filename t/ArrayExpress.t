#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
#use Devel::Cover;

# -----
# checks if the module can load
# -----
use_ok('EGTH::ArrayExpress');
use_ok('EGTH::EG');

# -----
# # test get_plant_names_AE_API method
# -----
my $plant_names = EGTH::ArrayExpress::get_plant_names_AE_API();
isa_ok($plant_names, "ARRAY", "Plant names are in an array");

my %plants = map { $_ => 1 } @$plant_names;
ok(
  exists($plants{"arabidopsis_thaliana"}),
  "arabidopsis_thaliana exists in the plant names"
);

my $eg_plants = EGTH::EG::get_plant_names();
my $num_eg_plants = keys %{$eg_plants};
 
cmp_ok(
  @$plant_names, '<=', $num_eg_plants,
  "Number of plants completed by AE is less than the plants in EG (". (@$plant_names) ." vs $num_eg_plants plants)"
);

cmp_ok(
  @$plant_names, 'gt', 30,
  "Number of plants completed by AE is more than 30"
);

# -----
# # test get_completed_study_ids_for_plants method
# -----
my $study_ids_href =
  EGTH::ArrayExpress::get_completed_study_ids_for_plants($eg_plants);
cmp_ok(
  keys (%$study_ids_href), 'gt', 0,
  "Several cram alignments are completed"
);

# -----
# # test get_study_ids_for_plant method
# -----
my $maize_study_href = EGTH::ArrayExpress::get_study_ids_for_plant("zea_mays");
cmp_ok(
  # 18 May 2016 it is 143
  keys (%$maize_study_href), 'gt', 140 ,
  "Number of cram alignments completed by AE is more than 140"
);

done_testing();

