**TO DO: 
*Put in tests for xtreg
*write helpfile


*! gets: General to specific algorithm for model selection
*! Version 1.1.0julio 8, 2013 @ 10:40:09
*! Author: Damian C. Clarke
*! Department of Economics
*! The University of Oxford
*! damian.clarke@economics.ox.ac.uk

cap program drop gets
program gets, eclass
	#delimit ;
	syntax varlist(min=2 fv ts) [if] [in] [pweight fweight aweight iweight]
	[,
	vce(name) 
	xt(name) 
	ts
	NODIAGnostic
	tlimit(real 1.96)
	verbose
	NUMSearch(integer 5)
	NOPARTition
	noserial
	]
	;
	#delimit cr	

	if "`if'"!="" {
		preserve
		qui keep `if'
	}	
	****************************************************************************
	*** (0) Setup base definitions
	****************************************************************************
	tempvar resid chow group
	if "`xt'"!="" {
		local regtype xtreg
		local unabtype fvunab
	}
	else if "`ts'"!="" {
		local regtype reg
		local unabtype fvunab
	}
	else {
		local regtype reg	
		local unabtype fvunab
	}
	
	if "`xt'"!=""&"`ts'"!="" {
		dis "Cannot specify both time-series and panel model. Select only one."
		exit 111
	}

	local DH "Doornik-Hansen test rejects normality of errors in the GUM."
	local BP "Breusch-Pagan test rejects homoscedasticity of errors in the GUM."
	local RESET "The RESET test rejects linearity of covariates."
	local CHOW "The in-sample Chow test rejects equality of coefficients"
	local ARCH "The test for ARCH components is not rejected."
	local SERIAL "The test for no autocorrelation in panel data is rejected"
	local RE "The LM test for Random Effects is rejected"

	local m2 "Breusch-Pagan test for homoscedasticity of errors not rejected."
	local m3 " Dornik-Hansen test for normality of errors not rejected."
	local m4 " RESET test for misspecification not rejected."
	local m5 " In-sample Chow test for equality of coefficients not rejected."
	local m6 " Continuing analysis."
	local m7 " The presence of (1 and 2 order) ARCH components is rejected."
	local m8 " There does not appear to be autocorrelation in panel data."
	local m9 " The LM test for Random Effects is not rejected."

	local mspec "Respecify using nodiagnostic if you wish to continue without"
	local ms2 "specification tests. This option should be used with caution"

	local runnumber=0
	****************************************************************************
	*** (1) Test unrestricted model for misspecification
	****************************************************************************
	fvexpand `varlist'
	local varlist `r(varlist)'
	tokenize `varlist'
	local y `1'
	macro shift
	local x `*'
	local numxvars : list sizeof local(x)


	if "`nodiagnostic'"=="" {
		**************************************************************************
		*** (1a) Cross sectional model
		**************************************************************************
		if "`xt'"==""&"`ts'"=="" {
			local p=0
			local q=0

			qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			predict `resid', residuals
			qui mvtest normality `resid'
			drop `resid'
			local ++q
		
			if r(p_dh)<0.05 {
				display as error "`DH'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p_dh)>=0.05 {
				local testDH yes
				local pass `m3'
				local ++p
			}

			qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			qui estat ovtest
			local ++q

			if r(p)<0.05 {
				display as error "`RESET'"
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p)>=0.05 {
				local testRESET yes
				local pass `pass' `m4'
				local ++p
			}

			if "`vce'"=="" {
				qui estat hettest
				local ++q

				if r(p)<0.05 {
					display as error "`BP'" 
					display as error "`mspec' `ms2'."
					display as error ""
				}
				else if r(p)>=0.05 {
					local testBP yes
					local pass `pass' `m2'
					local ++p
				}
			}

			qui gen `chow'=rnormal()
			sort `chow'
			qui count	
			local halfsample=round(r(N)/2)
			qui gen `group'=1 in 1/`halfsample'
			qui replace `group'=2 if `group'!=1
			cap qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			if _rc!=0 {
				dis as error "In sample Chow test failed"
				dis as error "Make sure to specify ts or xt if not cross-sectional data"
				exit 5
			}
			local rss_pooled=e(rss)
			qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
			local rss_1=e(rss)
			local n_1=e(N)
			qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
			local rss_2=e(rss)
			local n_2=e(N)
			local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
			local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
			local chowstat=`num_chowstat'/`den_chowstat'
			local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
			local ++q
			if `FChow'<0.05 {
				display as error "`CHOW'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p)>=0.05 {
				local testCHOW yes
				local pass `pass' `m5'
				local ++p
			}

			local fails=`q'-`p'
			local m1 "The GUM fails `fails' of `q' misspecification tests. "
			display "`m1' `pass'"
			if `fails'>= 2 {
				dis "This GUM performs poorly. Care should be taken in interpretation."
			}
			display ""
		}

		**************************************************************************
		*** (1b) panel model
		**************************************************************************
		if "`xt'"!="" {
			local p=0
			local q=0
			qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			predict `resid', e
			qui mvtest normality `resid'
			drop `resid'
			local ++q
		
			if r(p_dh)<0.05 {
				display as error "`DH'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p_dh)>=0.05 {
				local testDH yes
				local pass `m3'
				local ++p
			}

			if "`noserial'"=="" {
				cap which xtserial
				if _rc!=0 {
					local e1 "Use of panel data and diagnostic tests requires the"
					local e2 "user-written package xtserial.  Please install by typing:"
					dis "`e1' `e2'"
					dis "net sj 3-2 st0039"
					dis "net install st0039"
					dis "or respecify with the nodiagnostic option."
					exit 111
				}

				cap xtserial `y' `x' `if' `in'
				if _rc!=0&_rc==101 {
					local e1 "serial correlation tests with panel data do not allow factor"
					local e2 "factor variables and time-series operators.  Either respecify"
					local e3 "without these options, or use the noserial option"
					dis 
				}
				else if _rc!=0&_rc!=101 {
					qui xtserial `y' `x' `if' `in'
				}
				else if _rc==0{
					local ++q
					if r(p)<0.05 {
						display as error "`SERIAL'" 
						display as error "`mspec' `ms2'."
						display as error ""
					}
					else if r(p_dh)>=0.05 {
						local testSERIAL yes
						local pass `m8'
						local ++p
					}
				}
			}		

			if "`xt'"=="re" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				qui xttest0
				local ++q
				if r(p)<0.05 {
					display as error "`RE'" 
					display as error "`mspec' `ms2'."
					display as error ""
				}
				else if r(p_dh)>=0.05 {
					local testRE yes
					local pass `m9'
					local ++p
				}
			}

			qui count	
			local halfsample=round(r(N)/2)
			qui gen `group'=1 in 1/`halfsample'
			qui replace `group'=2 if `group'!=1
			cap qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			local rss_pooled=e(rss)
			qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
			local rss_1=e(rss)
			local n_1=e(N)
			qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
			local rss_2=e(rss)
			local n_2=e(N)
			local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
			local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
			local chowstat=`num_chowstat'/`den_chowstat'
			local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
			local ++q
			if `FChow'<0.05 {
				display as error "`CHOW'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p)>=0.05 {
				local testCHOW yes
				local pass `pass' `m5'
				local ++p
			}

			local fails=`q'-`p'
			local m1 "The GUM fails `fails' of `q' misspecification tests. "
			display "`m1' `pass'"
			if `fails'>= 2 {
				dis "This GUM performs poorly. Care should be taken in interpretation."
			}
			display ""
		}
		**************************************************************************
		*** (1c) time-series model
		**************************************************************************
		if "`ts'"!="" {	
			local p=0
			local q=0

			qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			predict `resid', residuals
			qui mvtest normality `resid'
			local ++q
		
			if r(p_dh)<0.05 {
				display as error "`DH'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p_dh)>=0.05 {
				local testDH yes
				local pass `m3'
				local ++p
			}

			tempvar resid_sq
			qui gen `resid_sq'=`resid'^2
			qui reg `resid_sq' l.`resid_sq' l2.`resid_sq'
			qui test l.`resid_sq' l2.`resid_sq'
			drop `resid' `resid_sq'
			local ++q

			if r(p)<0.05 {
				display as error "`ARCH'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p)>=0.05 {
				local testARCH yes
				local pass `pass' `m7'
				local ++p
			}


			if "`vce'"=="" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				qui estat hettest
				local ++q

				if r(p)<0.05 {
					display as error "`BP'" 
					display as error "`mspec' `ms2'."
					display as error ""
				}
				else if r(p)>=0.05 {
					local testBP yes
					local pass `pass' `m2'
					local ++p
				}
			}

			qui count	
			local halfsample=round(r(N)/2)
			qui gen `group'=1 in 1/`halfsample'
			qui replace `group'=2 if `group'!=1
			cap qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
			local rss_pooled=e(rss)
			qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
			local rss_1=e(rss)
			local n_1=e(N)
			qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
			local rss_2=e(rss)
			local n_2=e(N)
			local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
			local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
			local chowstat=`num_chowstat'/`den_chowstat'
			local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
			local ++q
			if `FChow'<0.05 {
				display as error "`CHOW'" 
				display as error "`mspec' `ms2'."
				display as error ""
			}
			else if r(p)>=0.05 {
				local testCHOW yes
				local pass `pass' `m5'
				local ++p
			}

			local fails=`q'-`p'
			local m1 "The GUM fails `fails' of `q' misspecification tests. "
			display "`m1' `pass'"
			if `q'-`p'>= 2 {
				dis "This GUM performs poorly. Care should be taken in interpretation."
			}
			display ""
		}
	}

	****************************************************************************
	*** (2) Run regression for underlying model
	****************************************************************************		
	foreach searchpath of numlist 1(1)`numsearch' {
		qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
		global Fbase=e(F)
		qui dis "the base F is" $Fbase
		local next= `searchpath'+1
		
		**************************************************************************
		*** (3) Sort by t-stat, remove least explanatory variable from varlist
		**************************************************************************
		mata: tsort(st_matrix("e(b)"), st_matrix("e(V)"), `searchpath')
		local num e(var)
		local t = e(t)
		
		tokenize `varlist'  // find lowest t-value variable
		macro shift
		qui dis "```num'''"
		qui dis "The lowest t-value is " in green e(t) in yellow " and is variable " in green "```num'''"
		local remove ```num'''
		
		tokenize `varlist'  // remove lowest t-value variable
		macro shift

		cap `unabtype' varlist : `varlist'
		if _rc!=0 {
			dis as error "factor variables and time-series operators not allowed"
			dis as error "Make sure to specify ts or xt if not cross-sectional data"
			exit 101
		}
		`unabtype' exclude : `remove' `y'
		qui local newvarlist : list varlist - exclude

		**************************************************************************
		*** (3a) Tests
		**************************************************************************
		local results=0		
		qui `regtype' `y' `newvarlist' `if' `in' [`weight' `exp'], `vce'
		if e(F)>$Fbase {
			qui dis "New F improves on GUM.  Keep going"
		}
		else if e(F)<$Fbase {
			dis as error "This model does not improve the F-statistic"
			local ++results
		}

		**************************************************************************
		*** (3ai) Cross section
		**************************************************************************
		if "`xt'"==""&"`ts'"=="" {
			if `"`testBP'"'=="yes" {
				qui estat hettest
				local BPresult=r(p)
				if `BPresult'<0.05 local ++results
			}
			if `"`testRESET'"'=="yes" {
				qui estat ovtest
				local RESETresult=r(p)
				if `RESETresult'<0.05 local ++results
			}
			if `"`testDH'"'=="yes" {
				tempvar resid
				predict `resid', residuals
				qui mvtest normality `resid'
				drop `resid'
				local DHresult=r(p_dh)
				if `DHresult'<0.05 local ++results
			}
			if `"`testCHOW'"'=="yes" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				local rss_pooled=e(rss)
				qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
				local rss_1=e(rss)
				local n_1=e(N)
				qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
				local rss_2=e(rss)
				local n_2=e(N)
				local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
				local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
				local chowstat=`num_chowstat'/`den_chowstat'
				local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
				if `FChow'<0.05 local ++results
			}
		}
		
		**************************************************************************
		*** (3aii) Panel
		**************************************************************************
		if "`xt'"!="" {
			if `"`testDH'"'=="yes" {
				tempvar resid
				predict `resid', e
				qui mvtest normality `resid'
				drop `resid'
				local DHresult=r(p_dh)
				if `DHresult'<0.05 local ++results
			}
			if `"`testCHOW'"'=="yes" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				local rss_pooled=e(rss)
				qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
				local rss_1=e(rss)
				local n_1=e(N)
				qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
				local rss_2=e(rss)
				local n_2=e(N)
				local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
				local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
				local chowstat=`num_chowstat'/`den_chowstat'
				local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
				if `FChow'<0.05 local ++results
			}
			if `"`testSERIAL'"'=="yes" {
				qui xtserial `y' `x' `if' `in'
				local SERIALresult=r(p)
				if `SERIALresult'<0.05 local ++results
			}
			if `"`testRE'"'=="yes" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				qui xttest0
				local REresult=r(p)
				if `REresult'<0.05 local ++results
			}
		}
		
		**************************************************************************
		*** (3aiii) Time series
		**************************************************************************
		if "`ts'"!="" {
			if `"`testBP'"'=="yes" {
				qui estat hettest
				local BPresult=r(p)
				if `BPresult'<0.05 local ++results
			}
			if `"`testRESET'"'=="yes" {
				qui estat ovtest
				local RESETresult=r(p)
				if `RESETresult'<0.05 local ++results
			}
			if `"`testDH'"'=="yes" {
				tempvar resid
				predict `resid', residuals
				qui mvtest normality `resid'
				drop `resid'
				local DHresult=r(p_dh)
				if `DHresult'<0.05 local ++results
			}
			if `"`testARCH'"'=="yes" {
				tempvar resid resid_sq
				predict `resid', residuals
				qui gen `resid_sq'=`resid'^2
				qui reg `resid_sq' l.`resid_sq' l2.`resid_sq'
				qui test l.`resid_sq' l2.`resid_sq'
				drop `resid' `resid_sq'
				local ARCHresult=r(p)
				if `ARCHresult'<0.05 local ++results
			}

			if `"`testCHOW'"'=="yes" {
				qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
				local rss_pooled=e(rss)
				qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
				local rss_1=e(rss)
				local n_1=e(N)
				qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
				local rss_2=e(rss)
				local n_2=e(N)
				local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
				local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
				local chowstat=`num_chowstat'/`den_chowstat'
				local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
				if `FChow'<0.05 local ++results
			}
		}

		**************************************************************************
		*** (3b) Assess whether passing tests
		**************************************************************************
		if `results'>0 {
			display "This path does not pass misspecification tests. Moving on"
			continue, break
		}

		****************************************************************************
		*** (4) Loop until all variables are significant
		****************************************************************************
		qui `regtype' `y' `newvarlist' `if' `in' [`weight' `exp'], `vce'
		mata: tsort(st_matrix("e(b)"), st_matrix("e(V)"), 1)
		local num e(var)
		local t = e(t)

		local trial 1
		while `t'<`tlimit' {
			tokenize `newvarlist'  // find lowest t-value variable
			qui dis "```num'''"
			qui dis "The lowest t-value is " in green e(t) in yellow " and is variable " in green "```num'''"
			
			local remove_try ```num''' `remove'
			`unabtype' varlist : `varlist'
			`unabtype' exclude : `remove_try' `y'
			local newvarlist_try : list varlist - exclude
			
			qui `regtype' `y' `newvarlist_try' `if' `in' [`weight' `exp'], `vce'
			
			**************************************************************************
			*** (4a) Tests
			**************************************************************************
			local results = 0

			if e(F)<$Fbase {
				dis as error "This model does not improve the F-statistic, reverting"
				local ++results
			}
			**************************************************************************
			*** (4ai) Cross section
			**************************************************************************
			if "`xt'"==""&"`ts'"=="" {
				if `"`testBP'"'=="yes" {
					qui estat hettest
					local BPresult=r(p)
					if `BPresult'<0.05 local ++results
					if `BPresult'<0.05 dis "fail BP"					
				}
				if `"`testRESET'"'=="yes" {
					qui estat ovtest
					local RESETresult=r(p)
					if `RESETresult'<0.05 local ++results
					if `RESETresult'<0.05 dis "fail RESET"					
				}
				if `"`testDH'"'=="yes" {
					tempvar resid
					predict `resid', residuals
					qui mvtest normality `resid'
					drop `resid'
					local DHresult=r(p_dh)
					if `DHresult'<0.05 local ++results
					if `DHresult'<0.05 dis "fail DH"					
				}
				if `"`testCHOW'"'=="yes" {
					qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
					local rss_pooled=e(rss)
					qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
					local rss_1=e(rss)
					local n_1=e(N)
					qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
					local rss_2=e(rss)
					local n_2=e(N)
					local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
					local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
					local chowstat=`num_chowstat'/`den_chowstat'
					local CHOWresult Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
					if `CHOWresult'<0.05 local ++results
					if `CHOWresult'<0.05 dis "fail DH"					
				}
			}

			**************************************************************************
			*** (4aii) Time series
			**************************************************************************
			if "`xt'"!="" {
				if `"`testDH'"'=="yes" {
					tempvar resid
					predict `resid', e
					qui mvtest normality `resid'
					drop `resid'
					local DHresult=r(p_dh)
					if `DHresult'<0.05 local ++results
				}
				if `"`testCHOW'"'=="yes" {
					qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
					local rss_pooled=e(rss)
					qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
					local rss_1=e(rss)
					local n_1=e(N)
					qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
					local rss_2=e(rss)
					local n_2=e(N)
					local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
					local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
					local chowstat=`num_chowstat'/`den_chowstat'
					local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
					if `FChow'<0.05 local ++results
				}
				if `"`testSERIAL'"'=="yes" {
					qui xtserial `y' `x' `if' `in'
					local SERIALresult=r(p)
					if `SERIALresult'<0.05 local ++results
				}
				if `"`testRE'"'=="yes" {
					qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
					qui xttest0
					local REresult=r(p)
					if `REresult'<0.05 local ++results
				}
			}

			**************************************************************************
			*** (4aiii) Time series
			**************************************************************************
			if "`ts'"!="" {
				if `"`testBP'"'=="yes" {
					qui estat hettest
					local BPresult=r(p)
					if `BPresult'<0.05 local ++results
				}
				if `"`testRESET'"'=="yes" {
					qui estat ovtest
					local RESETresult=r(p)
					if `RESETresult'<0.05 local ++results
				}
				if `"`testDH'"'=="yes" {
					tempvar resid
					predict `resid', residuals
					qui mvtest normality `resid'
					drop `resid'
					local DHresult=r(p_dh)
					if `DHresult'<0.05 local ++results
				}
				if `"`testARCH'"'=="yes" {
					tempvar resid resid_sq
					predict `resid', residuals
					qui gen `resid_sq'=`resid'^2
					qui reg `resid_sq' l.`resid_sq' l2.`resid_sq'
					qui test l.`resid_sq' l2.`resid_sq'
					drop `resid' `resid_sq'
					local ARCHresult=r(p)
					if `ARCHresult'<0.05 local ++results
				}

				if `"`testCHOW'"'=="yes" {
					qui `regtype' `y' `x' `if' `in' [`weight' `exp'], `vce'
					local rss_pooled=e(rss)
					qui `regtype' `y' `x' if `group'==1 `in' [`weight' `exp'], `vce'
					local rss_1=e(rss)
					local n_1=e(N)
					qui `regtype' `y' `x' if `group'==2 `in' [`weight' `exp'], `vce'
					local rss_2=e(rss)
					local n_2=e(N)
					local num_chowstat=((`rss_pooled'-(`rss_1'+`rss_2'))/(`numxvars'+1))
					local den_chowstat=(`rss_1'+`rss_2')/(`n_1'+`n_2'+2*(`numxvars'+1))
					local chowstat=`num_chowstat'/`den_chowstat'
					local FChow Ftail((`numxvars'+1),(`n_1'+`n_2'+2*(`numxvars'+1)),`chowstat')
					if `FChow'<0.05 local ++results
				}
			}
	
			**************************************************************************
			*** (4b) Assess tests
			**************************************************************************
			if `results'==0 {
				local trial 1
				local remove `remove_try'
				local newvarlist `newvarlist_try'
			}
			if `results'>0 {
				local ++trial
				dis `trial'
			}

			**************************************************************************
			*** (4c) Move on, either eliminating variable, or reverting and retrying
			**************************************************************************
			qui `regtype' `y' `newvarlist' `if' `in' [`weight' `exp'], `vce'
			cap mata: tsort(st_matrix("e(b)"), st_matrix("e(V)"), `trial')
			if _rc==3202 {
				dis as error "No variables are found to be significant at given level"
				dis as error "Respecify using a lower t-stat or an alternative GUM."
				exit 3202
			}
			local num e(var)
			local t = e(t)
			qui dis `t'
		}
		

		if "`verbose'"!="" {
			dis in green "Results for search path `searchpath':"
			dis in yellow "remaining variables are: " in green "`newvarlist'"
		}

		qui `regtype' `y' `newvarlist' `if' `in' [`weight' `exp'], `vce'
    ****************************************************************************
		*** (5) Determine model fit
		****************************************************************************
		if "`xt'"!="" {
			local ++runnumber
			if `runnumber'==1 {
				local runningvars `newvarlist'
			}
			if `runnumber'!=1 {
				foreach item1 of local newvarlist {
					local count=0
					foreach item2 of local runningvars {
						if `item1'==`item2' local ++count
					}
					if `count'==0 local runningvars `runningvars' `item1'
				}
			}
			global modelvars `runningvars'
		}
		else {
			local ++runnumber
			if `runnumber'==1 {
				global BICbest=.
				global BICbname Model
			}
			qui estat ic
			matrix BIC=r(S)
			local BIC=BIC[1,6]
			if `BIC'<$BICbest {
				global BICbest=`BIC'
				global BICbname Model`searchpath'
				global modelvars `newvarlist'
		    }
			}
		}
  ****************************************************************************
	*** (6) Output
	****************************************************************************
	if "`verbose'"!=""&"`xt'"=="" { 
		dis "Bayesian Information Criteria of best model ($BICbname) is $BICbest"
	}
	`regtype' `y' $modelvars `if' `in' [`weight' `exp'], `vce'
	qui ereturn scalar fit=$BICbest 
	if "`if'"!="" restore
end


********************************************************************************
*** (X) Mata code for selecting irrelevant variables
********************************************************************************
cap mata: mata drop tsort()
mata:
void tsort(real matrix B, real matrix V, real scalar num) {
	real vector se
	real vector t
	real vector tsort
	real vector tnum	
	real matrix X
	real scalar dimn
	real vector a
	
	se = diagonal(V)
	se = sqrt(se)
	t=abs(B':/se)
	dimn = length(t)
	if (dimn==1) {
		_error(3202)
	}
	
	t=t[|1\ dimn-1|]
	a = 1::dimn-1
	X = (t, a)
	tsort = sort(X, 1)
	tnum = tsort[num,1]
	tvar = tsort[num,2]
	st_numscalar("e(t)", tnum)
	st_numscalar("e(var)", tvar)
}
end