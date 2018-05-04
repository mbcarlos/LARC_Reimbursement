/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file reads in the LARC policy data and merges it with LARC utilization data (CMS SDUD) and vital statistics data to 
create .dta files for analysis. 
Input: 
	SAS formatted birth data in WORK library
	SAS formatted SDUD (quarterly) from util library
Output: 
	anlaysis data files (.dta) stored in &save_stata_data_path.
Date modified: May 4, 2018
Author: Marisa Carlos (mbc96@cornell.edu)
***************************************************************************************************************************************/

*** Upload LARC policies info;
data WORK.STATE_LARC_POLICIES    ;
	%let _EFIERR_ = 0; /* set the ERROR detection macro variable */
	infile "&larc_policy_spreadsheet_path." delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;

		informat state_long $20. ;
		informat state_short $2. ;
		informat month_enacted $4. ;
		informat year_enacted best32. ;
		informat policy_num best32. ;
		informat month_day_ended $3. ;
		informat year_ended best32. ;
		informat device_payment_type $5. ;
		informat insertion_payment_type $5. ;
		informat remove_robust_reason $50. ;
		informat any_separate_device best32. ;
		informat any_separate_insertion best32. ;

		format state_long $20. ;
		format state_short $2. ;
		format month_enacted $4. ;
		format year_enacted best12. ;
		format policy_num best12. ;
		format month_day_ended $3. ;
		format year_ended best12. ;
		format device_payment_type $5. ;
		format insertion_payment_type $5. ;
		format remove_robust_reason $50. ;
		format any_separate_device best12. ;
		format any_separate_insertion best12. ;
	input
		state_long $
		state_short $
		month_enacted $
		year_enacted
		policy_num
		month_day_ended $
		year_ended
		device_payment_type $
		insertion_payment_type $
		remove_robust_reason $
		any_separate_device
		any_separate_insertion
		;
	if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
	run;

%macro larc_policies;
*** Turn month/years into dates;
%let months = jan feb mar apr may jun jul aug sep oct nov dec;
%let month_codes = 1 2 3 4 5 6 7 8 9 10 11 12;
%let case_enacted_macro = ;
%let case_ended_macro = ;
%do i = 1 %to 12;
	%let month = %scan(&months.,&i.);
	%let code = %scan(&month_codes.,&i.);
	%let case_enacted_macro = &case_enacted_macro. when lowcase(substr(month_enacted,1,3)) = "&month." then &code.;
	%let case_ended_macro = &case_ended_macro. when lowcase(substr(month_day_ended,1,3)) = "&month." then &code.;
%end;
%put &case_enacted_macro.;
%put &case_ended_macro.;

proc sql noprint;
	create table state_larc_policies as 
		select *,
		case
			&case_enacted_macro.
			else .
		end as month_enacted_code,
		case
			&case_ended_macro.
			else .
		end as month_ended_code
			from state_larc_policies;

	create table state_larc_policies as 
		select *, 
			case
				when month_enacted_code is not missing then mdy(month_enacted_code,1,year_enacted) 
				else mdy(1,1,1900)
			end as date_enacted format=mmddyy10.,
			case
				when month_ended_code is not missing then intnx('day', intnx('month', mdy(month_ended_code,1,year_ended) , 1), -1)
				else mdy(1,1,2100)
			end as date_ended format=mmddyy10.,
	
			case
				when month_enacted_code is not missing then intnx('month', mdy(month_enacted_code,1,year_enacted), 9)
				else mdy(1,1,1900)
			end as date_enacted_9molag format=mmddyy10.,
			case
				when month_ended_code is not missing then 
					intnx('month', intnx('day', intnx('month', mdy(month_ended_code,1,year_ended) , 1), -1), 9) 
				else mdy(1,1,2100)
			end as date_ended_9molag format=mmddyy10.,

			case
				when month_enacted_code is not missing then intnx('month', mdy(month_enacted_code,1,year_enacted), 8)
				else mdy(1,1,1900)
			end as date_enacted_8molag format=mmddyy10.,
			case
				when month_ended_code is not missing then 
					intnx('month', intnx('day', intnx('month', mdy(month_ended_code,1,year_ended) , 1), -1), 8) 
				else mdy(1,1,2100)
			end as date_ended_8molag format=mmddyy10.
				from state_larc_policies;
quit;
%mend larc_policies;
%larc_policies;



*** Merge LARC policy info with MONTHLY birth data;
%let prefixes = lbw lt37weeks_lmp lt37weeks_oe natality;
%let suffixes = black hispanic teen total unmarried;
%macro merge_birth_policies;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _8molag;
	/*
	%if &prefix. = lbw %then %do;
		%let larc_date_suffix = _9molag;
	%end;
	%else %if %substr(&prefix.,1,4)=lt37 %then %do;
		%let larc_date_suffix = _8molag;
	%end;
	%else %do;
		%let larc_date_suffix = _9molag;
	%end;
	*/

	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);

		proc sql noprint;
			select count(*) into :count_a from &prefix._&suffix.RAW;

			select count(*) into :count_b from state_larc_policies;

			create table savedata.&prefix._&suffix. as 
				select *
					from &prefix._&suffix.RAW as a
					inner join state_larc_policies as b
						on (a.month_year >= b.date_enacted&larc_date_suffix. AND a.month_year <= b.date_ended&larc_date_suffix. 
						AND upcase(strip(a.state)) = upcase(strip(b.state_long))) 
						OR (upcase(strip(a.state)) = upcase(strip(b.state_long)) 
							AND b.policy_num=1 AND a.month_year < b.date_enacted&larc_date_suffix.);

			select count(*) into :countmerge from savedata.&prefix._&suffix.;

			create table savedata.&prefix._&suffix.(drop = month state_long month_enacted month_day_ended 
			month_enacted_code year_enacted month_ended_code year_ended month_code state_code year)  as 
				select *, 
				case
					when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=month_year<=date_ended&larc_date_suffix.  then 1
					else 0
				end as separate_device_reimb,
				case
					when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=month_year<=date_ended&larc_date_suffix.  then 1
					else 0
				end as separate_insert_reimb
					from savedata.&prefix._&suffix.;

			select count(*) into :countmissing from savedata.&prefix._&suffix. where births is missing;
		quit;
		%put -------------------------------------------------------------------------------;
		%put DATASET = &prefix._&suffix.;
		%put COUNT IN &prefix._&suffix. (a): &count_a.;
		%put COUNT IN state larc policies (b): &count_b.;
		%put MERGE COUNT: &countmerge.;
		%put COUNT MISSING: &countmissing.;
		%put -------------------------------------------------------------------------------;

		*Create stata dataset;
		proc export data=savedata.&prefix._&suffix. outfile="&save_stata_data_path.&prefix._&suffix..dta"
		replace;
		quit;
	%end;
%end;
%mend merge_birth_policies;
%merge_birth_policies;




*** Merge LARC policy data with LARC utilization data;
*** Create date variable for LARC utilization dataset;
***LARC data is at the QUARTER level - need to make a decision about when to turn the policy "ON" - if state starts covering LARC in 
february, do we say that "separate_device payemt" = 1 for quarter 1? Or is it 0?;

%macro merge_util_policy_data(syear=,eyear=);
*** Create variable for first day of quarter and last day of quarter;
proc sql noprint;
	create table larc_util_data(drop=year state quarter rename=(state_l=state year_l=year quarter_l=quarter)) as 
		select *,
		case
			when quarter_l=1 then mdy(1,1,year_l)
			when quarter_l=2 then mdy(4,1,year_l)
			when quarter_l=3 then mdy(7,1,year_l)
			when quarter_l=4 then mdy(10,1,year_l)
		end as firstday_q format=mmddyy10.,
		case
			when quarter_l=1 then mdy(3,31,year_l)
			when quarter_l=2 then mdy(6,30,year_l)
			when quarter_l=3 then mdy(9,30,year_l)
			when quarter_l=4 then mdy(12,31,year_l)
		end as lastday_q format=mmddyy10.
			from util.larc_state_year_q_&syear.to&eyear.;
quit;


proc sql noprint;
	select count(*) into :count_a from larc_util_data;
	select count(*) into :count_b from state_larc_policies;

	create table savedata.larc_util_fdq(drop=date_enacted_: date_ended_: month_enacted_code month_ended_code) as 
		select *
			from larc_util_data as a
			inner join state_larc_policies as b
				on (a.firstday_q >= b.date_enacted AND a.firstday_q <= b.date_ended
				AND upcase(strip(a.state))=upcase(strip(b.state_short)))
				OR (upcase(strip(a.state))=upcase(strip(b.state_short))
				AND b.policy_num=1 AND a.firstday_q < b.date_enacted);

	select count(*) into :countmerge_a from savedata.larc_util_fdq;

	create table savedata.larc_util_ldq(drop=date_enacted_: date_ended_: month_enacted_code month_ended_code) as 
		select *
			from larc_util_data as a
			inner join state_larc_policies as b
				on (a.lastday_q >= b.date_enacted AND a.lastday_q <= b.date_ended
				AND upcase(strip(a.state))=upcase(strip(b.state_short)))
				OR (upcase(strip(a.state))=upcase(strip(b.state_short))
				AND b.policy_num=1 AND a.lastday_q < b.date_enacted);

	select count(*) into :countmerge_b from savedata.larc_util_ldq;
quit;
%put -------------------------------------------------------------------------------;
%put COUNT IN larc_util_data (a): &count_a.;
%put COUNT IN state larc policies (b): &count_b.;
%put MERGE COUNT (first day): &countmerge_a.;
%put MERGE COUNT (last day): &countmerge_b.;
%put -------------------------------------------------------------------------------;

proc sql noprint;
	create table savedata.larc_util_fdq as 
		select *,
		case
			when upcase(device_payment_type) contains "S" AND date_enacted<=firstday_q<=date_ended then 1
			else 0
		end as separate_device_reimb,
		case
			when upcase(insertion_payment_type) contains "S" AND date_enacted<=firstday_q<=date_ended then 1
			else 0
		end as separate_insert_reimb
			from savedata.larc_util_fdq;

	create table savedata.larc_util_ldq as 
		select *,
		case
			when upcase(device_payment_type) contains "S" AND date_enacted<=lastday_q<=date_ended then 1
			else 0
		end as separate_device_reimb,
		case
			when upcase(insertion_payment_type) contains "S" AND date_enacted<=lastday_q<=date_ended then 1
			else 0
		end as separate_insert_reimb
			from savedata.larc_util_ldq;
quit;

*** Export to stata;
proc export data=savedata.larc_util_ldq outfile="&save_stata_data_path.larc_util_ldq.dta"
replace;
quit;

proc export data=savedata.larc_util_fdq outfile="&save_stata_data_path.larc_util_fdq.dta"
replace;
quit;
%mend merge_util_policy_data;
%merge_util_policy_data(syear=2009,eyear=2017);




*** Merge policy info into the QUARTERLY birth data;
%let prefixes = natality lbw lt37weeks_lmp lt37weeks_oe;
%let suffixes = total black hispanic teen unmarried;
%macro merge_quarter_birth_data;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _8molag;

	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);

		proc sql noprint;
		*** Merge in the policy info;
			create table savedata.&prefix._&suffix._fdq as 
				select *
					from &prefix._&suffix._q as a
					inner join state_larc_policies as b
						on (a.firstday_q >= b.date_enacted&larc_date_suffix. AND a.firstday_q <= b.date_ended&larc_date_suffix.
						AND upcase(strip(a.state))=upcase(strip(b.state_long)))
						OR (upcase(strip(a.state))=upcase(strip(b.state_long))
						AND b.policy_num=1 AND a.firstday_q < b.date_enacted&larc_date_suffix.);

			create table savedata.&prefix._&suffix._ldq as 
				select *
					from &prefix._&suffix._q as a
					inner join state_larc_policies as b
						on (a.lastday_q >= b.date_enacted&larc_date_suffix. AND a.lastday_q <= b.date_ended&larc_date_suffix.
						AND upcase(strip(a.state))=upcase(strip(b.state_long)))
						OR (upcase(strip(a.state))=upcase(strip(b.state_long))
						AND b.policy_num=1 AND a.lastday_q < b.date_enacted&larc_date_suffix.);

			create table savedata.&prefix._&suffix._fdq as 
				select *,
				case
					when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=firstday_q<=date_ended&larc_date_suffix. then 1
					else 0
				end as separate_device_reimb,
				case
					when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=firstday_q<=date_ended&larc_date_suffix. then 1
					else 0
				end as separate_insert_reimb
					from savedata.&prefix._&suffix._fdq
						order by state, year, quarter;

			create table savedata.&prefix._&suffix._ldq as 
				select *,
				case
					when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=lastday_q<=date_ended&larc_date_suffix. then 1
					else 0
				end as separate_device_reimb,
				case
					when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=lastday_q<=date_ended&larc_date_suffix. then 1
					else 0
				end as separate_insert_reimb
					from savedata.&prefix._&suffix._ldq
						order by state, year, quarter;
		quit;
	
		*Create stata dataset;
		proc export data=savedata.&prefix._&suffix._fdq outfile="&save_stata_data_path.&prefix._&suffix._fdq.dta"
		replace;

		proc export data=savedata.&prefix._&suffix._ldq outfile="&save_stata_data_path.&prefix._&suffix._ldq.dta"
		replace;
		quit;
	%end;
%end;
%mend merge_quarter_birth_data;
%merge_quarter_birth_data;




************************************************************************************************************************************
Merge LARC policy info with the monthly birth data for 2nd child +
************************************************************************************************************************************;

%let prefixes = lbw lt37weeks_lmp lt37weeks_oe natality;
%let suffixes = black hispanic teen total unmarried;
%macro merge_birth_policies_childtwo;
proc sql noprint;
	create table work_datasets as 
		select *
			from sashelp.vmember 
				where lowcase(libname) contains "work" and memtype = "DATA";
quit;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _8molag;

	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);

		*** First make sure the dataset exists (if not skip this prefix suffix combination);
		proc sql noprint; select count(*) into :dataset_exists from work_datasets where lowcase(memname) = "&prefix._&suffix.raw_c2"; quit;

		%if &dataset_exists.=1 %then %do;
			proc sql noprint;
				select count(*) into :count_a from &prefix._&suffix.RAW_C2;

				select count(*) into :count_b from state_larc_policies;

				create table savedata.&prefix._&suffix._C2 as 
					select *
						from &prefix._&suffix.RAW_C2 as a
						inner join state_larc_policies as b
							on (a.month_year >= b.date_enacted&larc_date_suffix. AND a.month_year <= b.date_ended&larc_date_suffix. 
							AND upcase(strip(a.state)) = upcase(strip(b.state_long))) 
							OR (upcase(strip(a.state)) = upcase(strip(b.state_long)) 
								AND b.policy_num=1 AND a.month_year < b.date_enacted&larc_date_suffix.);

				select count(*) into :countmerge from savedata.&prefix._&suffix._C2;

				create table savedata.&prefix._&suffix._C2(drop = month state_long month_enacted month_day_ended 
				month_enacted_code year_enacted month_ended_code year_ended month_code state_code year)  as 
					select *, 
					case
						when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=month_year<=date_ended&larc_date_suffix.  then 1
						else 0
					end as separate_device_reimb,
					case
						when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=month_year<=date_ended&larc_date_suffix.  then 1
						else 0
					end as separate_insert_reimb
						from savedata.&prefix._&suffix._C2;

				select count(*) into :countmissing from savedata.&prefix._&suffix._C2 where births is missing;
			quit;
			%put -------------------------------------------------------------------------------;
			%put DATASET = &prefix._&suffix._C2;
			%put COUNT IN &prefix._&suffix._C2 (a): &count_a.;
			%put COUNT IN state larc policies (b): &count_b.;
			%put MERGE COUNT: &countmerge.;
			%put COUNT MISSING: &countmissing.;
			%put -------------------------------------------------------------------------------;

			*Create stata dataset;
			proc export data=savedata.&prefix._&suffix._C2 outfile="&save_stata_data_path.&prefix._&suffix._C2.dta"
			replace;
			quit;
		%end;
		%else %do;
			%put SKIPPING PREFIX SUFFIX - &prefix._&suffix.RAW_C2 does not exist;
		%end;
	%end;
%end;
%mend merge_birth_policies_childtwo;
%merge_birth_policies_childtwo;


************************************************************************************************************************************
Merge LARC policy info with the quarterly birth data for 2nd child +
************************************************************************************************************************************;
%let prefixes = natality lbw lt37weeks_lmp lt37weeks_oe;
%let suffixes = total black hispanic teen unmarried;
%macro merge_quarter_childtwo;
proc sql noprint;
	create table work_datasets as 
		select *
			from sashelp.vmember 
				where lowcase(libname) contains "work" and memtype = "DATA";
quit;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _8molag;

	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);

		*** First make sure the dataset exists (if not skip this prefix suffix combination);
		proc sql noprint; select count(*) into :dataset_exists from work_datasets where lowcase(memname) = "&prefix._&suffix._q_c2"; quit;
		
		%if &dataset_exists.=1 %then %do;
			proc sql noprint;
			*** Merge in the policy info;
				create table savedata.&prefix._&suffix._fdq_C2 as 
					select *
						from &prefix._&suffix._q_C2 as a
						inner join state_larc_policies as b
							on (a.firstday_q >= b.date_enacted&larc_date_suffix. AND a.firstday_q <= b.date_ended&larc_date_suffix.
							AND upcase(strip(a.state))=upcase(strip(b.state_long)))
							OR (upcase(strip(a.state))=upcase(strip(b.state_long))
							AND b.policy_num=1 AND a.firstday_q < b.date_enacted&larc_date_suffix.);

				create table savedata.&prefix._&suffix._ldq_C2 as 
					select *
						from &prefix._&suffix._q_C2 as a
						inner join state_larc_policies as b
							on (a.lastday_q >= b.date_enacted&larc_date_suffix. AND a.lastday_q <= b.date_ended&larc_date_suffix.
							AND upcase(strip(a.state))=upcase(strip(b.state_long)))
							OR (upcase(strip(a.state))=upcase(strip(b.state_long))
							AND b.policy_num=1 AND a.lastday_q < b.date_enacted&larc_date_suffix.);

				create table savedata.&prefix._&suffix._fdq_C2 as 
					select *,
					case
						when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=firstday_q<=date_ended&larc_date_suffix. then 1
						else 0
					end as separate_device_reimb,
					case
						when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=firstday_q<=date_ended&larc_date_suffix. then 1
						else 0
					end as separate_insert_reimb
						from savedata.&prefix._&suffix._fdq_C2
							order by state, year, quarter;

				create table savedata.&prefix._&suffix._ldq_C2 as 
					select *,
					case
						when upcase(device_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=lastday_q<=date_ended&larc_date_suffix. then 1
						else 0
					end as separate_device_reimb,
					case
						when upcase(insertion_payment_type) contains "S" AND date_enacted&larc_date_suffix.<=lastday_q<=date_ended&larc_date_suffix. then 1
						else 0
					end as separate_insert_reimb
						from savedata.&prefix._&suffix._ldq_C2
							order by state, year, quarter;
			quit;
		
			*Create stata dataset;
			proc export data=savedata.&prefix._&suffix._fdq_C2 outfile="&save_stata_data_path.&prefix._&suffix._fdq_C2.dta"
			replace;

			proc export data=savedata.&prefix._&suffix._ldq_C2 outfile="&save_stata_data_path.&prefix._&suffix._ldq_C2.dta"
			replace;
			quit;
		%end;
		%else %do;
			%put SKIPPING PREFIX SUFFIX - &prefix._&suffix._q_c2 does not exist;
		%end;
	%end;
%end;
%mend merge_quarter_childtwo;
%merge_quarter_childtwo;
