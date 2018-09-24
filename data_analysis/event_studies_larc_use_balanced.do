/*
Project: LARC reimbursement
Description: This file creates event studies of the effect of unbundled LARC reimbursement on LARC use using data from state
Medicaid agencies

Output: PDFs of individual event study graphs stored in ${topdir}/${S_DATE}
Date modified: September 18 2018
Author: Marisa Carlos mbc96@cornell.edu
*/
clear
capture log close 
set seed 85718
set more off 



******************************************************* Set paths ****************************************************************************
** Make sure \\tsclient\Dropbox (Personal) is mapped to B: drive (subst B: "\\tsclient\Dropbox (Personal)")
global topdir "B:\Cornell\Research\Projects\LARC_Reimbursement\graphs\event_studies" // path to directory where event study graphs are stored
*** If B: is mapped to Dropbox/Cornell/Research/Projects/LARC_Reimbursement:
global topdir "B:\graphs\event_studies\balanced_panel" // path to directory where event study graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************

**** Event studies will be stored in a folder containing the CURRENT date. 
cd "${topdir}"
capture mkdir "${S_DATE}" // creates new folder for new date in event study graphs folder
cd "${S_DATE}"
log using "${log_path}/event_studies_larc_use_balanced_log_${S_DATE}.log", replace text


local quarter_type ldq
local max_policy_time_diff_cutoff = 6 // dont do: 3 (same as 4), cutoff for number of post-periods (will change the number of states making up the event study)
*** cut-off data 2 years before policy (8 quarters):
*** Variable for the number of months/quarters before policy to cut off graphs at:
**** Set local for number of time periods to cut off at before/after policy:
local num_t_lower_cutoff = -8
local num_t_upper_cutoff = `max_policy_time_diff_cutoff' //8

use "${analysis_data_path}/larc_utilization_`quarter_type'.dta", clear


if "`quarter_type'"=="ldq" {
	local current_date_var lastday_q
}
if "`quarter_type'"=="fdq" {
	local current_date_var firstday_q
}



local date_enacted_var date_enacted_9molag


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
**** Drop states where date enacted is after the end of data, i.e. we don't observe any post-period for the state. 
**** This will drop any observations for states that we only have "pre" periods for, as well as any states that 
**** never adopt:
*drop if separate_device_reimb_indata==0
* end 3 **************************************************************************************


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


* start 5 **************************************************************************************
* Generate outcome variable
gen log_larc_count = log(larc_count)
* end 5 **************************************************************************************

* start 6 **************************************************************************************
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

keep if max_policy_time_diff >= `max_policy_time_diff_cutoff'
* Drop observations before e.g. 8 quarter before policy or more than 8 quarters after (for balanced panel): 
keep if policy_time_diff >= `num_t_lower_cutoff' & policy_time_diff <= `num_t_upper_cutoff'
*******************************************************************************************************
*******************************************************************************************************
*******************************************************************************************************


* start 8 **************************************************************************************
* Run regression to generate event study graphs:

*reg log_`outcome_var' t_* i.`time_period' i.year i.state_num  if separate_device_reimb_indata==1, noomitted cluster(state_num)
*reg log_`outcome_var' t_* i.`time_period'##i.year i.state_num medicaid_expanded  if separate_device_reimb_indata==1, noomitted cluster(state_num)

reg log_larc_count t_* i.quarter#i.year i.state_num medicaid_expanded unemployment_rate_1yrlag if separate_device_reimb_indata==1, noomitted cluster(state_num)
* end 8 **************************************************************************************

* start 9 **************************************************************************************
*Create a submatrix of the coefficient estimates, upper bounds, lower bounds, and policy time differences 
matrix m = r(table)
forvalues i = `lower_cutoff_num'/`upper_cutoff_num' {
	if `i' != `omit_num' {
		if `i' == `lower_cutoff_num' | `i' == `upper_cutoff_num' {
			qui sum policy_time_diff if orig_t_`i' == 1
			local tdiff = r(mean)
		}
		if `i' != `lower_cutoff_num' & `i' != `upper_cutoff_num' {
			qui sum policy_time_diff if t_`i'==1
			local tdiff = r(mean)
		}
		
		matrix sub_`i' = (`tdiff' , m["b","t_`i'"] , m["ll","t_`i'"] , m["ul","t_`i'"])
	}
	if `i' == `omit_num' {
		qui sum policy_time_diff if omit_t_`i' == 1
		local tdiff = r(mean)
		matrix sub_`i' = (`tdiff',0,0,0)
	}
	matrix colnames sub_`i' = tdiff beta upperlimit lowerlimit
	matrix rownames sub_`i' = t_`i' 
}
matrix fullmat = sub_`lower_cutoff_num'
local N = `lower_cutoff_num'+1
forvalues i = `N'/`upper_cutoff_num' {
	matrix fullmat = (fullmat \ sub_`i')
}
matrix list fullmat
** Create variables from matrix
svmat fullmat, names(col)


* end 9 **************************************************************************************

* start 10 ***********************************************************************************
** summarize number of states for graph notes: 
qui egen tag_states_sep_reimb = group(state_short) if separate_device_reimb_indata==1
qui sum tag_states_sep_reimb
local num_states_indata = r(max)
local lower_cutoff_label = `num_t_lower_cutoff'*-1

*** Get list of states to put in graph notes:
qui egen state_tag = tag(state_short) if separate_device_reimb_indata==1
gsort - state_tag - max_policy_time_diff
qui sum state_tag
forvalues i = 1/`r(sum)' {
	local add_state = state_short[`i']
	if `i'==1 {
		local state_list_graph_notes "`add_state'"
	}
	else {
		local state_list_graph_notes "`state_list_graph_notes', `add_state'"
	}
}



twoway ///
	(scatter beta tdiff if tdiff!=., m(circle) mc(gs9) ///
	legend(off) xline(-1) yline(0) xmtick(`num_t_lower_cutoff'(1)`num_t_upper_cutoff') xlabel(`num_t_lower_cutoff'(2)`num_t_upper_cutoff') ///
	ytitle("log(larc_count)") xtitle("Time Since Policy (quarters)") ///
	title("LARC Use in Medicaid (balanced panel)" "`max_policy_time_diff_cutoff' post quarters, `num_states_indata' states") ///
	note("Notes: " ///
	"  - Whiskers are 95% confidence intervals" ///
	"  - Standard errors clustered at the state level" ///
	"  - Observations more than `lower_cutoff_label' quarters before policy are included in the `num_t_lower_cutoff' indicator" ///
	"  - Observations more than `num_t_upper_cutoff' quarters after policy are included in the `num_t_upper_cutoff' indicator" ///
	"  - Regression includes controls for date of Medicaid expansion and lagged unemployment rate" ///
	"  - `num_states_indata' states have separate device reimbursement during data time period" ///
	"         (`state_list_graph_notes')" ///
	"  - t=0 inidicates the quarter in which the policy went into effect")) ///
	(rcap upperlimit lowerlimit tdiff, lc(gs9))
****NOTE: If adding more notes to graph make sure to add them BEFORE "`merge_notes'" becuase merge_notes local is empty for month datasets which cutoffs comments after
graph export larc_utilization_quarterly_ES_`max_policy_time_diff_cutoff'postperiods.pdf, replace
* end 10 *************************************************************************************


log close
