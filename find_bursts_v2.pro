;###########################################################################
pro readlc,namef,time,rate,nx

;nx=file_lines(namef)

close,1
openr,1,namef
comments=""

readf,1,comments
readf,1,comments

ab=dblarr(4)

time=dblarr(nx) 
rate=dblarr(nx) 

;print,nx
for i=0,nx-1-2 do begin
;print,i
   readf,1,ab 
;    print,'ab is',ab
   time(i)=ab(0)
   rate(i)=ab(1)
;    print,'time is',time(i)
;    print,'rate is',rate(i)

endfor

close,1

index=where(time ne 0)
time=time(index)
rate=rate(index)

return
end 
;##################################################################
;##################################################################
;##################################################################
;pro find_bursts

;##################################################################
;Initial Setup
!P.MULTI=0


listfile='obsid_lc.list'

SET_PLOT,'X'

first_flag=1

;jncol
colors

burstlist=['']
tstartlist=['']
tstoplist=['']
avglist=['']
fsiglimlist=['']
burstchecklist=['']

;##################################################################
;Reading a list of input files
openr,1,listfile
k=0
temp=' '
files=strarr(10000)

while not eof(1) do begin
  readf,1,temp
  files[k]=temp
  k=k+1
endwhile
close,1
files=files[0:k-1]

;THIS IS FOR TESTING
;files=files[0]


;##################################################################
for ifl=0,n_elements(files)-1 do begin 

   namef=files[ifl]
if file_test(namef) eq 1 then begin

   nx=file_lines(namef)
   readlc,namef,time,rate,nx


   time_all=time
   rate_all=rate

nt=n_elements(time_all)-1
xmin_all=min(time_all)
xmax_all=max(time_all)
ymin_all=0.95*min(rate_all)
ymax_all=1.2*max(rate_all)

;mresult=moment(rate_all)
;fsiglim=mresult(0)+4*sqrt(mresult(1))
;tsiglim=mresult(0)+2*sqrt(mresult(1))


a=''
b=''
flag=1
while flag eq 1 do begin

nt=n_elements(time)-1
xmin=time(0)
xmax=time(nt)

mresult=moment(rate)
fsiglim=mresult(0)+4*sqrt(mresult(1))
tsiglim=mresult(0)+2*sqrt(mresult(1))

  index=where(rate gt fsiglim)
  
;  print,index
  stest=size(index)
;  print,stest

  if stest(0) eq 0 then begin
    flag=0
  endif else begin
;    print,'**********************'
    print,'Found burst candidate!'
;    print,namef

    tstart=time(index(0))-10
    tstop=time(index(0))+80

    index_b=where(time gt tstart and time lt tstop and rate gt tsiglim) 
    tstartb=time(index_b(0))-4.

    Ntime = n_elements(index_b)-1
    tstopb=time(index_b(Ntime))+30.

    if tstartb lt xmin_all then tstartb=xmin_all
    if tstopb gt xmax_all then tstopb=xmax_all

;    print,'Start time=',tstartb
;    print,'Stop time=',tstopb
;    print,'Length=',tstopb-tstartb

    burstlist=[burstlist,namef]
    tstartlist=[tstartlist,tstartb]
    tstoplist=[tstoplist,tstopb]
    avglist=[avglist,mresult[0]]
    fsiglimlist=[fsiglimlist,fsiglim]
    burstchecklist=[burstchecklist,1.]

    ;remove first element if there the lenght of array is 2
    if n_elements(burstlist) eq 2 && first_flag eq 1 then begin
       burstlist = burstlist[1]
       tstartlist = tstartlist[1]
       tstoplist = tstoplist[1]
       avglist = avglist[1]
       fsiglimlist = fsiglimlist[1]
       burstchecklist = burstchecklist[1]

       ;set flag
       first_flag = 0
    endif


    print,'Burst candidate appended to list'

    index2=where(time lt tstartb-20. or time gt tstopb+40.)
    time=time(index2)
    rate=rate(index2)
  endelse
endwhile
endif
endfor
print,'Ready'
print,'#################################################'
;########################################################

;loop lc until user stops
nn=n_elements(burstlist)-1.
i=0
flag=1
while flag eq 1 do begin

   namef=burstlist[i]
   nx=file_lines(namef)
   readlc,namef,time,rate,nx

   time_all=time
   rate_all=rate

   nt=n_elements(time_all)-1
   xmin_all=min(time_all)
   xmax_all=max(time_all)
   ymin_all=0.95*min(rate)
   ymax_all=1.2*max(rate)

   mresult=avglist[i]
   fsiglim=fsiglimlist[i]
   tstartb=tstartlist[i]
   tstopb=tstoplist[i]

   tstart=tstartb-10.
   tstop=tstopb+80.

   minmax_index=where(time_all gt tstart and time_all lt tstop)
   ymin=0.95*min(rate_all(minmax_index))
;   ymin=0.98*min(ymin,mresult)

   ymax=1.2*max(rate_all(minmax_index))

    print,'**********************'
;    print,'Found burst candidate!'
    print,namef
    print,'Start time=',tstartb
    print,'Stop time=',tstopb
    print,'Length=',tstopb-tstartb
    print,'Mean rate=',mresult

   ;PLOT THE WHOLE LIGHTCURVE
   plot,time_all,rate_all,xrange=[xmin_all,xmax_all],yrange=[ymin_all,ymax_all],position=[0.6,0.6,0.95,0.9],xtickname=REPLICATE(' ', 3),xticks=2,ytickname=REPLICATE(' ', 3),yticks=2
   oplot,[xmin_all,xmax_all],[fsiglim,fsiglim],linestyle=1
;   arrow,tstartb,ymax_all*0.9,tstartb,ymax_all*0.5
   xyouts,tstartb,ymax_all*0.9,'V',charsize=3,/DATA

    ;PLOT THE BURST   
    plot,time,rate,xtitle="Time",ytitle="Rate",xrange=[tstart,tstop],yrange=[ymin,ymax],title=namef,/noerase
;    plot,time,rate,xtitle="Time",ytitle="Rate",xrange=[tstart,tstop],title=namef,/noerase

    oplot,[xmin_all,xmax_all],[mresult,mresult],linestyle=0
    oplot,[xmin_all,xmax_all],[fsiglim,fsiglim],linestyle=1

    oplot,[tstartb,tstartb],[ymin_all,ymax_all],linestyle=1
    oplot,[tstopb,tstopb],[ymin_all,ymax_all],linestyle=1

    if burstchecklist[i] eq 0 then begin
      	  xyouts,0.2,0.7,'REMOVED',/NORMAL,charsize=10.
    endif

    a=''
    read,a,prompt='Next (Enter) or Previous (P) burst or Erase (E) from list or Correct (C) or Quit (Q)?'

    if a eq 'q' then begin
      flag=0
    endif else begin
    ;Main user interface starts here

      ;NEXT
      if a eq '' then begin
	if i eq nn then begin
	  print,'End of list, cant go forward'
	endif else begin
	  i++
	endelse
      endif
    
      ;PREVIOUS
      if a eq 'p' then begin
	if i eq 0 then begin
	  print,'Start of list, cant go backward'
	endif else begin
	  i--
	endelse
      endif      

      ;ERASE
      if a eq 'e' then begin
	if burstchecklist[i] eq 1 then begin
	  print,'Burst candidate removed from list'
	  burstchecklist[i]=0.
	  if i eq nn then begin
	    print,'End of list, cant go forward'
	  endif else begin
	    i++
	  endelse
	endif else begin
	  print,'Burst candidate appended again to list'
	  burstchecklist[i]=1.
	endelse
      endif   

      if a eq 'c' then begin
	  ;Setting start and stop using cursor
	  print,'Click the start of the burst'
	  CURSOR,tstartb,mousey, /DATA, /DOWN  
	  oplot,[tstartb],[mousey],psym=7
	  print,'Click the stop of the burst'
	  CURSOR,tstopb,mousey2, /DATA, /DOWN  
	  oplot,[tstopb],[mousey2],psym=7
	  oplot,[tstartb,tstopb],[mousey,mousey]
	  print,'New start and stop times set'

	  tstartlist(i)=tstartb
	  tstoplist(i)=tstopb
      endif

    ;Main user interface stops here
    endelse

    

endwhile

;########################################################


print,'List of obsids with bursts'
for i=0,n_elements(burstlist)-1 do begin
  if burstchecklist(i) eq 1 then begin
    print,burstlist(i),tstartlist(i),tstoplist(i)
  endif
endfor


openw,3,'burst_list.txt',WIDTH=1000
for i=0,n_elements(burstlist)-1 do begin
  if burstchecklist(i) eq 1 then begin
    printf,3,burstlist(i),' ',string(tstartlist(i),Format='(3I0)'),' ',string(tstoplist(i),Format='(3I0)')
  endif
endfor
close,3

end
