/*
Project: LARC reimbursement
Description: This file backs out 1st births from 2nd+ and All birth files. 
Input:

Output: PDFs of individual event study graphs stored in ${topdir}/${S_DATE}
Date modified: September 17 2018
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
global topdir "B:\graphs\event_studies" // path to directory where event study graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************

**** Event studies will be stored in a folder containing the CURRENT date. 
cd "${topdir}"
log using "${log_path}/create_1st_birth_datasets_log_${S_DATE}.log", replace text


*** Programs used: 
cap program drop display_count
program define display_count
	display "************************************************************************"
	qui count
	display "COUNT = `r(N)'"
	display "************************************************************************"
end


/*
quarter: natality_unmarried_ldq_C2 (2nd child) natality_unmarried_ldq (all) 
month: natality_unmarried_C2 (2nd child) natality_unmarried (all)  
1) Read in 2nd+ births
2) rename births variable and drop variables that are repetative
3) Save as temp file 
4) read in all  births
5) Renam births variable 
6) merge in temporary file on state month_year or state_quarter? 
7) save as ... 
*/
local quarter_type ldq
local birth_prefixes natality lbw 
local birth_suffixes total teen unmarried hsorless
local quarter_datasets
local monthly_datasets

*** Quarterly: 
foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		*see if all birth order dataset exists
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'_`quarter_type'.dta"
		local rc1 = _rc
		*see if 2nd+ birth order dataset exists 
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'_`quarter_type'_C2.dta"
		local rc2 = _rc
		
		if `rc1'==0 & `rc2' == 0 {
			local quarter_datasets "`quarter_datasets' `prefix'_`suffix'_`quarter_type'"
		}
		else{
			if `rc1' != 0 {
				display "all birth orders for `prefix'_`suffix' does not exist (quarterly)"
			}
			if `rc2' != 0 {
				display "2nd+ birth orders for `prefix'_`suffix' does not exist (quarterly)"
			}
		}
	}
}


*** Monthly: 
foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		*see if all birth order dataset exists
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'.dta"
		local rc1 = _rc
		*see if 2nd+ birth order dataset exists 
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'_C2.dta"
		local rc2 = _rc
		
		if `rc1'==0 & `rc2' == 0 {
			local monthly_datasets "`monthly_datasets' `prefix'_`suffix'"
		}
		else{
			if `rc1' != 0 {
				display "all birth orders for `prefix'_`suffix' does not exist (monthly)"
			}
			if `rc2' != 0 {
				display "2nd+ birth orders for `prefix'_`suffix' does not exist (monthly)"
			}
		}
	}
}

display "QUARTER DATASETS:"
foreach dataset of local quarter_datasets {
	display "`dataset'"
}
display "MONTHLY DATASETS:"
foreach dataset of local monthly_datasets {
	display "`dataset'"
}


*** Generate 1st+unknnown birth order datasets for monthly datasets: 
foreach time_period in "monthly" "quarter" {
	if "`time_period'" == "monthly" {
		local time_period_var month_year
	}
	else if "`time_period'" == "quarter" {
		local time_period_var firstday_q
	}
	foreach dataset of local `time_period'_datasets {
		use "${analysis_data_path}/`dataset'_C2.dta", clear

		keep births state_short `time_period_var'
		rename births births_C2
		tempfile C2
		save `C2'
		
		use "${analysis_data_path}/`dataset'.dta", clear
		rename births births_all_unknown
		merge 1:1 `time_period_var' state_short using `C2'
		
		gen births = births_all_unknown - births_C2
		
		drop births_all_unknown births_C2
		
		save "${analysis_data_path}/`dataset'_C1.dta", replace
	}
}

log close
