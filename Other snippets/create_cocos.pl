#!/usr/bin/perl -w

# This script reads various parameter values from input files
# and then writes an output file that contains fluxes in 5
# energy bands.

# The input file is a list of *[0-4]fitresults.dat files that
# were produced as output of pca_std2_coco_JK.pl script.
# Those inputs should have one .dat file name per line.

# Output should be just a name. It will contain fluxes in 5
# energy bands.

use feature "switch";
use strict;
use Getopt::Long;

my ($phalist, $input, $output, $output2, $datfile, $datfile2, $line);
my ($i, $prefix, $read, @datlist, $nullP, $result_str);
my ($value, $mean, $temp, $readflux);
my ($time, $timefile, $fkeyprint);


GetOptions(	"input=s" => \$input,
		"output=s" => \$output,
	       ) or die "Parameters not given correctly, check GetOptions part in the source code...\n";

#Reading the inputfile for list of files
unless(-e $input){
  die "Input file $input does not exist!\n";
}

if(-e $output){
  die "Output file $output exist! Delete it or rename output!\n";
}

$output2 = "badfits_${output}";

if ( ! open RESULTPRINT, ">", "$output") {die "Cannot open $output for appending: $!";}       
       
print RESULTPRINT "Time (spacecraft seconds) Flux (3-4)     Err (3-4)      Flux (4-6.4)   Err (4-6.4)    Flux (6.4-9.7) Err (6.4-9.7)  Flux (9.7-16)  Err (9.7-16)   Flux (2-25)    Err (2-25)\n";
close RESULTPRINT;

if ( ! open RESULTPRINT, ">", "$output2") {die "Cannot open $output2 for appending: $!";}        

print RESULTPRINT "Time (spacecraft seconds) Flux (3-4)     Err (3-4)      Flux (4-6.4)   Err (4-6.4)    Flux (6.4-9.7) Err (6.4-9.7)  Flux (9.7-16)  Err (9.7-16)   Flux (2-25)    Err (2-25)\n";
close RESULTPRINT;


# Now we start to loop over all the input files we want read
if ( ! open INPUT1, "<", $input) {die "Cannot open Input file $input for reading: $!";}

while (defined($datfile = <INPUT1>)){

  chomp($datfile);
  unless(-e $datfile){die "Input file $datfile does not exist! Aborting..."};

  if($datfile =~ /proc2\/(\S+)_(\d\d\d)_\S*/){
      $timefile = 'std2/' . $1 . '/1636_std2_' . $2 . '.pha';
      $fkeyprint = `ftlist ${timefile}+1 K | grep "TSTART  ="`;
      if($fkeyprint =~ /TSTART\s*=\s*(\S+)\s/){$time=$1;}
      $time=sprintf("%.9f", $time);
  }else{ die "Error in time-regexp";}

  # In a few cases, some .dat files are missing 
  # (typically when something strange happened in the fit)
  
  # proc/FS4a_128fcae0-128fdc10_000_dbb_po_0fitresults.dat
  # proc/FS4a_128fcae0-128fdc10_000_dbb_po_1fitresults.dat
  # proc/FS4a_128fcae0-128fdc10_000_dbb_po_2fitresults.dat
  # proc/FS4a_128fcae0-128fdc10_000_dbb_po_3fitresults.dat
  # proc/FS4a_128fcae0-128fdc10_000_dbb_po_4fitresults.dat

  given($datfile){
    when (/(\S+)0fitresults.dat$/){
      $i = 0; # Reset counter. This should have value 3 when 4fitresults.dat is matched.
      $prefix = $1;
      $read = "yes";
      @datlist = ($datfile);
    }
    when (/(\S+)1fitresults.dat$/){
      $i++;
      unless($1 eq $prefix){$read = "no"};
      push (@datlist, $datfile);
    }
    when (/(\S+)2fitresults.dat$/){
      $i++;
      unless($1 eq $prefix){$read = "no"};      
      push (@datlist, $datfile);
    }
    when (/(\S+)3fitresults.dat$/){
      $i++;
      unless($1 eq $prefix){$read = "no"};      
      push (@datlist, $datfile);     
    }
    when (/(\S+)4fitresults.dat$/){
      $i++;
      unless($1 eq $prefix){$read = "no"};      
      push (@datlist, $datfile);
    }
    default {
      die "The given/when structure should not end up here... Aborting...\n";
    }      
  }  

  # If $i = 4, and $read = "yes" we have found 5 matching fitresults.dat files
  if ($i == 4 and $read eq "yes") {
    $nullP = "";
    $result_str = "$time ";
    $readflux = "no";

 
    foreach $datfile2 (@datlist){
      # Now we start to loop over all the XXX[0-4]fitresults.dat files 
      if ( ! open INPUT2, "<", $datfile2) {die "Cannot open Input file $datfile2 for reading: $!";}
  
      # Going through each line of datfile (XXX[0-4]fitresults.dat)
      while (defined($line = <INPUT2>)){
	#print "$line\n";
        unless($nullP){
	  # If bad fits then the output will go to a different file.
	  if($line =~/nullP:\s+(\S+)/){
	    if ($1 >= 1e-6){
	      $nullP = "ok";
	    } else {
	      $nullP = "bad";
	    }
	  }
        }

        if($line =~/^Model component Fluxes/){
	  $readflux = "yes";
        }
        
        if ($readflux eq "yes"){
	  #6.9515200e-10_{-1.3426000e-11}^{+1.3560000e-11}
	  if($line =~/^(\S+)_{\-(\S+)}\^{\+(\S+)}$/){
	    $readflux = "no";
	    $value = sprintf("%-14.7e", $1);
	    $mean = sprintf("%-14.7e", ($2 + $3)/2.) ;
	    $temp = "$value $mean "; 
	    $result_str = $result_str . $temp;
	  
	    #print "$1\n";
	    #print "$2 $3\n";
	    #print "$result_str\n";
	    #die;
	  }
	}
      }
      close INPUT2;
      

      
    }
    
    # Now we print the results into the output file(s)
    # Two output files are created, the ones that have nullP > 0.05
    # and the bad fits that do not. 
    if ($nullP eq "ok"){
      if ( ! open RESULTPRINT, ">>", "$output") {die "Cannot open $output for appending: $!";}       
    }elsif ($nullP eq "bad"){
      if ( ! open RESULTPRINT, ">>", "$output2") {die "Cannot open $output2 for appending: $!";}        
    }else{
      die "The elsif structure should not end up here... Aborting...\n";
    }
       
    print RESULTPRINT "$result_str\n";
      
    close RESULTPRINT;
    
    
  }
}

close INPUT1;


