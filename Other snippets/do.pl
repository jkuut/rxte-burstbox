#!/usr/bin/perl -w
#Perl script for spectral analysis tasks
use strict;


my (@bursts);
my ($bur);
my $inputfile = "burst_input_list.txt";
my $phabsinputfile = "nH.txt";
my $phabs;
my $sum=0;
my $fit=1;

#TODO: Read bursts from file
#@bursts=('91059-03-01-04_1');

# Reading the burst directories from burst_input_list.txt
open(INPUT1, "<", $inputfile) or die "Failed to open file: $!\n";
while(<INPUT1>) { 
    chomp; 
    push @bursts, $_;
}
close(INPUT1);

if($sum){
    foreach $bur (@bursts){
        print("bin_sum_v3.pl -dir ${bur}/proc -outdir ${bur}/sum -list ${bur}/pha_${bur}.list\n");
        system("bin_sum_v3.pl -dir ${bur}/proc -outdir ${bur}/sum -list ${bur}/pha_${bur}.list");
    }
}


if($fit){
    open(PHABSINPUT, "<", $phabsinputfile) or die "Failed to open file: $!\n";
    while(<PHABSINPUT>) { 
        chomp; 
        $phabs = $_;
    }
    close(PHABSINPUT);

    foreach $bur (@bursts){
        print("xspec_burst_fit_v7.pl -inputfile ${bur}/pha_${bur}.list -outdir ${bur}/fit -outdir2 ${bur}/analysis -model bb -phabs $phabs\n");
        system("xspec_burst_fit_v7.pl -inputfile ${bur}/pha_${bur}.list -outdir ${bur}/fit -outdir2 ${bur}/analysis -model bb -phabs $phabs");
    }
}




