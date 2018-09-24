/*
Project: LARC reimbursement
Description: This file graphs of log_larc_count or log_births for states that implemented IPP LARC policies in a given year
Input:

Output: PDFs of graphs stored in ${topdir}/${S_DATE}
Date modified: September 23 2018
Author: Marisa Carlos mbc96@cornell.edu
*/
clear
capture log close 
set seed 85718
set more off 



******************************************************* Set paths ****************************************************************************
** Make sure \\tsclient\Dropbox (Personal) is mapped to B: drive (subst B: "\\tsclient\Dropbox (Personal)")
global topdir "B:\Cornell\Research\Projects\LARC_Reimbursement\graphs\exploratory_graphs" // path to directory where event study graphs are stored
*** If B: is mapped to Dropbox/Cornell/Research/Projects/LARC_Reimbursement:
global topdir "B:\graphs\exploratory_graphs" // path to directory where event study graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************

**** Event studies will be stored in a folder containing the CURRENT date. 
cd "${topdir}"
capture mkdir "${S_DATE}" // creates new folder for new date in event study graphs folder
cd "${S_DATE}"
log using "${log_path}/avg_log_outcome_graphs_by_year_implementation${S_DATE}.log", replace text

local datasets "larc_utilization_ldq"
local larc_utilization_ldq_title "LARC Use"

local prefixes natality lbw
local natality_title "Births"
local lbw_title "Low birthweight births"
local suffixes total teen unmarried hsorless 
local total_title "all"
local teen_title "teen"
local unmarried_title "unmarried"
local hsorless_title "HS or less"

foreach prefix of local prefixes {
	foreach suffix of local suffixes {
		local datasets "`datasets' `prefix'_`suffix'_ldq_C2"
		local `prefix'_`suffix'_ldq_C2_title "``prefix'_title', ``suffix'_title'"
	}
}

foreach dataset of local datasets {
	use "${analysis_data_path}/`dataset'.dta", clear
	display "USING: `dataset'"
	
	if "`dataset'" == "larc_utilization_ldq" {
		local outcome_var larc_count
		local date_enacted_var date_enacted
	}
	else {
		local outcome_var births
		local date_enacted_var date_enacted_9molag
	}
	
	gen log_`outcome_var' = ln(`outcome_var')
	
	gen year_enacted_lagged = year(`date_enacted_var')
	
	*Generate numeric state variable:
	capture drop state_num 
	capture drop separate_device_reimb_indata
	egen state_num = group(state_short)
	qui sum state_num
	* Variable "separate_device_reimb" = 1 if a state offers separate reimbursement for device at a given time - 
	* Create a variable for whether a state offers separate reimbursement for a device during the time period 
	* in which we have data, taking into account 9 month lag
	qui gen separate_device_reimb_indata = .
	local max = r(max)
	forvalues i = 1/`max' {
		qui sum separate_device_reimb if state_num==`i'
		local state_max = r(max)
		qui replace separate_device_reimb_indata=`state_max' if state_num==`i'
	}
	**** Drop states where date enacted is after the end of data, i.e. we don't observe any post-period for the state. 
	**** This will drop any observations for state that we only have "pre" periods for, as well as any states that 
	**** never adopt:
	*drop if separate_device_reimb_indata==0 
	tab state_short if  separate_device_reimb_indata==0 
	replace year_enacted_lagged = 0 if separate_device_reimb_indata==0 
	* end 3 **************************************************************************************
	
	
	*** Generate list of states expanding in each year to add to legend of graph: 
	qui sum year_enacted_lagged if separate_device_reimb_indata==1
	forvalues year = `r(min)'/`r(max)' {
		cap drop tag
		egen tag = tag(state_short) if year_enacted_lagged == `year' & separate_device_reimb_indata==1 
		gsort - tag state_short
		qui sum tag
		forvalues i = 1/`r(sum)' {
			local state = state_short[`i']
			if `i'==1 {
				local states_`year' "`state'"
			}
			else {
				local states_`year' "`states_`year'' `state'"
			}
		}
	}
	*** For states not expanding during data time period: 
	if "`dataset'" != "larc_utilization_ldq" {
		local states_0 "all other states"
	}
	else {
		cap drop tag
		egen tag = tag(state_short) if year_enacted_lagged == 0
		gsort - tag state_short
		qui sum tag
		forvalues i = 1/`r(sum)' {
			local state = state_short[`i']
			if `i'==1 {
				local states_0 "`state'"
			}
			else {
				local states_0 "`states_0' `state'"
			}
		}
	}
	
	 
	tempvar year_min year_max year_enacted_min year_enacted_max
	egen `year_min' = min(year)
	egen `year_max' = max(year)
	egen `year_enacted_min' = min(year_enacted_lagged) if separate_device_reimb_indata==1
	egen `year_enacted_max' = max(year_enacted_lagged) if separate_device_reimb_indata==1
	
	sum `year_min'
	local year_min = r(mean)
	sum `year_max'
	local year_max = r(mean)
	sum `year_enacted_min'
	local year_enacted_min = r(mean)
	sum `year_enacted_max' 
	local year_enacted_max = r(mean)
	
	preserve
		clear

		local obs_num = (`year_max' - `year_min' + 1)*4*(`year_enacted_max'-`year_enacted_min'+1)
		display "`obs_num'"

		set obs `obs_num'
		gen obs_num = _n
		gen quarter = .
		gen year = .
		gen year_enacted_lagged = .
		local obs_num = 0

		forvalues year_enacted = `year_enacted_min'/`year_enacted_max' {
			forvalues year = `year_min'/`year_max' {
				forvalues quarter = 1/4 {
					local ++obs_num
					qui replace quarter = `quarter' if obs_num==`obs_num'
					qui replace year = `year' if obs_num == `obs_num'
					replace year_enacted_lagged = `year_enacted' if obs_num==`obs_num'
				}
			}
		}
		
		gen firstday_q = .
		replace firstday_q = mdy(1,1,year) if quarter == 1
		replace firstday_q = mdy(4,1,year) if quarter == 2
		replace firstday_q = mdy(7,1,year) if quarter == 3
		replace firstday_q = mdy(10,1,year) if quarter == 4
		

		drop obs_num
		tempfile quarter_year_merge_dataset
		save `quarter_year_merge_dataset'
		sort year quarter
	restore
	
	

	
	*one graph with 5 lines: 1 line for each year_enacted lag 
	*collapse (mean) log_`outcome_var', by(state_short year quarter year_enacted_lagged)
	collapse (mean) log_`outcome_var', by(firstday_q year quarter year_enacted_lagged)
	
	
	*[(stat)] target_var=varname [target_var=varname ...] [ [(stat)] ...]
	
	format firstday_q %td
	
	merge 1:1 year quarter year_enacted_lagged using `quarter_year_merge_dataset'
	
	
	drop _merge
	reshape wide log_`outcome_var', i(firstday_q quarter year) j(year_enacted_lagged)

	
	egen num_nonmissing = rownonmiss(log_`outcome_var'*)
	drop if num_nonmissing == 0
	
	** change labels on log_`outcome_var' to change legend on graph: 
	foreach var of varlist log_`outcome_var'* {
		local year = substr("`var'",-4,4)
		label var `var' "`year' (`states_`year'')"
		qui count if `var'!=.
		if `r(N)' == 0 {
			drop `var'
		}
	}
	
	*** Replace label for year=0 (nonimplementing in data states):
	label var log_`outcome_var'0 "non-implementing (`states_0')"
	
	gen quarter_year = qofd(firstday_q)
	format quarter_year %tq
	
	qui count
	local num_major_ticks = `r(N)'/4
	twoway connected log_`outcome_var'* quarter_year, title("``dataset'_title'") ytitle(Avg log_`outcome_var') xtitle(quarter) ///
		legend(size(vsmall)) /*xlabel(size(small))*/ xlabel(#`num_major_ticks') xlabel(,labsize(small)) 
	
	graph export log_outcome_`dataset'.pdf, replace
}


log close
