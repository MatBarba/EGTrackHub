package EGTrackHubs::EG;

# this module is written in order to have a method that returns the right assembly name in the cases where AE gives the assembly accession instead of the assembly name (due to our bug)

use strict ;
use warnings;

use EGTrackHubs::JsonResponse;

my $ens_genomes_plants_call = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

# Cache variables
my %plant_names;
my %species_name_assembly_id_hash;
my %species_name_assembly_name_hash;

sub get_plant_names {
  load_EG_plants() if not %plant_names;
  return \%plant_names;
}

sub get_species_name_assembly_id_hash {
  load_EG_plants() if not %species_name_assembly_id_hash;
  return \%species_name_assembly_id_hash;
}

sub get_assembly_name_using_species_name {
  my $species_name = shift;

  load_EG_plants() if not %species_name_assembly_name_hash;
  my $assembly_name = $species_name_assembly_name_hash{$species_name};

  if (not defined $assembly_name) {
    die "The species name: $species_name is not in EG REST response ($ens_genomes_plants_call) in the species field\n";
  }
  return $assembly_name;
}

sub load_EG_plants {
  #test server - new assemblies:
  #my $ens_genomes_plants_call = "http://test.rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json";

  my @array_response_plants_assemblies; 

  my $array_response_plants_assemblies = EGTrackHubs::JsonResponse::get_Json_response($ens_genomes_plants_call);  

  # response:
  #[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
  #"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
  #"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},

  #examples:
  #ass_name      ass_accession
  #AMTR1.0	GCA_000471905.1
  #Theobroma_cacao_20110822	GCA_000403535.1

  foreach my $plant_href (@$array_response_plants_assemblies) {
    $plant_names{$plant_href->{"species"}} = 1;

    $species_name_assembly_name_hash {$plant_href->{"species"} } =  $plant_href->{"assembly_name"};
    
    # for triticum_aestivum that is without assembly id,
    # I store 0000, this is specifically for the THR to work
    if (not $plant_href->{"assembly_id"}) {
      $species_name_assembly_id_hash{ $plant_href->{"species"} } = "0000";
    } else {
      $species_name_assembly_id_hash{ $plant_href->{"species"} } = $plant_href->{"assembly_id"};
    }
  }
}

1;

