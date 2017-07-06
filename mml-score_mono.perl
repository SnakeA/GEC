#!/usr/bin/env perl
#
# This file is part of moses.  Its use is licensed under the GNU Lesser General
# Public License version 2.1 or, at your option, any later version.

use warnings;
use strict;

#
# Calculate the perplexity or the modified Moore-Lewis scores
# written by Barry Haddow
# adapted for EMS by Philipp Koehn
#

my ($corpus,$query,$domain_file,$filter_domains);

use Getopt::Long;
GetOptions('corpus=s' => \$corpus,
           'query=s' => \$query,
           'domains=s' => \$domain_file,
           'filter-domains=s' => \$filter_domains
    ) or exit(1);

die("ERROR: corpus not specified (-corpus FILE)") unless defined($corpus);
die("ERROR: query command not specified (-query CMD)") unless defined($query);

my $target_inlm = "in-target.blm";
my $target_corpus = "$corpus";

print STDERR "querying language models...
$query $target_inlm < $target_corpus\n";

open(INTARGET, "$query $target_inlm < $target_corpus |") || die "Failed to open in lm query on target";
open(TARGET, "$target_corpus") || die "Unable to open target corpus";

&load_domains() if defined($filter_domains);

sub score {
  my $fd = shift;
  my $line = <$fd>;
  #print "$line";
  return 1 if !defined($line) || $line =~ /^Perplexity /;
  $line =~ /Total: ([\.\-0-9]+) /;
  return $1;
}

sub line_length {
  local *FH = shift;
  my $line = <FH>;
  chomp $line;
  my @tokens = split /\s+/, $line;
  return $#tokens+1;
}

my %DOMAIN_FILTERED;
my %DOMAIN_NAME;
my @DOMAIN;
sub load_domains {
  my %FILTER_DOMAIN;
  foreach (split(/ /,$filter_domains)) {
    $FILTER_DOMAIN{$_}++;
  }
  open(DOMAIN,$domain_file) || die("ERROR: could not open domain file '$domain_file'");
  while(<DOMAIN>) {
    chop;
    my ($line_number,$name) = split;
    push @DOMAIN, $line_number;
    $DOMAIN_NAME{$line_number} = $name;
    $DOMAIN_FILTERED{$line_number} = defined($FILTER_DOMAIN{$name});
  }
  close(DOMAIN);
}

sub check_sentence_filtered {
  my ($sentence_number) = @_;
  foreach my $last_sentence_number_of_domain (@DOMAIN) {
    if ($sentence_number <= $last_sentence_number_of_domain) {
      return $DOMAIN_FILTERED{$last_sentence_number_of_domain};
    }
  }
  die("ERROR: domain file incomplete -- could not find sentence $sentence_number");
}

my $i=1;
while(1) {
  # This is actually the -ve of the modified M-L score, so we take sentence with
  # highest scores
  my $intarget = score(*INTARGET);
  last if ($intarget == 1);
  my $target_length = line_length(*TARGET);
  if (defined($filter_domains) && !&check_sentence_filtered($i)) {
    print "99999\n"; # keep it
  }
  else {
    my $total =  $intarget/$target_length;
    #print "$intarget\n"
    print "$i\t$total\n";
  }
  $i++;
}
