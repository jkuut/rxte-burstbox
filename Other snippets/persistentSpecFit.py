
import readline
#import rpy2.robjects

import os
import fitXspec as xfit

#get current working dir for xspec
pwd =  os.getcwd()


#Read pre_bursts bursts from file
prestd = "prestd2.list"
prestd_fh = open(prestd, "r")
prestd2list = prestd_fh.readlines()
prestd_fh.close()

#Read nH from file
nh_fh = open("nH.txt", "r")
nH = float(nh_fh.readline().rstrip())
nh_fh.close()

absmodel = 'TBabs'
#absmodel = 'wabs'
#absmodel = 'phabs'

#model="tbabs*bbodyrad"
#initVals = [(nH, -1), #abs nH
#            (2.5, 0.01), # powerlaw Gamma
#            (300, 1.)] # powerlaw norm

models = [absmodel+'*powerlaw', # powerlaw
          absmodel+'*(diskbb + bbodyrad)', # First "freeze" Tbb to previous step                         
          absmodel+'*(diskbb + bbodyrad)', # Tbb free parameter   
          absmodel+'*(diskbb + powerlaw)', # First "freeze" Gamma to 0.9 of previous step
          absmodel+'*(diskbb + powerlaw)', # Gamma free parameter          
          #absmodel+'*(cutoffpl)', # cutoff powerlaw                          
          absmodel+'*(diskbb + cutoffpl)']

######################
# Loop over each burst
for prestd2pha in prestd2list:
    
    print '##############################'
    print '# Input data: '
    print '#    ', prestd2pha
    print '##############################'

    prestd2pha = prestd2pha.rstrip()

    HighECut = 7.0
    dbbTin = 0.5
    dbbTinNorm = 100.
    bbT = 2.5
    bbNorm = 1.

    i=0
    for i in range(len(models)):
        model = models[i]

        print '##############################'
        print '# Fitting model: '
        print '#    ', model
        print '##############################'

        if i==0: # powerlaw
            initVals = [(nH, -1), #abs nH
                        (2.5,0.01), # powerlaw Gamma
                        (1., 0.1)] # powerlaw norm
        
            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            Gamma = bestfitVals[1][0]
            GammaDelta = bestfitVals[1][1]
            GammaNorm = bestfitVals[2][0]
            GammaNormDelta = bestfitVals[2][1]
            powerlawChi2Red = chi2 / dof 

        if i==1: # diskbb + bbodyrad (dbbTin is fixed to previous best fit!)
            initVals = [(nH, -1), #abs nH
                        (dbbTin, -1), # diskbb temperature
                        (dbbTinNorm, 1.), # diskbb norm
                        (bbT, 0.1), # bbodyrad Tbb
                        (bbNorm, 0.1), # bbodyrad norm
                        ]

            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            dbbTin = bestfitVals[1][0]
            #dbbTinDelta = bestfitVals[1][1]
            dbbTinNorm = bestfitVals[2][0]
            dbbTinNormDelta = bestfitVals[2][1]
            bbT = bestfitVals[3][0]
            bbTDelta = bestfitVals[3][1]
            bbNorm = bestfitVals[4][0]
            bbNormDelta = bestfitVals[4][1]

        if i==2: # diskbb + bbodyrad 
            initVals = [(nH, -1), #abs nH
                        (dbbTin, 0.1), # diskbb temperature
                        (dbbTinNorm, dbbTinNormDelta), # diskbb norm
                        (bbT, 0.1), # bbodyrad Tbb
                        (bbNorm, 0.1), # bbodyrad norm
                        ]

            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            dbbTin = bestfitVals[1][0]
            dbbTinDelta = bestfitVals[1][1]
            dbbTinNorm = bestfitVals[2][0]
            dbbTinNormDelta = bestfitVals[2][1]
            bbT = bestfitVals[3][0]
            bbTDelta = bestfitVals[3][1]
            bbNorm = bestfitVals[4][0]
            bbNormDelta = bestfitVals[4][1]


        if i==3: # diskbb + powerlaw (photon index is fixed to 0.9 of previous best fit!)
            initVals = [(nH, -1), #abs nH
                        (dbbTin, 0.1), # diskbb temperature
                        (dbbTinNorm, 0.1), # powerlaw norm
                        (Gamma*0.9, -1.0), # powerlaw Gamma
                        (GammaNorm, GammaNormDelta), # powerlaw norm
                        ]

            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            dbbTin = bestfitVals[1][0]
            dbbTinDelta = bestfitVals[1][1]
            dbbTinNorm = bestfitVals[2][0]
            dbbTinNormDelta = bestfitVals[2][1]
            #Gamma = bestfitVals[3][0]
            #GammaDelta = bestfitVals[3][1]
            GammaNorm = bestfitVals[4][0]
            GammaNormDelta = bestfitVals[4][1]

        if i==4: # diskbb + powerlaw
            initVals = [(nH, -1), #abs nH
                        (dbbTin, dbbTinDelta), # diskbb temperature
                        (dbbTinNorm, dbbTinNormDelta), # powerlaw norm
                        (Gamma*0.9, GammaDelta), # powerlaw Gamma
                        (GammaNorm, GammaNormDelta), # powerlaw norm
                        ]

            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            dbbTin = bestfitVals[1][0]
            dbbTinDelta = bestfitVals[1][1]
            dbbTinNorm = bestfitVals[2][0]
            dbbTinNormDelta = bestfitVals[2][1]
            Gamma = bestfitVals[3][0]
            GammaDelta = bestfitVals[3][1]
            GammaNorm = bestfitVals[4][0]
            GammaNormDelta = bestfitVals[4][1]

 
        if i==5: # diskbb + cutoffpl 
            initVals = [(nH, -1), #abs nH
                        (dbbTin, dbbTinDelta), # diskbb temperature
                        (dbbTinNorm, dbbTinNormDelta), # diskbb norm
                        (Gamma, GammaDelta), # powerlaw Gamma
                        (HighECut, 1.), # high energy cutoff                                  
                        (GammaNorm, GammaNormDelta) # powerlaw norm
                        ]

            bestfitVals, bestfitErrs, chi2, dof, nullP, flux, fluxErr,  rate, rateErr, rate, rateErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
            dbbTin = bestfitVals[1][0]
            dbbTinNorm = bestfitVals[2][0]
            Gamma = bestfitVals[3][0]
            HighECut = bestfitVals[4][0]
            GammaNorm = bestfitVals[5][0]

        
        #if i==1: # cutoff powerlaw
        #    initVals = [(nH, -1), #abs nH
        #                (Gamma, GammaDelta), # powerlaw Gamma
        #                (HighECut, 1.), # high energy cutoff                                  
        #                (GammaNorm, GammaNormDelta), # powerlaw norm
        #                ]

        #    bestfitVals, chi2, dof,nullP, flux, fluxErr, energ, energErr, uf, ufErr, resid, residErr = xfit.fitXspec(prestd2pha, model, initVals)
        #    HighECut = bestfitVals[2][0]

        if nullP >= 0.05:
            print 'found acceptable fit!'
            break  


       
