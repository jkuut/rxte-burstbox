#!/usr/bin/perl -w
#Perl script for making inputfiles for plotb_v2.pro 

use warnings;
use strict;

my (@bursts, @bursts_old,@bursts_old_id);
my ($workdir, $bur, $bur_id, $prev_bur_id, $i, $j, $k);
my $inputfile = "burst_input_list.txt";
my $do_old = 1;

# Getting work directory
chomp($workdir = `pwd`);

#Create bbfit.txt which contains the list of inputfiles for plotting
system "ls */analysis/*_fabs.dat > bbfit.txt";

open(INPUT1, "<", "bbfit.txt") or die "Failed to open file bbfit.txt: $!\n";
while(<INPUT1>) { 
    chomp; 
    push @bursts, $_;
}
close(INPUT1);

#Finding old analysis files 
if($do_old) {
    open(INPUT2, "<", "$workdir/Old_files/bbfit.txt") or die "Failed to open file bbfit.txt: $!\n";
    while(<INPUT2>) { 
        if ($_ =~ /(\d\d\d\d\d\-\d\d\-\d\d\-\w+)\_\S+/) {
            push @bursts_old_id, $1;
            chomp;
            push @bursts_old, $_; 
        } else { die "Invalid burst found in Old_files/bbfit.txt"; }
    }
    close(INPUT2);
}
if ($#bursts_old > $#bursts) { print "\n***\nThere are more burst candidates in the old files!\n***\n";}

$prev_bur_id = "";
$i=0;
$j=0;
$k=0;
#Checking if there exists an old analysis file with the same burstid for each new analysis file
#If not, then printing # instead so plotb_v2.pro knows to skip
#If there are two bursts with the same id, the script should still work 
#unless there are only one burst with that id in the old files, then the script doesn't know which ones are the same
open(OUTPUT, ">", "bbfit2.txt") or die "Failed to open file bbfit2.txt: $!\n";
foreach $bur (@bursts) {
    $k=0;
    if ($bur =~ /(\d\d\d\d\d\-\d\d\-\d\d\-\w+)\_\S+/) {
        $bur_id = $1;
        if ($bur_id eq $prev_bur_id) { 
            print "Two bursts with same id, check bbfit2.txt\n"; 
            $k=1;
        } else { $prev_bur_id = $bur_id; }
        print "$bur_id\n";

        $j = 0;
        while($j <= $#bursts_old_id) {
            if ($bursts_old_id[$j] eq $bur_id) { 
                if ($k == 1) {
                    $k = 0;
                } else { 
                    print OUTPUT "Old_files/$bursts_old[$j]\n";
                    $j = 500;
                }
            }
            $j++; 
        }
        if($j < 500) { print OUTPUT "#\n";}
        
        $i++;
    } else { die "Invalid burst, check regexp"; }

}
close (OUTPUT);
