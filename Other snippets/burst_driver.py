from astropy.io import fits
import os
import fitXspec as xfit

#get current working dir for xspec
pwd =  os.getcwd()

#Read bursts from file
bbfit = "burst_PRE.list"
txtfile = open(bbfit, "r")
bursts = txtfile.readlines()

source = 'HETEJ1900'

#model="tbabs*bbodyrad"
#initVals = [(0.16, -1), #tbabs
#            (2.5, 0.1), #bb kT
#            (300,1.0)] #bb norm

model="tbabs*edge*bbodyrad"
initVals = [(0.16, -1), #tbabs
            (7.5, 0.1, 5.0, 5.0, 10.0, 10.0), #edgeE
            (0.5, 0.05), #tau
            (2.5, 0.1), #bb kT
            (300,1.0)] #bb norm

fluxScale = 1.0e-9 # Burst fluxes will be scaled to these units

######################
# Loop over each burst
for burst in bursts:
    #print burst

    burst = burst.rstrip()
    phalist = burst + "/pha_" + burst + ".list"
    txtfile = open(phalist, "r")
    phafiles = txtfile.readlines()
    txtfile.close()

    print 'analysing burst: ', burst

    #loop over pha files in each burst
    i = 0
    for pha in phafiles:
        fullpha = pwd+"/"+pha.rstrip()

        print '  fitting pha file: ', pha.rstrip()

        bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(fullpha, model, initVals)

        # For printing best fit values and errors to file:
        output_str = ""
        for k in range(len(bestfitVals)):
            output_str += str(round(bestfitVals[k][0], 3)) +" " # value
            output_str += str(round(bestfitErrs[k][0], 3)) +" " # min 
            output_str += str(round(bestfitErrs[k][1], 3)) +" " # max
        
        for s in range(len(flux)):
            output_str += str(round(flux[s]/fluxScale, 3)) +" " # value
            output_str += str(round(fluxErr[s][0]/fluxScale, 3)) +" " # min
            output_str += str(round(fluxErr[s][1]/fluxScale, 3)) +" " # max

        output_str += str(round(chi2, 3)) + " " + str(dof)

            #    print l
            #initVals_list = list(bestfitVals[l])
	    #initVals_list[0] = bestfitVals[l][0]
            #initVals[l] = tuple(initVals_list)

        # opening .pha file to read: time, exposure...
        phafits = fits.open(fullpha)

        TelescopeTime = phafits[1].header['tstart']
        expTimeDTCorrected = phafits[1].header['exposure']

        expTime_NO_DTCorrected = float(phafits[1].header.comments['exposure'].split(" ")[3])

        print "expTimeDTCorrected: ", expTimeDTCorrected
        print "expTime_NO_DTCorrected: ", expTime_NO_DTCorrected

        phafits.close()

        #expTime_NO_DTCorrected = phafits[2].header['ontime']

        #rate_nobacksub = xs.allData.rate[2]
        #rateErr_nobacksub = xs.allData.rate[3]

        #print 'bestfitVals: ', bestfitVals, type(bestfitVals)
        #print 'initVals: ', initVals, type(initVals)
        #print 'initVals(len): ',len(initVals)

        for l in range(len(initVals)):
        #    print l
            initVals_list = list(initVals[l])
	    initVals_list[0] = bestfitVals[l][0]
            initVals[l] = tuple(initVals_list)


	#Print header
        if i == 0:
	    summary_text = pwd + "/" + burst + "/analysis/"+source+burst+"bb_edgefit.dat" 
            summaryfile = open(summary_text, "w")
	    
            # Printing output header
            print >>summaryfile, "#"+model+"\n#\n"
	    print >>summaryfile, "# Columns:"
	    print >>summaryfile, "# 1. Time (spacecraft seconds)"
	    print >>summaryfile, "# 2,3. Count rate & error (not corrected for PCUs)"
            print >>summaryfile, "# 4. Time bin size (s)"
            print >>summaryfile, "# 5,6,7. nH (frozen in bbfit_fabs.log) and min, max (both zero in"
            print >>summaryfile, "#     bbfit_fabs.log)"
            print >>summaryfile, "# 8,9,10. kT (keV) and min, max (1 sigma error)"
            print >>summaryfile, "# 11,12,13. Blackbody normalisation ((R_km/d_10kpc)^2) and min,max"
            print >>summaryfile, "# 14. Fit reduced chi^2"
            print >>summaryfile, "# 15. \"Raw\" flux value (2.5-25 keV, ergs/cm^2/s)"
            print >>summaryfile, "# 16,17,18. Estimated bolometric flux (1e-9 ergs/cm^2/s) and"
            print >>summaryfile, "# 	min,max (1 sigma error)"
            summaryfile.close

        #print type(rate), type(rateErr), type(expTime_NO_DTCorrected)

        #Print datavalues
  	summaryfile = open(summary_text, "a")
        print >>summaryfile, TelescopeTime, round(rate, 0), round(rateErr, 0), round(expTime_NO_DTCorrected, 3), output_str
        print TelescopeTime, round(rate, 0), round(rateErr, 0), round(expTime_NO_DTCorrected, 3), output_str
        summaryfile.close

	resid_text = pwd + "/" + burst + "/analysis/resid_edge_"+ str(i) + ".txt" 
        residfile = open(resid_text, "w")

        for j in range(len(energ)):

                print >>residfile, energ[j], energErr[j], uf[j], ufErr[j], resid[j], residErr[j]               

        residfile.close()

	i += 1
            
        
