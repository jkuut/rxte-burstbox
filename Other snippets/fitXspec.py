
import readline
#import rpy2.robjects
import xspec as xs

import re

from scipy import stats
import numpy as np
import math

# List of inputs:

#model = "tbabs*powerlaw"
#pha = "91059-03-01-04_5/proc/HETEJ19001m2455_B5_prestd2.pha"
#initVals = [(0.89, -1),(2.5),(100.)]

#Splitting function that accepts arrays of inputs
def array_split(s, seps):
    res = [s]
    for sep in seps:
        s, res = res, []
        for seq in s:
            res += seq.split(sep)
    return res

#Replace function that accepts arrays of inputs
def array_remove_chars(s, reps):
    res = s
    for rep in reps:
        res = res.replace(rep, "")

    return res




#####################
# Check sanity of input values
def check_inputs(statistic):
    
    if not(statistic in ["chi", "cstat", "pgstat", "lstat", "whittle"]):
        raise ValueError("Statistic input value is not in the list of accepted parameters")




def fitXspec(pha, #string for pha file
             model, #Model in xspec syntax
             initVals, #array of tuples of initial values
             statistic="chi", #Statistic
             weight="standard", #Weighting for channels
             abundances="wilm", #Abundances
             confidence_level=1.0, #Confidence level for error calc
             max_chi=1000.0, #Maximum chisq accepted for error calc
             extend_lowE=0.001, #Lower energy limit for response
             extend_highE=200.0, #Upper energy limit for response
             extend_Nbins=200, #Number of bins used in response expansion
             Ebounds=[(0.001, 200.0)], #Array of flux bounds
             dobkg = False): #toggle flag for additional bkg model


    #Add sanity checking function for input parameters
    xs.Xset.chatter = 1
    xs.Fit.statMethod = statistic
    xs.Fit.weight = weight

    xs.Xset.abund = abundances

    xs.AllData.clear()
    xs.AllData += pha

    xs.AllData.ignore("**-3. 20.-**")
    #xs.AllData.ignore("bad")

    xs.Fit.query="yes"

    # Getting rate and rate variance
    rate = xs.AllData(1).rate[0]
    rateErr = xs.AllData(1).rate[1]

    #Build model
    m1=xs.Model(model)

    #set parameter values
    nPars = m1.nParameters

    if nPars != len(initVals):
        raise Exception("Number of input parameters and model parameters do not match.\n")

    for i in range(nPars):
        #print initVals[i]
        m1(i+1).values = initVals[i]

    #fit
    xs.Fit.renorm()
    xs.Fit.perform()

    #errors for bestfit values (if not frozen)
    bestfitErrs=[]
    for i in range(nPars):
        error_string = "maximum "+str(float(max_chi)) + " " + str(float(confidence_level))+" "+str(i+1)
        #print m1(i+1).values[1], type(m1(i+1).values[1])
        if m1(i+1).values[1] > 0:
            #print error_string
            xs.Fit.error(error_string)
            bestfitErrs.append(m1(i+1).error)
        else:
            bestfitErrs.append((0.0, 0.0, 'XXX'))

    #get statistics
    chi2 = xs.Fit.statistic
    dof = xs.Fit.dof

    nullP = 1 - stats.chi2.cdf(chi2, dof)

    #best fit values
    bestfitVals = []
    for i in range(nPars):
        #print m1(i+1).values
        bestfitVals.append(m1(i+1).values)


    #Unfolded spectrum points (y-axis) and energies (x-axis)
    xs.Plot("uf")
    energ = xs.Plot.x()
    energErr = xs.Plot.xErr()
    uf = xs.Plot.y()
    ufErr = xs.Plot.yErr()

    #residuals
    xs.Plot("del")
    resid = xs.Plot.y()
    residErr = xs.Plot.yErr()

    
    #####################
    # cflux computations
    #####################



    cflux_model = add_cflux(model, bkg=dobkg)

    #update init vals to have bestfit values
    for i in range(len(initVals)):
            initVals_list = list(initVals[i])
	    initVals_list[0] = bestfitVals[i][0]
            initVals[i] = tuple(initVals_list)

    # "Copying" the array using a slice to a new array.
    cflux_initVals = initVals[:]

    #get number of parameters and freeze norm
    clean_model = array_remove_chars(model, ["(", ")"])
    components = array_split(clean_model, ["*", "+"])
    nPars_norm = -1
    for component in components:
        paramNums, paramNames, modelType = findModelInfo(component, pathToData)
        #print paramNums, component        
        nPars_norm += paramNums
        if modelType == "add":
            #print 'nPars_norm: ', nPars_norm
	    cflux_initVals_list = list(cflux_initVals[nPars_norm])
	    cflux_initVals_list[1] = -1
            cflux_initVals[nPars_norm] = tuple(cflux_initVals_list)

           
    #Add cflux
    ##############

    xs.AllModels.clear()
    m1 = xs.Model(cflux_model)

    #Extend energies
    xs.AllModels.setEnergies("extend", "low, "+str(extend_lowE)+", "+str(extend_Nbins)+" log")
    xs.AllModels.setEnergies("extend", "high, "+str(extend_highE)+", "+str(extend_Nbins)+" log")

    #get number of parameters before cflux
    clean_model = array_remove_chars(cflux_model, ["(", ")"])
    components = array_split(clean_model.split("cflux")[0], ["*", "+"])
    nPars_cflux = -1
    for component in components:
        paramNums, paramNames, modelType = findModelInfo(component, pathToData)
        nPars_cflux += paramNums


    flux = []
    fluxErr = []
    for Ebound in Ebounds:
        Emin = Ebound[0]
        Emax = Ebound[1]


        cflux_initVals.insert(nPars_cflux-3, (Emin, -1))
        cflux_initVals.insert(nPars_cflux-2, (Emax, -1))
        cflux_initVals.insert(nPars_cflux-1, (-8.0, 0.08))

        #insert first guess for cflux parameter by freezing everything and fitting
        nPars = m1.nParameters
        for i in range(nPars):
            m1(i+1).values = cflux_initVals[i]
            m1(i+1).values[1] = -1

        xs.Fit.perform()

        #Read new cflux value and reset initial values for real flux fit
	cflux_initVals[nPars_cflux-1] = (m1(nPars_cflux).values[0], 0.01*abs(m1(nPars_cflux).values[0]))
        
        for i in range(nPars):
            m1(i+1).values = cflux_initVals[i]
        

        xs.Fit.perform()

        #Compute errors for flux
	error_string = "maximum "+str(float(max_chi)) + " " + str(float(confidence_level))+" "+str(nPars_cflux)

        xs.Fit.error(error_string)
                

	#print nPars_cflux
	#print m1(nPars_cflux).values[0], type(m1(nPars_cflux).values[0]) 
	#print 10**(m1(nPars_cflux).values[0])

        flux.append(10**(m1(nPars_cflux).values[0]))
        fluxErr.append( (10**(m1(nPars_cflux).error[0]), 10**(m1(nPars_cflux).error[1]), m1(nPars_cflux).error[2]) )

        #print "Flux value"
        #print flux

        #print "Flux error"
        #print fluxErr
        #exit()
        
        # Removing cflux parameters from initVals variable
        cflux_initVals.pop(nPars_cflux-3)
        cflux_initVals.pop(nPars_cflux-3)
        cflux_initVals.pop(nPars_cflux-3)


    return  (bestfitVals, bestfitErrs, chi2, dof, nullP,
            flux, fluxErr, rate, rateErr,
            energ, energErr,
            uf, ufErr,
            resid, residErr)



#Add cflux component in general if we have also bkg components
def add_cflux(model, bkg = False):

    #remove any unnecessary spaces
    model = model.replace(" ", "").lower()
    if bkg:
        #Add flux after the first parenthesis group
        Np = model.count('(')
        if Np != 2:
            raise Exception("Trying to add cflux component failed, check parenthesis")

        indx = model.index(')')
        if model[indx+1] == '+':
            bkg_part = model[:indx+2]
            model_part = model[indx+2:]

            model_part = add_cflux_nobkg(model_part)
            cflux_model = bkg_part+model_part
	else:
            raise Exception("Trying to add cflux component failed, check parenthesis")
    else:
        cflux_model = add_cflux_nobkg(model)

    return cflux_model


#Add flux after the absorption
def add_cflux_nobkg(model):
    abs_models=["tbabs", "phabs", "wabs"]
    
    for absm in abs_models:
        indx = model.find(absm)
        if indx != -1:
            aindx = indx + len(absm)
            abs_part = model[:aindx+1]
            model_part = model[aindx+1:]
            break

    if indx == -1:
        raise Exception("No absorption model found in model string")

    return abs_part+"cflux*("+model_part+")"
    

def findModelInfo(modelComponent, pathToData):

    modelComponent = modelComponent.replace(" ", "").lower()
    fo = open(pathToData, "r")
    lines = fo.readlines()
    fo.close()

    regExpwords = ['add', 'mul', 'con']
    
    i=0
    for line in lines:
        
        paramNames = []
        paramNums = 0
        
        match = re.match(modelComponent, line.lower())
  
        if match and any(z in line for z in regExpwords):

            modelDescription = line.split()
            #print modelDescription
            modelType = modelDescription[5]
            paramNums = int(modelDescription[1]) 

            #print type(modelDescription[1])            

            for j in range(paramNums):
                paramName = re.findall("^(\S+)",lines[i+1])[0]
                #print paramName
                paramNames.append(paramName)
                i += 1

            if modelType == "add":
                paramNames.append("norm")
                paramNums += 1 

            return paramNums, paramNames, modelType
            break

        i += 1
    #print modelComponent        
    raise Exception("No matching model found in Xspec")

############### testing ###################
# List of inputs:


pathToData = '/lhome/jkajava/soft/heasoft-6.14/Xspec/src/manager/model.dat'
#modelComponent = 'powerlaw'

#paramNames = []

#paramNums, paramNames, modelType = findModelInfo(modelComponent, pathToData)

#print paramNums, paramNames, modelType

#model="tbabs*(bbodyrad+powerlaw)+tbabs*(bbodyrad+compTT)"
#print add_cflux(model, bkg=True)

#bestfitVals, chi2, dof, nullP, energ, energErr, uf, ufErr, resid, residErr = fitXspec(pha, model, initVals)

#model = "tbabs*bbodyrad"
#pha = "91059-03-01-04_5/proc/HETEJ19001m2455_B5_prestd2.pha"
#initVals = [(0.89, -1), #tbabs
#            (2.5,1.), #kt
#            (100.,1.)] #norm

#modelComponent = 'bbodyrad'
#paramNames = []
#paramNums, paramNames, modelType = findModelInfo(modelComponent, pathToData)
#print paramNums, paramNames, modelType

#model="tbabs*(bb+plaw)+tbabs*(bb+compTT)"
#print add_cflux(model, bkg=True)

#model = "tbabs*powerlaw"
#bestfitVals, chi2, dof,nullP, flux, fluxErr, energ, energErr, uf, ufErr, resid, residErr = fitXspec(pha, model, initVals)

#print chi2, dof, nullP
#print bestfitVals
#print " "
#print energ
#print energErr


