*** for each STATE, make a graph of LARC count on y axis and time on x axis, add verticle line for date policy implemented
/*
Project: LARC reimbursement
Description: This file create graphs of LARC counts/time for each state

Output: PDFs of state graphs in exploratory_graphs/larc_count_graph_`state'.pdf
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
global topdir "B:\graphs\exploratory_graphs" // path to directory where graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************


**** Event studies will be stored in a folder containing the CURRENT date. 
cd "${topdir}"
capture mkdir "${S_DATE}" // creates new folder for new date in event study graphs folder
cd "${S_DATE}"
log using "${log_path}/state_larc_count_graphs_log_${S_DATE}.log", replace text


local current_date_var lastday_q


use "${analysis_data_path}/larc_utilization_ldq.dta", clear

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

format firstday_q %td

qui sum state_num
gen obs_num = _n
forvalues i = 1/`r(max)' {
	qui sum obs_num if state_num == `i'
	local state = state[`r(min)']
	
	** Figure out date of policy enactment (only doing 1st policy date right now):
	qui sum date_enacted
	local min_date = r(min)
	qui sum date_enacted if state_num==`i'
	if `min_date'!=`r(mean)' {
		qui sum date_enacted if separate_device_reimb_indata==1 & state_num==`i' & policy_num==1
		local date_enacted_line_local "xline(`r(mean)'"
		if "`state'"=="VT" {
			qui sum date_enacted if separate_device_reimb_indata==1 & state_num==`i' & policy_num==2
			local date_enacted_line_local "`date_enacted_line_local' `r(mean)')"
		}
		else {
			local date_enacted_line_local "`date_enacted_line_local')"
		}
	}
	qui sum date_enacted if state_num==`i'
	if `min_date'==`r(mean)' {
		local date_enacted_line_local ""
	}
	
	cap drop log_larc_count
	gen log_larc_count = ln(larc_count)
	twoway connected log_larc_count firstday_q if state_num==`i', title("LARC Use, `state'") m(circle) mc(gs9) `date_enacted_line_local'
	graph export log_larc_count_graph_`state'.pdf, replace
}


log close
