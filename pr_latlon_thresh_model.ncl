load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

;  
; This script reads daily observed precipitation from Historical
; Climate Network sites and creates frequency distributions of 
; precipitation events falling within a range of continuous "bins."  
; Data are aggregated into a latitude-longitude grid.
;
; Input files:
;   - Daily precipitation data are contained in "infile.nc". 
; Usually these file names will be symbolic links to the actual files.
; 
; Output file:
;   - An array of counts in each bin and an array giving the upper
;     limit of each corresponding bin will be written to "binned.nc".
;
; Call the script as follows:
;
;  ncl -Q start_year=${start_year} end_year=${end_year} select_season=${season} prbins.ncl
;
;     start_year and end_year are integer values, e.g., 1951 and 2005 or other desired years
;     season is one of \"warm\", \"cool\", or \"year\".  The desired season MUST be enclosed
;       in quotes, and the quote marks MUST be escaped with backslashes as shown.

begin



;
;  *******************************************************************
;
;                     USER SETTABLE PARAMETERS
;
;  *******************************************************************
;

; Max and min lat/lon

latlon = asciiread ("latlon.in", -1, "float")
latmin = latlon(0)
latmax = latlon(1)
lonmin = latlon(2)
lonmax = latlon(3)

; Ensure lons are degreese east

print ("latmin, latmax, lonmin, lonmax "+latmin+" "+latmax+" "+lonmin+" "+lonmax)
lonmin = mod ((lonmin+360.), 360.)
lonmax = mod ((lonmax+360.), 360.)

; check if lat/lon are flipped

if (lonmin .gt. lonmax) then
  ltmp = lonmin
  lonmin = lonmax
  lonmax = ltmp
end if

print ("latmin, latmax, lonmin, lonmax "+latmin+" "+latmax+" "+lonmin+" "+lonmax)

; Start and end year, and season

;  for 'rcp85' simulations
 start_year = 2075
 end_year = 2099

;  for 'hist' simulations
;start_year = 1981
;end_year = 2005

;  for 'eval' simulations (ERA-Interim driven)
 start_year = 1990
 end_year = 2009

select_season = "warm"

; Set minimum value for measurable precip (mm/day). Below this is considered trace.

trace = 0.254           
trace@long_name = "precip_lower_limit"
trace@units = "mm d-1"


do_exceed = False
do_pdf_region = True

thresh = (/ 1., 25.4, 25.4 * 2 /)                ; precipitation thresholds
nthresh = dimsizes (thresh)
thresh!0 = "nthresh"

print (thresh)


; *****************   
; *****************     end user settable parameters
; *****************  

; Report the arguments that this script was called with
 
print ("start_year = "+start_year+" end_year = "+end_year+"  select_season = "+select_season)

; Check that the season is an allowable value

if (select_season.ne."warm" .and.  select_season.ne."cool" .and.  select_season.ne."year") then
  print ("STOP - Unknown season "+select_season)
end if

print ("lonmin, lonmax = "+lonmin+"  "+lonmax)
print ("latmin, latmax = "+latmin+"  "+latmax)

;   Arrays to hold output

;nxceed = new ( (/nthresh,nlat,nlon/), "integer")
;nxceed!0 = "nthresh"
;nxceed!1 = "y"
;nxceed!2 = "x"
;nxceed = 0
;
;printVarSummary (nxceed)
;
;nrecs = nxceed(0,:,:)
;
;freq = int2flt (nxceed)

;   Open file for input

f1 = addfile ("infile.nc", "r")
prt = f1->pr(0,:,:)

printVarSummary (prt)

;   Create output file and define dimensions

f2 = addfile ("binned_model.nc", "c")

;dimNames = (/"lat", "lon"  /)     ; dimension names
;dimSizes = (/ nlat,  nlon  /)     ; dimension sizes
;dimUnlim = (/ False, False /)     ; unlimited dimension
;filedimdef(f2, dimNames  , dimSizes,  dimUnlim )


;    Get the times in this file.

timein = f1->time
nt = dimsizes (timein)

; Turn the time into an understandable calendar date

cal = cd_calendar (timein, -5)  ; note year = calendar(:,0) and month is calendar (:,1)

; itstart is the first record in the starting year.
; Report the year corresponding to this record.

  itstart = get1Dindex (cal(:,0), start_year)

  print ("itstart "+itstart)

  print ("Starting record: itstart, year = "+itstart+"   "+cal(itstart,0))

  if (itstart .gt. 0) then
    print ("Year for record (itstart-1) = "+cal(itstart-1,0))
  end if

; Find the ending record

  itend = nt - 1

  if (cal(nt-1,0) .gt. end_year) then
    itend = max (ind(cal(:,0).eq.end_year))
  end if

  print ("Ending record: itend, year = "+itend+"   "+cal(itend,0))
  if (itend .lt. (nt-1)) then
    print ("Year for record (itend+1) = "+cal(itend+1,0))
  end if

;   Loop over grid points

  xlat = f1->lat
  xlon = f1->lon

;   Convert longitude to degrees east

  xlon = xlon + 360.
  xlon = mod (xlon, 360.)

  dimsz = dimsizes (xlat)
  ny = dimsz(0)
  nx = dimsz(1)

  print ("nx, ny = "+nx+"  "+ny)

;------------------------------------------------------------

  if (do_exceed) then

;  Total the number of data points and exceedences in each grid cell
;  and compute frequency of exceedence.


;  do j = 0, (ny-1)
;    do i = 0, (nx-1)
;      flat = (xlat(j,i)-latmin) / dlat
;      jj = round (flat,3)
;      if (jj.ge.0 .and. jj.le.(nlat-1)) then
;        flon = (xlon(j,i)-lonmin) / dlon
;        ii = round (flon,3)
;        if (ii.ge.0 .and. ii.le.(nlon-1)) then
;          print ("j,i  "+j+"  "+i+"  jj,ii "+jj+"  "+ii+" lon, lat = "+xlon(j,i)+"  "+xlat(j,i))
;          pr = f1->pr(itstart:itend,j,i)
;          numt = dimsizes(pr)
;          print ("numt = "+numt)
;          nrecs(jj,ii) = nrecs(jj,ii) + numt
;          pr = pr * 86400.                        ;  convert precip to mm/day
;          do ith = 0, (nthresh-1)
;            numx = num (pr .gt. thresh(ith)) 
;            nxceed(ith,jj,ii) = nxceed(ith,jj,ii) + numx
;          end do
;          print ("numx, numt = "+numx+"  "+numt)
;        end if
;      end if
;    end do
;  end do

; f2->nrecs = nrecs
; f2->nxceed = nxceed

; freq = int2flt (nxceed)

; do ith = 0, (nthresh-1)
;   freq(ith,:,:) = int2flt (nxceed(ith,:,:)) / int2flt (nrecs)
; end do

; f2->freq   = freq

  end if    ; end if for computing exceedences

;------------------------------------------------------------


;printVarSummary( zpdf )
;print ("Bin center and bounds")
;print (zpdf@bin_center)
;print ("Bin bounds")
;print (zpdf@bin_bounds)
;

;nn = dimsizes (zpdf)

;do j = 0, (nn-1)
;  print (zpdf(j)+"  "+npdf(j))
;end do

;npts = sum(npdf)
;zpts = sum(zpdf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if (do_pdf_region) then

; Set up bins for pdf

  opt = True
  opt@bin_spacing = 2.
  opt@bin_min =  0.
  opt@bin_max =  500.

  xbins = (opt@bin_max - opt@bin_min) / opt@bin_spacing
  print ("xbins = "+xbins)

  nbins = round (xbins, 3)

  num_bin = new (nbins, double)
  num_bin!0 = "nbins"
  num_bin@long_name = "number of events in each intensity bin"
  num_bin = 0

  bin_center = new (nbins, double)
  bin_center!0 = "nbins"
  bin_center@long_name = "center value of intensity bin"
  bin_center@units = "mm d-1"
  bin_center = 0

  bin_bounds = new (nbins+1, double)
  bin_bounds!0 = "nbounds"
  bin_bounds@long_name = "bounds of intensity bin"
  bin_bounds@comment = "lowest bound should equal trace"
  bin_bounds@units = "mm d-1"
  bin_bounds = 0

  printVarSummary (num_bin)
  printVarSummary (bin_center)

  nmax_tot = 0
  nuse_tot = 0
  nlo_tot = 0
  nhi_tot = 0
  numt_tot = 0
  numpr_tot = 0
  numtrace_tot = 0
  numpoints = 0

  points_lat = new (50000, typeof(xlat))
  points_lon = new (50000, typeof(xlon))

;  npdf = number of events in each bin for this grid point
;  numpdf = total number of events summed over all bins for this grid point
;  num_bin = number of events in each bin accumulated over all grid points
;  num_bin_tot = total number of events summed over all bins and grid points
;  nmax_tot = total number of non-missing (i.e., non-trace) values, accumulated over all grid points
;  nuse_tot = total number of values used (i.e., lying within the bin limits), accumulated over all grid points
;  nlo_tot = total number of values below the lowest bin, accumulated over all grid points (should always be zero)
;  nhi_tot = total number of values above the highest bin, accumulated over all grid points 

  do j = 0, (ny-1)
    do i = 0, (nx-1)
      flag = 0
      lat = xlat(j,i)
      lon = xlon(j,i)
      lon = mod (lon + 360., 360.)          ;    convert to degrees east
; check if lat is within our region
      if ((lat.lt.latmin) .or. (lat.gt.latmax)) then
;       print (fin+"  not in target region")
        continue
      end if
; check if lon is within our region
      if ((lon.lt.lonmin) .or. (lon.gt.lonmax)) then
;       print (fin+"  not in target region "+lat+"  "+lon)
        continue
      end if
      time = f1->time
      nt = dimsizes (time)
      cale = cd_calendar (time, -5)
      pr_in = f1->pr(:,j,i)
; use only warm season
      if (select_season .eq. "warm") then
        prind = ind (cale(:,0).ge.start_year .and. cale(:,0).le.end_year .and. cale(:,1).ge.4 .and. cale(:,1).le.9)
        pr = pr_in(prind)
        pr@_FillValue = -999.
      end if
;
; at this point we have a grid point within our target region
;
      flag = 1
      numpoints = numpoints + 1
      points_lat(numpoints-1) = (/ lat /)
      points_lon(numpoints-1) = (/ lon /)
      pr = pr * 86400.                             ;  convert precip to mm/day
      pr = where (pr.gt.trace, pr, pr@_FillValue)  ;  ignore values below cutoff (trace) by setting them to missing
      numpr = num (.not.ismissing(pr))             ;  number of non-trace values at this grid point
      numtrace = num (ismissing(pr))               ;  number of trace values at this grid point
      numt = dimsizes(pr)                          ;  number of values at this grid point, both trace and non-trace (equals number of time steps)
      numpr_tot = numpr_tot + numpr                ;  accumulate number of non-trace values over all grid points
      numtrace_tot = numtrace_tot + numtrace       ;  accumulate number of trace values
      numt_tot = numt_tot + numt                   ;  accumulate total number of values over all grid points
      pr_pdf = pdfx(pr, nbins, opt)                 ;  compute pdf here -- note pdfx computes pdf as percent
      npdf = pr_pdf@nMax * pr_pdf / 100            ;  convert percent to counts
      nmax_tot = nmax_tot + pr_pdf@nMax            ;  nMax is how many non-missing values were input
      nuse_tot = nuse_tot + pr_pdf@nUse            ;  nUse is how many values were used in the pdf, i.e., within the bin ranges
      nehi = 0
      nelo = 0
      if (isatt(pr_pdf,"nLoOut")) then
        nelo = pr_pdf@nLoOut                 ;  number of values at this grid point that are below the lowest bin
      end if
      nlo_tot = nlo_tot + nelo               ;  accumulate number of values below lowest bin
      if (isatt(pr_pdf,"nHiOut")) then
        nehi = pr_pdf@nHiOut
      end if
      nhi_tot = nhi_tot + nehi               ;  number of values at this grid point that are above highest bin
      num_bin = num_bin + npdf               ;  add counts to accumulator bins
      pr_max = max (pr)
      num_bin_tot = sum (num_bin)
      numpdf = sum (npdf)
      print ("numpdf, num_bin_tot, nmax_tot, nuse_tot, nlo_tot, nhi_tot, lat, lon "+numpdf+"  "+num_bin_tot+"  "+nmax_tot+"  "+nuse_tot+"  "+nlo_tot+"  "+nhi_tot+"  "+pr_max+" "+nehi+"  "+lat+"  "+lon)

      if (numpoints .eq. 1) then
        bin_center = pr_pdf@bin_center
        bin_bounds = pr_pdf@bin_bounds
      end if
      if (flag .eq. 1) then
        delete (pr)
        delete (pr_pdf)       ;     for good measure
      end if

;   if (numpoints .gt. 3) then
;     break                  ;  bail out of the lon loop
;   end if

    end do           ; end lon loop

;   if (numpoints .gt. 3) then
;     break                  ;  bail out of the lat loop
;   end if
  end do             ; end lat loop

end if


;    Done.  Prepare to write output.


  print ("numpoints  "+numpoints)

  printVarSummary (numpoints)

  do jpts = 0, (numpoints-1)
    print ("lat, lon  "+points_lat(jpts)+"  "+points_lon(jpts))
  end do

  print ("num_bin_tot, nmax_tot, nuse_tot, nlo_tot, nhi_tot "+num_bin_tot+"  "+nmax_tot+"  "+nuse_tot+"  "+nlo_tot+"  "+nhi_tot)
  print ("numt_tot, numpr_tot, nuntrace_tot  "+numt_tot+"  "+numpr_tot+"  "+numtrace_tot)

  printVarSummary (points_lat)
  printVarSummary (points_lon)

  lat_points = new (numpoints, typeof(points_lat))
  lon_points = new (numpoints, typeof(points_lon))

  lat_points = points_lat(0:numpoints-1)
  lon_points = points_lon(0:numpoints-1)
  lat_points!0 = "numpoints"
  lon_points!0 = "numpoints"
  lat_points@units = xlat@units
  lon_points@units = xlon@units
  lat_points@long_name = "latitude of data points used"
  lon_points@long_name = "longitude of data points used"
  lat_points@units = "degrees north"
  lon_points@units = "degrees east"

  bin_center!0 = "nbins"

  printVarSummary (numpoints)

  f2->num_bin = num_bin
  f2->lat_points = lat_points
  f2->lon_points = lon_points
  f2->bin_center = bin_center
  f2->bin_bounds = bin_bounds

; print (trace)
  trace!0 = "ncl_scalar"
; print (trace)

  numt_tot!0 = "ncl_scalar"
  numpr_tot!0 = "ncl_scalar"
  numtrace_tot!0 = "ncl_scalar"

  latmin!0 = "ncl_scalar"
  latmax!0 = "ncl_scalar"
  lonmin!0 = "ncl_scalar"
  lonmax!0 = "ncl_scalar"

  latmin@long_name = "south limit of latitude"
  latmax@long_name = "north limit of latitude"
  lonmin@long_name = "west limit of longitude"
  lonmax@long_name = "east limit of longitude"

  latmin@units = "degrees north"
  latmax@units = "degrees north"
  lonmin@units = "degrees east"
  lonmax@units = "degrees east"

  numt_tot@long_name = "total number of data values"
  numpr_tot@long_name = "number of values with precipitation trace or above"
  numtrace_tot@long_name = "number of values with precipitation less than trace"

  f2->trace = trace
  f2->numt = numt_tot                  
  f2->numpr = numpr_tot                 ;  accumulate number of non-trace values
  f2->numtrace = numtrace_tot
  f2->latmin = latmin
  f2->latmax = latmax
  f2->lonmin = lonmin
  f2->lonmax = lonmax

  print ("Preparing to copy global attributes")
  copy_VarAtts(f1, f2)             ;   copy global attributes from input to output
  print ("Copied global attributes")

;  more global attributes
 
  globalAtt = True
  globalAtt@start_year = start_year
  globalAtt@end_year = end_year
  fileattdef (f2, globalAtt)

  exit 

;         num_bins(:,jj,ii) = num_bins(:,jj,ii) + npdf
;         print ("numx, numt = "+numx+"  "+numt)

;------------------------------------------------------------


  print ("Done.")


  printVarSummary (lat)
  printVarSummary (lon)

; f2->lat = lat
; f2->lon = lon



end
