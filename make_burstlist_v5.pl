#! /usr/bin/perl
# Perl script for making a burst list for run_pca_burst_vX.pl


use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
#no strict "refs";

require "utils.pl";
require "interface.pl";

##################################################################
# BEGIN: Defining variables

my $inputfile;
my $source;
my $outputfile = "pca_burst_input.txt";
my $new_flag=1;

my $burstid;
my $pid;
my $id;
my @idarr;
my @pidarr;
my $main_dir;
my $tstart;
my $tstop;
my @tstartarr;
my @tstoparr;
my ($i,$dir,$k,$file,$mode,$j);
my (@files);
my $start;
my $stop;
my @std2arr;
my @std1arr;
my @eventarr;
my $std1c;
my $std2c;
my $eventc;
my @id_split;
my @validityarr;

GetOptions("input=s" => \$inputfile, 
	#   "output=s" => \$outputfile,
	   "source=s" => \$source, #Name of the source, DO NOT USE minus or plus signs, but m and p instead!!! 
			);




if($ENV{'LHEASOFT'} !~/\S/) 
{
    print "\n You need to set up HEASOFT to use this script.\n\n";
    exit(0);
}

chomp($main_dir = `pwd`);

#Reading the inputfile for list of burstids
unless(-e $inputfile){
  die "Input file $inputfile does not exist!\n";
}

if (!open INPUT1, "<", $inputfile) {die "Cannot open Input file $inputfile for reading: $!";}

if($new_flag){
while (defined($burstid = <INPUT1>)){
	chomp($burstid);
	if ($burstid =~ /(\S+)\s\s*(\S*)\s\s*(\S*)/) {
		$id= $1 ;
		$tstart=$2;
		$tstop=$3;
		@id_split=split(/\//,$id);
		$id=$id_split[1];
		if ($id =~ /((\S*)-\S*-\S*-\S*)/) {
		  $pid= $2;
		  $id= $1;
		}
	}  else {die "Error: burstid not found. Check that it is given in standard format ie. 50052-02-01-01\n"};
	push @idarr, $id;
	push @pidarr, $pid;
	push @tstartarr, $tstart;
	push @tstoparr, $tstop
}
}
else{
while (defined($burstid = <INPUT1>)){
	chomp($burstid);
	if ($burstid =~ /((\S*)-\S*-\S*-\S*)\s\s*(\S*)\s\s*(\S*)/) {
		$pid= $2 ;
		$id= $1 ;
		$tstart=$3;
		$tstop=$4;
	}  else {die "Error: burstid not found. Check that it is given in standard format ie. 50052-02-01-01\n"};
	push @idarr, $id;
	push @pidarr, $pid;
	push @tstartarr, $tstart;
	push @tstoparr, $tstop
}
}


$i=0;
foreach(@idarr){
    $dir="P$pidarr[$i]/$idarr[$i]/pca";
    $tstart=$tstartarr[$i];
    
    $std2c=0;
    $std1c=0;
    $eventc=0;
    if(-e $dir){
      @files=`ls $dir/*.gz`;
      $k=1;
      foreach $file (@files){
	chomp($file);

       #added if-switch for neglecting *.bm.*
        if($file =~ /.*.bm.gz/) {}
	else {

	$mode=`ftlist $file K include=datamode`;

	#start and stop time of file
	$start=`ftlist $file K include=tstart`;
	if($start =~ /TSTART\s*\=\s*(\S+)\s*\//){$start=$1;}

	$stop=`ftlist $file K include=tstop`;
	if($stop =~ /TSTOP\s*\=\s*(\S+)\s*\//){$stop=$1;}

	#search for std2
	if($mode =~ /DATAMODE\=\s*'Standard2/){
          if ($tstart > $start and $tstart < $stop and $std2c eq 0){
	    push @std2arr, $file;
	    $std2c++;
	    $validityarr[$i]++;
	  }
	}
	#search for std1
	if($mode =~ /DATAMODE\=\s*'Standard1/){
          if ($tstart > $start and $tstart < $stop and $std1c eq 0){
	    push @std1arr, $file;
	    $std1c++;
	    $validityarr[$i]++;
	  }
	}
	#search for event file
	if($mode =~ /DATAMODE\=\s*'E_/){
          if ($tstart > $start and $tstart < $stop and $eventc eq 0){
#	    print "found event file\n";
	    push @eventarr, $file;
	    $eventc++;
	    $validityarr[$i]++;
	  }
	}      
       }
      }

    if($eventc ==0){
      print "No event found for $idarr[$i]\n";




      push @eventarr, "$dir/";
    }

    if($std1c ==0){
      print "No std1 found for $idarr[$i]\n";
      push @std1arr, "$dir/";
    }

    if($std2c ==0){
      print "No std2 found for $idarr[$i]\n";
      push @std2arr, "$dir/";
    }




    }	else {die "No directory named $dir exisits! \n"}

$i++;
chdir $main_dir;
}


$i=0;
foreach(@idarr){

    print "Burst $i $idarr[$i]\n";
    print "Event file= $eventarr[$i]\n";
    print "Std1 file= $std1arr[$i]\n";
    print "Std2 file= $std2arr[$i]\n";
    print "\n";
    $i++;
}

chdir $main_dir;
$i=0;
foreach(@idarr){
  $j=$i+1.;
 $dir = "$idarr[$i]_$j";

if (!-d $dir) { mkdir $dir or die "Error creating directory: $dir"; }

   open(my $fh, ">", "$main_dir/$idarr[$i]_$j/$outputfile") or die "Cannot open $outputfile for writing the input file: $!";
  
  print "Writing an input file to: $idarr[$i]_$j/$outputfile\n";

  print $fh "# This file is used as an input for pca_burst.pl\n\n";

  print $fh "# Edit/add the necessary input files and parameter values\n";
  print $fh "# Do not remove or edit any other lines as they are required\n";
  print $fh "# for reading this file by pca_burst.pl!\n";
  print $fh "##############################################################\n\n";

  print $fh "# Source name (used as root filename). Give only letters or numbers (no -+# etc.)\n\n";

  print $fh "SOURCE_NAME $source\n\n";

  print $fh "# Output goes here\n\n";


  print $fh "OUTDIR_BEGIN\n";
  print $fh "$idarr[$i]_$j/proc\n"; 
  print $fh "OUTDIR_END\n\n";


  print $fh "# Burst Catcher mode data\n\n";
  print $fh "BC_BEGIN\n";
  print $fh "$eventarr[$i]\n"; 
  print $fh "BC_END\n\n";


  print $fh "# Standard 1 mode data: keep the same order as in\n";
  print $fh "# Burst Catcher mode data!\n\n";
  print $fh "STD1_BEGIN\n";
  print $fh "$std1arr[$i]\n"; 
  print $fh "STD1_END\n\n";


  print $fh "# Standard 2 mode data: keep the same order as in\n";
  print $fh "# Burst Catcher mode data!\n\n";
  print $fh "STD2_BEGIN\n";
  print $fh "$std2arr[$i]\n"; 
  print $fh "STD2_END\n\n";


  print $fh "# Burst start times: keep the same order as previously.\n";
  print $fh "# Define this only if using Event mode, otherwise leave empty\n\n";
  print $fh "BSTART_BEGIN\n";
  print $fh "$tstartarr[$i]\n"; 
  print $fh "BSTART_END\n\n";


  print $fh "# Burst stop times: keep the same order as previously.\n";
  print $fh "# Define this only if using Event mode, otherwise leave empty\n\n";
  print $fh "BSTOP_BEGIN\n";
  print $fh "$tstoparr[$i]\n";
  print $fh "BSTOP_END\n\n";

  print $fh "# Parameters used, when pca_burst.pl is called in the script (written automatically)\n\n";
  print $fh "# Which PCU layers to use?\n";
  print $fh "# All active PCUs will be merged, because CB mode does so\n";
  print $fh "# automatically!\n";
  print $fh "LAYERS 1,2,3\n";
  print $fh "# Minimum spectral channel (unedit to change)\n";
  print $fh "#CHMIN 0\n";
  print $fh "# Maximum spectral channel (unedit to change)\n";
  print $fh "#CHMAX 256\n";
  print $fh "# \n\n# \n\n#\n\n";

  close($fh);

$i++;
}

chdir $main_dir;
$i=0;
  if ( ! open WINPUT, ">", "pca_burst_input_list.txt") {
	die "Cannot open $outputfile for writing the input file: $!";
  }

  print "Writing a list of $outputfile files to: pca_burst_input_list.txt\n";

foreach(@idarr){
    $j=$i+1.;
   if($validityarr[$i] eq 3.){
      print WINPUT "$idarr[$i]_$j/$outputfile\n";
    }
    if($validityarr[$i] lt 3.){
      print WINPUT "#$idarr[$i]_$j/$outputfile\n";
      print "Invalid burst found: $idarr[$i]_$j\n";
    }
$i++;
}

  close(WINPUT);

chdir $main_dir;
$i=0;
  if ( ! open DINPUT, ">", "burst_input_list.txt") {
	die "Cannot open burst_input_list.txt for writing the input file: $!";
  }

  print "Writing a list of burst directories to burst_input_list.txt for do.pl\n";

foreach(@idarr){
    $j=$i+1.;
   if($validityarr[$i] eq 3.){
      print DINPUT "$idarr[$i]_$j\n";
    }
    if($validityarr[$i] lt 3.){
      print DINPUT "#$idarr[$i]_$j\n";
      print "Invalid burst found: $idarr[$i]_$j\n";
    }
$i++;
}

  close(DINPUT);













