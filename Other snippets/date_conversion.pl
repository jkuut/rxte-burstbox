#! /usr/bin/perl
#Reads burst_list.txt and separates pre-12/2007 bursts for comparison with Galloway
#Changes the date from Spacecraft Clock Seconds to Gregorian, may be inaccurate

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

my ($main_dir,$file,$start_time,$end_time,$MJD_start,$MJD_end);
my ($Y_start,$M_start,$D_start,$Y_end,$M_end,$D_end,$I,$J,$K,$L,$N,$x);
my ($HH_start,$MM_start,$SS_start, $HH_end,$MM_end,$SS_end);
my $ref_time = 54465+2400000.5; #Bursts before 12/2007 in JD

chomp($main_dir = `pwd`);

open(BURSTLIST, "burst_list.txt");
open(NEWBURSTLIST, ">burst_list2.txt");
while (<BURSTLIST>) {
 chomp;
 ($file, $start_time, $end_time) = split(" ");

#Converting starting time to Gregorian calendar
  $start_time = $start_time/86400.0 + 49353.000696574074 +2400000.5;
  $MJD_start = $start_time - 2400000.5;
 if($start_time <= $ref_time){
	$L = int($start_time+68569);
	$x = int($L/146097);
	$N = int(4*$x);
	$x = int((146097*$N+3)/4);
	$L = int($L-$x);
	$I = int(4000*($L+1)/1461001);
	$x = int(1461*$I/4);
	$L = int($L-$x+31);
	$J = int(80*$L/2447);
	$x = int(2447*$J/80);
	$K = int($L-$x);
	$L = int($J/11);
	$J = int($J+2-12*$L);
	$I = int(100*($N-49)+$I+$L);
       $Y_start = $I;
       $M_start = $J;
       $D_start = $K;
	if($M_start <= 9) {$M_start = "0" . "$M_start"; }
	else {}
	if($D_start <= 9) {$D_start = "0" . "$D_start"; }
	else {}

#Getting hours, minutes and seconds from given MJD
	$x = int($start_time);
	$x = $start_time - $x;
	$HH_start = int($x*24);
	$MM_start = int(($x*86400-$HH_start*3600)/60);
	$SS_start = $x*86400-$HH_start*3600-$MM_start*60;
	 if($HH_start <= 11) { $HH_start = $HH_start + 12; } #24h day
	 else { $HH_start = $HH_start -12; }
	 if($HH_start <= 9) {$HH_start = "0" . "$HH_start"; } #Making sure that format is HH:MM:SS
	 else {}
	 if($MM_start <= 9) {$MM_start = "0" . "$MM_start"; }
	 else {}

#Converting ending time to Gregorian calendar	
   $end_time = $end_time/86400.0 + 49353.000696574074+2400000.5;
   $MJD_end = $end_time - 2400000.5;
	$L = int($end_time+68569);
	$x = int($L/146097);
	$N = int(4*$x);
	$x = int((146097*$N+3)/4);
	$L = int($L-$x);
	$I = int(4000*($L+1)/1461001);
	$x = int(1461*$I/4);
	$L = int($L-$x+31);
	$J = int(80*$L/2447);
	$x = int(2447*$J/80);
	$K = int($L-$x);
	$L = int($J/11);
	$J = int($J+2-12*$L);
	$I = int(100*($N-49)+$I+$L);
       $Y_end = $I;
       $M_end = $J;
       $D_end = $K;
	if($M_end <= 9) {$M_end = "0" . "$M_end"; }
	else {}
	if($D_end <= 9) {$D_end = "0" . "$D_end"; }
	else {}

#Getting hours, minutes and seconds from given MJD
	$x = int($end_time);
	$x = $end_time - $x;
	$HH_end = int($x*24);
	$MM_end = int(($x*86400-$HH_end*3600)/60);
	$SS_end = $x*86400-$HH_end*3600-$MM_end*60;
	 if($HH_end <= 11) { $HH_end = $HH_end + 12; } #24h day
	 else { $HH_end = $HH_end -12; }
	 if($HH_end <= 9) {$HH_end = "0" . "$HH_end"; } #Making sure that format is HH:MM:SS
	 else {}
	 if($MM_end <= 9) {$MM_end = "0" . "$MM_end"; }
	 else {}

  if($SS_start < 10) {
  print NEWBURSTLIST "$file\n"."Start: $Y_start-"."$M_start-"."$D_start"." T $HH_start:"."$MM_start:0";
    }
  else {
  print NEWBURSTLIST "$file\n"."Start: $Y_start-"."$M_start-"."$D_start"." T $HH_start:"."$MM_start:";
    }
  printf NEWBURSTLIST ("%.0f",$SS_start); 
  print NEWBURSTLIST "     MJD: ";
  printf NEWBURSTLIST ("%.5f",$MJD_start);
  if($SS_end < 10) {
  print NEWBURSTLIST "\nEnd:   $Y_end-" . "$M_end-" . "$D_end" . " T $HH_end:"."$MM_end:0";
    }
  else {
  print NEWBURSTLIST "\nEnd:   $Y_end-" . "$M_end-" . "$D_end" . " T $HH_end:"."$MM_end:";
    }
  printf NEWBURSTLIST ("%.0f",$SS_end);
  print NEWBURSTLIST "     MJD: ";
  printf NEWBURSTLIST ("%.5f",$MJD_end);
  print NEWBURSTLIST "\n"; 
     }
 }
close(NEWBURSTLIST);
close(BURSTLIST);


