#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use List::Util qw(sum);

# This program is designed to determine errors for best
# fitting parameters obtained in XSPEC

# The idea is to first fit the data by hand, and then
# save the results using XSPEC command
# 		save all xxx.xcm

# This program then computes the errors of the best fitting
# parameters and saves the computations into a 
#	output.log
# file. 
# Another program then reads this file, and produces a latex
# table of the results.

# The code works in the following way
#	1) 	The best fitting model is read in using the command
#		@xxx.xcm

#	2)	Then the user input parameters are read in
#	modcomp	:		The number of model components
#		example	:	phabs*(bbodyrad+powerlaw) => 3
#	modpars	:		The amound of model parameters PER MODEL
#					COMPONENT
#		example	:	phabs*(bbodyrad+powerlaw) => 1,2,2 
#	comp_parerr:	For which parameters do we compute errors 
#		example	:	phabs*(bbodyrad+powerlaw) => 1,2,3,4,5
#					(if we want errors for all paramters)
#	comp_fluxerr:	For which model component do we compute errors 
#		example	:	phabs*(bbodyrad+powerlaw) => 0,2,3
#					(if we want flux errors for all model components)
#					"0" stands for absorbed flux error, (XSPEC flux command)
#	init_flux:		Initial guesses for model component fluxes IN LOG10 UNITS.
#					This goes into XSPEC CFLUX model initial parameters. 
#					IT IS CRUCIAL THAT THIS ESTIMATE IS CLOSE THE CORRECT VALUE.
#					Because if it is not, the results can be wrong.
#	flux_band:		Pair of min and max energy values over which the flux errors
#					are computed.
#		example	:	phabs*(bbodyrad+powerlaw) model, and @comp_fluxerr = 0,2,3
#					we want to compute flux errors over 0.3-10 keV for absorbed
#					model, 0.01-100 keV for bbody component and 2-10 keV flux
#					for the powerlaw.
#					=> @flux_band = 0.3,10.,0.01,100.,2.,10.
#	ext_ene:		If we are computing model component fluxes beyond the 
#					energy ranges of the instruments, then we need to make dummy
#					responses (XSPEC energies extend command!). 
#					Using the same scenario as for @flux_band, and
#					assuming we used XMM-Newton data in the fitting (~0.2-12 keV)
#		example	:	@ext_ene = no,no,low,high,no,no
#       skip:			If for any reason, one computes the flux over convolved or multiplied
#                               	paramter (like cflux*refl*po or cflux*wabs*po, the code did not work).
#                               	Therefore, I added this skip parameter, which skips the multiplicative
#                               	component, and then correctly freezes the normalization of the additive
#                               	model.
#		example	:	Imagine a model constant*wabs(bbody+refl*po)
#   					In order to compute the flux of bbody and po refl*po components we make
#					@comp_fluxerr = 3,4 and @skip = 0,1 
#					(@skip = 0,0 would not work because the code would try to freeze the
#					last parameter of refl, instead the po normalization.
#	datafolder:		Data folder where the spectral data, and best fitting
#					xxx.xcm file is. If no parameter given, then
#					the datafolder is the directory where the script was ran.
#	outdir:			Output is directed here. If no parameter given, then
#					the output goes into $datafolder directory
#	outname:		Name of the output log file
#	instrus:		How many instrument were fitted together?
#		example	:	If we fitted XMM EPIC pn, mos1 and mos2 together => 3
#	confidence:		Error sigma (or delta chi2 for error search)
#		example	:	1 sigma => 1. , 90% conf. => 2.706, 3 sigma => 9.
#	maxchi:			If your original fit was bad so that red.chi^2 > 2
#					this control parameter allows to change the limit.
#					Just set it above the red chi^2 value from your original
#					fit, but note that the error most likely is meaningless.

#	3)	The script makes consistency checks, and then writes an
#		XSPEC "commands file" based on the user input

#	4)	The XSPEC commands file is executed.
#			=> output is writted into outname.log file



# REMEMBER IF YOU USED CONSTANT PARAMETER TO RENORMALIZE IN THE FITTING,
# THEN YOU NEED TO GIVE THOSE PARAMETERS IN @comp_parerr



######################################################################
# Setting up variables

my ($xspecfit,$modcomp,$datafolder,$outdir,$outname,$instrus);
my (@modpars,@comp_parerr,@comp_fluxerr,@skip,@init_flux,@freeze_params);
my (@init_flux_guess,@flux_band,@ext_ene);
my ($confidence,$maxchi);

my ($sumpar,$value);
my ($error_expr,$conf_percent,$absmodel_min,$absmodel_max);

my (@flux_band_min,@flux_band_max,@ext_ene_min,@ext_ene_max,@absmodel_limits);

my ($i,$j,$k,$skip_num,$sumpar4cflux1,$sumpar4cflux2,$sumpar4cflux3,$absmodel);

######################################################################
# Setting up defaults, note that getopts will change these...

$confidence = 2.706;
$maxchi=2.;
# Setting up datafolder as the folder where the script was run...
chomp($datafolder = `pwd`);

######################################################################
# Getting user defined inputs using GetOptions Perl module

GetOptions("xspecfit=s" => \$xspecfit,
		   "modcomp=i" => \$modcomp,
		   "modpar=i{,}" => \@modpars,
		   "comp_parerr=i{3,}" => \@comp_parerr,
		   "comp_fluxerr:i{,}" => \@comp_fluxerr,
		   "skip:i{,}" => \@skip,
   		   "init_flux_guess:f{,}" => \@init_flux_guess,
   		   #"init_flux:f{,}" => \@init_flux,
   		   "flux_band:f{,}" => \@flux_band,
   		   "extend_energies:s{,}" => \@ext_ene,
		   "datafolder=s" => \$datafolder,
		   "outdir:s" => \$outdir,
		   "outname=s" => \$outname,
		   "instruments:i" => \$instrus,
		   "confidence:f" => \$confidence,
		   "maxchi:f" => \$maxchi,
		   "absmodel:s" => \$absmodel,
		   #"absmodel_limits:s" => \@absmodel_limits
	       );

@absmodel_limits = (0.025, 2.5);
#$confidence = 1.0;

# Lets allow two formats for all arrays:
#	1) comma separated, or
#	2) space separated

print "comp_parerr is: @comp_parerr\n";

@modpars = split(/,/,join(',',@modpars));
@comp_parerr = split(/,/,join(',',@comp_parerr));
@comp_fluxerr = split(/,/,join(',',@comp_fluxerr));
@init_flux = split(/,/,join(',',@init_flux));
@flux_band = split(/,/,join(',',@flux_band));
@ext_ene = split(/,/,join(',',@ext_ene));
@absmodel_limits = split(/,/,join(',',@absmodel_limits));

$sumpar = sum @modpars;

######################################################################
# Making consistency checks...

unless(defined($xspecfit)){
  die "Error: xspecfit parameter is not specified: $!";
}

unless(defined($modcomp)){
  die "Error: modcomp parameter is not specified: $!";
}

unless(@modpars){
  die "Error: modpar parameter is not specified: $!";
}

unless(@comp_parerr){
  die "Error: comp_parerr parameter is not specified: $!";
}

print "comp_parerr is: @comp_parerr\n";

unless(@skip){
  die "Error: skip parameter is not specified: $!";
}

unless(defined($outname)){
  die "Error: outname parameter is not specified: $!";
}


# Checking that the datafolder exists.
unless(-e "$datafolder"){
  die "Error: data folder $datafolder does not exist: $!";
}

# Going to the place where the data is...
chdir "$datafolder";

# Checking if the output folder exists.
# If not, then we make one...
if (defined($outdir)){
  unless(-e "$outdir"){
	mkdir "$outdir", 0755 or die "cannot make $outdir directory: $!";
  }
} else {
  # If output folder not given, then we put the output to $datafolder
  $outdir = $datafolder;
}

if (@ext_ene){
  foreach(@ext_ene){
	unless(/yes | no/x){
	  die "Error: extend_energies parameter can only have values: yes / no: $!";
	}
  }
}

unless(-e "$datafolder/$xspecfit"){
  die "Error: input file $datafolder/$xspecfit does not exist: $!";
}

# If the user accidentally gives more parameters for error computations than
# there is actual model parameters, we die...
if ($#comp_parerr+1 > $sumpar){
  die "Error: You gave more parameters for computing errors\nthan you gave model parameters\ncomp_parerr > modpar: $!";
}

if ($#init_flux_guess != $#comp_fluxerr){
  die "Error: The number of init_flux_guesses is not the same comp_fluxerrs.\n
       If the first value of comp_fluxerr==0 (to compute absorbed flux error),\n
       then set the first value of init_flux_guess=0\n $!";
}

if (@absmodel_limits){
  #unless ($#absmodel_limits==2){die "How many absmodel_limits are you giving??\n"};
  $absmodel_min = $absmodel_limits[0];
  $absmodel_max = $absmodel_limits[1];
}

# Standard errors are 68.3% ("one sigma"), 90% ("typical X-ray"), or 99.7% ("three sigma") confidence intervals.
# These correspond to delta chi^2: 1., 2.706, 9.
# We force the code to use these values!

unless($confidence == 1. or $confidence == 2.706 or $confidence == 9.){
  die "Error: only confidence values 1. 2.706 or 9. accepted.\n They correspond to 68.3% (1sigma), 90% and 99.7% (3sigma).";
}
if($confidence == 1.){$conf_percent = 68.3};
if($confidence == 2.706){$conf_percent = 90.};
if($confidence == 9.){$conf_percent = 99.7};


######################################################################
# Making expressions that are used in the XSPEC computations...

# Expression used for error computations
$error_expr = "error maximum $maxchi $confidence";

# Making the expressions for adding the cflux component


#foreach(@modpars){print};

# debugging stuff...
print "xspecfit is: $xspecfit\n";
print "modcomp is: $modcomp\n";
print "modpar is: @modpars\n";
print "comp_parerr is: @comp_parerr\n";
print "comp_fluxerr is: @comp_fluxerr\n";
print "init_flux_guess is: @init_flux_guess\n";
print "flux_band is: @flux_band\n";
print "extend_energies is: @ext_ene\n";
print "outdir is: $outdir\n";
print "outname is: $outname\n";
print "instruments is: $instrus\n";
print "confidence is: $confidence\n";
print "maxchi is: $maxchi\n";





for($i=0 ; $i <= $#flux_band; $i++){

  if ($i%2) {
	#print "$i is odd\n";
	push @flux_band_max,$flux_band[$i];
	push @ext_ene_max,$ext_ene[$i];

  } else {
	#print "$i is even\n";
	push @flux_band_min,$flux_band[$i];
	push @ext_ene_min,$ext_ene[$i];

  } 

}

print "flux_band_min is: @flux_band_min\n";
print "flux_band_max is: @flux_band_max\n";

print "ext_ene_min is: @ext_ene_min\n";
print "ext_ene_max is: @ext_ene_max\n";

#die;

##################################################
#Making an input file for Xspec primary fitting

if ( ! open XSINPUT, ">", "$outdir/${outname}_commands.xcm") {
  die "Cannot open $outdir/${outname}_commands.xcm for output: $!";
}

# Loading the best fit results, open output log, show all results
# and compute parameter errors.
print XSINPUT "\@${xspecfit}\n";
print XSINPUT "log $outdir/$outname \n";
print XSINPUT "chatter 5 10\n";
print XSINPUT "query yes\n";
print XSINPUT "show all\n";
print XSINPUT "fit 100 1e-2\n";
print XSINPUT "fit 100 1e-2\n";
print XSINPUT "fit 100 1e-2\n";
print XSINPUT "fit 100 1e-2\n";
print XSINPUT "fit 100 1e-2\n";
print XSINPUT "$error_expr @comp_parerr\n";

# Doing the flux error computations for all the model components
# determined by the user.

$j=0;
$k=0;

$skip_num=0;
foreach(@comp_fluxerr){
  $k = $_;
  $skip_num = $skip[$j];
  print "skip number is: ".$skip_num."\n";
  
  @freeze_params = @comp_parerr;
  #for($l=0 ; $l <= $#freeze_params; $l++){
  #  if ($freeze_params[$l] > sum @modpars[0 .. $k]){
    
  #  }
  #}
  
  # Summing the parameter before and after the
  # model component we want to compute the flux over.
  # Like this, we know which parameter number
  # cflux flux is, and also we know which parameter
  # the model component normalization is.
  # We need to freeze is to compute the flux in cflux...


  # If error is computed over the absorbed model
  # then we do it using the flux command
  if ($k == 0){

	# If model component flux is computed beyond the energy band the of the instrument
	# response, then we need to extend the energy band (standard 200 bins in log intervals). 
	if ($ext_ene_min[$j] eq "yes"){print XSINPUT "energies extend low $flux_band_min[$j]\n"};
	if ($ext_ene_max[$j] eq "yes"){print XSINPUT "energies extend high $flux_band_max[$j]\n"};

	print XSINPUT "fit 100 1e-2\n";
	print XSINPUT "flux $flux_band_min[$j] $flux_band_max[$j] err 1000 $conf_percent\n";
	
  } else {
	$sumpar4cflux1 = sum 3,@modpars[0 .. $k-2];
	$sumpar4cflux2 = sum 3,@modpars[0 .. $k-1+$skip_num];
	$sumpar4cflux3 = sum @modpars[0 .. $k-2];

	# ...
	@freeze_params = @comp_parerr;
	my $l=0;
	foreach $value (@freeze_params){
	  if ($value > $sumpar4cflux3){
	    $freeze_params[$l] = $value +3;
	  }
	  $l++;
	}
	
	# If model component flux is computed beyond the energy band the of the instrument
	# response, then we need to extend the energy band (standard 200 bins in log intervals). 
	if ($ext_ene_min[$j] eq "yes"){print XSINPUT "energies extend low $flux_band_min[$j]\n"};
	if ($ext_ene_max[$j] eq "yes"){print XSINPUT "energies extend high $flux_band_max[$j]\n"};

	# Adding the cflux convolution model
	if (@absmodel_limits){
	 if ($k == 2){
	  print XSINPUT "addcomp 1 $absmodel & 0.1 0.01 $absmodel_min $absmodel_min $absmodel_max $absmodel_max\n";
  	  #print XSINPUT "addcomp 1 $absmodel &=2 0.01 $absmodel_min $absmodel_min $absmodel_max $absmodel_max\n";
         }
	}
	print XSINPUT "addcomp $comp_fluxerr[$j] cflux\n";
	print XSINPUT "$flux_band_min[$j] -1\n";
	print XSINPUT "$flux_band_max[$j] -1\n";
	print XSINPUT "$init_flux_guess[$j] 0.05\n";
	if (@absmodel_limits){
	 if ($k == 2){
	  print XSINPUT "delcomp 3\n";
	 }
	} 
	print XSINPUT "freeze @freeze_params\n";
	print XSINPUT "query no\n";
	print XSINPUT "fit 3\n";
	print XSINPUT "query yes\n";
	print XSINPUT "thaw @freeze_params\n";
	
	if (defined($instrus)){
	  # If many instruments were used, and therefore many data groups
	  # we need to put the cflux parameters the same for all the 
	  # instruments (or data groups)...
	  for ($i=1 ; $i <= $instrus -1; $i++){print XSINPUT "\n\n\n";};
	}

	print XSINPUT "freeze $sumpar4cflux2\n";
	print XSINPUT "fit 100 1e-2\n";
	print XSINPUT "$error_expr $sumpar4cflux1\n";
	print XSINPUT "\@${xspecfit}\n";

  }

  $j++;

}

print XSINPUT "log none\n";
print XSINPUT "exit\n";
print XSINPUT "\n";



close XSINPUT;

# Xspec fitting
my $command="xspec - $outdir/${outname}_commands";
print "$command\n";
system($command);



