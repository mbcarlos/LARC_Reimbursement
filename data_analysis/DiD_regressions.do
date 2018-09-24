/*
Project: LARC reimbursement
Description: This file runs the DiD and regressions averaging coefficients from event studies for LARC use and births

Output: 
Date modified: September 21 2018
Author: Marisa Carlos mbc96@cornell.edu
*/
clear
capture log close 
set seed 85718
set more off 

******************************************************* Set paths ****************************************************************************
** Make sure \\tsclient\Dropbox (Personal) is mapped to B: drive (subst B: "\\tsclient\Dropbox (Personal)")
global topdir "B:\Cornell\Research\Projects\LARC_Reimbursement\regression_output" // path to directory where event study graphs are stored
*** If B: is mapped to Dropbox/Cornell/Research/Projects/LARC_Reimbursement:
global topdir "B:\graphs\regression_output" // path to directory where event study graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************

**** Event studies will be stored in a folder containing the CURRENT date. 
cd "${topdir}"
capture mkdir "${S_DATE}" // creates new folder for new date in event study graphs folder
cd "${S_DATE}"
log using "${log_path}/DiD_regressions_log_${S_DATE}.log", replace text

local quarter_type ldq


local date_enacted_var date_enacted_9molag

********************************* Set policy time cutoffs (for use when balancing) ******************************************
local max_policy_time_diff_cutoff = 6 // dont do: 3 (same as 4), cutoff for number of post-periods (will change the number of states making up the event study)
**** Set local for number of time periods to cut off at before/after policy:
local num_t_lower_cutoff = -8
local num_t_upper_cutoff = `max_policy_time_diff_cutoff' //8



**** Generate list of outcomes to go through when estimating regressions: 
local outcome_samples "larc_utilization" 
local prefixes natality // lbw 
local suffixes total teen unmarried hsorless
foreach prefix of local prefixes {
	foreach suffix of local suffixes {
		local outcome_samples "`outcome_samples' `prefix'_`suffix'"
	}
}




foreach outcome of local outcome_samples {
	display "OUTCOME DATASET: `outcome'_`quarter_type'.dta"
	if "`outcome'" == "larc_utilization" {
		use "${analysis_data_path}/`outcome'_`quarter_type'.dta", clear
		local outcome_var larc_count
	}
	else {
		use "${analysis_data_path}/`outcome'_`quarter_type'_C2.dta", clear
		local outcome_var births
	}
	
	if "`quarter_type'"=="ldq" {
		local current_date_var lastday_q
	}
	if "`quarter_type'"=="fdq" {
		local current_date_var firstday_q
	}

	* start 1  ************************************************************************************** 
	* Create Medicaid expansion variables:
	{
	local nonexpansion_states AL FL GA ID KS ME MS MO NE NC OK SC SD TN TX UT VA WI WY
	local expansion_states_2014 AZ AR CA CO CT DE DC HI IL IA KY MD MA MN NV NJ NM NY ND OH OR RI VT WA WV
	capture drop medicaid_expanded
	qui gen medicaid_expanded = .

	foreach nonexpansion_state of local nonexpansion_states {
		qui replace medicaid_expanded=0 if state_short==`"`nonexpansion_state'"'
	}
	foreach expansion_state of local expansion_states_2014 {
		qui replace medicaid_expanded=1 if state_short==`"`expansion_state'"' & `current_date_var'>=mdy(1,1,2014)
		qui replace medicaid_expanded=0 if state_short==`"`expansion_state'"' & `current_date_var'<mdy(1,1,2014)
	}
	qui replace medicaid_expanded=1 if state_short=="MI" & `current_date_var'>=mdy(4,1,2014)
	qui replace medicaid_expanded=0 if state_short=="MI" & `current_date_var'<mdy(4,1,2014)
	qui replace medicaid_expanded=1 if state_short=="NH" & `current_date_var'>=mdy(8,15,2014)
	qui replace medicaid_expanded=0 if state_short=="NH" & `current_date_var'<mdy(8,15,2014)
	qui replace medicaid_expanded=1 if state_short=="PA" & `current_date_var'>=mdy(1,1,2015)
	qui replace medicaid_expanded=0 if state_short=="PA" & `current_date_var'<mdy(1,1,2015)
	qui replace medicaid_expanded=1 if state_short=="IN" & `current_date_var'>=mdy(2,1,2015)
	qui replace medicaid_expanded=0 if state_short=="IN" & `current_date_var'<mdy(2,1,2015)
	qui replace medicaid_expanded=1 if state_short=="AK" & `current_date_var'>=mdy(9,1,2015)
	qui replace medicaid_expanded=0 if state_short=="AK" & `current_date_var'<mdy(9,1,2015)
	qui replace medicaid_expanded=1 if state_short=="MT" & `current_date_var'>=mdy(1,1,2016)
	qui replace medicaid_expanded=0 if state_short=="MT" & `current_date_var'<mdy(1,1,2016)
	qui replace medicaid_expanded=1 if state_short=="LA" & `current_date_var'>=mdy(7,1,2016)
	qui replace medicaid_expanded=0 if state_short=="LA" & `current_date_var'<mdy(7,1,2016)
	}
	* end 1  **************************************************************************************

	* start 3 **************************************************************************************
	*Generate numeric state variable:
	egen state_num = group(state_short)

	* Variable "separate_device_reimb" = 1 if a state offers separate reimbursement for device at a given time - 
	* Create a variable for whether a state offers separate reimbursement for a device during the time period 
	* in which we have data, taking into account 9 month lag

	qui gen separate_device_reimb_indata = .
	qui sum state_num
	forvalues i = 1/`r(max)' {
		qui sum separate_device_reimb if state_num==`i'
		local state_max = r(max)
		qui replace separate_device_reimb_indata=`state_max' if state_num==`i'
	}


	* start 4 **************************************************************************************
	* Generate a variable that calculates the time before/after the policy: 
	capture drop date_enacted_quarter
	capture drop current_quarter
	capture drop policy_time_diff

	qui gen date_enacted_quarter = qofd(date_enacted)
	qui gen current_quarter = qofd(`current_date_var')

	qui gen policy_time_diff = current_quarter - date_enacted_quarter if separate_device_reimb_indata==1
	** Generate group variable for time since policy
	capture drop t_*
	qui tab policy_time_diff, gen(t_)
	* end 4 **************************************************************************************
	
	
	*Figure out which time since policy FE represents t=-1 and figure out which t_ var to cut off at:
	capture drop count_t_periods 
	qui egen count_t_periods = group(policy_time_diff)
	qui sum count_t_periods
	local max = r(max)
	forvalues i = 1/`max' {
		qui sum policy_time_diff if t_`i'==1
		local mean = r(mean) 
		if `mean' == -1 {
			display "MEAN IS -1 for t_`i'"
			local omit_var = "t_`i'"
			display "OMIT VAR: `omit_var'"
			local omit_num = `i'
		}
		
		if `mean' == `num_t_lower_cutoff' { // this is `num_t_lower_cutoff_num' from event_studies_births.do
			display "MEAN IS `num_t_lower_cutoff' for t_`i'"
			local lower_cutoff_num = `i'
		}
		
		if `mean' == `num_t_upper_cutoff' { // 8 quarters, 2 years before and 2 years after (but 5 quarters after currently gives a balanced panel) 
			display "policy time diff = `num_t_upper_cutoff' for t_`i'"
			local upper_cutoff_num = `i'
		}
	}

	rename `omit_var' omit_`omit_var'


	qui gen orig_t_`lower_cutoff_num' = t_`lower_cutoff_num'
	local N = `lower_cutoff_num'-1
	forvalues i = 1/`N' {
		replace t_`lower_cutoff_num' = t_`i' if t_`i'==1
		rename t_`i' omit_t_`i'
	}


	gen orig_t_`upper_cutoff_num'=t_`upper_cutoff_num'
	local N = `upper_cutoff_num'+1
	if `N'<=`max' {
		forvalues i = `N'/`max' {
			replace t_`upper_cutoff_num' = t_`i' if t_`i'==1
			rename t_`i' omit_t_`i'
		}
	}
	* end 6 **************************************************************************************
	
	*******************************************************************************************************
	*************************************** BALANCING THE PANEL *******************************************
	*******************************************************************************************************
	cap drop group_state max_policy_time_diff min_policy_time_diff
	qui egen group_state = group(state) if separate_device_reimb_indata==1
	qui gen max_policy_time_diff = .
	qui gen min_policy_time_diff = .

	qui sum group_state
	forvalues i = 1/`r(max)' {
		cap drop tag 
		qui egen tag=tag(group_state) if group_state==`i'
		gsort - tag
		local state = state[1]
		
		qui sum policy_time_diff if group_state == `i'
		qui replace max_policy_time_diff = `r(max)' if group_state == `i'
		qui replace min_policy_time_diff = `r(min)' if group_state == `i'
		display "** `state' ** number of pre-periods: `r(min)' number of post-periods: `r(max)'"
	}

	*keep if max_policy_time_diff >= `max_policy_time_diff_cutoff'
	gen balanced_panel_sample = (max_policy_time_diff >= `max_policy_time_diff_cutoff')
	*******************************************************************************************************
	*******************************************************************************************************
	*******************************************************************************************************
	
	************************************ MIGHT NOT DO THIS: *********************************************
	gen outcome_missing = (`outcome_var'==.)
	replace `outcome_var' = 5 if `outcome_var'==.
	*****************************************************************************************************
	
	****************************** Generate log of outcome and treatment dummy ******************************************
	gen log_`outcome_var' = ln(`outcome_var')
	qui gen treatment_dummy = (policy_time_diff>=0) if policy_time_diff!=.
	
	/*** Determine year cutoffs for balancing diff in diff panel (i.e. only include state-YEARs where we see ALL states)
	*1) count the number of states in the data 
	*2) Count the number of states in each quarter-year 
	*3) Find the minimum quarter-year where num_states=total number of states
	*4) find the maximum quarter-year where num_states = total number of states 
	
	*firstday_q is quarter-year variable 
	sort firstday_q
	
	*Total number of states: 
	qui sum state_num
	local total_num_states = r(max)
	
	qui egen quarter_year_group = group(firstday_q)
	qui sum quarter_year_group
	forvalues i = 1/`r(max)' {
		qui sum firstday_q if quarter_year_group == `i'
		local date : di %td r(mean)
		
		cap drop tag 
		egen tag = tag(state) if quarter_year_group == `i'
		qui sum tag
		local num_states_this_quarter = r(sum)
		display "`i' --> `date' --> `num_states_this_quarter' states in this quarter" 
	}*/
	
	
	
	*** For most birth outcomes, the panel should be balanced in all subsamples except hsorless b/c the only time births should be missing
	*** is when the data are censored at less than 11 births. For hsorless, the inclusion varies by states - some states 
	
	*********************************************************************************************************************
	*                     FIRST COLUMN: 2-way fixed effect "diff in diff" (unbalanced panel)                            *
	*********************************************************************************************************************
	reg log_`outcome_var' treatment_dummy i.quarter#i.year i.state_num medicaid_expanded unemployment_rate_1yrlag, cluster(state_num)
	
	
	*********************************************************************************************************************
	*                     SECOND COLUMN: 2-way fixed effect "diff in diff" (balanced panel, only treated states)                             *
	*********************************************************************************************************************
	preserve
	replace 
	reg log_`outcome_var' treatment_dummy i.quarter#i.year i.state_num medicaid_expanded unemployment_rate_1yrlag if balanced_panel_sample==1, cluster(state_num)
	
	restore
	
	
	
	
	/* start 8 **************************************************************************************
	* Run regression to generate event study graphs:

	*reg log_`outcome_var' t_* i.`time_period' i.year i.state_num  if separate_device_reimb_indata==1, noomitted cluster(state_num)
	*reg log_`outcome_var' t_* i.`time_period'##i.year i.state_num medicaid_expanded  if separate_device_reimb_indata==1, noomitted cluster(state_num)

	reg log_larc_count t_* i.quarter#i.year i.state_num medicaid_expanded unemployment_rate_1yrlag if separate_device_reimb_indata==1, noomitted cluster(state_num)
	* end 8 **************************************************************************************/
}



/*
larc_utilization_`quarter_type'.dta
`prefix'_`suffix'_`quarter_type'_C2.dta
*/
log close
