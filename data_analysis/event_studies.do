/*
Project: LARC reimbursement
Description: This file creates event studies of the effect of unbundled LARC reimbursement on birth outcomes and LARC use
Input:

Output: PDFs of individual event study graphs stored in ${topdir}/`date'
Date modified: May 4 2018
Author: Marisa Carlos mbc96@cornell.edu
*/
clear
capture log close 
set seed 85718
set more off 

*************************** CHANGE THE DATE IF RUNNING NEW EVENT STUDIES SO YOU DONT WRITE OVER OLD ONES *************************************
local date 2018_05_04
**********************************************************************************************************************************************

******************************************************* Set paths ****************************************************************************
** Make sure \\tsclient\Dropbox (Personal) is mapped to B: drive (subst B: "\\tsclient\Dropbox (Personal)")
global topdir "B:\Cornell\Research\Projects\LARC_Reimbursement\graphs\event_studies" // path to directory where event study graphs are stored
global analysis_data_path "S:/LARC/data/analysis_data"
global log_path "S:/LARC/log_files"
**********************************************************************************************************************************************


cd "${topdir}"
capture mkdir "`date'" // creates new folder for new date in event study graphs folder
cd "`date'"
log using "${log_path}/event_studies_log_`date'.log", replace text



***************** Set quarter merge type (first day of q or last day of q) *****************
local quarter_type ldq

local birth_prefixes natality lbw lt37weeks_lmp lt37weeks_oe 
local birth_suffixes total black hispanic teen unmarried 
local count = 0
*** Set locals for list of quarter/month datasets for when birth order is any order:
local quarter_datasets_order_any larc_util_`quarter_type'
local ++count
foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		display "`prefix'_`suffix'"
		local ++count
		local quarter_datasets_order_any `quarter_datasets_order_any' `prefix'_`suffix'_`quarter_type'
	}
}
foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		local ++count
		local month_datasets_order_any `month_datasets_order_any' `prefix'_`suffix'
	}
}

*Set locals for list of quarter/month datasets when birth order is 2nd or greater:

foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		*display "S:\LARC\data\analysis_data\\`prefix'_`suffix'_`quarter_type'_C2.dta"
		display "${analysis_data_path}/`prefix'_`suffix'_`quarter_type'_C2.dta"
		*capture confirm file "S:\LARC\data\analysis_data\\`prefix'_`suffix'_`quarter_type'_C2.dta"
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'_`quarter_type'_C2.dta"
		
		if _rc==0 {
			local quarter_datasets_order_two_plus `quarter_datasets_order_two_plus' `prefix'_`suffix'_`quarter_type'_C2
			local ++count
		}
		else {
			display "FILE DOESNT EXIST - MOVE ON"
		}
	}
}
foreach prefix of local birth_prefixes {
	foreach suffix of local birth_suffixes {
		*display "S:\LARC\data\analysis_data\\`prefix'_`suffix'_C2.dta"
		display "${analysis_data_path}/`prefix'_`suffix'_C2.dta"
		*capture confirm file "S:\LARC\data\analysis_data\\`prefix'_`suffix'_C2.dta"
		capture confirm file "${analysis_data_path}/`prefix'_`suffix'_C2.dta"
		if _rc==0 {
			local month_datasets_order_two_plus `month_datasets_order_two_plus' `prefix'_`suffix'_C2
			local ++count
		}
		else {
			display "FILE DOESNT EXIST - MOVE ON"
		}
	}
}
display `count'



/*********************************************************************************************
*************************** COMMENT OUT BELOW TO DO ALL DATASETS ****************************
*********************************************************************************************
local quarter_datasets larc_util_fdq natality_total_ldq
local month_datasets lbw_black
*********************************************************************************************/
local count2 = 0

foreach birth_order in order_any order_two_plus {
	foreach time_period in quarter month {
		display "--------------------------------------------------"
		display "`time_period'"
		display "--------------------------------------------------"
		foreach dataset_orig in ``time_period'_datasets_`birth_order'' {
			local ++count2
			display "--------------------------------------------------"
			display "--------------------------------------------------"
			display "DATASET ORIGINAL NAME: `dataset_orig'"
			display "--------------------------------------------------"
			display "--------------------------------------------------"
			use "${analysis_data_path}/`dataset_orig'.dta", clear
			
			*** Generate a dataset local that takes the C2 off of the end of the dataset name:
			*** Only need to do this if `birth_order'=order_two_plus
			if "`birth_order'"=="order_two_plus" {
				local dataset = substr("`dataset_orig'",1,strlen("`dataset_orig'")-3)
			}
			if "`birth_order'"=="order_any" {
				local dataset "`dataset_orig'"
			}
			
			display "DATASET EDITED NAME: `dataset'"
			

			* start 1 **************************************************************************************
			***Variables differ according to which dataset we are using - check the dataset and set locals accordingly:
			if "`time_period'"=="quarter" {
				*** Variable for the number of months/quarters before policy to cut off graphs at:
				local num_t_lower_cutoff = -8
				
				if "`quarter_type'"=="ldq" {
					local current_date_var lastday_q
				}
				if "`quarter_type'"=="fdq" {
					local current_date_var firstday_q
				}
			}
			if "`time_period'"=="month" {
				local current_date_var month_year
				local num_t_lower_cutoff = -24
				gen month = month(`current_date_var')
				gen year = year(`current_date_var')
			}
			
			if substr("`dataset'",1,4)=="larc" {
				local date_enacted_var date_enacted
				local outcome_var num_rx
			}
			if substr("`dataset'",1,4)!="larc" {
				local date_enacted_var date_enacted_8molag
				local outcome_var births
			}
			
			* end 1 ***************************************************************************************

			* start 2  ************************************************************************************** 
			* Create Medicaid expansion variables:
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
			* end 2  **************************************************************************************
			
			* start 3 **************************************************************************************
			*Generate numeric state variable:
			capture drop state_num 
			capture drop separate_device_reimb_indata
			egen state_num = group(state_short)
			qui sum state_num
			* Variable "separate_device_reimb" = 1 if a state offers separate reimbursement for device at any time - 
			* Create a variable for whether a state offers separate reimbursement for a device during the time period 
			* in which we have data:
			qui gen separate_device_reimb_indata = .
			local max = r(max)
			forvalues i = 1/`max' {
				qui sum separate_device_reimb if state_num==`i'
				local state_max = r(max)
				qui replace separate_device_reimb_indata=`state_max' if state_num==`i'
			}
			* end 3 **************************************************************************************
			
			* start 4 **************************************************************************************
			* Generate a variable that calculates the time before/after the policy: 
			capture drop date_enacted_`time_period'
			capture drop current_`time_period'
			capture drop policy_time_diff
			if "`time_period'"=="month" {
				qui gen date_enacted_`time_period' = mofd(`date_enacted_var')
				qui gen current_`time_period' = mofd(`current_date_var') 
			}
			if "`time_period'"=="quarter"{
				qui gen date_enacted_`time_period' = qofd(`date_enacted_var')
				qui gen current_`time_period' = qofd(`current_date_var') 
			}
			qui gen policy_time_diff = current_`time_period' - date_enacted_`time_period' if separate_device_reimb_indata==1
			** Generate group variable for time since policy
			capture drop t_*
			qui tab policy_time_diff, gen(t_)
			* end 4 **************************************************************************************
			
			* start 5 **************************************************************************************
			* Generate outcome variable - log(births) or log(num_rx)
			capture drop log_`outcome_var'
			gen log_`outcome_var' = log(`outcome_var')
			* end 5 **************************************************************************************
			
			* start 6 **************************************************************************************
			*Figure out which time since policy FE represents t=-1 and figure out which t_ var to cut off at
			* (based on locals defined earlier for 8 quarters or 24 months before policy): 
			capture drop count_t_periods 
			qui egen count_t_periods = group(policy_time_diff)
			qui sum count_t_periods
			local max =r(max)
			forvalues i = 1/`max' {
				qui sum policy_time_diff if t_`i'==1
				local mean = r(mean) 
				if `mean' == -1 {
					display "MEAN IS -1 for t_`i'"
					local omit_var = "t_`i'"
					display "OMIT VAR: `omit_var'"
					local omit_num = `i'
				}
				
				if `mean' == `num_t_lower_cutoff' {
					display "MEAN IS `num_t_lower_cutoff' for t_`i'"
					local lower_cutoff_num = `i'
				}
			}
			capture drop omit_*
			rename `omit_var' omit_`omit_var'
			
			capture drop orig_t_`lower_cutoff_num'
			qui gen orig_t_`lower_cutoff_num' = t_`lower_cutoff_num'
			local N = `lower_cutoff_num'-1
			forvalues i = 1/`N' {
				qui replace t_`lower_cutoff_num' = t_`i' if t_`i'==1
				rename t_`i' omit_t_`i'
			}
		
			* end 6 **************************************************************************************
			
			/* start 7 **************************************************************************************
			* Look at number of obs in each pre-policy month:
			qui sum count_t_periods
			local max =r(max)
			forvalues i = 1/`max' {
				if `i' != `omit_num' {
					qui count if t_`i'==1
					local N = r(N) 
					display "t_`i': `N'"
				}
				if `i' == `omit_num' {
					qui count if omit_t_`omit_num' ==1
					local N = r(N) 
					display "t_`i' (==-1): `N'"
				}
			}
			*/
			* Use number of obs in each pre-policy month to figure out where to cutoff at top 
			* Code below just cuts off at greatest number of months after policy, but can use it to 
			* cutoff at different point later....
			qui sum count_t_periods
			*local upper_cutoff_num = r(max)
			local max = r(max)
			
			*Cutoff once the number of observations is less than 3:
			local to_val = `omit_num'+1
			forvalues i = `max'(-1)`to_val'{
				qui count if t_`i'==1
				local n = r(N)
				if r(N)<=3 {
					local upper_cutoff_num = `i'
				}
			}
			
			
			capture drop orig_t_`upper_cutoff_num'
			gen orig_t_`upper_cutoff_num'=t_`upper_cutoff_num'
			local N = `upper_cutoff_num'+1
			if `N'<=`max' {
				forvalues i = `N'/`max' {
					qui replace t_`upper_cutoff_num' = t_`i' if t_`i'==1
					rename t_`i' omit_t_`i'
				}
			}
			* end 7 **************************************************************************************
			
			* start 8 **************************************************************************************
			* Run regression to generate event study graphs:

			*reg log_`outcome_var' t_* i.`time_period' i.year i.state_num  if separate_device_reimb_indata==1, noomitted cluster(state_num)
			reg log_`outcome_var' t_* i.`time_period'##i.year i.state_num medicaid_expanded  if separate_device_reimb_indata==1, noomitted cluster(state_num)

			* end 8 **************************************************************************************
			
			* start 9 **************************************************************************************
			* Store the differences (time before/after policy), coefficients, upper bounds, lower bounds in matrix,
			* then turn that matrix into a data set and plot 
			
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
			
			* start 10 **************************************************************************************
			****** Reset locals:
			local title_line1
			local title_line2
			local subtitle 
			local merge_notes
			** Create event study graph
			*** Get the population from the dataset name to use in the title:
			if substr("`dataset'",1,4)!="larc" {
				if "`time_period'"=="month" {
					local population = substr("`dataset'",strrpos("`dataset'","_")+1, .)
					if "`population'"=="total" {
						local population "all"
					}
				}
				if "`time_period'"=="quarter" {
					local population = substr(substr("`dataset'",1,strrpos("`dataset'","_")-1),strrpos(substr("`dataset'",1,strrpos("`dataset'","_")-1),"_")+1, .)
					if "`population'"=="total" {
						local population "all"
					}
				}
			}
			
			*** Generate the subtitle to use in the graph which indicates birth order :
			if "`birth_order'"=="order_two_plus" {
				local subtitle "(second child or greater birth order)"
			}
			if "`birth_order'"=="order_any" {
				local subtitle "(all birth orders)"
			}
			
			if substr("`dataset'",1,4)=="larc" {
				local title_line1 "LARC utilization, Medicaid"
				local title_line2
			}
			*Get the outcome from the dataset name to use in the title: 
			if substr("`dataset'",1,3)=="lbw" {
				local title_line1 "low birthweight births, `population'"
				local title_line2
			}
			if substr("`dataset'",1,8)=="natality" {
				local title_line1 "total births, `population'"
				local title_line2
			}
			if substr("`dataset'",1,12)=="lt37weeks_oe" {
				local title_line1 "premature births, `population'"
				local title_line2 "(<37 weeks, OB estimate)"
			}
			if substr("`dataset'",1,13)=="lt37weeks_lmp" {
				local title_line1 "premature births, `population'" 
				local title_line2 "(<37 weeks, last menstrual period)"
			}
			qui sum policy_time_diff if orig_t_`lower_cutoff_num'==1
			local min = r(mean)
			qui sum policy_time_diff if orig_t_`upper_cutoff_num'==1
			local max = r(max)
			local min_num = abs(`min')
			
			if "`quarter_type'"=="fdq" {
				local merge_notes "  - Policy info merged using the first day of the quarter in which the outcome is measured"
			}
			if "`quarter_type'"=="ldq" {
				local merge_notes "  - Policy info merged using the last day of the quarter in which the outcome is measured"
			}
			if "`time_period'"=="month" {
				local merge_notes 
			}
			
			*** Policy lag note - indicate what t=0 means:
			if substr("`dataset'",1,4)=="larc" {
				local policy_lag_note "t=0 inidicates the quarter in which the policy went into effect"
			}
			if substr("`dataset'",1,4)!="larc" {
				local policy_lag_note "t=0 indicates the `time_period' that is 8 months after the policy went into effect"
			}
			
			*** Count number of states with separate device reimbursement in dataset time period:
			qui egen tag_states_sep_reimb = group(state_short) if separate_device_reimb_indata==1
			qui sum tag_states_sep_reimb
			local num_states_indata = r(max)
			
			*** Count the number of state-quarter/month obs that are missing among the states that have device reimbursement in 
			* dataset time period:
			qui count if `outcome_var'==. & separate_device_reimb_indata==1
			local num_missing_state_time_obs = r(N)
			qui count if separate_device_reimb_indata==1
			local num_total_state_time_obs = r(N)
			local pct_missing_state_time_obs = round((`num_missing_state_time_obs'/`num_total_state_time_obs')*100,1)
			
			
			twoway ///
				(scatter beta tdiff if tdiff!=., m(circle) mc(gs9) ///
				legend(off) xline(-1) yline(0) xmtick(`min'(1)`max') xlabel(`min'(2)`max') ///
				ytitle("log(`outcome_var')") xtitle("Time Since Policy (`time_period's)") ///
				title("`title_line1'" "`title_line2'") subtitle("`subtitle'") ///
				note("Notes: " ///
				"  - Whiskers are 95% confidence intervals" ///
				"  - Standard errors clustered at the state level" ///
				"  - Observations more than `min_num' `time_period's before policy are included in the `min' indicator" ///
				"  - Observations more than `max' `time_period's after policy are included in the `max' indicator" ///
				"  - `num_states_indata' states have separate device reimbursement during data time period" ///
				"  - `num_missing_state_time_obs' out of `num_total_state_time_obs' state-`time_period's missing due to small cell censoring (`pct_missing_state_time_obs'%)" ///
				"  - `policy_lag_note'" ///
				"`merge_notes'")) ///
				(rcap upperlimit lowerlimit tdiff, lc(gs9))
			****NOTE: If adding more notes to graph make sure to add them BEFORE "`merge_notes'" becuase merge_notes local is empty for month datasets which cutoffs comments after
			graph export `dataset_orig'_`time_period'_ES.pdf, replace
			* end 10 **************************************************************************************
			
			display "--------------------------------------------------"
			display "--------------------------------------------------"
		}
	}
}
display "COUNT 1: `count'"
display "COUNT 2: `count2'"
log close
