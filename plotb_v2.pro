;###########################################################################
; chi-distribution

FUNCTION chi_pdf,x,dof

E=2.718281828459045

y=(1/((2^(dof/2))*gamma(dof/2)))*(x^((dof/2)-1))*E^(-x/2)
return,y

end

;###########################################################################
; plotting error bars in two dimensions = diamonds 
pro oploterr5,x,xmin,xmax,y,ymin,ymax,icol

n=N_ELEMENTS(x)
for i=0,n-1 do plots,[x[i],x[i]],[ymin[i],ymax[i]],col=icol, thick=1.2,noclip=0,clip=[-5.,0.,80.,10000.]
return
end

;###########################################################################
; plotting error bars in two dimensions = diamonds 
pro oploterr4,x,xmin,xmax,y,ymin,ymax,icol

n=N_ELEMENTS(x)
for i=0,n-1 do plots,[xmin[i],x[i]],[y[i],ymin[i]],col=icol, thick=0.5,noclip=0,clip=[-5.,0.,80.,10000.]
for i=0,n-1 do plots,[x[i],xmax[i]],[ymin[i],y[i]],col=icol, thick=0.5,noclip=0,clip=[-5.,0.,80.,10000.]
for i=0,n-1 do plots,[xmin[i],x[i]],[y[i],ymax[i]],col=icol, thick=0.5,noclip=0,clip=[-5.,0.,80.,10000.]
for i=0,n-1 do plots,[x[i],xmax[i]],[ymax[i],y[i]],col=icol, thick=0.5,noclip=0,clip=[-5.,0.,80.,10000.]
return
end

;###########################################################################
; data from Galloway 
pro readdata_log,namef,time,timeerr,tbb,tbberr,kbb,kbberr,fbb,fbberr,fbol,fbolerr,kbb4,kbb4err,bin,fluxunit,nx,chi,starttime

corr= 1.0 ; 0.90 ; correcting for new responses 

;are there any comment lines in *.log?
close,1
openr,1,namef
comments=""
tmp=0
c=-1
while tmp ne -1 do begin
   readf,1,comments
   tmp = STRPOS( comments, "#") 
   c=c+1
endwhile
close,1
;print,'c=',c

openr,1,namef

;reading comment lines
if c ne 0 then begin
   for jj=0,c-1 do begin
      readf,1,comments 
;        print,jj
;        print,comments
   endfor
endif

;nx=nx-c-1

ab=dblarr(18)
; Tbb in keV 
tbb=dblarr(nx) 
tbberr=dblarr(nx) 
; K=(Rbb [km]/D_10kpc)^2 
kbb=dblarr(nx) 
kbberr=dblarr(nx) 
kbb4=dblarr(nx) 
kbb4err=dblarr(nx) 
; Calculated flux
fbb=dblarr(nx)
fbberr=dblarr(nx) 
; Model flux (cflux)
fbol=dblarr(nx) 
fbolerr=dblarr(nx) 

time=dblarr(nx) 
timeerr=dblarr(nx) 
bin=dblarr(nx)
chi=dblarr(nx)


;reading the actual data
time0=0. 
timeerr(0)=0.25/2.
;print,nx
for i=0,nx-1-c do begin
;print,i
   readf,1,ab 
   if(i ne 0) then timeerr(i)=(ab(0)-time0)/2.
   time(i)=ab(0)
   time0=ab(0)
   bin(i)=ab(3)
   tbb(i)=ab(7) 
   tbberr(i)=(ab(9)-ab(8))/2. 
   kbb(i)=ab(10) *corr
   kbberr(i)=(ab(12)-ab(11))/2. *corr		
   fbol(i)=ab(15) /100. *corr   ; flux in units 10^-7
   fbolerr(i)=(ab(17)-ab(16))/2. /100. *corr
   chi(i)=ab(13)

   
; (Rbb km/D 10kpc)^(-1/2) = K^-1/4
   
   if kbb(i) eq 0 then begin
      kbb4(i)=10.
      kbb4err(i)=0.
   endif else begin
      kbb4(i)=kbb(i)^(-0.25)
      kbb4err(i)=kbb4(i)*(kbberr(i)/kbb(i))/4.
   endelse
   
endfor

time=time-time(0)
starttime=time(0)

close,1

sigma= 0.0000567051 ; Stefan-Boltzmann constant 
clight= 29979245800. ; speed of light 
; const = sigma * (keV/K)^4 * (10^5)^2/ (3.086*10^22)^2 = 1.0781e-11
const = 1.0781e-11 
; Flux = (Rbb/D)^2 sigma Tbb^4 = Kbb * tbbkeV^4 * const

fbb= const*kbb*tbb^4 / fluxunit
;fbberr= fbb*(sqrt( (4.*tbberr/tbb)^2 + (kbberr/kbb)^2 ) )
fbberr=const*((kbberr*tbb^4)+(4*kbb*tbberr*tbb^3)) /fluxunit
;fbberr= fbb*(sqrt((4.*tbberr/tbb)^2)+sqrt((kbberr/kbb)^2 ))/ fluxunit


return
end 


;###########################################################################
pro expo_decay_func,x,A,f

E=2.71828
f=A[0]*(E^[-x/A[1]]+A[2]*(E^[-x/A[3]]))
;f=A[0]*(E^[-x/A[1]])

end


;###########################################################################

;==============================================
; MAIN PROGRAM
;==============================================

pro plotb_v2,bbfile,bbfile2


out_name='fig_burst_JD'+string(systime(/JULIAN),format='(I0)')+'.ps'

;==============================================
; preparation of the graph and datafiles
;==============================================
!X.THICK=3
!Y.THICK=3
!Y.MINOR=5
!X.MINOR=5
!Y.TICKLEN=0.03
!X.TICKLEN=0.03
!P.THICK=2
!P.CHARSIZE=1.0 ; 1.2
!X.MARGIN=[5.,2.]
!Y.MARGIN=[0.5,0.5]
!X.OMARGIN=[10.,2.]
!Y.OMARGIN=[5.,5.]
!P.MULTI = [0,1,4,0,1]

fname=string(out_name)
!P.FONT = 0  
;set_plot,'PS' & device,filename=fname,xsize=16.0,ysize=14.0,YOFF=0.,XOFF=0.,/portrait,/COLOR,/CMYK 
set_plot,'PS' & device,filename=fname,xsize=16.0,ysize=21.0,YOFF=0.,XOFF=0.,/portrait,/COLOR,/CMYK 

 DEVICE, /TIMES, /ITALIC, FONT_INDEX=4 ; ,  FONT_SIZE=12 
 DEVICE, /TIMES, FONT_INDEX=5

 
colors 
suffix=suffix

; flux in 10^-7 units 
fluxunit = 1e-7 
fluxunit2 = 1e-7 

;chi_arr=[]
;chi_arr_all=[]

;==============================================
; Calculating stats for each burst
;==============================================
;loop for each burst begins here

;Reading a list of input files
openr,1,bbfile
k=0
temp=' '
files=strarr(500)

while not eof(1) do begin
  readf,1,temp
  files[k]=temp
  k=k+1
endwhile
close,1
files=files[0:k-1]

checkold = FILE_TEST(bbfile2) 
do_old = 0

if checkold eq 1 then begin
    openr,1,bbfile2
    l=0
    temp2=' '
    files2=strarr(500)

    while not eof(1) do begin
        readf,1,temp2
        files2[l]=temp2
        l=l+1
    endwhile
    close,1
    files2=files2[0:l-1]
endif


for ifl=0,n_elements(files)-1 do begin 

    namef=files[ifl]
    nx=file_lines(namef)
    readdata_log,namef,time,timeerr,tbb,tbberr,kbb,kbberr,fbb,fbberr,fbol,fbolerr,kbb4,kbb4err,bin,fluxunit,nx,chi,starttime

if checkold eq 1 then begin 
    namef2=files2[ifl]
    if (namef2 eq '#') then begin
        do_old = 0
    endif else begin
        do_old = 1
    endelse

    if do_old eq 1 then begin
        nx2=file_lines(namef2)
        readdata_log,namef2,time2,timeerr2,tbb2,tbberr2,kbb2,kbberr2,fbb2,fbberr2,fbol2,fbolerr2,kbb42,kbb4err2,bin2,fluxunit2,nx2,chi2,starttime2
    endif
endif

  print,'################## B',namef,' ##################'
 ; print,'################## ',namef2,' ##################'

;==============================================
; Peak flux
;==============================================

;Maximum values for fbol (model flux)

;Starting from the second bin, 
;because in some bursts max value for fbol is incorrectly(?) in first bin 
;while the peak of the burst occurs later

  fbb_model=0.
; for i=0,n_elements(fbol)-1 do begin 
  for i=1,n_elements(fbol)-1 do begin
    if fbol(i) gt fbb_model then begin 
    fbb_model=fbol(i)
    fbb_model_err=fbolerr(i)
    fp_i=i
    endif
  endfor


;This is average peak flux over 3 top bins
    fbb_model_3=(fbol(fp_i-1)+fbol(fp_i)+fbol(fp_i+1))/3
    fbb_model_err_3=(fbolerr(fp_i-1)+fbolerr(fp_i)+fbolerr(fp_i+1))/3  
    print,'f_peak=',fbb_model*100.,' +-',fbb_model_err*100.


;==============================================
; Determine touchdown and half-down
;==============================================

;T1 = touchdown time
  tbb_max=0.
  for i=fp_i,n_elements(tbb)-1 do begin
    if tbb(i) gt tbb_max then begin 
    tbb_max=tbb(i)
    i_td=i
    endif
  endfor


f1_i=i_td


;determining the F2 time (half fedd)
i=f1_i
while fbol(i) gt ((fbol(f1_i))/2.) do begin
f2_i=i
i=i+1.
endwhile

f2_i=f2_i+1.

td_err=(time(f1_i+1)-time(f1_i))/2.


print,'td=',time(f1_i),' err=',td_err
print,'fedd=',fbol(f1_i),'	half-fedd=',fbol(f2_i)




;==============================================
; Burst Fluence
;==============================================

  index3=where(fbol gt 0)

;  print,fbol
;  print,' '
;  print,fbol(index3)


  fbol=fbol(index3)
  fbolerr=fbolerr(index3)
  bin=bin(index3)

  fbol_max=fbol+fbolerr
  fbol_min=fbol-fbolerr

  fluence=0.
  fluence_min=0.
  fluence_max=0.
  fsum=0.
  fsum_max=0.
  fsum_min=0.

;print,n_elements(fbol)

  for i=0,n_elements(fbol)-1 do begin
;    print,'F(i)=',fbol(i),' bin(i)=',bin(i),' Etot=',fluence

    fluence=fluence+fbol(i)*bin(i)
    fluence_max=fluence_min+fbol_max(i)*bin(i)
    fluence_min=fluence_min+fbol_min(i)*bin(i)

  endfor

  fluence=fluence*(1e-1)
  fluence_max=fluence_max*(1e-1)
  fluence_min=fluence_min*(1e-1)

  flerr_max=fluence_max-fluence
  flerr_min=fluence-fluence_min

  Etot=fluence

  N_f=n_elements(fbol)

;  print,'N_f:',N_f

  flerr_min=flerr_min/sqrt(N_f)
  flerr_max=flerr_max/sqrt(N_f)

;  print,n_elements(fbol)-14.

;  print,flerr_max,flerr_min

  Etot_err=max(flerr_min,flerr_max)

  print,'E_tot=',Etot,' err=',Etot_err


;==============================================
; Touchdown fluence
;==============================================
;Touchdown is determined as time when temp is maximum

  fluence=0.
  fluence_min=0.
  fluence_max=0.
  fsum=0.
  fsum_max=0.
  fsum_min=0.

  if f1_i gt n_elements(fbol)-1 then f1_i=n_elements(fbol)-1

  for i=0,f1_i do begin
    fluence=fluence+fbol(i)*bin(i)
    fluence_max=fluence_min+fbol_max(i)*bin(i)
    fluence_min=fluence_min+fbol_min(i)*bin(i)

  endfor

  fluence=fluence*(1e-1)
  fluence_max=fluence_max*(1e-1)
  fluence_min=fluence_min*(1e-1)
  
  flerr_max=fluence_max-fluence
  flerr_min=fluence-fluence_min
  
  Eint=fluence
  
  N_f=f1_i
;  print,'N_f:',N_f
  
  flerr_max=flerr_max/sqrt(N_f)
  flerr_min=flerr_min/sqrt(N_f)
  
  Eint_err=max(flerr_min,flerr_max)

  print,'E_td=',Eint,' err=',Eint_err
 

;==============================================
; Plotting bursts
;==============================================

  xmax=60.0
  ymax=2.0

    if starttime gt starttime2 then begin
        time2=time2+(starttime-starttime2)
    endif

    if starttime2 gt starttime then begin
        time=time+(starttime2-starttime)
    endif  


    index=where(time gt -1. and time lt xmax)
    plot,[0],[0], xstyle=1,ystyle=1,xrange=[-2.,xmax],yrange=[0.,ymax],thick=0.7,ytitle='Bolometric Flux',title=namef+'!c'+namef2,XTICKFORMAT="(A1)"
    ;calculated bolometric flux
    revtime= REVERSE(time(index))
    revfbol= REVERSE(fbb(index))
    revfbolerr= REVERSE(fbberr(index))
    polytime= [time(index),revtime]
    polyfbol= [fbb(index)-fbberr(index),revfbol+revfbolerr]
    POLYFILL, polytime, polyfbol, col=0,noclip=0,clip=[-2.,0.,xmax,ymax]

    ;measured bolometric flux
    revtime= REVERSE(time(index))
    revfbol= REVERSE(fbol(index))
    revfbolerr= REVERSE(fbolerr(index))
    polytime= [time(index),revtime]
    polyfbol= [fbol(index)-fbolerr(index),revfbol+revfbolerr]
    POLYFILL, polytime, polyfbol, col=4,noclip=0,clip=[-2.,0.,xmax,ymax]

    ;Line showing T1 time
     plots,[time(f1_i),time(f1_i)],[0.,ymax],thick=0.7,linestyle=1,col=0
    ;Line showing T2 time
    plots,[time(f2_i),time(f2_i)],[0.,ymax],thick=0.7,linestyle=1,col=0

    if do_old eq 1 then begin
    index=where(time2 gt -1. and time2 lt xmax)
    revtime= REVERSE(time2(index))
    revfbol= REVERSE(fbol2(index))
    revfbolerr= REVERSE(fbolerr2(index))
    polytime= [time2(index),revtime]
    polyfbol= [fbol2(index)-fbolerr2(index),revfbol+revfbolerr]
    POLYFILL, polytime, polyfbol, col=2,noclip=0,clip=[-2.,0.,xmax,ymax],/LINE_FILL,ORIENTATION=45,SPACING=0.04,THICK=0.9
    POLYFILL, polytime, polyfbol, col=2,noclip=0,clip=[-2.,0.,xmax,ymax],/LINE_FILL,ORIENTATION=135,SPACING=0.04,THICK=0.9
    endif


    legend,['New analysis','Old analysis'],colors=[0,2],charsize=0.6,linestyle=0,/right


    index=where(time gt -1. and time lt xmax+10)
    plot,[0],[0], xstyle=1,ystyle=1,xrange=[-2.,xmax],yrange=[10.,10000.],thick=0.7,ytitle='Normalization',XTICKFORMAT="(A1)", /YLOG
    ;Read and plot kbb with polygons making it ribbon-like 
    revtime= REVERSE(time(index))
    revkbb= REVERSE(kbb(index))
    revkbberr= REVERSE(kbberr(index))
    polytime= [time(index),revtime]
    polykbb= [kbb(index)-kbberr(index),revkbb+revkbberr]
    POLYFILL, polytime, polykbb, col=0,noclip=0,clip=[-2.,0.,xmax,10000.]

    ;Line showing T1 time
     plots,[time(f1_i),time(f1_i)],[10.,10000.],thick=0.7,linestyle=1,col=0
    ;Line showing T2 time
    plots,[time(f2_i),time(f2_i)],[10.,10000.],thick=0.7,linestyle=1,col=0

    if do_old eq 1 then begin
    index=where(time2 gt -1. and time2 lt xmax+10)
    revtime2= REVERSE(time2(index))
    revkbb2= REVERSE(kbb2(index))
    revkbberr2= REVERSE(kbberr2(index))
    polytime2= [time2(index),revtime2]
    polykbb2= [kbb2(index)-kbberr2(index),revkbb2+revkbberr2]
    POLYFILL, polytime2, polykbb2, col=2,noclip=0,clip=[-2.,0.,xmax,10000.],/LINE_FILL,ORIENTATION=45,SPACING=0.04,THICK=0.9
    POLYFILL, polytime2, polykbb2, col=2,noclip=0,clip=[-2.,0.,xmax,10000.],/LINE_FILL,ORIENTATION=135,SPACING=0.04,THICK=0.9
    endif


    index=where(time gt -1. and time lt xmax)
    plot,[0],[0], xstyle=1,ystyle=1,xrange=[-2.,xmax],yrange=[0.0,3.2],thick=0.7,ytitle='Temperature',XTICKFORMAT="(A1)"
    ;Plot tbb 
    revtime= REVERSE(time(index))
    revtbb= REVERSE(tbb(index))
    revtbberr= REVERSE(tbberr(index))
    polytime= [time(index),revtime]
    polytbb= [tbb(index)-tbberr(index),revtbb+revtbberr]
    POLYFILL, polytime, polytbb, col=0,noclip=0,clip=[-2.,0.,xmax,3.2]

    ;Line showing T1 time
     plots,[time(f1_i),time(f1_i)],[0.,3.2],thick=0.7,linestyle=1,col=0
    ;Line showing T2 time
    plots,[time(f2_i),time(f2_i)],[0.,3.2],thick=0.7,linestyle=1,col=0

    if do_old eq 1 then begin
    index=where(time2 gt -1. and time2 lt xmax)
    revtime= REVERSE(time2(index))
    revtbb= REVERSE(tbb2(index))
    revtbberr= REVERSE(tbberr2(index))
    polytime= [time2(index),revtime]
    polytbb= [tbb2(index)-tbberr2(index),revtbb+revtbberr]
    POLYFILL, polytime, polytbb, col=2,noclip=0,clip=[-2.,0.,xmax,3.2],/LINE_FILL,ORIENTATION=45,SPACING=0.04,THICK=0.9
    POLYFILL, polytime, polytbb, col=2,noclip=0,clip=[-2.,0.,xmax,3.2],/LINE_FILL,ORIENTATION=135,SPACING=0.04,THICK=0.9
    endif


    index=where(time gt -1. and time lt xmax)
     plot,[0],[0], xstyle=1,ystyle=1,xrange=[-2.,xmax],yrange=[0.0,5.],thick=0.7,ytitle='chi^2',xtitle='Time (s)'  
    ;Plot chi with histogram
    oplot,time(index)+((bin(index))/2.),chi(index),col=0,thick=1.5,psym=10
    ;Line showing T1 time
     plots,[time(f1_i),time(f1_i)],[0.,5.],thick=0.7,linestyle=1,col=0
    ;Line showing T2 time
    plots,[time(f2_i),time(f2_i)],[0.,5.],thick=0.7,linestyle=1,col=0
    ;Line y=1
     plots,[-2.,xmax],[1.,1.],thick=0.7,linestyle=1,col=0   

    if do_old eq 1 then begin
    index=where(time2 gt -1. and time2 lt xmax)
    oplot,time2(index)+((bin2(index))/2.),chi2(index),col=2,thick=1.5,psym=10
    endif


endfor


print,' '
print,'postscript plot saved to file ',fname

DEVICE,/close


end

