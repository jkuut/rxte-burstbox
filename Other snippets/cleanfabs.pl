#!/usr/bin/perl -w
#Perl script to remove duplicate lines in xpsec analysis files

use warnings;
use strict;


my (@bursts);
my ($bur,$fh,$fh2,$i,$firstline,$dir,$temp);


#Create bbfit.txt which contains the list of inputfiles for cleaning
system "ls */analysis/*_fabs.dat > bbfit.txt";

open(INPUT1, "<", "bbfit.txt") or die "Failed to open file bbfit.txt: $!\n";
while(<INPUT1>) { 
    chomp; 
    push @bursts, $_;
}
close(INPUT1);

$i=0;
foreach $bur (@bursts){
    if($bur =~ /(\S+\/\S+)\/\S+/) {$dir=$1;}
    open($fh, "<", $bur) or die "Failed to open $bur: $!\n";
    open($fh2, ">", "$dir/new.txt") or die "Failed to open new.txt: $!\n";
    $i=0;
    $firstline="11";
    while(<$fh>) { 
        #chomp;
        if($_ =~ /(\S+)/) {$temp=$1;}
        #print "$temp\n";
        if($i==14) { 
            $firstline=$temp;
            print $fh2 "$_";
        }       
        elsif($i<10000) {
            if($temp eq $firstline) { $i=10000; }
            else { print $fh2 "$_"; }
        }
        $i++;    
    }
    close($fh);
    close($fh2);
    system "mv $bur $dir/old.txt";
    system "mv $dir/new.txt $bur";
}





