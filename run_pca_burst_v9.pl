#! /usr/bin/perl

# Perl script for producing time resolved PCA burst spectra


use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use List::Util qw[min max];
use File::Copy;

require "utils.pl";
require "interface.pl";

##################################################################
# BEGIN: Defining variables

#====== These will be done always

my $doxtefilt=1;
my $dogti=1;
my $doextract=1;
my $dobkgmodel=1;
my $dobkg=1;
my $dobkgextract=1;
my $dodt=1;
my $dorsp=1;
my $gtiorvalue="APPLY";
my $dobkg_only=0;
#my $do_pcushutdown_mode=0; #Be careful with this as it might screw up your response

my $doeventmode=0;# automatically detected
my $opt_h;
my $slew;
my $elv=1; #Usually 10
my $offset=0.35; #Usually 0.02
my $screen;

my $dataroot;
my $readstd1="no";
my $readstd2="no";
my $readout="no";
my $readbc="no";
my $readbstart="no";
my $readbstop="no";

my @outputdirs;
my @cb_data;
my @std1_data;
my @std2_data;
my @bstart;
my @bstop;

my $root;
my @layers;
my $chmin;
my $chmax;

my $i;
my $j;
my $k;
my $l;

my $obs_id;
my $datadir;
my $tmp;
my $burstN;
my $cbdatafile;
my $std2datafile;
my $std1datafile;
my $datamode;

my $std2pha;
my $cbpha;
my $rsp;
my $cb_rsp;
my $r_ascension=0;
my $declination=0;
my $bkg;
my $std2_bkg;
my $rootbkg;
my $rootbkg_ac0;
my $rootbkg_ac1;

my $collist;
my $std2list;
my $std1list;
my $cblist;
my $bkglist;
my $bkglist_std2;
my $raw_bkg;
my $gti;
my $win;

my $filterfile;
my $cb_gti;
my $std1_gti;
my $std2_gti;
my $raw_bkg_gti;
my $P;
my $prestd_duration=160;
my $prestd_mod;
my $cb_tstart;
my $cb_tstop;
my $file_tstart;
my $file_tstop;
my $raw_bkg_start;
my $raw_bkg_stop;
my $std2_tstart;
my $std2_tstop;
my $std1_tstart;
my $std1_tstop;
my $startrow;
my $stoprow;
my $pcu_on_str;
my $input_str;
my $num_pcu_on;
my $which_pcus_on;
my $which_on_str;

my @pcus;
my @dpcus;
my $pcu;
my $layer;
my $side;
my $col;
my $layers;
my $pcus;
my @array;
my @tstart;
my @tstop;
my $ngtis;
my $t1;
my $t2;
my $expr;
my $maketime_str;
my $naxis2;
my $root_cbpha;
my $root_cbbkg;

my $fkeyprint;
my $pha;

my $username;
my $version = "1.0c";
my $date;

my $caldb_path;

my $inputfile = "pca_burst_input_list.txt"; # file containing the list of pca_burst_input.txt files
my @inputfiles;
my $inputcheck = "";
my $workdir = "";
my $pcacheck="no";

my $filter_Tres = 0.25;
my $used_res;
my $suffix;
# Use multiples of $filter_Tres as $cbmode_Tres
my $cbmode_Tres = 0.25;

my $std2_lcbinsz = 16.;

my $dynamic_rsp = 0;
my $dcb_rsp;
my $good_interval;
my $start;
my $stop;

# END: Defining variables
##################################################################


#Using GetOptions to get parameters

GetOptions("x=s" => \$r_ascension, #right ascension for object
	   "y=s" => \$declination, #declination for object
	   "inputfile=s" => \$inputfile, #Name of the inputfile
	   "prestd=f" => \$prestd_duration, #Duration of the prestd spectra  
	   "bkg" => \$dobkg,	#Takes 16s bkg file from preburst instead of modelling it
	   "bkg_only" => \$dobkg_only, #Do 16s bkg only, not the whole burst
	   "dt!" => \$dodt	#Toggle deadtime correction on or off
			);


##################################################################
# BEGIN: OUTPUT TO USER
chomp($date = `date`);
$username = $ENV{'LOGNAME'};

print "*******************************************************\n";
print "$username running pca_burst.pl version $version on $date\n";
print "\n";
print "Inputfile to be used is:$inputfile\n";
print "Duration of backround spectra:$prestd_duration\n";
print "\n";
print "\n";
print "*******************************************************\n";
# END: OUTPUT TO USER
##################################################################


##################################################################
# BEGIN: Checking if set-up is ok

# Is CALDB enviroment ok?
$caldb_path=$ENV{CALDB};
if($caldb_path eq ''){
  print "CALDB is not defined!\n";
  die;
}

foreach(`caldbinfo INSTR XTE PCA`){
  print;
  if(/completed successfully/m){$pcacheck = "yes"};
}

unless($pcacheck eq "yes"){die "PCA CALDB not set properly. \n Command: caldbinfo INSTR XTE PCA failed\n"};

# and we also need HEASOFT...
if($ENV{'LHEASOFT'} !~/\S/) 
{
    print "\n You need to set up HEASOFT to use this script.\n\n";
    exit(0);
}

# Pointing to appidlist file
my $xtefilt_appid = "${caldb_path}/data/xte/pca/appidlist";
unless(-e $xtefilt_appid){die "appidlist not found in $caldb_path/data/xte/pca/appidlist\n"};

my $saahfile="${caldb_path}/data/xte/pca/cpf/bgnd/pca_saa_history.gz";
unless(-e $saahfile){die "saahfile not found in ${caldb_path}/data/xte/pca/cpf/bgnd/pca_saa_history.gz\n"};

############ Background model, for some observations of the First Cicle
############ VLE background (that is better than Q6) does not work
 
my $bkgfiles_l7="${caldb_path}/data/xte/pca/cpf/bgnd/pca_bkgd_cmfaintl7_eMv20051128.mdl";
my $bkgfiles_vle="${caldb_path}/data/xte/pca/cpf/bgnd/pca_bkgd_cmbrightvle_eMv20051128.mdl";

# Un-edit to change background model. Rate should be less than 40cts/s to use L7 model. 
my $bkgmodel = $bkgfiles_vle;
#my $bkgmodel = $bkgfiles_l7;

print "\n Accepted background model $bkgmodel \n";

# Do not allow slew data
$slew=0;

$screen="ELV.gt.$elv.and.OFFSET.lt.$offset";
if($slew){
  $screen="ELV.gt.8.and.OFFSET.lt.0.35";
}

#Checking that prestd_duration is multiple of 16
$prestd_mod = $prestd_duration % 16;
if($prestd_mod ne 0){die "Aborting... Backround duration is not multiple of 16, you gave $prestd_duration!\n"} 

#pcarsp only accepts four digits to offset values so truncating given parameters if necessary
if($r_ascension =~ /(\S+\.\d\d\d\d)\d+/){
  print "\n\npcarsp only accepts 4 digits, you gave $r_ascension for -x parameter\n";
  print "WARNING: Parameter will be truncated into $1\n";
  $r_ascension = $1;
}

if($declination =~ /(\S+\.\d\d\d\d)\d+/){
  print "\n\npcarsp only accepts 4 digits, you gave $declination for -y parameter\n";
  print "WARNING: Parameter will be truncated into $1\n";
  $declination = $1;
}

# Getting work directory
chomp($workdir = `pwd`);

print "$workdir\n";

# Checking if the input file has been written. 
if(-e $inputfile){
  print "\n Inputfile ${inputfile} given in directory ${workdir}.\n";
  $dataroot = $workdir;
} else {
    die "Inputfile $inputfile does not exist!";
}

# END: Checking if set-up is ok
##################################################################


##################################################################
# BEGIN: Reading the input file

# Reading coordinates
if(!$r_ascension && !$declination)
{
    open(COORDSINPUT, "<", "coordinates.txt") or die "Failed to read coordinates: $!\n";
    while(<COORDSINPUT>) { 
        if(/RA=(\S+)/m){
            $r_ascension = $1;
            chomp($r_ascension);
            print "RA = $r_ascension\n";
        }
        if(/DEC=(\S+)/m){
            $declination = $1;
            chomp($declination);
            print "DEC = $declination\n";
        }    
    }
    close(COORDSINPUT);
}


# Reading the paths of the separate inputfiles from pca_burst_input_list.txt
open(INPUT1, "<", $inputfile) or die "Failed to open file: $!\n";
while(<INPUT1>) { 
    chomp; 
    push @inputfiles, $_;
}
close(INPUT1);

# Reading the input files 
$i=0;
foreach(@inputfiles) {

  open(my $fh, "<", $inputfiles[$i]) or die "Failed to open file: $!\n";

  while(<$fh>){
    print;
    print "\n";
    # Finding the correct lines

    if(/OUTDIR_END/m){
	$readout="no";
    }

    if(/BC_END/m){
	$readbc="no";
    }

    if(/STD1_END/m){
	$readstd1="no";
    }

    if(/STD2_END/m){
	$readstd2="no";
    }

    if(/BSTART_END/m){
	$readbstart="no";
    }

    if(/BSTOP_END/m){
	$readbstop="no";
    }

    # Reading datafiles to arrays
    if($readout eq "yes"){
  	print "matched readout!\n";
  	chomp;
  	push @outputdirs, $_;
    }
    if($readbc eq "yes"){
	print "matched readbc!\n";
	chomp;
	push @cb_data, $_;
    }
    if($readstd1 eq "yes"){
	print "matched readstd1!\n";
	chomp;
	push @std1_data, $_;
    }
    if($readstd2 eq "yes"){
	print "matched readstd2!\n";
	chomp;
	push @std2_data, $_;
    }

    if($readbstart eq "yes"){
	print "matched readbstart!\n";
	chomp;
	push @bstart, $_-4.0;
    }

    if($readbstop eq "yes"){
	print "matched readbstop!\n";
	chomp;
	push @bstop, $_;
    }

    # READING INPUT PARAMETERS TO VARIABLES

    # Getting output root name
    if(/SOURCE_NAME\s+(\S+)/m){
	$root = $1;
	chomp($root);
	# Testing if root name is properly given. Non-number & non-letters give problems.
	if ($root =~ /\W/){die "Give only numbers and letters as root name.\nYou gave: $root \n"};
    }

    # Getting the layers
    if(/LAYERS\s+(\S+)/m){
	@layers=split(/\,/,$1);
	# Testing if layers are properly given.
	foreach(@layers){
		if (/[^1-3]/){die "Give only numbers 1,2,3 as layers.\nYou gave: @layers \n"};
	}
    }

    # Lowest energy channel
    if (/^([\D\d]?)CHMIN\s+(\S+)/m) {
	if ($1){  
	  $chmin = 'INDEF';
	} else {
	  $chmin=$2;
	}
    }

    # Highest energy channel
    if (/^([\D\d]?)CHMAX\s+(\S+)/m) {
	if ($1){  
	  $chmax = 'INDEF';
	} else {
	  $chmax=$2;
	}
    }

    # Finding the correct lines
    if(/OUTDIR_BEGIN/m){
	$readout="yes";
    }
    if(/BC_BEGIN/m){
	$readbc="yes";
    }
    if(/STD1_BEGIN/m){
	$readstd1="yes";
    }
    if(/STD2_BEGIN/m){
	$readstd2="yes";
    }
    if(/BSTART_BEGIN/m){
	$readbstart="yes";
    }
    if(/BSTOP_BEGIN/m){
	$readbstop="yes";
    }

  #  continue LOOPEND;
  }

 close($fh);
 $i++;
}




# Checking that the number of input files match

$tmp = $#cb_data+1;
print "number of burst to analyze: $tmp\n";

unless($#cb_data == $#std1_data && $#cb_data == $#std2_data && $#cb_data == $#outputdirs){die "Number of input data files do not match!\n"};
unless($#bstart == $#bstop){die "Number of start and stop times given do not match!\n"};

# Checking that the data files exist
foreach(@cb_data){
  unless(-e $_){die "File $_ does not exist\n"};
}
foreach(@std1_data){
  unless(-e $_){die "File $_ does not exist\n"};
}
foreach(@std2_data){
  unless(-e $_){die "File $_ does not exist\n"};
}
# Making output directories if they do not exist yet.
foreach(@outputdirs){
  @array = split(/\//,$_);
  foreach(@array){
	print "My outdir to be possibly created is: ";
	print;
	print "\n";
	if(-e $_){
	  chdir "$_";
	}else{
	  mkdir "$_", 0755 or die "Cannot make directory: $_\n $!";
	  chdir "$_";
	}
  }
  # Lets first go back to the $dataroot folder
  chdir $dataroot;
}


$i=0;
while($i<=$#outputdirs){

    my $pculistname = "$workdir/$outputdirs[$i]/pcu_list";      
    #Deleting old and/or creating new pcu_list.txt
    if (-e "$pculistname.txt") {
        my $numm = 2;
        $numm++ while (-e "$pculistname\_$numm.txt");
        copy("$pculistname.txt","$pculistname\_$numm.txt") or die "cannot copy file";
    } 

    open(my $fhh, ">", "$workdir/$outputdirs[$i]/pcu_list.txt") or die "Failed to create pcu_list.txt: $!\n";
    print "Created pcu_list.txt in $outputdirs[$i]\n";
    close($fhh);
    $i++;
}

# END: Reading the input file
##################################################################


##################################################################
# BEGIN: Making the light curves
$i=0;

while($i<=$#cb_data){

  # Defining variables (needed for xtefilt)
  # 1) obs_id
  if($cb_data[$i] =~ /\/(\S+)\/pca/){
	$obs_id = $1;
  }else{die  "Could not match obs ID from $cb_data[$i] \n"};
  # 2) datadir ()
  if($cb_data[$i] =~ /(\S+)\/pca/){
	$datadir = $1;
  }else{die "Could not match data directory from $cb_data[$i] \n"};

  # Defining burst number B (adding 0 in front if N lt 10)
  $tmp = $i+1;
  if ($tmp lt 10){
	$burstN = "B0"."$tmp";
  } else {$burstN = "B"."$tmp"};

  # Defining output data names
  $std2pha="$outputdirs[$i]/${root}_${burstN}_prestd2.pha";
  $cbpha="$outputdirs[$i]/${root}_${burstN}_cb.pha";
  $rsp="$outputdirs[$i]/${root}_${burstN}.rsp";
  $cb_rsp="$outputdirs[$i]/${root}_${burstN}_cb.rsp";
  $bkg="$outputdirs[$i]/${root}_${burstN}_bkg.pha";
  $rootbkg="$outputdirs[$i]/${root}_${burstN}_bkg";
  $rootbkg_ac0="$outputdirs[$i]/${root}_${burstN}_bkg_ac0";
  $rootbkg_ac1="$outputdirs[$i]/${root}_${burstN}_bkg_ac1";
  $collist="$outputdirs[$i]/${root}_${burstN}.col";


  #Checking if burst mode matches given data
  $datamode = `ftlist $cb_data[$i]+1 K`;

  if($datamode =~ /[\d\D]+DATAMODE=\s+'([\d\D]+)'/m){
  $datamode = $1;
  print "\n\n\n*** Detected datamode:$datamode ***\n\n";

	#event -> seextrct
	#array -> saextrct

    #Checking if Event mode is used
    if($datamode =~ /E_(\S+)_\S+/){
      print "Using Event encoded mode that needs the burst start and stop times to be given\n";
      
      if($bstart[$i] ne "" && $bstop[$i] ne ""){
      print "Given start time is:$bstart[$i] and stop time:$bstop[$i]\n";
    } else {
      die "No burst start and stop time defined for event mode!\n";
      }
      $doeventmode=1;
      $used_res=$1;
    }

    #Good Xenon Data
    if($datamode =~ /GoodXenon_2s/){
      print "Using GoodXenon mode that needs the burst start and stop times to be given\n";
      
      if($bstart[$i] ne "" && $bstop[$i] ne ""){
      print "Given start time is:$bstart[$i] and stop time:$bstop[$i]\n";
    } else {
      die "No burst start and stop time defined for event mode!\n";
      }
      $doeventmode=1;

      #Making some technical changes so that we can use 2s GoodXenon Data
      $used_res="2s";
      $filter_Tres = 2.0;
      $cbmode_Tres = 2.0;
    }

   
    #Checking if Binned Burst Catcher mode is used
    if($datamode =~ /CB_\S+/){
      print "Using Binned Burst Catcher mode\n";
      $doeventmode=0;  
    }

    #Checking if other not supported modes used
    if($datamode =~ /CE_\S+/){
      print "Using Event Burst Catcher mode\n";
      die "Code does not (yet) support Event Burst Chatcher mode CE_**\n";
    }

    if($datamode =~ /\s+B_\S+/){
      print "Using Binned Data mode\n";
      die "Code does not (yet) support Binned Data mode B_**\n";
    }

    if($datamode =~ /D_\S+/){
      print "Using Delta-binned mode\n";
      die "Code does not support Delta-binned mode D_**\n";
    }
 
    if($datamode =~ /F_\S+/){
      print "Using Fast Fourier Transform mode\n";
      die "Code does not support Fast Fourier Transform mode F_**\n";
    }

    #Making sure single bit mode is not used
    if($datamode =~ /SB_\S+/){
      die "Single-bit mode detected, spectra can't be extracted from it!\n";
    }

  } else {
  die "NO DATAMODE DETECTED\n";
  }


#Resolution units into right format
  if($used_res =~ /(\d*)(\w*)_\S*_\S*/){
      $used_res=$1;
      $suffix=$2;
      if($suffix=~/us/){$used_res=$used_res/10**(6)}
      elsif($suffix=~/ms/){$used_res=$used_res/10**(3)}
      elsif($suffix=~/s/){ }
      else{die "no match found for used resolution multiplyer $suffix";}
  }


#making filtter file
  print "xtefilt  -c -a ${xtefilt_appid} -o ${obs_id} -p ${datadir} -t $filter_Tres -f $outputdirs[$i]/${root}_${burstN}\n";
  system "xtefilt  -c -a ${xtefilt_appid} -o ${obs_id} -p ${datadir} -t $filter_Tres -f $outputdirs[$i]/${root}_${burstN}";


  $filterfile = "$outputdirs[$i]/${root}_${burstN}".".xfl";

  unless(-e $filterfile){die "Filterfile $filterfile does not exist!\n"};
  # Defining file names for GTI files
  $cb_gti = "$outputdirs[$i]/${root}_${burstN}_cb.gti";
  $std1_gti = "$outputdirs[$i]/${root}_${burstN}_std1.gti";
  $std2_gti = "$outputdirs[$i]/${root}_${burstN}_std2.gti";


  #Filttering according to bitmask: b1xxxxxxxxxxxxxxx 
  # if using event mode is used.
  if($doeventmode){
  print "\n\nScience Event mode used, filttering FITS file...\n\n"; 
      if($cb_data[$i] =~ m/(\S+).gz/){
	$cbdatafile=$1;
      }

    if($datamode =~ /GoodXenon_2s/){
      print "GoodXenon mode used, no bitmasking will be done\n";
    }else{
  print "fselect $cb_data[$i] $cbdatafile.bm.gz expr=\"Event.eq.b1xxxxxxxxxxxxxxx.and.Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes\n";
  system "fselect $cb_data[$i] $cbdatafile.bm.gz expr=\"Event.eq.b1xxxxxxxxxxxxxxx.and.Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes";
  $cb_data[$i]="$cbdatafile.bm.gz";
  print "\nUsing $cb_data[$i] as a filttered cb_data file now\n";
    }
  }

#Filttering std2-datafile for better performance
  print "\nFilttering std2 file now...\n\n"; 
      if($std2_data[$i] =~ m/(\S+).gz/){
	$std2datafile=$1;
      }
  print "fselect $std2_data[$i] $std2datafile.bm.gz expr=\"Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes\n";
  system "fselect $std2_data[$i] $std2datafile.bm.gz expr=\"Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes";
  $std2_data[$i]="$std2datafile.bm.gz";
  print "\nUsing $std2_data[$i] as a filttered std2_data file now\n";
  print "Continuing...\n";


#Filttering std1-datafile for better performance
  print "\nFilttering std1 file now...\n\n"; 
      if($std1_data[$i] =~ m/(\S+).gz/){
	$std1datafile=$1;
      }
  print "fselect $std1_data[$i] $std1datafile.bm.gz expr=\"Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes\n";
  system "fselect $std1_data[$i] $std1datafile.bm.gz expr=\"Time.gt.$bstart[$i]-170.and.Time.lt.$bstop[$i]+40\" clobber=yes";
  $std1_data[$i]="$std1datafile.bm.gz";
  print "\nUsing $std1_data[$i] as a filttered std1_data file now\n";
  print "Continuing...\n";



  # Making a GTI file according to given burst start and stop times 
  if($doeventmode){
    print "\n\nRunning the maketime according to given burst start:$bstart[$i] and stop:$bstop[$i]\n\n";
    print "maketime clobber=yes infile=$filterfile outfile=$cb_gti expr=\"time.gt.$bstart[$i].and.time.lt.$bstop[$i]\" name=NAME value=VALUE time='Time' compact=no\n"; 
    system "maketime clobber=yes infile=$filterfile outfile=$cb_gti expr=\"time.gt.$bstart[$i].and.time.lt.$bstop[$i]\" name=NAME value=VALUE time='TIME' compact=no";
  }

  # Making a GTI file from the burst mode data.
  else{
    system "maketime clobber=yes infile=$cb_data[$i] outfile=$cb_gti expr=\"time.gt.0\" name=NAME value=VALUE time='Time' compact=no";
    print "maketime clobber=yes infile=$cb_data[$i] outfile=$cb_gti expr=\"time.gt.0\" name=NAME value=VALUE time='Time' compact=no\n";
  }

  #----- check that it is not empty
  system "fkeypar $cb_gti+1 naxis2";
  `pget fkeypar value`>0 or die "\n ERROR: The GTI file $cb_gti is empty!\nMost likely change Slew=1 in the script!\n";

  # Getting START and STOP from $cb_gti
  $cb_tstart = "";
  foreach(`flist $cb_gti STDOUT START - prhead=no`){
	if(/START =\s+(\S+)/){$cb_tstart=$1};
  }
  if($cb_tstart eq ""){die "Did not get start value from $cb_gti.\n"};

  $cb_tstop = "";
  foreach(`flist $cb_gti STDOUT STOP - prhead=no`){
	if(/STOP =\s+(\S+)/){$cb_tstop=$1};
  }
  if($cb_tstop eq ""){die "Did not get start value from $cb_gti.\n"};


  #Making gti files for std1 and std2 data
  #If prestd_duration is not given, 160s used
  #Using $cb_tstart to derive the values

  #Default values:
  #$std2_gti will be made from -180 to -20 seconds before the TSTART CB MODE 
  #$std1_gti will be made from -180 before the TSTART CB MODE to the TSTOP CB MODE 

  $std2_tstart = $cb_tstart-$prestd_duration-5;
  $std2_tstop = $cb_tstart-5;
  $std1_tstart = $cb_tstart-$prestd_duration-5;
  $std1_tstop = $cb_tstop+5;

  $expr = "time.gt.$std2_tstart.and.time.lt.$std2_tstop";
  system "maketime clobber=yes infile=$filterfile outfile=$std2_gti expr=\"$expr\" name=NAME value=VALUE time='Time' compact=no";

  $expr = "time.gt.$std1_tstart.and.time.lt.$std1_tstop";
  system "maketime clobber=yes infile=$filterfile outfile=$std1_gti expr=\"$expr\" name=NAME value=VALUE time='Time' compact=no";

  $expr = "";

  # Getting the rows of the filter file that corresponds to 
  # Beginning and end of the std1 gti.
  # This will be used to check how many PCUs are on during the
  # X-ray burst.

  $pcu_on_str = "$outputdirs[$i]/${root}_${burstN}_active_pcus.ps";

  $input_str = "${filterfile}_flt time \'PCU0_ON,PCU1_ON,PCU2_ON,PCU3_ON,PCU4_ON,NUM_PCU_ON\' - ${pcu_on_str}/PS quit offset=yes";

  # Filter XFL file with the obtained GTI
  system "fltime infile=$filterfile gtifile=$std1_gti outfile=${filterfile}_flt clobber=yes";  
  system "fplot $input_str";

  system "fltime infile=$std2_data[$i] gtifile=$std2_gti outfile=std2.flt clobber=yes";
  system "fltime infile=$std1_data[$i] gtifile=$std1_gti outfile=std1.flt clobber=yes";
  system "fltime infile=$cb_data[$i] gtifile=$cb_gti outfile=cb.flt clobber=yes";

  system("ls std2.flt > std2.list");
  system("ls std1.flt > std1.list");
  system("ls cb.flt > cb.list");
  $std2list = "std2.list";
  $std1list = "std1.list";
  $cblist =  "cb.list";
  $bkglist="bkg.list";
  $bkglist_std2="bkg_std2.list";

  $collist="${root}.col";
  $gti="${root}.gti";
  $win="${root}.win";


  # Calculate average number of operational PCUs

  system "fstatistic infile=${filterfile}_flt colname='num_pcu_on' rows='-'";
  $num_pcu_on=`pget fstatistic mean`;
  
  if($num_pcu_on eq 0 or $num_pcu_on eq ""){die "Error reading the number of average PCUs ($num_pcu_on)"} 

  # Checking which PCUs are operational
  $l=0;
  # This variable will be a string that is used to tell
  # saextrct and pcarsp which PCUs were on.
  # F.E. if PCUs 0,2,3 were on it would have value "0,2,3"
  $which_pcus_on="";
  $which_on_str="";
  while($l <= 4){
	system "fstatistic infile=${filterfile}_flt colname='PCU${l}_ON' rows='-'";
  	$tmp = `pget fstatistic mean`;
	if ($tmp == 1) {
    #PCUs that are ON
	  print "During the observation, PCU $l was on.\n";
	  if ($which_pcus_on ne ""){	
		$which_pcus_on = $which_pcus_on . ",$l";
		$which_on_str = $which_on_str.".and.pcu${l}_on.eq.1";
	  }
	  if ($which_pcus_on eq ""){	
		$which_pcus_on = $l;
		$which_on_str = "pcu${l}_on.eq.1";
	  }
	} elsif ($tmp == 0){
    #PCUs that are OFF
	  print "During the observation, PCU $l was off.\n";
	} else {
    #PCUs that are partially ON
	  print "During the observation, PCU $l went off! Strange?\n";
	 # die "During the observation, PCU $l went off! Strange?\n";
	}
	$l++
  }

  @pcus = split(/,/,$which_pcus_on);

	#check standard deviation of PCUs on
	# using pget fstatistic
	system "fstatistic infile=${filterfile}_flt colname='num_pcu_on' rows='-'";
	$tmp = `pget fstatistic sigma`;
	print "sigma = $tmp \n";
    if(defined($tmp)) {
        if($tmp == 0) {$dynamic_rsp=0;}
        else { $dynamic_rsp=1; } 
    } else { $dynamic_rsp=0; }



  # Doing the column list for used PCUs and layers
  open(COLLIST, "> $collist");
  foreach $pcu (@pcus) {foreach $layer (@layers) {foreach $side ("L","R") {
	$col="X${layer}${side}SpecPcu$pcu"; 
	print COLLIST "$col\n";
  }}}
  close(COLLIST);

  print "my std2list : $std2list\n";

  # Extracting light curve and spectrum (SAEXTRACT) for the WHOLE duration of
  # STD1 data. This is used to create the background LC and SPECTRA!	
  if($doextract) {
	print "\n\n Will extract pha and lc now ...\n\n";
	system "saextrct infile=\@$std2list gtiorfile=$gtiorvalue gtiandfile=$std1_gti outroot=$outputdirs[$i]/${root}_${burstN}_std1gti accumulate=one timecol=TIME columns=\@$collist binsz=$std2_lcbinsz printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
  }

  # Extracting light curve and spectrum (SAEXTRACT) for the duration of
  # STD2 data. This is the preburst STD2 spectrum and lc!	
  if($doextract) {
	print "\n\n Will extract pha and lc now ...\n\n";
	system "saextrct infile=\@$std2list gtiorfile=$gtiorvalue gtiandfile=$std2_gti outroot=$outputdirs[$i]/${root}_${burstN}_prestd2 accumulate=one timecol=TIME columns=\@$collist binsz=$std2_lcbinsz printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
  }

  # Extracting light curve and spectrum (SAEXTRACT) for the duration of
  # CB data. This spectrum will only be used to make a CB response!	

if($doextract){
  if($doeventmode){
	print "\n\n Using seextract to get pha and lc...\n\n";
	system "seextrct infile=$cb_data[$i] gtiorfile=$gtiorvalue gtiandfile=$cb_gti outroot=$outputdirs[$i]/${root}_${burstN}_cb timecol=TIME columns=Event binsz=$filter_Tres printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
  }
  else{
	print "\n\n  Using saextract to get pha and lc...\n\n";
	#system "saextrct infile=\@$cblist gtiorfile=$gtiorvalue gtiandfile=$cb_gti outroot=$outputdirs[$i]/${root}_${burstN}_cb accumulate=one timecol=TIME columns=GOOD binsz=$filter_Tres printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
	system "saextrct infile=$cb_data[$i] gtiorfile=$gtiorvalue gtiandfile=$cb_gti outroot=$outputdirs[$i]/${root}_${burstN}_cb accumulate=one timecol=TIME columns=GOOD binsz=$filter_Tres printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
  
 
  }
}


#XXX check what is "Update paratemer file?"
# change bkglist to obsid-dir not to main dir


  # Model background (RUNPCABACKEST), making it only for the std1 duration (uses ${filterfile}_flt). 
  if($dobkgmodel) {
	print "\n\nWill model BKG now ...\n\n";
	system "pset pcabackest timeslop=1024";
	open(BKGPAR, "> runpcabackest.par");
#	print BKGPAR "$std2_data[$i]\n$bkglist\nbkg\n${filterfile}\n$bkgmodel\n$filter_Tres\nyes\nno\nyes\n$saahfile\nno"; 
	print BKGPAR "$std2_data[$i]\n$bkglist\nbkg\n${filterfile}\n$bkgmodel\n16\nyes\nno\nyes\n$saahfile\nno"; 
	close BKGPAR;
	system "runpcabackest < runpcabackest.par";
  }
  
  # doing the same for the std2 background spectra (time 16s binning, 129 channels).
  #this should work
   if($dobkgmodel) {
	system "pset pcabackest timeslop=1024";
	open(BKGPAR, "> runpcabackest.par");
	print BKGPAR "$std2_data[$i]\n$bkglist_std2\nbkg_std2\n${filterfile}\n$bkgmodel\n16\nyes\nno\nno\n$saahfile\nno"; 
	close BKGPAR;
	system "runpcabackest < runpcabackest.par";
  } 
  
	  print "Running seextrct for bkg!\n";   
	  system "saextrct infile=\@$bkglist gtiorfile=APPLY gtiandfile=$std1_gti outroot=$outputdirs[$i]/full_std1_bkg accumulate=one timecol=TIME columns='GOOD' binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";

#  >> saextrct.dbg
	  print "Running rbnpha!\n"; 
	  system "rbnpha binfile=cb_chan.txt $outputdirs[$i]/full_std1_bkg.pha $outputdirs[$i]/full_std1_bkg_64ch.pha clobber=true";
	  print "Running fparkey!\n";



  if($dobkg){
	#This part is optionally done
	#Extracting 16s prestd background spectra from std2 file that will be used as a bkg.

      print "\nExtracting 16s background now...\n\n";
      
      $raw_bkg = "$outputdirs[$i]/${root}_${burstN}_bkg_16s";
      $raw_bkg_gti = "$outputdirs[$i]/${root}_${burstN}_bkg_16s.gti";

      $raw_bkg_start = $cb_tstart-16;
      $raw_bkg_stop = $cb_tstart-0;


      #Checking times
      $fkeyprint = `ftlist $cb_data[$i]+1 K`;
      if($fkeyprint =~ /TSTART\s+=\s+(\S+)\s+\//){
	  $file_tstart=$1;
      }
      if($fkeyprint =~ /TSTOP\s+=\s+(\S+)\s+\//){
	  $file_tstop=$1;
      }

      $fkeyprint = `ftlist $std1_data[$i]+1 K`;
      if($fkeyprint =~ /TSTART\s+=\s+(\S+)\s+\//){
	  $file_tstart=max($1,$file_tstart);
      }
      if($fkeyprint =~ /TSTOP\s+=\s+(\S+)\s+\//){
	  $file_tstop=min($1,$file_tstop);
      }

      #Making background before or after the burst depending on the lenght
      if($file_tstart >= ($bstart[$i]-16.)){
	  print "WARNING: Using 16s background from after the burst\n";
	  $raw_bkg_start=$cb_tstop+20.;
	  $raw_bkg_stop=$cb_tstop+36.;
      } else {
	  print "Using 16s background just prior the burst\n";
	  $raw_bkg_start = $cb_tstart-16;
	  $raw_bkg_stop = $cb_tstart-0;
      }
      
      $expr = "time.gt.$raw_bkg_start.and.time.lt.$raw_bkg_stop.and.offset.lt.$offset.and.elv.gt.$elv";
      
      
if($doeventmode){ #if possible, doing raw bkg from event mode data

  print "maketime clobber=yes infile=$filterfile outfile=$raw_bkg_gti expr=\"$expr\" name=NAME value=VALUE time='Time' compact=no\n";
  system "maketime clobber=yes infile=$filterfile outfile=$raw_bkg_gti expr=\"$expr\" name=NAME value=VALUE time='Time' compact=no";

  $expr = "";

  #Extracting bkg from event data into 64ch
  print "seextrct infile=$cb_data[$i] gtiorfile=$gtiorvalue gtiandfile=$raw_bkg_gti outroot=${raw_bkg}_64ch timecol=TIME columns=EVENT binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> saextrct.dbg\n";
  system "seextrct infile=$cb_data[$i] gtiorfile=$gtiorvalue gtiandfile=$raw_bkg_gti outroot=${raw_bkg}_64ch timecol=TIME columns=EVENT binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> saextrct.dbg";
}

else{ #else making it from std2 data (spectrum is valid only up to 24.85 keV due to channel binning differences)
  print "Warning: 16s background made from std2. This is not a good way to do this!";
  system "maketime clobber=yes infile=$std2_data[$i] outfile=$raw_bkg_gti expr=\"$expr\" name=NAME value=VALUE time='Time' compact=no";
  $expr = "";

  system "saextrct infile=$std2_data[$i] gtiorfile=$gtiorvalue gtiandfile=$raw_bkg_gti outroot=$raw_bkg accumulate=one timecol=TIME columns='GOOD' binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> saextrct.dbg ";

  #binning into 64 channels
  #&write_std2_chan($dataroot);
  system "rbnpha binfile=std2_chan.txt $raw_bkg.pha ${raw_bkg}_64ch.pha clobber=true";
}

  #dtcorr
  if($dodt){
	deadtime_corr("${raw_bkg}_64ch.pha",$std1_data[$i],$raw_bkg_gti);
  } 
}
  
  if($dobkg_only){
    die;
  }


  # Extracting bkg spectrum (SAEXTRACT) for STD2 spectrum
  if($dobkgextract) {
	print "\n\n Will extract BKG pha and lc now for standard 2 mode\n\n";
	system "saextrct infile=\@$bkglist_std2 gtiorfile=$gtiorvalue gtiandfile=$std2_gti outroot=${rootbkg}_std2 accumulate=one timecol=TIME columns=\@$collist binsz=$std2_lcbinsz printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";
  }

  # Inserting keyword for background file to $std2pha
  system "fparkey fitsfile=$std2pha value='${rootbkg}_std2.pha' keyword='BACKFILE'";

  # Creating responses for STD2 and CB mode
  if($dorsp){
	print "\n\n Will prepare response now for STD2...\n\n";

	# Here I preset the pcarmf value "nofits" to be 1 according to ERRATUM (see
	# top lines
	system "pset pcarmf nofits=0";

	$pcus=""; foreach $pcu (@pcus) {$pcus.="$pcu,"};$/=",";chomp($pcus);
	$layers=""; foreach $layer (@layers) {$layers.="LR$layer,"};chomp($layers);
	print "\npcus=$pcus"; print "\nlayers=$layers\n";
	open(RSPPAR, "> pcarsp.par");
	print RSPPAR "$std2pha\n$filterfile\n$layers\ny\n$pcus\ny\ny\n";
	close RSPPAR;

	if($r_ascension eq 0 && $declination eq 0){
	  system "pcarsp -n $rsp < pcarsp.par";
	  print "pcarsp -n $rsp < pcarsp.par\n";
	} else{
	  print "\npcarsp -n $rsp -x $r_ascension -y $declination < pcarsp.par \n";
	  system "pcarsp -n $rsp -x $r_ascension -y $declination < pcarsp.par";
	}

  	print "\n\n Will prepare response now for CB...\n\n";

	# Here I preset the pcarmf value "nofits" to be 1 according to ERRATUM (see
	# top lines

	system "pset pcarmf nofits=0";

	open(RSPPAR, "> pcarsp.par");
	print RSPPAR "$cbpha\n$filterfile\n$layers\ny\n$pcus\ny\ny\n";
	close RSPPAR;

	#Again making responses to offset if ra and dec given

	if($r_ascension eq 0 && $declination eq 0){
	  system "pcarsp -n $cb_rsp < pcarsp.par";
	} else{
	  print "\npcarsp -n $cb_rsp -x $r_ascension -y $declination < pcarsp.par \n";
	  system "pcarsp -n $cb_rsp -x $r_ascension -y $declination < pcarsp.par";
	}
  }


  # Dead time correction for the STD2 data
  # This is std2_prestd spectra that will be corrected
  if($dobkgextract){
    if($dodt){
	  deadtime_corr($std2pha,$std1_data[$i],$std2_gti);
    } 
  }

  #  Script makes the hell lot of small time integrated spectra 
  # from the proveded observations. It needs list of STD2 files "list"
  # XTE filter file "*.xfl", response file for the pha spectra "*.rsp"
  # and global GTI that will be used "*.gti".
  #   Also the user provides the dt value - integration time for the single
  #   spectrum
  #
  #

  print "Running command\n";   
  print "fdump infile='$cb_gti+1' outfile=goodtime.dat columns='-' rows='-' prhead=no showcol=no showunit=no pagewidth=200 showrow=no clobber=yes\n";   
  system "fdump infile='$cb_gti+1' outfile=goodtime.dat columns='-' rows='-' prhead=no showcol=no showunit=no pagewidth=200 showrow=no clobber=yes";   

  open(GTI,"goodtime.dat");
  $l=0;
  while(<GTI>){
	chomp;
	if(/(\S+)\s+(\S+)/){
	  #@array=split(/ +/,$_);
	  $tstart[$l]=$1;
	  $tstop[$l]=$2;
	  print "$tstart[$l] $tstop[$l]\n";
	  $l++;
	}
  }
  $ngtis=$l-1;

  $tmp=$ngtis+1;
  print "Number of GTIs : $tmp\n";

  $j=0;
  $k=0;
  $t1=$tstart[$j];
  $t2=sprintf("%.12E",$t1+$cbmode_Tres);

  print "tstart = $tstart[0]\n";
  print "tstop = $tstop[$ngtis]\n";
  print "cbTres = $cbmode_Tres\n";
  print "t1 = $t1\n";
  print "t2 = $t2\n";

  if($which_on_str ne ""){
    $expr=$which_on_str.".and.time.gt.$t1.and.time.le.$t2.and.offset.lt.$offset.and.elv.gt.$elv";
    print "expr = $expr\n";
  }else{
    print "WARNING: No PCUs detected\n";
    $expr="time.gt.$t1.and.time.le.$t2.and.offset.lt.$offset.and.elv.gt.$elv";
    print "expr = $expr\n";
  }

  system "rddescr phafil=$outputdirs[$i]/${root}_${burstN}_cb.pha chanfil=cb_chan.txt";


    #main loop over whole duration of the burst
  while($t2<=$tstop[$ngtis]){

    $good_interval = 0;

	$t2=sprintf("%.12E",$t1+$cbmode_Tres);
	print "\n Interval $k: tstart=$t1 tstop=$t2\n";

	if($which_on_str ne ""){
	  $expr=$which_on_str.".and.time.gt.$t1.and.time.le.$t2.and.offset.lt.$offset.and.elv.gt.$elv";
	}else{
	  $expr="time.gt.$t1.and.time.le.$t2.and.offset.lt.$offset.and.elv.gt.$elv";
	}

	# This makes the appropriate GTI file for the 0.25 spectrum
	$maketime_str="maketime infile=$filterfile outfile=cur.gti expr=$expr name=NAME value=VALUE time=Time compact=no clobber=yes";
	print "\n$maketime_str\n";
	print "Running maketime!\n";
	system "$maketime_str";

	print "Running fkeypar!\n";    
	system "fkeypar cur.gti naxis2";
	print "Running pget!\n"; 
	$naxis2=1.0 * `pget fkeypar value`;
	print "NAXIS2 $naxis2\n";

	$k=sprintf("%03d", $k);

    #make specific filter and check that number of PCU does not change
    if($dynamic_rsp){
        #Make new filter
        system "fltime infile=$filterfile gtifile=cur.gti outfile=${filterfile}_dflt clobber=yes";

    	#check standard deviation of PCUs on using pget fstatistic
        system "fstatistic infile=${filterfile}_dflt colname='num_pcu_on' rows='-'";
    	$tmp = `pget fstatistic sigma`;
        if($tmp == 0){
            $good_interval = 1;
        }else{
            $good_interval = 0;
            print "Skipping interval because number of PCUs is varying\n";
            die;
        }
    }else{$good_interval = 1;}

	if($naxis2>=1 && $good_interval){

	$root_cbpha="$outputdirs[$i]/${root}_${burstN}_${k}";

	print "Running seextrct!\n"; 
	  #Using saextrct/seextrct to get spectra
    #Reduce the 0.25 spectrum
	  if($doeventmode){
	    system "seextrct infile=$cb_data[$i] gtiorfile=APPLY gtiandfile=cur.gti outroot=$root_cbpha timecol=TIME columns=Event binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> seextrct.dbg";
	  }
	  else{
	    system "saextrct infile=$cb_data[$i] gtiorfile=APPLY gtiandfile=cur.gti outroot=$root_cbpha accumulate=one timecol=TIME columns='XeCnt' binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> saextrct.dbg ";
	  }


	if($dobkg && $dobkgmodel){

	  $root_cbbkg="$outputdirs[$i]/${root}_${burstN}_${k}_bkg";

	  print "Running seextrct for bkg!\n";   
	  system "saextrct infile=\@$bkglist gtiorfile=APPLY gtiandfile=cur.gti outroot=$root_cbbkg accumulate=one timecol=TIME columns='GOOD' binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";

#  >> saextrct.dbg

	  print "Running rbnpha!\n";
	  system "rbnpha binfile=cb_chan.txt ${root_cbbkg}.pha ${root_cbbkg}_64ch.pha clobber=true";
	  print "Running fparkey!\n";

    #XXX: momentarily write 16s to backfile cos simulated bkg is not working
#	  system "fparkey ${root_cbbkg}_64ch.pha ${root_cbpha}.pha backfile";
      system "fparkey ${raw_bkg}_64ch.pha ${root_cbpha}.pha backfile";


	}
	else{
	  #Writing information into pha's header
	  if($dobkg){
	    system "fparkey ${raw_bkg}_64ch.pha ${root_cbpha}.pha backfile";
	  }

	  if($dobkgmodel){

	  $root_cbbkg="$outputdirs[$i]/${root}_${burstN}_${k}_bkg";

	    print "Running saextrct for model background!\n";
	    system "saextrct infile=\@$bkglist gtiorfile=APPLY gtiandfile=cur.gti outroot=$root_cbbkg accumulate=one timecol=TIME columns='GOOD' binsz=INDEF printmode=spectrum lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF >> saextrct.dbg";
	    system "rbnpha binfile=cb_chan.txt ${root_cbbkg}.pha ${root_cbbkg}_64ch.pha";
	    #system "fparkey ${root_cbbkg}_64ch.pha ${root_cbpha}.pha backfile";
	    }
	}

    #if dynamic_rsp == 1 then 
    #update all the values and filterfile needed for new response
    #do new response and write it to header
    # else write common rsp to header system "fparkey $cb_rsp ${root_cbpha}.pha respfile";

    if($dynamic_rsp){

        print "\n*** Making dynamic response ***\n";

        # Checking which PCUs are operational
        $l=0;
        @dpcus = ();
        # This variable will be a string that is used to tell
        # saextrct and pcarsp which PCUs were on
        # F.E. if PCUs 0,2,3 were on it would have value "0,2,3"
        $which_pcus_on="";
        while($l <= 4){
            system "fstatistic infile=${filterfile}_dflt colname='PCU${l}_ON' rows='-'";
          	$tmp = `pget fstatistic mean`;
        	if ($tmp == 1) {push @dpcus, $l;}
    	    $l++
        }
        print "During our time interval, PCUs were on: @dpcus\n";

        #name new response similar to original spectrum file
    	$dcb_rsp="$outputdirs[$i]/${root}_${burstN}_${k}.rsp";

    	$pcus=""; foreach $pcu (@dpcus) {$pcus.="$pcu,"};$/=",";chomp($pcus);

#    	$layers=""; foreach $layer (@layers) {$layers.="LR$layer,"};chomp($layers);
    	print "\npcus=$pcus"; print "\nlayers=$layers\n";
	    system "pset pcarmf nofits=0";
	    open(DRSPPAR, "> dpcarsp.par");
	    print DRSPPAR "${root_cbpha}.pha\n${filterfile}\n$layers\ny\n$pcus\ny\ny\n";
	    close DRSPPAR;

	    #Making responses to offset if ra and dec given
	    if($r_ascension eq 0 && $declination eq 0){
	        system "pcarsp -n $dcb_rsp < dpcarsp.par";
	    } else{
	        print "\npcarsp -n $dcb_rsp -x $r_ascension -y $declination < dpcarsp.par \n";
	        system "pcarsp -n $dcb_rsp -x $r_ascension -y $declination < dpcarsp.par";
	    }


    	system "fparkey $dcb_rsp ${root_cbpha}.pha respfile";
    }else{
        system "fparkey $cb_rsp ${root_cbpha}.pha respfile";
    }


    #Making list of the response files and starting and ending times
    open(PHAINPUT, ">>", "$workdir/$outputdirs[$i]/pcu_list.txt");
    print PHAINPUT "${root_cbpha}.pha $t1 $t2 $pcus\n";
    close(PHAINPUT);


	print "Running fparkey again!\n";
	system "fparkey $t1 ${root_cbpha}.pha+1 tstart";
	system "fparkey $t2 ${root_cbpha}.pha+1 tstop";
	#system "fparkey $cb_rsp ${root_cbpha}.pha respfile";

	print "Running deadtime corr!\n";
	  # Deadtime correction for the CB data file
	  if($dodt){
		deadtime_corr("${root_cbpha}.pha",$std1_data[$i],"cur.gti");
	  } 

    	  $k++;
	} else {
	  print "$naxis2 rows in GTI file\n";
	}

    	$t1=sprintf("%.12E",$t1+$cbmode_Tres);
    	if($t2>=$tstop[$j]&&$j<$ngtis){
	  $j=$j+1;
	  $t1=$tstart[$j];
    	}
  }
	
$i++;
}

# END: Making the light curves
##################################################################

############### Clean up unnesessary files

#system "rm -f *.list";
#system "rm -f *.col";
#system "rm -f *.gti";
#system "rm -f *.par";
#system "rm -f pcadtspec.dt";
#system "rm -f *_bkg";
#system "rm -f xspec_log.tmp";
#system "rm -f xcm.tmp";

#===== finished
print "FINISHED\n";


##################################################################
# BEGIN: Correct for the deadtime 

sub deadtime_corr
{
  my($pha,$std1,$gti) = @_;

  #++++++++++++++++++++++ This part is my own correction for the deadtime
  #+++++++++++++++++++++++according to Cook Book receipt++++++++++++++++++++++++++


  print "\nStarting to calculate the deadtime correction\n"; 

  # We do not do activation...
  my $do_ac=0;

  my $fdump_str;
  my @col;
  my $cnts_back_gx=0;
  my $cnts_back_rmvp=0;
  my $cnts_vle=0;
  my $cnts_src_gx=0;
  my $dtback;
  my $dtsrc;
  my $tmpexp;
  my $pha_1;
  my $fkeyprint_s;
  my $exp_str;
  my $new_exp_for_bkg;
  my $new_exp_for_src;
  my $bkgmodel_ac0;
  my $bkgmodel_ac1;
  my $fparkey_s;

  my $bkgcnts_gx="DUMP_gx";
  my $bkgcnts_gx_lc="$bkgcnts_gx.lc+1";
  my $bkgcnts_rmvp="DUMP_Rm_Vp";
  my $bkgcnts_rmvp_lc="$bkgcnts_rmvp.lc+1";
  my $src_gx="DUMP_src_gx";
  my $src_gx_lc="$src_gx.lc+1";
  my $vle_rate="DUMP_vle";
  my $vle_rate_lc="$vle_rate.lc+1";
  my $num_pcu="DUMP_num";
  my $num_pcu_lc="$num_pcu.lc+1";
  my $lcbinsz="1000000";

  ########### Extraction Remaining cnts and Propane cnts from STD1list files


  my $saextrct_std2_backRmnVp_for_dt="saextrct infile='$std1' gtiorfile=APPLY gtiandfile=$gti outroot=$bkgcnts_rmvp accumulate=one timecol=TIME columns='RemainingCnt VpCnt' binsz=$lcbinsz printmode=LIGHTCURVE lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";
  system "$saextrct_std2_backRmnVp_for_dt";

  ############# Extraction SRC Good Xenon events from the STD1list files

  my $saextrct_std2_src_gx="saextrct infile='$std1' gtiorfile=APPLY gtiandfile=$gti outroot=$src_gx  accumulate=one timecol=TIME columns='XeCntPcu0 XeCntPcu1 XeCntPcu2 XeCntPcu3 XeCntPcu4' binsz=$lcbinsz printmode=LIGHTCURVE lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";
  system "$saextrct_std2_src_gx";

  ############# Extraction VLE rate from the STD1list files

  my $saextrct_std1_vle="saextrct infile='$std1' gtiorfile=APPLY gtiandfile=$gti outroot=$vle_rate accumulate=one timecol=TIME columns='VLECnt' binsz=$lcbinsz printmode=LIGHTCURVE lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=INDEF chmax=INDEF chint=INDEF chbin=INDEF";
  system "$saextrct_std1_vle";

  ############ Output RmnCnts and Propane cnts to  file

  $fdump_str = "fdump infile='$bkgcnts_rmvp_lc' outfile='$bkgcnts_rmvp' ";
  $fdump_str .= "columns='RATE' rows='-' clobber='no' prhead='no' ";
  $fdump_str .= "showcol='no' showunit='no' ";

  system "$fdump_str";

  ############ Output VLE cnts to  file

  $fdump_str = "fdump infile='$vle_rate_lc' outfile='$vle_rate' ";
  $fdump_str .= "columns='RATE' rows='-' clobber='no' prhead='no' ";
  $fdump_str .= "showcol='no' showunit='no' ";

  system "$fdump_str";

  ############ Output SRC good xenon rate to file

  $fdump_str = "fdump infile='$src_gx_lc' outfile='$src_gx' ";
  $fdump_str .= "columns='RATE' rows='-' clobber='no' prhead='no' ";
  $fdump_str .= "showcol='no' showunit='no' ";

  system "$fdump_str";

  ################ Ready to get the Remaining Cnts and Propane rate
  if(-e $bkgcnts_rmvp){
  open(F1,$bkgcnts_rmvp) || die "Can't open $bkgcnts_rmvp";
  while(<F1>){
	if(/\s*\S*\s*(\S+)\s*/){$cnts_back_rmvp=$1}
  }
  print "RmVp $cnts_back_rmvp\n";
  close(F1);    
  }
  ################ Ready to get the VLE cnts from file
  if(-e $vle_rate){
  open(F1,$vle_rate) || die "Can't open $vle_rate";
  while(<F1>){
	if(/\s*\S*\s*(\S+)\s*/){$cnts_vle=$1}
  }
  print "VLE $cnts_vle\n";
  close(F1);   
  }
  ################ Ready to get the src gx cnts from file
  if(-e $src_gx){
  open(F1,$src_gx) || die "Can't open $src_gx";
  while(<F1>){
	if(/\s*\S*\s*(\S+)\s*/){$cnts_src_gx=$1}
  }
  print "SRC_gx $cnts_src_gx\n";
  close(F1);    
  }

  # Calculate number of operational PCUs
  print "Calculating number of operational PCUs\n";
  system "fltime infile=$filterfile gtifile=$gti outfile=${filterfile}_dt_flt clobber=yes"; 

  system "fstatistic infile=${filterfile}_dt_flt colname='num_pcu_on' rows='-'";
  $num_pcu_on=`pget fstatistic mean`;


  ################# Calculation of the DTcorr.
  $dtsrc=1e-5*($cnts_src_gx+$cnts_back_rmvp)+1.5e-4*$cnts_vle;
  if($dtsrc ne 0. && !($num_pcu_on == 0.)){
  print "dtsrc=$dtsrc\n";
  print "N_on=$num_pcu_on\n";
  $dtsrc=$dtsrc/$num_pcu_on;


  print "dtsrc/N_on=$dtsrc\n";

  ################### Extracting the exposure value from the pha file

  $tmpexp="DUMP_EXPOSURE";
  $pha_1="$pha+1";

  $fkeyprint_s = "ftlist $pha_1 K >$tmpexp";

  system "$fkeyprint_s";

  open(F2,$tmpexp) || die "Can't open $tmpexp ! \n";

  while(<F2>){
    if($_ =~ /EXPOSURE\=\s*(\S+)\s*/){$exp_str = $1}
  }
  close(F2);
  $exp_str=$exp_str*1.0;
  $new_exp_for_src=(1.0-$dtsrc)*$exp_str;

  print "Old source  exposure $exp_str, newexposure=$new_exp_for_src\n";

  ############### This part was designed especially for separate using
  ############### activation and X-ray parts of the background
  if ($do_ac){

	print "\n\n Will model BKG without activation now ...\n\n";
	open(BKGPAR, "> runpcabackest.par");
	print BKGPAR "\@$std2list\n$bkglist\nbkg\n$filterfile\n$bkgmodel_ac0\n16\nyes\nno\nno\n$saahfile\nno"; 
	close BKGPAR;
	system "runpcabackest < runpcabackest.par";

	print "\n\n Will extract BKG_AC0 pha and lc now ...\n\n";
	system "saextrct infile=\@$bkglist gtiorfile=APPLY gtiandfile=$gti outroot=$rootbkg_ac0 accumulate=one timecol=TIME columns=\@$collist binsz=$lcbinsz printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";

	print "\n\n Will model BKG activation now ...\n\n";
	open(BKGPAR, "> runpcabackest.par");
	print BKGPAR "\@$std2list\n$bkglist\nbkg\n$filterfile\n$bkgmodel_ac1\n16\nyes\nno\nno\n$saahfile\nno"; 
	close BKGPAR;
	system "runpcabackest < runpcabackest.par";

	print "\n\n Will extract BKG_AC1 pha and lc now ...\n\n";
	system "saextrct infile=\@$bkglist gtiorfile=APPLY gtiandfile=$gti outroot=$rootbkg_ac1 accumulate=one timecol=TIME columns=\@$collist binsz=$lcbinsz printmode=BOTH lcmode=RATE spmode=SUM timemin=INDEF timemax=INDEF timeint=INDEF chmin=$chmin chmax=$chmax chint=INDEF chbin=INDEF";


  }

  ################# Changing and adding the KEYWORDS to SRC file

  system "fparkey value=$new_exp_for_src fitsfile=$pha+1 keyword='EXPOSURE' add=no comm='Uncorrected value was $exp_str\'";

  }
  else{
    print"WARNING: No dtcorr was made due to lack of data (propably std1)\n";
    if(-e "no_dtcorr.list"){
    open(DTCORR, ">> no_dtcorr.list");
    print DTCORR "$pha\n"; 
    close DTCORR;
    }
    else{
      open(DTCORR, "> no_dtcorr.list");
      print DTCORR "$pha\n"; 
      close DTCORR; 
      }
    }

  if ($do_ac) {


	$fparkey_s="fparkey value='T' fitsfile='${rootbkg_ac0}.pha' keyword='DEADAPP' add=yes";

	print "$fparkey_s\n";
	system "$fparkey_s";

	$fparkey_s="fparkey value='T' fitsfile='${rootbkg_ac1}.pha' keyword='DEADAPP' add=yes";

	print "$fparkey_s\n";
	system "$fparkey_s";

  }
  #################### Cleaning the DUMP files

  system "rm -f DUMP*";

}
# END: Correct for the deadtime
##################################################################




