/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file reads in the LARC policy data and merges it with vital statistics data to 
create .dta files for analysis. 
Input: 
	SAS formatted birth data in WORK library
	LARC policy spreadsheet (&larc_policy_spreadsheet_path.)
Output: 
	anlaysis data files (.dta) stored in &save_stata_data_path.
Date modified: September 14, 2018
Author: Marisa Carlos (mbc96@cornell.edu)
***************************************************************************************************************************************/

*** Read in LARC policy info;
data state_larc_policies    ;
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
				when month_ended_code is not missing then intnx('month',mdy(month_ended_code,1,year_ended),0,'E')
				/*the last day of the month in which the policy is enacted (means from the end ('E') of mdy(month_ended_code_1,year_ended), add 0 months)*/
				/*when month_ended_code is not missing then intnx('day', intnx('month', mdy(month_ended_code,1,year_ended) , 1), -1)*/
				else mdy(1,1,2100)
			end as date_ended format=mmddyy10.,
	
			case
				/*when month_enacted_code is not missing then intnx('month', mdy(month_enacted_code,1,year_enacted), 9)*/
				when month_enacted_code is not missing then intnx('month',intnx('month', mdy(month_enacted_code,1,year_enacted), 9,'M'),0,'B')
				/*from the month the policy is enacted, go to the middle of the month, add 9 months, then go to th beginning of that month*/
				else mdy(1,1,1900)
			end as date_enacted_9molag format=mmddyy10.,
/*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
			case
				when month_ended_code is not missing then 
					intnx('month', 
						intnx('day', 
							intnx('month', mdy(month_ended_code,1,year_ended) , 1)
						, -1)
					, 9) 
				else mdy(1,1,2100)
			end as date_ended_9molag format=mmddyy10.,
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************/
			case
				when month_ended_code is not missing then intnx('month',intnx('month',intnx('month',mdy(month_ended_code,1,year_ended),0,'E'),9,'M'),0,'E')
				/*from the last day of the month when the policy is enacted, go tot he middle of the month, add 9 months, then go to the end of that month*/
				/*when month_ended is not missing then intnx('month',intnx('month',date_ended,9,'M'),0,'E')*/
				else mdy(1,1,2100)
			end as date_ended_9molag format=mmddyy10.,

			case
				when month_enacted_code is not missing then intnx('month',intnx('month', mdy(month_enacted_code,1,year_enacted), 8,'M'),0,'B')
				/*from the middle of the month the policy is enacted, add 8 months, then go to the bginning of that month*/
				/*when month_enacted_code is not missing then intnx('month', mdy(month_enacted_code,1,year_enacted), 8)*/
				else mdy(1,1,1900)
			end as date_enacted_8molag format=mmddyy10.,
			case
				when month_ended_code is not missing then intnx('month',intnx('month',intnx('month',mdy(month_ended_code,1,year_ended),0,'E'),8,'M'),0,'E')
				/*from the end of the month the policy is enacted, move to the middle of the month, add 8 months, then go to the last day of that month*/
				/*when month_ended is not missing then intnx('month',intnx('month',date_ended,8,'M'),0,'E')*/
				/*when month_ended_code is not missing then 
					intnx('month', intnx('day', intnx('month', mdy(month_ended_code,1,year_ended) , 1), -1), 8) */
				else mdy(1,1,2100)
			end as date_ended_8molag format=mmddyy10.
				from state_larc_policies;
quit;
%mend larc_policies;
%larc_policies;


*******************************************************************************************************************************
*********************************************** Read in unemployment info data ************************************************
*******************************************************************************************************************************;
*** Read in excel sheet;
proc import datafile = "&unemployment_data_path."
	dbms=xlsx
	out=unemployment_data
	replace;
	getnames=yes;
run;

*** Add in two-character state codes using SASHELP zipcode table;
proc sql noprint;
	create table unemployment_data as 
		select input(a.year,4.) as year, a.*, b.statecode as state_short
			from unemployment_data as a
			inner join 
				(select distinct statename, statecode
				from sashelp.zipcode) as b
					on upcase(strip(a.state)) = upcase(strip(b.statename));
quit;

******************************************************************************************************************************
********************************************* Merge LARC policy info with MONTHLY birth data**********************************
******************************************************************************************************************************;
*%let prefixes = lbw lt37weeks_lmp lt37weeks_oe natality;
*%let suffixes = black hispanic teen total unmarried;

*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let prefixes = lbw natality;
%let suffixes = teen total unmarried;
%macro merge_birth_policies;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _9molag;

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

		*** Merge in annual unemployment data;
		proc sql noprint;
			select count(*) into :count1 from savedata.&prefix._&suffix.;

			create table savedata.&prefix._&suffix. as 
				select a.*, year(a.month_year)-1 as year_lagged, b.population, b.unemployment_rate
					from savedata.&prefix._&suffix. as a
					left join unemployment_data as b
						on year(a.month_year)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			create table savedata.&prefix._&suffix. as 
				select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
					from savedata.&prefix._&suffix. as a
					inner join unemployment_data as b
						on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			select count(*) into :count2 from savedata.&prefix._&suffix.;

		quit;
		%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;

		*Create stata dataset;
		proc export data=savedata.&prefix._&suffix. outfile="&save_stata_data_path.&prefix._&suffix..dta"
		replace;
		quit;
	%end;
%end;
%mend merge_birth_policies;
%merge_birth_policies;


******************************************************************************************************************************
********************************************* Merge LARC policy info with QUARTERLY birth data**********************************
******************************************************************************************************************************;

%let prefixes = natality lbw;
%let suffixes = total teen unmarried hsorless;
%macro merge_quarter_birth_data;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _9molag;

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
						on (
							a.lastday_q >= b.date_enacted&larc_date_suffix. AND a.lastday_q <= b.date_ended&larc_date_suffix.
							AND upcase(strip(a.state))=upcase(strip(b.state_long))
							)
						OR (
							upcase(strip(a.state))=upcase(strip(b.state_long))
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

		*** Merge in annual unemployment data;
		proc sql noprint;
			select count(*) into :count1 from savedata.&prefix._&suffix._fdq;

			create table savedata.&prefix._&suffix._fdq as 
				select a.*, year(a.firstday_q)-1 as year_lagged, b.population, b.unemployment_rate
					from savedata.&prefix._&suffix._fdq as a
					left join unemployment_data as b
						on year(a.firstday_q)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			create table savedata.&prefix._&suffix._fdq as 
				select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
					from savedata.&prefix._&suffix._fdq as a
					inner join unemployment_data as b
						on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			select count(*) into :count2 from savedata.&prefix._&suffix._fdq;
		quit;
		%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;

		proc sql noprint;
			select count(*) into :count1 from savedata.&prefix._&suffix._ldq;

			create table savedata.&prefix._&suffix._ldq as 
				select a.*, year(a.firstday_q)-1 as year_lagged, b.population, b.unemployment_rate
					from savedata.&prefix._&suffix._ldq as a
					left join unemployment_data as b
						on year(a.firstday_q)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			create table savedata.&prefix._&suffix._ldq as 
				select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
					from savedata.&prefix._&suffix._ldq as a
					inner join unemployment_data as b
						on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

			select count(*) into :count2 from savedata.&prefix._&suffix._ldq;
		quit;
		%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;
	
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

%let prefixes = lbw natality;
%let suffixes = teen total unmarried;
%macro merge_birth_policies_childtwo;
proc sql noprint;
	create table work_datasets as 
		select *
			from sashelp.vmember 
				where lowcase(libname) contains "work" and memtype = "DATA";
quit;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _9molag;

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

			*** Merge in annual unemployment data;
			proc sql noprint;
				select count(*) into :count1 from savedata.&prefix._&suffix._C2;

				create table savedata.&prefix._&suffix._C2 as 
					select a.*, year(a.month_year)-1 as year_lagged, b.population, b.unemployment_rate
						from savedata.&prefix._&suffix._C2 as a
						left join unemployment_data as b
							on year(a.month_year)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

				create table savedata.&prefix._&suffix._C2 as 
					select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
						from savedata.&prefix._&suffix._C2 as a
						inner join unemployment_data as b
							on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

				select count(*) into :count2 from savedata.&prefix._&suffix._C2;
			quit;
			%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;

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
%let prefixes = natality lbw;
%let suffixes = total teen unmarried hsorless;
%macro merge_quarter_childtwo;
proc sql noprint;
	create table work_datasets as 
		select *
			from sashelp.vmember 
				where lowcase(libname) contains "work" and memtype = "DATA";
quit;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%let larc_date_suffix = _9molag;

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

			*** Merge in annual unemployment data;
			proc sql noprint;
				select count(*) into :count1 from savedata.&prefix._&suffix._fdq_C2;

				create table savedata.&prefix._&suffix._fdq_C2 as 
					select a.*, year(a.firstday_q)-1 as year_lagged, b.population, b.unemployment_rate
						from savedata.&prefix._&suffix._fdq_C2 as a
						left join unemployment_data as b
							on year(a.firstday_q)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

				select count(*) into :count2 from savedata.&prefix._&suffix._fdq_C2;

				create table savedata.&prefix._&suffix._fdq_C2 as 
					select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
						from savedata.&prefix._&suffix._fdq_C2 as a
						inner join unemployment_data as b
							on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));
			quit;
			%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;

			proc sql noprint;
				select count(*) into :count1 from savedata.&prefix._&suffix._ldq_C2;

				create table savedata.&prefix._&suffix._ldq_C2 as 
					select a.*, year(a.firstday_q)-1 as year_lagged, b.population, b.unemployment_rate
						from savedata.&prefix._&suffix._ldq_C2 as a
						left join unemployment_data as b
							on year(a.firstday_q)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

				create table savedata.&prefix._&suffix._ldq_C2 as 
					select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
						from savedata.&prefix._&suffix._ldq_C2 as a
						inner join unemployment_data as b
							on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

				select count(*) into :count2 from savedata.&prefix._&suffix._ldq_C2;
			quit;
			%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) DIFF NUMBER OF OBS AFTER MERGING IN UNEMPLOYMENT INFO;
		
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




************************************************************************************************************************************
Merge LARC policy info with LARC utilization data
************************************************************************************************************************************;
proc sql noprint;
	create table savedata.larc_utilization_fdq as 
		select *
			from savedata.larc_utilization as a
			inner join state_larc_policies as b
				on (a.firstday_q >= b.date_enacted
					AND a.firstday_q <= b.date_ended
					AND upcase(strip(a.state))=upcase(strip(b.state_short)))
				OR (upcase(strip(a.state))=upcase(strip(b.state_short))
					AND b.policy_num=1 
					AND a.firstday_q < b.date_enacted);

	create table savedata.larc_utilization_ldq as 
		select *
			from savedata.larc_utilization as a 
			inner join state_larc_policies as b
				on (a.lastday_q >= b.date_enacted 
					AND a.lastday_q <= b.date_ended
					AND upcase(strip(a.state))=upcase(strip(b.state_short)))
				OR (upcase(strip(a.state))=upcase(strip(b.state_short))
					AND b.policy_num=1 
					AND a.lastday_q < b.date_enacted);

	create table savedata.larc_utilization_fdq as 
		select *,
		case
			when upcase(device_payment_type) contains "S" AND date_enacted<=firstday_q<=date_ended then 1
			else 0
		end as separate_device_reimb,
		case
			when upcase(insertion_payment_type) contains "S" AND date_enacted<=firstday_q<=date_ended then 1
			else 0
		end as separate_insert_reimb
			from savedata.larc_utilization_fdq
				order by state, year, quarter;

	create table savedata.larc_utilization_ldq as 
		select *,
		case
			when upcase(device_payment_type) contains "S" AND date_enacted<=lastday_q<=date_ended then 1
			else 0
		end as separate_device_reimb,
		case
			when upcase(insertion_payment_type) contains "S" AND date_enacted<=lastday_q<=date_ended then 1
			else 0
		end as separate_insert_reimb
			from savedata.larc_utilization_ldq
				order by state, year, quarter;
quit;

************************************************************************************************************************************
Merge unmployment and population data into LARC utilization data
************************************************************************************************************************************;
%macro merge_larc_unemployment_data;
proc sql noprint;
	select count(*) into :count1 from savedata.larc_utilization_fdq;

	create table savedata.larc_utilization_fdq as 
		select a.*, a.year-1 as year_lagged, b.population, b.unemployment_rate
			from savedata.larc_utilization_fdq as a
			left join unemployment_data as b
				on a.year=b.year and upcase(strip(a.state)) = upcase(strip(b.state_short));

	create table savedata.larc_utilization_fdq as 
		select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
			from savedata.larc_utilization_fdq as a
			inner join unemployment_data as b
				on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

	select count(*) into :count2 from savedata.larc_utilization_fdq;
quit;
%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) NUMBER OF OBS NOT EQUAL AFTER MERGING IN UNEMPLOYMENT DATA;

proc sql noprint;
	select count(*) into :count1 from savedata.larc_utilization_ldq;

	create table savedata.larc_utilization_ldq as 
		select a.*, a.year-1 as year_lagged, b.population, b.unemployment_rate
			from savedata.larc_utilization_ldq as a
			left join unemployment_data as b
				on a.year=b.year and upcase(strip(a.state)) = upcase(strip(b.state_short));

	create table savedata.larc_utilization_ldq as 
		select a.*, b.population as population_1yrlag, b.unemployment_rate as unemployment_rate_1yrlag
			from savedata.larc_utilization_ldq as a
			inner join unemployment_data as b
				on a.year_lagged=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

	select count(*) into :count2 from savedata.larc_utilization_ldq;
quit;
%if &count1.~=&count2. %then %put ERROR: (count1=&count1. count2=&count2.) NUMBER OF OBS NOT EQUAL AFTER MERGING IN UNEMPLOYMENT DATA;
%mend merge_larc_unemployment_data;
%merge_larc_unemployment_data;

*** Export LARC utilization datasets to stata;
proc export data=savedata.larc_utilization_fdq outfile="&save_stata_data_path.larc_utilization_fdq.dta"
replace;
quit;

proc export data=savedata.larc_utilization_ldq outfile="&save_stata_data_path.larc_utilization_ldq.dta"
replace;
quit;
