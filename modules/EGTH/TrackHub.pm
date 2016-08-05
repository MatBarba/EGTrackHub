package EGTH::TrackHub;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;
use Log::Log4perl qw(:easy);
my $logger = get_logger();

use Moose;
use namespace::autoclean;
use File::Spec;
use File::Path qw(make_path);

use EGTH::TrackHub::Genome;

# Attributes
has id => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has [
  qw(
    shortLabel
    longLabel
    )
  ] => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has [
  qw(
    email
    descriptionUrl
    )
  ] => (
  is  => 'rw',
  isa => 'Str',
  );

has hub_file => (
  is      => 'ro',
  isa     => 'Str',
  default => 'hub.txt'
);

has genomes_file => (
  is      => 'rw',
  isa     => 'Str',
  default => 'genomes.txt'
);

has root_dir => (
  is     => 'rw',
  isa    => 'Str',
  writer => '_set_root_dir',
  reader => '_get_root_dir',
);

has hub_dir => (
  is  => 'rw',
  isa => 'Str',
);

has server => (
  is  => 'rw',
  isa => 'Str',
);

has url => (
  is  => 'rw',
  isa => 'Str',
  lazy    => 1,
  'builder' => '_build_hub_url',
);

has genomes => (
  is      => 'rw',
  isa     => 'HashRef[EGTH::TrackHub::Genome]',
  default => sub { {} },
);

sub root_dir {
  my $self = shift;
  my ($dir) = @_;

  if ( defined $dir ) {
    $self->_set_root_dir($dir);
    $self->update_hub_dir;
  }

  return $self->_get_root_dir;
}

sub update_hub_dir {
  my ($self) = shift;
  die "Can't update hub dir if the root dir is not defined"
    if not defined $self->_get_root_dir;

  my $hub_dir = File::Spec->catfile( $self->_get_root_dir, $self->id );
  $self->hub_dir($hub_dir);
}

sub _build_hub_url {
  my $self = shift;
  die "Can't create hub url without server"
    if not $self->server;
  
  return $self->server . '/' . $self->id . '/' . $self->hub_file;
}

sub create_files {
  my ( $self, $dir ) = @_;

  $self->root_dir($dir) if $dir;

  # Make trackhub dir
  make_path $self->hub_dir;

  # Generate files
  $self->make_hub_file();
  $self->make_genomes_file();
  $self->make_genomes_dirs();
  $self->make_trackdb_files();
  return 1;
}

sub make_hub_file {
  my $self = shift;

  croak "Can't create hub file without a directory."
    if ( not defined $self->hub_dir );
  my $hub_path = File::Spec->catfile( $self->hub_dir, $self->hub_file );

  make_path $self->hub_dir;
  open my $hub_fh, '>', $hub_path;
  print $hub_fh $self->hub_file_content;
  close $hub_fh;
  return 1;
}

sub hub_file_content {
  my $self = shift;

  my %content = (
    hub            => $self->id,
    shortLabel     => $self->shortLabel,
    longLabel      => $self->longLabel,
    genomesFile    => $self->genomes_file,
    email          => $self->email,
    descriptionUrl => $self->descriptionUrl,
  );
  my @content_order = qw(
    hub
    shortLabel
    longLabel
    genomesFile
    email
    descriptionUrl
  );

  my @lines;
  my %missing_keys;
  for my $key (@content_order) {
    if ( defined $content{$key} ) {
      push @lines, "$key $content{$key}";
    }
    else {
      $missing_keys{$key}++;
    }
  }

  #if (%missing_keys) {
  #  croak "Missing keys: " . join(', ', sort keys %missing_keys);
  #}

  return join( "\n", @lines ) . "\n";
}

sub make_genomes_file {
  my $self = shift;

  if ( not defined $self->hub_dir ) {
    croak "Can't create genomes file without a directory.";
  }
  elsif ( not keys %{ $self->genomes } ) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my $genomes_path = File::Spec->catfile( $self->hub_dir, $self->genomes_file );

  open my $genomes_fh, '>', $genomes_path;
  print $genomes_fh $self->genomes_file_content;
  close $genomes_fh;
  return 1;
}

sub genomes_file_content {
  my $self = shift;

  if ( not keys %{ $self->genomes } ) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my @lines;
  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    push @lines, $genome->config_text;
  }
  return join "\n\n", @lines;
}

sub make_genomes_dirs {
  my $self = shift;

  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    $genome->make_genome_dir;
  }
  return 1;
}

sub make_trackdb_files {
  my $self = shift;

  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    $genome->make_trackdb_file;
  }
  return 1;
}

sub add_genome {
  my $self = shift;
  my ($genome) = @_;

  if ( defined $self->genomes->{ $genome->id } ) {
    croak "The trackhub already has a genome named $genome->id";
  }
  my $genomes = $self->genomes->{ $genome->id } = $genome;
  $genomes->hub_dir( $self->hub_dir );
  return 1;
}

sub assembly_map {
  my $self = shift;

  my %map;
  my %genomes = %{ $self->genomes };
  for my $genome_id ( keys %genomes ) {
    $logger->debug("Map assembly for $genome_id");
    $map{$genome_id} = $genomes{$genome_id}->insdc;
  }
  return \%map;
}

__PACKAGE__->meta->make_immutable;
1;

