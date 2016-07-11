package EGTH::AEStudy;

use strict;
use warnings;
use Moose;

use Date::Manip;

use EGTH::EG;
use EGTH::ArrayExpress;
use EGTH::ENA;

## this is a class of an AE study. It considers only PLANT species.
# AE REST call: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getRunsByStudy/SRP068911

has id => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has plant_names => (
  is       => 'ro',
  isa      => 'ArrayRef[Str]',
  required => 1,
);

has runs => (
  is      => 'ro',
  isa     => 'HashRef[HashRef]',
  lazy    => 1,
  builder => 'make_runs',
);

sub make_runs {
  my $self = shift;

  my %plant_names = map { $_ => 1 } @{ $self->plant_names };

  my %run_tuple;    # to be returned

  # Get the runs
  my $runs_response =
    EGTH::ArrayExpress::get_runs_json_for_study( $self->id );
  my @runs_json = @{$runs_response};

  # Get the fields
  my %fmap = (
    sample_ids                    => 'SAMPLE_IDS',
    organism                      => 'REFERENCE_ORGANISM',
    assembly_name                 => 'ASSEMBLY_USED',
    big_data_file_server_location => 'CRAM_LOCATION',
    AE_processed_date             => 'LAST_PROCESSED_DATE',
    run_ids                       => 'RUN_IDS',
  );

  my %runs;
  foreach my $stanza (@runs_json) {
    my $plant_ref = $stanza->{"REFERENCE_ORGANISM"};
    if (  $stanza->{"STATUS"} eq "Complete"
      and $plant_names{$plant_ref} )
    {
      my %run;
      for my $run_field ( keys %fmap ) {
        my $stanza_field = $fmap{$run_field};
        $run{$run_field} = $stanza->{$stanza_field};
      }
      my $biorep_id = $stanza->{"BIOREP_ID"};
      $runs{$biorep_id} = \%run;
    }
  }
  return \%runs;
}

# this method is used when there is a study with many assemblies (or organisms); I can get the biorep ids of a specific organism of the study
sub get_biorep_ids_by_organism {
  my $self = shift;
  my ($organism_name) = @_;

  my $run_tuple = $self->runs;
  my %biorep_ids;

  foreach my $biorep_id ( keys %{$run_tuple} ) {

    if ( $run_tuple->{$biorep_id}{"organism"} eq $organism_name ) {
      $biorep_ids{$biorep_id} = 1;
    }
  }

  return \%biorep_ids;
}

sub get_organism_names_assembly_names {
  my $self = shift;

  my $run_tuple = $self->runs;
  my %organism_names;
  my $organism_name;

  foreach my $biorep_id ( keys %{$run_tuple} ) {
    $organism_name = $run_tuple->{$biorep_id}{"organism"};
    $organism_names{$organism_name} =
      $run_tuple->{$biorep_id}{"assembly_name"};
  }

  return \%organism_names;
}

sub get_sample_ids {
  my $self = shift;

  my $run_tuple = $self->runs;
  my %sample_ids;

  my %biorep_ids = %{ $self->get_biorep_ids };

  foreach my $biorep_id ( keys %biorep_ids ) {
    my $sample_ids_string = $run_tuple->{$biorep_id}{"sample_ids"};

    # Ie $run{"SRR1042754"}{"sample_ids"}="SAMN02434874,SAMN02434875" , could also be $run{"SRR1042754"}{"sample_ids"}= null
    if ( !$sample_ids_string ) {
      return 0;
    }
    my @sample_ids_from_string = split( /,/, $sample_ids_string );

    foreach my $sample_id (@sample_ids_from_string) {
      $sample_ids{$sample_id} = 1;
    }
  }
  return \%sample_ids;
}

sub get_assembly_name_from_biorep_id {
  my $self      = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->runs;

  my $assembly_name = $run_tuple->{$biorep_id}{"assembly_name"};
  return $assembly_name;
}

sub get_sample_ids_from_biorep_id {
  my $self      = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->runs;

  my @sample_ids = split( /,/, $run_tuple->{$biorep_id}{"sample_ids"} );

  return \@sample_ids;
}

sub get_biorep_ids {
  my $self      = shift;
  my $run_tuple = $self->runs;

  my %biorep_ids;

  foreach my $biorep_id ( keys %{$run_tuple} ) {
    $biorep_ids{$biorep_id} = 1;
  }

  return \%biorep_ids;
}

sub get_biorep_ids_from_sample_id {
  my $self      = shift;
  my $sample_id = shift;

  my $run_tuple = $self->runs;

  my %biorep_ids;

  foreach my $biorep_id ( keys %{$run_tuple} ) {

    # could be "SAMPLE_IDS":"SAMN02666905,SAMN02666906"
    my @sample_ids = split( /,/, $run_tuple->{$biorep_id}{"sample_ids"} );

    foreach my $sample_id_from_string (@sample_ids) {

      if ( $sample_id_from_string eq $sample_id ) {

        $biorep_ids{$biorep_id} = 1;
      }
    }
  }
  return \%biorep_ids;
}

sub get_assembly_names {
  my $self      = shift;
  my $run_tuple = $self->runs;

  my %assembly_names;

  foreach my $biorep_id ( keys %{$run_tuple} ) {
    my $assembly_name = $run_tuple->{$biorep_id}{"assembly_name"};
    $assembly_names{$assembly_name} = 1;
  }
  return \%assembly_names;
}

sub get_big_data_file_location_from_biorep_id {
  my $self      = shift;
  my $biorep_id = shift;

  my $run_tuple = $self->runs;

  if ( !$run_tuple->{$biorep_id} ) {
    die "There is not such biorep id $biorep_id in study "
      . $self->id . "\n";
  }

  # Returns a string
  return $run_tuple->{$biorep_id}{"big_data_file_server_location"};
}

sub get_AE_last_processed_date_from_biorep_id {
  my $self      = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->runs;

  if ( !$run_tuple->{$biorep_id} ) {
    die "There is not such biorep id $biorep_id in study "
      . $self->id . "\n";
  }

  return $run_tuple->{$biorep_id}{"AE_processed_date"};

}

# could be more than 1 run id : "RUN_IDS":"DRR001028,DRR001035,DRR001042,DRR001049",
sub get_run_ids_of_biorep_id {

  my $self      = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->runs;

  if ( !$run_tuple->{$biorep_id} ) {
    die "There is not such biorep id $biorep_id in study "
      . $self->id . "\n";
  }

  my $run_string = $run_tuple->{$biorep_id}{"run_ids"};

  my @run_ids = split( /,/, $run_string );

  return \@run_ids;
}

sub give_big_data_file_type_of_biorep_id {
  my $self      = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->runs;

  if ( !$run_tuple->{$biorep_id} ) {
    die "There is not such biorep id $biorep_id in study "
      . $self->id . "\n";
  }

  my $server_location =
    $self->get_big_data_file_location_from_biorep_id($biorep_id);

  #ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000745/DRR000745.cram
  # or ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-2037/E-MTAB-2037.biorep4.cram
  $server_location =~ /.+\/.+\.(.+)$/;

  return $1;    # ie cram

}

# of the study : i get all its bioreps and then find the max date of all bioreps # tried with this study: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getRunsByStudy/SRP067728
sub get_AE_last_processed_unix_date {
  my $self = shift;

  my %biorep_ids = %{ $self->get_biorep_ids };
  my $run_tuple  = $self->runs;

  my $max_date = 0;

  foreach my $biorep_id ( keys %biorep_ids ) {

    # each study has more than 1 processed date, as there are usually multiple bioreps in each study with different processed date each. I want to get the most current date
    my $date = $self->get_AE_last_processed_date_from_biorep_id($biorep_id);
    my $unix_time = UnixDate( ParseDate($date), "%s" );

    if ( $unix_time > $max_date ) {
      $max_date = $unix_time;
    }
  }

  return $max_date;

}

1;

__END__

# a response stanza (the response is usually
#  more than 1 stanza,
# 1 study has many bioreps,
#  each stanza is a biorep) of this call:
#  http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getRunsByStudy/SRP033494
# [{
# "STUDY_ID":"SRP033494",
# "SAMPLE_IDS":"SAMN02434874",
# "BIOREP_ID":"SRR1042754",
# "RUN_IDS":"SRR1042754",
# "ORGANISM":"arabidopsis_thaliana",
# "REFERENCE_ORGANISM":"arabidopsis_thaliana",
# "STATUS":"Complete",
#"ASSEMBLY_USED":"TAIR10",
#"ENA_LAST_UPDATED":"Fri Jun 19 2015 18:11:03",
#"LAST_PROCESSED_DATE":"Sun Nov 15 2015 00:31:20",
#"CRAM_LOCATION":
#"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/SRR104/004/SRR1042754/SRR1042754.cram"
#},

# or with merges of CRAMs

#[{
#"STUDY_ID":"SRP021098",
#"SAMPLE_IDS":"SAMN02799120",
#"BIOREP_ID":"E-MTAB-4045.biorep54",
#"RUN_IDS":"SRR1298603,SRR1298604",
#"ORGANISM":"glycine_max",
#"REFERENCE_ORGANISM":"glycine_max",
#"STATUS":"Complete",
#"ASSEMBLY_USED":"V1.0",
#"ENA_LAST_UPDATED":"Fri Jun 19 2015 18:53:48",
#"LAST_PROCESSED_DATE":"Mon Jan 25 2016 16:46:04",
#"CRAM_LOCATION":
#"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-4045/E-MTAB-4045.biorep54.cram",
#"MAPPING_QUALITY":77
#},

# there are cases of null sample ids: (I want to skip those track hubs)
#[{
#"STUDY_ID":"DRP002805",
#"SAMPLE_IDS":null,
#"BIOREP_ID":"DRR048597",
#"RUN_IDS":"DRR048597",
#"ORGANISM":"brachypodium_distachyon",
#"REFERENCE_ORGANISM":"brachypodium_distachyon",
#"STATUS":"Complete",
#"ASSEMBLY_USED":"v1.0",
#"ENA_LAST_UPDATED":"Fri Mar 11 2016 01:37:14",
#"LAST_PROCESSED_DATE":"Sat Mar 12 2016 22:48:54",
#"CRAM_LOCATION":
#"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR048/DRR048597/DRR048597.cram",
#"MAPPING_QUALITY":88
#},
