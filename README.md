Scripts &amp; snippets for burstdatabase project

### Source reduction timeline

* `lcurve_all_std1.pl`
* `idl/find_bursts_v2.pro`
* `make_burstlist_v4.pl`
* `run_pca_burst_v7.pl`
* `bin_sum_v3.pl`
* `xspec_burst_fit_v6.pl`
* `plotb.pro`

## Description

### lcurve_all_std1.pl

##### input:
```
lcurve_all_std1.pl
```

##### output:
* *obsid_lc.txt*

The first thing to do with the raw data is to separate bursts from the data. The first part of this is making lightcurves of all observations with the script `lcurve_all_std1.pl`. The script searches all subdirectories in the main directory, which are something like *HETEJ19001_2455/P91015/91015-01-03-04/pca* and finds all the Standard1 files in *.gz* format using [ftlist](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/ftlist.html), which lists the contents of the input file. Then the script uses [saextrct](http://heasarc.gsfc.nasa.gov/lheasoft/ftools/fhelp/saextrct.txt) to create a lightcurve from the data and saves it in *.lc* format. This FITS-file is then converted to standard text file using [fdump](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/fdump.txt) that produces *lc.dat*. After that the script converts the lightcurves to *.gif* files for easy visual analysis. It also makes a list of the lightcurves, *obsid_lc.txt*, for the next script. 

-

### idl/find_bursts.pro

##### input:
```
idl> .run find_bursts.pro
```

##### output:
* *burst_list.txt*

The next script is made with *idl* while all the others are made with *perl*. This script reads the list of the lightcurves made by the previous script and for each lightcurve it calculates the average counts per second and the standard deviation. Then it finds from the lightcurve all the peaks, which are higher than four-sigma from the average. After that the script plots the lightcurve and shows to the user the peaks with height over four-sigma and asks if they are bursts or not. The data may contain pcu-breakdowns and data from other events than bursts, so the user has to separate the bursts visually from the candidates. The user may also correct the estimated starting and ending times of the bursts. Finally, the script creates a list of the bursts named *burst_list.txt*.

-

### make_burstlist.pl

##### input:
```
make_burstlist.pl -input <in_file> -output <out_file> -source "4U1608m52"
```
where `<in_file>` is usually *burst_list.txt* and `<out_file>` is *pca_burst_input.txt*.


##### output:
* *pca_burst_input.txt* (multiple files)
* *pca_burst_input_list.txt*
* *burst_input_list.txt*

This script makes an input files for the next one. The script requires [HEASOFT](http://heasarc.nasa.gov/lheasoft/) to be set up. It reads the list of user-chosen bursts made by the previous *idl* script and finds the directories with data from the bursts specified in the list. For each burst this script finds the files containing Burst Catcher, Standard 1 and Standard 2 mode data using the same [ftlist](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/ftlist.html) as mentioned above and writes the filenames and paths for each burst into separate files named *pca_burst_input.txt*. These files are located in directories named `<burst_id>`_`<nmb>`, e.g. 91059-03-01-04_1, where `<burst_id>` is the identification number of the burst and `<nmb>` is just running number starting from one. Then this script writes the locations of input files into a *pca_burst_input_list.txt* located in the main directory of the object and also makes similar file for the `do.pl` script. It also writes the starting and ending times of the bursts into the files. At the end the script writes some parameters for the next script.

-

### run_pca_burst.pl

##### input:
```
run_pca_burst.pl -opts <val>
```
where possible options are

* `inputfile <in_file>` name of the input file (usually *pca_burst_input_list.txt*)
* `x <val>` right ascension for the object
* `y <val>` declination for the object
* `prestd=<val>` duration of the prestd spectrum
* `bkg_only` do 16s bkg reduction only

##### output:
* `<obsid>/proc/<data_files>`

This script produces time resolved PCA burst spectra. It requires [HEASOFT](http://heasarc.nasa.gov/lheasoft/) and [CALDB](http://heasarc.gsfc.nasa.gov/docs/heasarc/caldb/) to be set up. First this script reads the *pca_burst_input_list.txt* which should contain the paths to separate input files, e.g.*91059-03-01-04_1/pca_burst_input.txt*. These files contain the necessary parameters for each burst. After reading these files, the script extracts light curves using either [saextrct](http://heasarc.gsfc.nasa.gov/lheasoft/ftools/fhelp/saextrct.txt) for [science array data](http://heasarc.gsfc.nasa.gov/docs/xte/abc/extracting.html#array) or [seextrct](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/seextrct.txt) for [science event data](http://heasarc.gsfc.nasa.gov/docs/xte/abc/extracting.html#event). Both of these need a [good time interval (GTI)](http://heasarc.gsfc.nasa.gov/docs/xte/abc/screening.html) file created by [maketime](https://heasarc.gsfc.nasa.gov/ftools/caldb/help/maketime.txt), which, in turn, needs a [filter file](http://heasarc.nasa.gov/docs/xte/abc/data_files.html#filter) created by [xtefilt](http://heasarc.gsfc.nasa.gov/lheasoft/ftools/fhelp/xtefilt.txt). The filter file is also used to check which PCUs are operational using [pget](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/pget.txt) [fstatistic](https://heasarc.gsfc.nasa.gov/ftools/caldb/help/fstatistic.txt). If some PCU went off during the observation, the script creates dynamic response file instead of a normal response file. [Response files](http://heasarc.nasa.gov/docs/xte/recipes/pca_response.html) are created using [fparkey](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/fparkey.txt). The script also corrects for PCA deadtime according to [RXTE cook book](http://heasarc.nasa.gov/docs/xte/recipes/pca_deadtime.html). Right now this script extracts 16s prestd background spectra from standard2 file that will be used as a background, but there is also an option to use [pcabackest](https://heasarc.gsfc.nasa.gov/ftools/caldb/help/pcabackest.txt) for model background.

-

### bin_sum.pl

##### input:
```
bin_sum_v3.pl -opts <val>
```
where possible options are

* `dir <burst_dir>` burst directory created by make_burstlist.pl (e.g. *91059-03-01-04_1*)
* `inputfile <in_file>` name of the input file
* `outdir <output_dir>` name of the output directory (usually `/<obsid>/sum/`)
* `list <list_file>` name of the file containing a list of the pha files (usually `/<obsid>/pha_<obsid>.list`)

Can also be launched via `do.pl` which takes care of all the necessary options.

##### output:
* `<obsid>/sum/<data_files>`
* `/<obsid>/pha_<obsid>.list`

This is perl script for merging pha files created by `run_pca_burst.pl` and it uses 0.25s resolution. It requires [XSPEC](http://heasarc.gsfc.nasa.gov/xanadu/xspec/) to be set up. This script reads the exposure times from pha-files using [ftlist](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/ftlist.html) and then uses XSPEC to get the count rate of each pha-file and the peak count. Then it sums the column counts and adds the pha-files together if count rate is not high enough. During the summation this script checks the number of PCUs on and if the number changes between pha-files, it splits the summation so that only the pha-files with same PCUs on are added together. It also marks the channels with low count rate as bad and prints a list of pha files into a file .

-

### xspec_burst_fit.pl

##### input:
```
xspec_burst_fit_v7.pl -opts <val>
```
where possible options are

* `inputfile <in_file>` name of the input file (`/<obsid>/pha_<obsid>.list`)
* `outdir <output_dir>` name of the output directory for fit-files (usually `/<obsid>/fit/`)
* `outdir2 <output_dir2>` name of the output directory for analysis-files (usually `/<obsid>/analysis/`)
* `model <model_id>` used XSPEC model (in this case model is blackbody radiation, *bb*)
* `phabs <val>` value of the nH-absoption

Can also be launched via `do.pl` which takes care of all the necessary options.

##### output:
* `<obsid>/fit/<data_files>`
* `<obsid>/analysis/<data_files>`

This is perl script for fitting blackbody model ([tbabs](https://heasarc.gsfc.nasa.gov/xanadu/xspec/manual/XSmodelTbabs.html)*[bbodyrad](http://heasarc.gsfc.nasa.gov/xanadu/xspec/manual/XSmodelBbodyrad.html)) into spectrums in [XSPEC](http://heasarc.gsfc.nasa.gov/xanadu/xspec/) and reading parameters into a file. This script may use [C-statistics](https://heasarc.gsfc.nasa.gov/xanadu/xspec/manual/XSappendixStatistics.html) or [Churazov weighting](https://heasarc.gsfc.nasa.gov/xanadu/xspec/manual/XSweight.html) or it simply ignores channels marked as bad. After fitting the model the script reads the logfiles created by XSPEC, gets the spacecraft time and right exposure time using [ftlist](http://heasarc.gsfc.nasa.gov/ftools/caldb/help/ftlist.html), converts some values to correct formats and produces another file with the following parameters: 
* 1. Time (spacecraft seconds) 
* 2. , 3. Count rate & error (not corrected for PCUs) 
* 4. Time bin size (s) 
* 5. , 6. , 7. nH (frozen in bbfit_fabs.log) and min, max (both zero in bbfit_fabs.log) 
* 8. , 9. , 10. kT (keV) and min, max (1 sigma error) 
* 11. , 12. , 13. Blackbody normalisation ((R_km/d_10kpc)^2) and min, max 
* 14. Fit reduced chi^2 
* 15. "Raw" flux value (2.5-25 keV, ergs/cm^2/s) 
* 16. , 17. , 18. Estimated bolometric flux (1e-9 ergs/cm^2/s) and min, max (1 sigma error). 

-

### idl/plotb.pro

##### input:
```
idl> .run plotb_v2.pro
idl> plotb_v2,'bbfit.txt','bbfit2.txt'
```
where 'bbfit.txt' contains the list of parameter files and 'bbfit2.txt' contains the list of old parameter files for comparison

##### output:
* `fig_burst_JD<systime>.ps`

This idl script reads the parameter files `<obsid>/analysis/<data_files>` and plots the bolometric flux, chi-squared, blackbody normalization and temperature fitted by the previous xspec-script for each burst. The graphs are plotted one below another, with the same time on x-axis. Then it calculates the average peak flux, determines touchdown and half-down time and also calculates burst and touchdown fluences and prints them on the screen. If the *bbfit2.txt* file is provided and contains the list of old parameter files, the old figures are plotted on the same window with different colour for easier comparison between different analysis methods. 
