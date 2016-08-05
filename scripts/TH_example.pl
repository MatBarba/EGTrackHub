#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;
use Readonly;
use Carp;
use autodie qw(:all);
use English qw( -no_match_vars );
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use Perl6::Slurp;
use List::Util qw( first );
use File::Spec qw(cat_file);
use File::Path qw(make_path);
use File::Copy;
use Data::Dumper;

#################################
# You need all this to create a
# track hub
use EGTH::TrackHub;
use EGTH::TrackHub::Genome;
use EGTH::TrackHub::Track;
use EGTH::TrackHub::SuperTrack;
use EGTH::Registry;
#################################

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($WARN);
my $logger = get_logger();

###############################################################################
# MAIN

my %example = (
  id          => 'SRP016018',
  genome_id   => 'TAIR10',
  assembly    => 'GCA_000001735.1',
  title       => 'RNA-Seq alignment hub SRP016018',
  description => 'An epigenetic role for disrupted paternal gene expression in postzygotic seed abortion in Arabidopsis interspecific hybrids ; SRP016018',
  url         => 'http://ftp.sra.ebi.ac.uk/vol1/ERZ306/ERZ306020/SRR580951.cram',
  type        => 'cram',
  root_dir    => './Track_Hubs',
);

# Get command line args
my %opt = %{ opt_check() };
$example{server} = $opt{server};

# We create a track hub object
my $hub = prepare_trackhub(\%example);

# At this point, no file have been created

# Create the files for this track_hub
if ($opt{create}) {
  $hub->create_files;

# Interaction with the track hub registry
} else {
  my $registry;
  if ($opt{reg_user} and $opt{reg_pass}) {
    $registry = EGTH::Registry->new(
      user     => $opt{reg_user},
      password => $opt{reg_pass},
    );
    # The registered hubs are hidden by default
    # $registry->is_public(1);
  } else {
    croak "Can't use registry without reg_user and reg_pass";
  }
  
  # Registry actions: register, delete
  if ($opt{register}) {
    $registry->register_track_hubs([$hub]);
  }
  elsif ($opt{delete}) {
    $registry->delete_track_hubs($hub->id);
  }
}

###############################################################################
# This function is the core of the creation of a track hub
sub prepare_trackhub {
  my ($data) = @_;

  # Create an empty track hub with just an id (you can add other fields though)
  my $track_hub = EGTH::TrackHub->new(
    id      => $data->{id},
  );
  
  # Root dir: where all the track_hub directories are created on your system
  $track_hub->root_dir( $data->{root_dir} );
  
  # Server: where the track hub files are publicly accessible
  # This should point to the same root dir via http/ftp
  $track_hub->server( $data->{hub_server} );

  # Create a genome for the hub
  # The insdc part is only used when registering the hub
  my $genome = EGTH::TrackHub::Genome->new(
    id    => $data->{genome_id},
    insdc => $data->{assembly},
  );

  # We can create as many super tracks as we want per genome
  my $super_track = EGTH::TrackHub::SuperTrack->new(
    track      => 'Supertrack',
    shortLabel => 'Signal density',
    type       => $data->{type},
    show       => 1,
  );
  
  # Each supertrack needs a collection of subtracks
  my $track = EGTH::TrackHub::Track->new(
    track       => $data->{id},
    shortLabel  => $data->{title},
    longLabel   => $data->{description},
    bigDataUrl  => $data->{url},
    type        => $data->{type},
    visibility  => 'full',
  );
  
  # Put everything together
  $super_track->add_sub_track($track);
  $genome->add_track($super_track);
  $track_hub->add_genome($genome);
  
  # Note: The genome can include only a list of tracks and no super tracks
  # (Super-tracks are just specialized tracks)

  return $track_hub;
}

###############################################################################
# Parameters and usage
# Print a simple usage note
sub usage {
  my $error = shift;
  my $help = '';
  if ($error) {
    $help = "[ $error ]\n";
  }
  $help .= <<"EOF";
    This script creates a track_hub example.
    
    Choose among the 3 following actions:
    
    
    CREATE FILES
    --create          : create the track hub example files
      
      This script will create trackhub files for $example{id}
      in the directory $example{root_dir}
    
      
    REGISTER
    --register        : register the track hub example
    
      The track hub files created by the above action need to be put in a
      publicly accessible directory. Use the following parameter to set it:
    --server <path>   : http/ftp path to the root of the hubs dir
    
      You also need Track Hub Registry credentials:
    --reg_user        : user name
    --reg_pass        : user password
    
    With both the server and the credentials set, this action will register
    the track hub in the Track Hub Registry. You can check it by login in on
    the website https://beta.trackhubregistry.org/
    
    
    DELETE
    --delete          : delete the same track hub once registered
    
      You can delete the tracks yourself via the website, but you can also use
      this action. It will delete tracks simply based on their id.
    
    
    Hint:
    * Use a dedicated test user
    * Set a variable \$REG_PASS to not show the password on screen/history:
        read -s REG_PASS
    
    OTHER
                        (production_name)
    --help            : show this help message
    --verbose         : show detailed progress
    --debug           : show even more information
                        (for debugging purposes)
EOF
  print STDERR "$help\n";
  exit(1);
}

# Get the command-line arguments and check for the mandatory ones
sub opt_check {
  my %opt = ();
  GetOptions(\%opt,
    "help",
    "create",
    "register",
    "delete",
    "reg_user=s",
    "reg_pass=s",
    "server=s",
    "verbose",
    "debug",
  ) or usage();

  usage()                if $opt{help};
  usage("Action needed") if not ($opt{create} xor $opt{register} xor $opt{delete});
  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

