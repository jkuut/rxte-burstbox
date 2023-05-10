#!/usr/bin/perl -w

use strict;
use warnings;

my ($main_dir, @file_list, $file, @result_files, $file2);

my $outputfile="results_list_morebursts.txt";



$main_dir = '/home/jkuuttila/database/db/4U1636_536/proc2';
chdir $main_dir;

@file_list=<*>;

foreach $file (@file_list){
    if($file =~ /(\S+)fitresults.dat$/){ push @result_files, $file; }
}


$main_dir = '/home/jkuuttila/database/db/4U1636_536';
chdir $main_dir;


if ( ! open WINPUT, ">", "$outputfile") {
	die "Cannot open'$outputfile for writing the input file: $!";
}

foreach $file2 (@result_files) {
    print WINPUT "proc2/$file2\n";
}

close WINPUT;
