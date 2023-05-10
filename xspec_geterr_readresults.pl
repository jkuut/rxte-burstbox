#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use List::Util qw(sum);

# This program reads the output of 
# xspec_geterr.pl

# The idea is that the user gives the parameter numbers and names
# and then the program matches these input values and searches
# the xspec_geterr.pl output logfile, and prints the results
# into an output file.

######################################################################
# Setting up variables

my ($inputfile,$modcomp,$datafolder,$outdir,$outname,$instrus);
my (@modpar,@modcomp_names,@modpar_names);
my (@read_parerr,@read_fluxerr);

my (@warnings);

my ($readinfo,$readparam,$readparamerr);
my ($readflux,$readcflux,$readcflux2,$readcfluxerr);

my ($chi2,$dof,$nullP);

my (@specdata,@countrates,@parameter_expr,@parameter_values);
my ($instrument,$pn_exposure,$mos1_exposure,$mos2_exposure);

my ($modcomp2);

my ($i,$j,$k,$name);

my (@abs_errors_min,@abs_errors_max,@rel_errors_min,@rel_errors_max);
my ($absorbedflux,$absorbedflux_relerr_min,$absorbedflux_relerr_max);
my ($absorbedflux_abserr_min,$absorbedflux_abserr_max);

my (@cflux_abserr_min,@cflux_abserr_max,@cflux_relerr_min,@cflux_relerr_max);

my (@cflux_emin,@cflux_emax,@cflux_lg10flux,@cflux_flux);
my (@cflux_flux_min,@cflux_flux_max);

my (@modcomp_names_keep);

my ($sumpar, $die);

# Setting up initial values

$readinfo = "yes";
$readparam = "no";
$readparamerr = "no";
$readflux = "no"; 
$readcflux = "no";
$readcflux2 = "no";
$readcfluxerr = "no";

$die = "";

# Setting up datafolder as the folder where the script was run...
chomp($datafolder = `pwd`);

######################################################################
# Getting user defined inputs using GetOptions Perl module

GetOptions("inputlog=s" => \$inputfile,
		   "modcomp=i" => \$modcomp,
   		   "modcomp_names=s{,}" => \@modcomp_names,
		   "modpar=i{,}" => \@modpar,
		   "read_parerr=i{,}" => \@read_parerr,
		   "read_fluxerr:i{,}" => \@read_fluxerr,
		   "datafolder=s" => \$datafolder,
		   "outdir:s" => \$outdir,
		   "outname=s" => \$outname,
		   "instruments:i" => \$instrus,
	       );

@modcomp_names_keep =@modcomp_names;

# Based on the user input, we make expressions that
# are matched to find the correct lines.

# Computing how many variable parameter are per model component


$sumpar = sum @modpar;

#print "sumpar: $sumpar\n";

#$i=0;
$k=0;

for ($j=1 ; $j <= $sumpar; $j++){
  if ($j > sum @modpar[0 .. $k]) {
	$k++;
  }

  my $name = $modcomp_names[$k];
  $modcomp2 = $k+1;

  foreach(@read_parerr){
	if ($j == $_){
		#push @parameter_expr, "$j\\s+${modcomp2}\\s+${name}\\s+\\S+\\s+?\\S*?\\s*?(\\S+)\\s+[+\\/-]";
		push @parameter_expr, "$j\\s+${modcomp2}\\s+${name}\\s+\\S+\\s+?\\S*?\\s*?(\\S+)\\s+[+\\/]";

#		push @parameter_expr, "$j\\s+${modcomp2}\\s+${name}[\\d\\D]*?(\\S+)\\s+\+\/\-]";
#		push @parameter_expr, "$j\\s+${modcomp2}\\s+${name}&(\\S+)\\s+\\+\\/\\-]";
		

	}
  }

}

# Old buggy version...
#foreach(@modcomp_names){
#  my $num=$modpar[$i];
#  $name = "$_";
#  $modcomp2 = $i +1;
#   1    1   TBabs      nH         10^22    0.173189     +/-  0.0          
#   2    2   bknpower   PhoIndx1            2.97772      +/-  0.0          
#   3    2   bknpower   BreakE     keV      1.62840      +/-  0.0          
#   4    2   bknpower   PhoIndx2            2.60106      +/-  0.0          
#   5    2   bknpower   norm                9.62626E-04  +/-  0.0

#  for ($j=0 ; $j <= $num -1; $j++){
#	if ($modcomp2 == $read_parerr[${k}]){
#	push @parameter_expr, "$read_parerr[${k}]\\s+${modcomp2}\\s+${name}\\s+\\S+\\s+?\\S*?\\s*?(\\S+)\\s+[+\\/-]";
#	$k++;
#	}
#  }
  
#  $i++;
#}

print "The following expressions are used to match from the log:\n";

foreach(@parameter_expr){
  print;
  print "\n";
}

#die;


# Xspec fitting produces a log 
# Opening the log for getting the best fit parameter
# values, fluxes and errors.

if ( ! open XSLOG, "<", "${datafolder}/$inputfile") {
	die "Cannot open log ${datafolder}/$inputfile for reading: $!";
}	



while(<XSLOG>){					#Reading each line of log ${object}_${fit_id}_bbodyrad_pofit

my $line=$_;

# We read input data files in order of
# 1) $readinfo: 	info (exposure times, instruments, count rates, input data files)
# 2) $readparam: 	best fitting parameters (+chi2, d.o.f. nullP)
# 3) $readparamerr: parameter errors
# 4) $readflux: 	Absorbed model flux (from XSPEC flux command) and errors
# 5) $readcflux: 	UNAbsrobed model component fluxes (from cflux command)
# 6) $readcfluxerr:	UNAbsrobed model component flux errors (from cflux command)

# These parameters are boolean, and they are set to "yes" or "no" depending
# on where in the log file we are.

# These are checked for every line...

if ($readinfo eq "no"){

  #Copying all the warnings from xspec to @warnings array.
  if(/Warning:/){push @warnings, $'};
  #If new best fit parameters are found, then result arrays set empty.
  if ($die){
   if(/Warning: New best fit found, fit parameters will be set to new values/){
    die "Error: New best fit was found found when you searched for errors!\nRedo your initial fitting!\n";
   }
  }
}

# Matching is done here...

if ($readinfo eq "yes"){

  # Getting input data file names
  if (/#Spectrum \d+  Spectral Data File: (\S+)/){
	push @specdata, $1;
  }

  # Getting count rates
  if (/Net count rate \(cts\/s\) for Spectrum:\d+\s+(\S+)/){
	#print "Found a match...\n";
	push @countrates, $1;
  }

  #	Net count rate (cts/s) for Spectrum:1  1.159e+00 +/- 7.358e-03 (99.3 % total)

  #Getting instrument names
  if (/#  Telescope: \w+ Instrument:/){	
  #Getting instrument id
  #	Chandra ACIS is seen as EPIC PN.
	if ($'=~/(EPN)/i or $'=~/(ACIS)/i or $'=~/(WFC2)/i or $'=~/(XRT)/i  or $'=~/(ISGRI)/i){$instrument = $1};
	if ($'=~/(EMOS1)/i or $'=~/(PCA)/i ){$instrument = $1};
	if ($'=~/(EMOS2)/i or $'=~/(HEXTE)/i or $'=~/(ISGRI)/i){$instrument = $1};
	#print "$instrument\n";
  }
  #	Getting exposure times
  if (/#  Exposure Time: /){		
#	if ($instrument eq "EPN" or $instrument eq "ACIS"  or $instrument eq "WFC2" or $instrument eq "XRT" or $instrument eq "ISGRI"){
	if ($instrument eq "EPN" or $instrument eq "ACIS"  or $instrument eq "WFC2" or $instrument eq "XRT"){

	  if($'=~/(\d+|\d+\.?[\d\D]+?)\s/){$pn_exposure= $1};
	} elsif ($instrument eq "EMOS1" or $instrument eq "PCA"){
	  if($'=~/(\d+|\d+\.?[\d\D]+?)\s/){$mos1_exposure= $1};
	} elsif ($instrument eq "EMOS2" or $instrument eq "HEXTE" or $instrument eq "ISGRI"){
	  if($'=~/(\S+?)/){$mos2_exposure= $1};
	} else {die "no intrument exposure found!!!!\n"};
  }

  # Here the info ends, and parameters come next...
  if (/#Current model list:/){
	$readinfo = "no";
	$readparam = "yes";

  }
}

if ($readparam eq "yes"){
  #print "$line\n";
  foreach(@parameter_expr){
	my $line2= $_;
	#print "printing line2: $line2\n";
	if($line =~/$line2/){
	  #print "It mathed! Value of $line is: ${1}\n";
	  
	  # Putting the matched parameter into a result array
	  push @parameter_values, $1;
	  
	  # If we match a parameter value, we remove it from the array.
	  # (no need to match it again...)
	  shift(@parameter_expr);
	}
  }

	if($line =~/^#Test statistic : Chi-Squared =\s+(\S+)/){
	  $chi2 = $1;
	}
	if($line =~/^# Reduced chi-squared =\s+\S+\s+for\s+(\S+)/){
	  $dof = $1;
	}	
	if($line =~/^# Null hypothesis probability =\s+(\S+)/){
	  $nullP = $1;
	}	

# Chi-Squared =       929.1371 using 814 PHA bins.
# Reduced chi-squared =       1.148501 for    809 degrees of freedom 
# Null hypothesis probability =   2.073028e-03
  
  if (/!XSPEC12>fit/){
	$readparam = "no";
	#$readparamerr = "yes";
  }

}

#print @read_parerr;

if (/!XSPEC12>error maximum \S+ \S+ @read_parerr/){
	$readparamerr = "yes";
	#print "Matching parameter errors...\n";
}



if ($readparamerr eq "yes"){

  #print "\n\nReading parameters!!!!\n\n";

  foreach(@read_parerr){
	my $val=$_;
	#print "$line\n";
	if ($line=~/\s+$val\s+(\S+)\s+(\S+)\s+\((\S+?),(\S+)\)/){
#	if ($line=~/^#\s+$val\s+(\S+)\s+(\S+)\s+/){
	  #print "Matched at last...\n";
	  push @abs_errors_min, $1;
	  push @abs_errors_max, $2;
	  push @rel_errors_min, $3;
	  push @rel_errors_max, $4;

	  shift @read_parerr;
	}
  }

  if (/XSPEC12>flux/){
	$readparamerr = "no";
	$readflux = "yes";
	#print "\n\nFound flux!!!!\n\n";
  }



# Parameter   Confidence Range (2.706)
#     1     0.162806     0.184179    (-0.0103827,0.0109896)
#     2      2.90924      3.05136    (-0.0684821,0.0736352)
#     3      1.51809      1.76003    (-0.110311,0.131632)
#     4      2.55951      2.64308    (-0.0415517,0.0420245)
#     5  0.000938381  0.000987879    (-2.42435e-05,2.52541e-05)


}

if ($readflux eq "yes"){

	#print "\n\nlooking for flux!!!!\n\n";

# Model Flux 0.0014736 photons (2.524e-12 ergs/cm^2/s) range (0.30000 - 10.000 keV)
#     Error range  0.001460 - 0.001491    (2.498e-12 - 2.556e-12)  (90.00% confidence)

  #print $line;

  if ($line=~/^#\s*Model\s+Flux\s+\S+\s+photons\s+\((\S+)/){
	print "\nFound absorbed flux!!!!\n";
	print "Readflux is ".$readflux."\n";
	$absorbedflux = $1;
  }

  # We only read the first instrument flux. 
  if ($line=~/^#\s+Error range\s+(\S+) - (\S+)\s+\((\S+) - (\S+)\)/){
  #if ($line=~/confidence/){
  #if ($line=~/#\s+(Error)/){
	print "\n\nFound flux errors!!!!\n\n";
	$absorbedflux_relerr_min = $1;
	$absorbedflux_relerr_max = $2;
	$absorbedflux_abserr_min = $3;
	$absorbedflux_abserr_max = $4;
	$readflux = "no";
  }

}

if(/!XSPEC12>addcomp/){$readcflux="yes"};

if ($readcflux eq "yes"){

  # We look take the cflux values after the fit...
  if(/!XSPEC12>thaw/){$readcflux2="yes"};

  if ($readcflux2 eq "yes"){
	if ($line =~/cflux\s+Emin\s+keV\s+(\S+)/){
	  push @cflux_emin, $1;
	}
	if ($line =~/cflux\s+Emax\s+keV\s+(\S+)/){
	  push @cflux_emax, $1;
	
	}
	# As soon as we get the flux, we don't look for it anymore...
	if ($line =~/cflux\s+lg10Flux\s+cgs\s+(\S+)/){
	  push @cflux_lg10flux, $1;
  	  $readcflux2="no"
	}
  }

  # Now we start looking for the error...
  if(/!XSPEC12>error/){
	$readcflux="no";
	$readcfluxerr = "yes";
  }

}

if ($readcfluxerr eq "yes"){

  if ($line =~/^#\s+\d+\s+(\S+)\s+(\S+)\s+\((\S+?),(\S+)\)/){
	push @cflux_abserr_min, $1;
	push @cflux_abserr_max, $2;
	push @cflux_relerr_min, $3;
	push @cflux_relerr_max, $4;

	$readcfluxerr="no"
  }

#     4     -11.3059     -11.2606    (-0.0202843,0.025025)


}

}

close XSLOG;

# Debugging stuff...
print "warnings...\n";
print "@warnings\n";
print "*** Results ***\n";
print "specdata: @specdata\n";
print "countrates: @countrates\n";
print "exposures: ";
if ($pn_exposure){print "$pn_exposure "};
if ($mos1_exposure){print "$mos1_exposure "};
if ($mos2_exposure){print "$mos2_exposure "};
print "\n";


print "modcomp_names: @modcomp_names_keep\n"; 


print "chi2, dof, nullP: $chi2, $dof, $nullP\n";


print "parameter_values: @parameter_values\n";

print "abs_errors_min: @abs_errors_min\n";
print "abs_errors_max: @abs_errors_max\n";
print "rel_errors_min: @rel_errors_min\n";
print "rel_errors_max: @rel_errors_max\n";

if ($absorbedflux){
  print "absorbedflux: $absorbedflux\n";

  $absorbedflux_relerr_min = sprintf("%.7e",$absorbedflux_abserr_min - $absorbedflux);
  $absorbedflux_relerr_max = sprintf("%.7e",$absorbedflux_abserr_max - $absorbedflux);

  print "absorbedflux_relerr_min: $absorbedflux_relerr_min\n";
  print "absorbedflux_relerr_max: $absorbedflux_relerr_max\n";
  print "absorbedflux_abserr_min: $absorbedflux_abserr_min\n";
  print "absorbedflux_abserr_max: $absorbedflux_abserr_max\n";
}
print "cflux_emin: @cflux_emin\n";
print "cflux_emax: @cflux_emax\n";
print "cflux_lg10flux: @cflux_lg10flux\n";

print "cflux_abserr_min: @cflux_abserr_min\n";
print "cflux_abserr_max: @cflux_abserr_max\n";
print "cflux_relerr_min: @cflux_relerr_min\n";
print "cflux_relerr_max: @cflux_relerr_max\n";

my $l=0;

foreach(@cflux_lg10flux){
  my $val = sprintf("%.5e", 10 ** $_);
  my $val2 = sprintf("%.5e", 10 ** $cflux_abserr_min[$l]);
  my $val3 = sprintf("%.5e", 10 ** $cflux_abserr_max[$l]);
  push @cflux_flux, $val;
  push @cflux_flux_min, $val2;
  push @cflux_flux_max, $val3;
  $l++
}

print "cflux_flux: @cflux_flux\n";
print "cflux_flux_min: @cflux_flux_min\n";
print "cflux_flux_max: @cflux_flux_max\n";


#if ( ! open OUTPUT, ">", "${outdir}/$outname") {
#  die "Cannot open ${outdir}/$outname for output: $!";
#}

if ( ! open OUTPUT, ">", "$outname") {
  die "Cannot open $outname for output: $!";
}

# Printing the header
print OUTPUT "#\tInput data:\t@specdata\n";
print OUTPUT "#\tCount rates:\t@countrates\n";
print OUTPUT "#\tExposure times:\t";
if ($pn_exposure){print OUTPUT "$pn_exposure "};
if ($mos1_exposure){print OUTPUT "$mos1_exposure "};
if ($mos2_exposure){print OUTPUT "$mos2_exposure "};
print OUTPUT "\n";
print OUTPUT "#\tModels:\t\t@modcomp_names_keep\n\n";
print OUTPUT "#\tChi2:\t\t$chi2\n";
print OUTPUT "#\td.o.f.:\t\t$dof\n";
print OUTPUT "#\tnullP:\t\t$nullP\n";
print OUTPUT "Warnings that were found...\n";
print OUTPUT "@warnings\n\n";
print OUTPUT "Parameter values:\n";
# Printing parameters and fluxes in latex readable format!
my $n=0;
foreach(@parameter_values){
  my $val=sprintf("%.7f",$_);
  my $min=sprintf("%.7f",$rel_errors_min[$n]);
  my $max=sprintf("%.7f",$rel_errors_max[$n]);
  if ($n != 0){print OUTPUT " \& "};
  print OUTPUT "${val}_{$min}^{+$max}";
  $n++;
}
print OUTPUT "\n\n";
if ($absorbedflux){
  print OUTPUT "Absorbed Flux:\n";
  print OUTPUT "${absorbedflux}_{$absorbedflux_abserr_min}^{$absorbedflux_abserr_max}\n\n";
} else {
  print OUTPUT "Absorbed Flux:\n";
  print OUTPUT "NA_{NA}^{NA}\n\n";
}
print OUTPUT "Model component Fluxes, (min & max): (@cflux_emin, @cflux_emax) keV\n";

$n=0;
foreach(@cflux_flux){
  my $val=sprintf("%.7e",$_);
  #my $min=sprintf("%.7e",@cflux_flux_min[$n] - $cflux_flux[$n]);
  #my $max=sprintf("%.7e",@cflux_flux_max[$n] - $cflux_flux[$n]);
  my $min=sprintf("%.7e",$val-$cflux_flux_min[$n]);
  my $max=sprintf("%.7e",$cflux_flux_max[$n] - $val);
  if ($n != 0){print OUTPUT " \& "};
  print OUTPUT "${val}_{-${min}}^{+${max}}";
  $n++;
}

print OUTPUT "\n";

close(OUTPUT);





# END OF FIRST ROUND ########
#############################
