#!/usr/bin/perl -w
#Perl script for fitting blackbody model into spectrums in Xspec and reading parameters into file
#This code supports 16s bkg spectra before burst and uses it as a background (instead of 160s preburst spectrum)

#Used model is tbabs*bbodyrad
#instead of getting tbabs value from fitting, pre-determined constant value is used 


use strict;
use Getopt::Long;

my $model;
my $cstat=0;
my $churazov=0;
my $systematic=1;
my $do_round_bin=1;
my $do_mainf_cp=0; #copy .dat files to main dir  for further analysis in IDl

#Defining some variables
my ($datafile, $fit_id, $object, $fkeyprint, $preburst, $inputfile, $outdir,$outdir2, $bnumber);
my ($pre_par, $pre_par_read, $line);
my (@data, @warnings, @phabs);
my ($bolcflux_min, $bolcflux_max);
my ($cflux_old,$bolcflux_old);
my ($used_model, $exposure, $countrate, $countrate_error, $time, $phabs_sum);
my ($phabs, $tbb, $tbb_norm, $cflux, $bolcflux); #value variables
my ($phabs_min, $phabs_max, $tbb_min, $tbb_max, $tbb_err, 
$norm_min, $norm_max, $norm_err, $flux_min, $flux_max, $flux_err, $bolcflux_err); #error variables
my ($chisq, $dof, $prob);
my (@errors);
my ($fluxread, $bolfluxread);

print "\n";


GetOptions("inputfile=s" => \$inputfile,
		   "outdir=s" => \$outdir,
		   "outdir2=s" => \$outdir2,
		   "model=s" => \$model,
           "phabs=s" => \$phabs
	       );

unless ($model) {
  $model="bb";
}

unless ($outdir) {
  $outdir="BXX/fit";
}

unless ($outdir2) {
  $outdir="BXX/analysis";
}


unless(-e $outdir){
  mkdir $outdir, 0755 or die "cant make ${outdir} folder. Create such folder for output!\n";
}

unless(-e $outdir2){
  mkdir $outdir2, 0755 or die "cant make ${outdir2} folder. Create such folder for output!\n";
}

unless($phabs) {
    die "phabs value not defined";
}


#Reading the burst number from outputfile it it's defined
$bnumber="";
if($outdir =~ /\S+(\d\d\d*)/){$bnumber="B${1}_";}


######################################################################################################################

unless(-e $inputfile){
  die "Input file $inputfile does not exist!\n";
}

#if (-e "${outdir2}/${object}_${bnumber}${model}fit_fabs.dat") {
#}


# Now we start to loop over all the input files we want to fit...

if ( ! open INPUT1, "<", $inputfile) {
	die "Cannot open Input file $inputfile for reading: $!";
}	

	$tbb=1;
	$tbb_norm=200;
	$cflux_old=-8.5;
	$bolcflux_old=-8.5;

while (defined($datafile = <INPUT1>)){


	$time=0;
	$exposure=0;
	$countrate=0;
	$countrate_error=0;
#	$phabs=0;
	$phabs_min=0;
	$phabs_max=0;
#	$tbb=0;
	$tbb_min=0;
	$tbb_max=0;
#	$tbb_norm=0;
	$norm_min=0;
	$norm_max=0;
	$chisq=0;
	$dof=0;
	$prob=0;
	$cflux=0;
	$bolcflux=0;
	$bolcflux_min=0;
	$bolcflux_max=0;
	@errors= ();
	$fluxread="false";
	$bolfluxread="false";

if($tbb < 0.01 or $tbb > 3.5){
  $tbb=1.5;
}
if($tbb_norm < 1 or $tbb_norm > 10000){
  $tbb_norm=500;
}

if($bolcflux_old > -6){
  $bolcflux_old=-8;
}
if($bolcflux_old < -12){
  $bolcflux_old=-8;
}

# Getting identification of the file	
	chomp($datafile);
	print "File is:$datafile\n";

	if ( $datafile =~ m%[\d\D]*/([\d\D]+)_([\d\D]+_[\d]+)[._][\d\D]+%) {
		$object = $1 ;
		$fit_id = $2 ;
	}  else {die "Error: fit_id not found!!!\n"};
	print "Object name is:" . $object . "\n";
	print "fit_id is:" . $fit_id . "\n\n";

##################################################
#Making an input file for Xspec primary fitting

	if(! open XSINPUT2, ">", "${outdir}/${object}_${fit_id}_${model}_fitcommands_fabs.xcm") {
		die "Cannot open ${outdir}/${object}_${fit_id}_${model}_fitcommands_fabs.xcm for output: $!";}
	{
	#if output to file then Xspec logfile is created
	print XSINPUT2 "log ${outdir}/${object}_${fit_id}_${model}fit_fabs \n";

	#Foreach loop for setting up datafiles for Xspec
	print XSINPUT2 "data $datafile\n";

	print XSINPUT2 "cpd ${outdir}/${object}_${fit_id}_${model}fit.ps/cps\n";

	print XSINPUT2 "setplot energy\n";
	if($cstat){
	print XSINPUT2 "statistic cstat\n";
	}

    if($churazov){
	print XSINPUT2 "weight churazov\n";    
    }else{
	print XSINPUT2 "ignore bad\n";
	}
	if($systematic){
	print XSINPUT2 "systematic 0.005\n";
	}

	#Fitting only channels XX-YY
	print XSINPUT2 "ignore **-2.5 25.-**\n";

	print XSINPUT2 "mo tbabs*bbodyrad\n";
	print XSINPUT2 "$phabs\n"; #nH absorption
	print XSINPUT2 "$tbb\n";	#bbodyrad keV 
	print XSINPUT2 "$tbb_norm\n";	#bbodyrad normalization

	print XSINPUT2 "freeze 1\n";

	print XSINPUT2 "query yes\n";
	print XSINPUT2 "fit 100 1e-3\n";	
	print XSINPUT2 "fit 100 1e-3\n";	
	print XSINPUT2 "fit 100 1e-3\n";	
	print XSINPUT2 "fit 100 1e-3\n";	

	print XSINPUT2 "pl lda\n";
	print XSINPUT2 "pl euf ratio\n";
  
	#Getting errors for parameters
#	print XSINPUT2 "error maximum 10 1. 1\n";	#phabs
	print XSINPUT2 "error maximum 100 1. 2\n";	#tbb
	print XSINPUT2 "error maximum 100 1. 3\n";	#normalization

	#Determining the bolometric flux & error
	print XSINPUT2 "freeze 3\n";
	print XSINPUT2 "energies extend low 0.01\n";
	print XSINPUT2 "energies extend high 200.\n";
	print XSINPUT2 "addcomp 2 cflux\n";
	print XSINPUT2 "0.01\n"; #low E
	print XSINPUT2 "200.\n"; #High E
	print XSINPUT2 "$bolcflux_old\n"; #cflux
	print XSINPUT2 "fit\n";
	print XSINPUT2 "fit\n";
	print XSINPUT2 "fit 100 1e-3\n";
	print XSINPUT2 "fit 100 1e-3\n";
	print XSINPUT2 "error maximum 100 1. 4\n";

	#Getting the raw flux
	print XSINPUT2 "newpar 2 2.5\n";
	print XSINPUT2 "newpar 3 25\n";
	print XSINPUT2 "fit\n";
	print XSINPUT2 "fit\n";
	print XSINPUT2 "fit 100 1e-3\n";
	print XSINPUT2 "fit 100 1e-3\n";
	#exiting
	print XSINPUT2 "exit\n";



}#if XSINPUT
close(XSINPUT2);


#Cheking XSPEC input file xspec_errorcommands.xcm
if ( ! open XSINPUTCHECK2, "<", "${outdir}/${object}_${fit_id}_${model}_fitcommands_fabs.xcm") {
	die "Cannot open ${outdir}/${object}_${fit_id}_${model}_fitcommands_fabs.xcm for reading: $!";
}	
close XSINPUTCHECK2;

#Xspec fitting for bbody*********************************************************************************

my $command="xspec - ${outdir}/${object}_${fit_id}_${model}_fitcommands_fabs.xcm";
system($command);

#Reading parameter values and error values*****************************

if(! open XSLOG2, "<", "${outdir}/${object}_${fit_id}_${model}fit_fabs") {
	die "Cannot open log ${outdir}/${object}_${fit_id}_${model}fit_fabs for reading: $!";
}

while(<XSLOG2>){	#Reading each line of log  ${outdir}/${object}_${fit_id}_${model}fit


	#Defining some help parameters for reading fluxes from right place
	if(/!XSPEC12>freeze 3/){$bolfluxread="true";}
	if(/!XSPEC12>newpar 2 2.5/){$fluxread="true";}

	#Getting exposure times
	if (/#  Exposure Time: (\d+|\d+\.?[\d\D]+?)\s/){$exposure= $1;}

	#Getting count rate and error	
	if(/#Net count rate \(cts\/s\) for Spectrum:1\s+(\S+)\s*\+\/\-\s*(\S+)\s\S+/){
        $countrate=$1; 
        $countrate_error=$2;
    }

	#Reading the used model
	if (/#(Model[\s\S]+) Source No./ && $bolfluxread eq "false")
    {	
        $used_model=$1;	
    }

	#phabs value	  4    2   phabs      nH         10^22    0.0          +/-  3.70854
#	if (/#   1\s+1\s+phabs\s+nH\s+10\^22\s*(\d+\.?[\d\D]+?)\s+[\S]+\s+(\d+.[\S]+)\s+/ && $bolfluxread eq "false")
#	{
#	    $phabs=$1;
#	    $phabs_min=$phabs-$2;
#	    if($phabs_min < 0){$phabs_min=0;}
#	    $phabs_max=$phabs_max+$2;
#	}


	#Tin value!
	if (/#   [1-9][\D\d]*bbodyrad\s+kT\s+keV\s*(\d+\.?[\d\D]+?)\s+[\S]+\s+(\d*.[\S]*)\s+/ && $bolfluxread eq "false")
	{
        $tbb=$1; 
	}

	#Tin norm 
	if (/#   [1-9][\D\d]*bbodyrad\s*norm\s*/ && $bolfluxread eq "false")
    {
		if ($'=~/\s*(-?\d+\.\d+E?-?\+?\d*\d*)\s+[\S]+\s+(\d*.[\S]*)\s+/)
		{$tbb_norm=$1;}
#		if ($tbb_norm == 0){die};
	}

	#Getting reduced chi and d.o.f.
	if(/# Reduced chi-squared =\s*(\d+\.\d+)\s*for\s*(\d+)/ && $bolfluxread eq "false" )
    {
		$chisq=$1;
		$dof=$2;
	}

	#Getting Null hypothesis probability
	if(/# Null hypothesis probability =\s*([\d\D]*)\s/ && $bolfluxread eq "false")
    {
	    $prob=$1;
	}

	#phabs errors##     1            0      0.71142    (0,0.71142)
#	if(/#\s+1\s+(\S+)\s+(\S+)\s+\((\S+),(\S+)\)/){
#	    $phabs_min=$1;
#	    $phabs_max=$2;
#	}

	#Tin errors
	if(/#\s+2\s+(\S+)\s+(\S+)\s+\((\S+),(\S+)\)/ && $bolfluxread eq "false")
    {
	    $tbb_min=$1;
	    $tbb_max=$2;
	}
	
	#Normalization errors
	if(/#\s+3\s+(\S+)\s+(\S+)\s+\((\S+),(\S+)\)/ && $bolfluxread eq "false")
    {
	    $norm_min=$1;
	    $norm_max=$2;	
	}

	#Raw flux error
#	if(/#\s+3\s+(\S+)\s+(\S+)\s+\((\S+),(\S+)\)/ && $bolfluxread eq "false"){
#	    $flux_min=$1;
#	    $flux_max=$2;
#	}

	#bolometric cflux
	if(/#   [1-9][\D\d]*cflux\s+lg10Flux\s+cgs\s*(\S+)\s+\S+\s*(\S+)/ && $fluxread eq "false")
    {
	    $bolcflux=$1;
	    $bolcflux_min=$1-$2;
	    $bolcflux_max=$1+$2;
	}

	#Bolometric flux error
	if(/#\s+4\s+(\S+)\s+(\S+)\s+\((\S+),(\S+)\)/ && $fluxread eq "false")
    {
	    $bolcflux_min=$1;
	    $bolcflux_max=$2;
	}
	
	#cflux
	if(/#   [1-9][\D\d]*cflux\s+lg10Flux\s+cgs\s*(\S+)\s+\S+(\S+)/ && $fluxread eq "true")
	{
        $cflux=$1;
	}


}#end of xslog2	
close XSLOG2;



#Reading right exposure from datafile
if($do_round_bin){
    $fkeyprint = `ftlist ${datafile}+1 K`;
    if($fkeyprint =~ /EXPOSURE=\s+\S+\s*\S\s*Uncorrected value was (\S+)/){$exposure=$1+0;}
}

#Getting the spacecraft time

#TSTART  =   4.502793894997E+08 /
$fkeyprint = `ftlist ${datafile}+1 K`;
if($fkeyprint =~ /TSTART\s*=\s*(\S+)\s/){$time=$1;}

#Converting fluxes to be in right format
#$cflux_old=$cflux;
$bolcflux_old=$bolcflux;

$cflux=(10**$cflux);
$bolcflux=(10**$bolcflux)*(10**9);
$bolcflux_min=(10**$bolcflux_min)*(10**9);
$bolcflux_max=(10**$bolcflux_max)*(10**9);

#Smallest binsize accepted
#if($exposure < 0.07){
#$phabs_min=0;
#$phabs_max=0;
#$tbb=0;
#$tbb_min=0;
#$tbb_max=0;
#$tbb_norm=0;
#$norm_min=0;
#$norm_max=0;
#$chisq=0;
#$cflux=0;
#$bolcflux=0;
#$bolcflux_min=0;
#$bolcflux_max=0;
#}

#Forcing values to be in same format
$time=sprintf("%.3f", $time);
$countrate=sprintf("%.2f", $countrate);
$countrate_error=sprintf("%.2f", $countrate_error);
$exposure=sprintf("%.4f", $exposure);
$phabs=sprintf("%.5f", $phabs);
$phabs_min=sprintf("%.5f",0);
$phabs_max=sprintf("%.5f",0);
$tbb=sprintf("%.5f", $tbb);
$tbb_min=sprintf("%.5f", $tbb_min);
$tbb_max=sprintf("%.5f", $tbb_max);
$tbb_norm=sprintf("%.3f", $tbb_norm);
$norm_min=sprintf("%.3f", $norm_min);
$norm_max=sprintf("%.3f", $norm_max);
$chisq=sprintf("%.3f", $chisq);
$cflux=sprintf("%.2e", $cflux);
$bolcflux=sprintf("%.4f", $bolcflux);
$bolcflux_min=sprintf("%.4f", $bolcflux_min);
$bolcflux_max=sprintf("%.4f", $bolcflux_max);


#6) Printing results to console and file

# File bbfit_kabs.log
# Created Mon Jan 18 12:10:33 EST 2010
# bspectra_fit_v12.perl v1.1 on host w-cl26-110-01
#
# Burst directory
#   /mnt/burst/data/1608-52/d283/burst1/analysis
# 
# PCARMF version v11.7, HEASOFT version 6.7

#if file exists then append if not then newfile with header
if (-e "${outdir2}/${object}_${bnumber}${model}fit_fabs.dat") {
	if ( ! open RESULTPRINT2, ">>", "${outdir2}/${object}_${bnumber}${model}fit_fabs.dat") {
		die "Cannot open ${outdir2}/${object}_${bnumber}${model}fit_fabs.dat for appending: $!";
	}

#new print according to fit code
	print RESULTPRINT2 "$time $countrate $countrate_error $exposure $phabs $phabs_min $phabs_max ${tbb} $tbb_min $tbb_max ${tbb_norm} $norm_min $norm_max ${chisq} ${cflux} $bolcflux $bolcflux_min $bolcflux_max\n";
	close RESULTPRINT2;
}else{
	if ( ! open RESULTPRINT2, ">", "${outdir2}/${object}_${bnumber}${model}fit_fabs.dat") {
		die "Cannot open ${outdir2}/${object}_${bnumber}${model}fit_fabs.dat for writing: $!";
	}
	print RESULTPRINT2 "#$used_model\n#\n";
	print RESULTPRINT2 "# Columns:
#	1. Time (spacecraft seconds)
#	2,3. Count rate & error (not corrected for PCUs)
#	4. Time bin size (s)
#	5,6,7. nH (frozen in bbfit_fabs.log) and min, max (both zero in
#		bbfit_fabs.log)
#	8,9,10. kT (keV) and min, max (1 sigma error)
#	11,12,13. Blackbody normalisation ((R_km/d_10kpc)^2) and min,max
#	14. Fit reduced chi^2
#	15. \"Raw\" flux value (2.5-25 keV, ergs/cm^2/s)
#	16,17,18. Estimated bolometric flux (1e-9 ergs/cm^2/s) and
#		min,max (1 sigma error)\n";

	print RESULTPRINT2 "$time $countrate $countrate_error $exposure $phabs $phabs_min $phabs_max ${tbb} $tbb_min $tbb_max ${tbb_norm} $norm_min $norm_max ${chisq} ${cflux} $bolcflux $bolcflux_min $bolcflux_max\n";
	close RESULTPRINT2;
}


} #End of loop

######################################################################################################################


if($do_mainf_cp){
    system "cp ${outdir2}/${object}_${bnumber}${model}fit_fabs.dat ${object}_${bnumber}${model}fit_fabs.dat ";
#    system "cp ${outdir2}/${object}_${bnumber}${model}fit_kabs.dat ${object}_${bnumber}${model}fit_kabs.dat ";
}

print "\n\n";

#Printing parameters into console
#system "cat ${outdir2}/${object}_${bnumber}${model}fit_kabs.dat";
system "cat ${outdir2}/${object}_${bnumber}${model}fit_fabs.dat";
