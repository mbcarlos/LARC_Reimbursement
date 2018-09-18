/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file reads in the raw text files (vital statistics birth data) in S:\LARC\data\raw_data\birth_data and creates SAS formatted 
Input: 
	birth data .txt files from S:\LARC\data\raw_data\birth_data
Output: 
	SAS formatted raw birth data stored in the WORK library (turned into .dta files in 04_create_analysis_dta.sas)
Date modified: September 14, 2018
Author: Marisa Carlos (mbc96@cornell.edu)
***************************************************************************************************************************************/

/*
%let prefixes = lbw lt37weeks_lmp lt37weeks_oe natality;
%let suffixes = black hispanic teen total unmarried;
*/
*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let prefixes = lbw natality;
%let suffixes = teen total unmarried;
****************************************************************************************************************************************************
********************************************* IMPORT MONTHLY BIRTH DATA (ALL BIRTH ORDERS) *********************************************************
****************************************************************************************************************************************************;
%macro import_birth_data(syear=,eyear=);
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);

	%do j = 1 %to %sysfunc(countw(&suffixes.));
	%let suffix = %scan(&suffixes., &j.);

	%put ------------------------------------------------------------------------------------------;
	%put 				READING IN MONTHLY DATA: &prefix._&suffix._&syear.-&eyear..txt ;
	%put ------------------------------------------------------------------------------------------;
		
		proc import datafile = "&birthdata_pathname.&prefix._&suffix._&syear.-&eyear..txt"
			dbms = dlm
			out = &prefix._&suffix.RAW
			replace;
			delimiter = '09'X;
			getnames = yes;
			guessingrows=6682;
		run;

		proc contents data = &prefix._&suffix.RAW out=contents nodetails noprint;
		run;

		%let varlist = births month_code state_code year;
		%do varnum = 1 %to %sysfunc(countw(&varlist.));
			%let var = %scan(&varlist.,&varnum.);
			proc sql noprint;
				select type, length into :type, :length from contents where lowcase(name) = "&var.";
			quit;
			%if &type. = 1 %then %do;
				%let &var._macro = &var.;
			%end;
			%else %if &type. = 2 %then %do;
				%let &var._macro = input(&var.,&length..);
			%end;
		%end;

		proc sql noprint;
			create table &prefix._&suffix.RAW as 
				select &births_macro. as births, &month_code_macro. as month_code, &state_code_macro. as state_code, &year_macro. as year,
				state, month, mdy(&month_code_macro.,1,&year_macro.) as month_year format=mmddyy10.
					from &prefix._&suffix.RAW
						where births is not missing AND month is not missing ;
		quit;
	%end;
%end;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);
		select count(*) into :count_missing from &prefix._&suffix.RAW where births is missing;
		select count(*) into :count_total from &prefix._&suffix.RAW;
		%put --------------------------------------------------------------------------------;
		%put NUMBER OF MONTHS IN &prefix._&suffix. WITH MISSING DATA: &count_missing. (&count_total. total);
		%put --------------------------------------------------------------------------------;
	%end;
%end;
quit;
%mend import_birth_data;
%import_birth_data(syear=&first_year_birth_data.,eyear=&last_year_birth_data.);



****************************************************************************************************************************************************
******************************************* IMPORT QUARTERLY BIRTH DATA (ALL BIRTH ORDERS) *********************************************************
****************************************************************************************************************************************************;

*%let datasets = lbw_black lbw_hispanic lbw_teen lt37weeks_lmp_black lt37weeks_lmp_hispanic lt37weeks_lmp_teen 
lt37weeks_oe_black lt37weeks_oe_hispanic lt37weeks_oe_teen natality_black natality_hispanic;
*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let datasets = lbw_teen lbw_HSorless natality_HSorless; 
%macro import_quarter_birth_data(syear=,eyear=);
%do i = 1 %to %sysfunc(countw(&datasets.));
	%let dataset = %scan(&datasets., &i.);

	%do q = 1 %to 4;

		%put ------------------------------------------------------------------------------------------;
		%put 				READING IN QUARTERLY DATA: &dataset._q&q._&syear.-&eyear..txt ;
		%put ------------------------------------------------------------------------------------------;

		proc import datafile = "&quarter_birthdata_path.&dataset._q&q._&syear.-&eyear..txt"
			dbms = dlm
			out = &dataset._q&q.
			replace;
			delimiter = '09'X;
			getnames = yes;
			guessingrows=5200;
		run;

		proc contents data = &dataset._q&q. out=contents nodetails noprint;
		run;

		%let varlist = births state_code year;
		%do varnum = 1 %to %sysfunc(countw(&varlist.));
			%let var = %scan(&varlist.,&varnum.);
			proc sql noprint;
				select type, length into :type, :length from contents where lowcase(name) = "&var.";
			quit;
			%if &type. = 1 %then %do;
				%let &var._macro = &var.;
			%end;
			%else %if &type. = 2 %then %do;
				%let &var._macro = input(&var.,&length..);
			%end;
		%end;

		proc sql noprint;
			create table &dataset._q&q. as 
				select &births_macro. as births, &q. as quarter, &state_code_macro. as state_code, &year_macro. as year, state
					from &dataset._q&q.
						where births is not missing;
	
			create table &dataset._q&q. as 
				select *, 
				case
					when quarter=1 then mdy(1,1,year)
					when quarter=2 then mdy(4,1,year)
					when quarter=3 then mdy(7,1,year)
					when quarter=4 then mdy(10,1,year)
				end as firstday_q format=mmddyy10.,
				case
					when quarter=1 then mdy(3,31,year)
					when quarter=2 then mdy(6,30,year)
					when quarter=3 then mdy(9,30,year)
					when quarter=4 then mdy(12,31,year)
				end as lastday_q format=mmddyy10.
					from &dataset._q&q.
						order by state, year, quarter;
		quit;
	%end;

	*** Stack the 4 quarters of data into one dataset;
	proc sql noprint;
		create table &dataset._q as 
			select *
			from &dataset._q1
			%do q = 2 %to 4;
				outer union corresponding
				select * from &dataset._q&q.
			%end;
				order by state, year, quarter;
	quit;
%end;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&datasets.));
	%let dataset = %scan(&datasets., &i.);

	select count(*) into :count_missing from &dataset._q where births is missing;
	select count(*) into :count_total from &dataset._q;
	%put --------------------------------------------------------------------------------;
	%put NUMBER OF QUARTERS IN &dataset._q WITH MISSING DATA: &count_missing. (&count_total. total);
	%put --------------------------------------------------------------------------------;
%end;
quit;
%mend import_quarter_birth_data;
%import_quarter_birth_data(syear=&first_year_birth_data., eyear=&last_year_birth_data.);



****************************************************************************************************************************************************
**************************************************** ROLL UP BIRTH DATA (ALL BIRTH ORDERS) *********************************************************
****************************************************************************************************************************************************;


*%let rollup_datasets = lbw_total lbw_unmarried lt37weeks_lmp_total lt37weeks_lmp_unmarried lt37weeks_oe_total lt37weeks_oe_unmarried
natality_teen natality_total natality_unmarried;
*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let rollup_datasets = lbw_total lbw_unmarried natality_teen natality_total natality_unmarried;
%macro rollup_birth_data;
proc sql noprint;
%do i = 1 %to %sysfunc(countw(&rollup_datasets.));
	%let dataset = %scan(&rollup_datasets., &i.);
		*** Roll up the raw birth data to the quarter level and create evariable for first day and last day of quarter;
		create table &dataset._q as 
			select *,
			case
				when month_code in (1,2,3) then 1
				when month_code in (4,5,6) then 2
				when month_code in (7,8,9) then 3
				when month_code in (10,11,12) then 4
				else .
			end as quarter,
			case
				when month_code in (1,2,3) then mdy(1,1,year)
				when month_code in (4,5,6) then mdy(4,1,year)
				when month_code in (7,8,9) then mdy(7,1,year)
				when month_code in (10,11,12) then mdy(10,1,year)
				else .
			end as firstday_q format=mmddyy10.,
			case
				when month_code in (1,2,3) then mdy(3,31,year)
				when month_code in (4,5,6) then mdy(6,30,year)
				when month_code in (7,8,9) then mdy(9,30,year)
				when month_code in (10,11,12) then mdy(12,31,year)
				else .
			end as lastday_q format=mmddyy10.
				from &dataset.RAW;

		create table &dataset._q as 
			select firstday_q, lastday_q, quarter, year, state_code, state,
			case
				when count(births)=3 then sum(births)
				when count(births)~=3 then .
				else .
			end as births
				from &dataset._q
					group by firstday_q, lastday_q, quarter, year, state_code, state
						order by state, year, quarter;

%end;
quit;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&rollup_datasets.));
	%let dataset = %scan(&rollup_datasets., &i.);

	select count(*) into :count_missing from &dataset._q where births is missing;
	select count(*) into :count_total from &dataset._q;
	%put --------------------------------------------------------------------------------;
	%put NUMBER OF QUARTERS IN &dataset._q WITH MISSING DATA: &count_missing. (&count_total. total);
	%put --------------------------------------------------------------------------------;
%end;
quit;
%mend rollup_birth_data;
%rollup_birth_data;


****************************************************************************************************************************************************
****************************************** IMPORT MONTHLY BIRTH DATA, 2nd+ BIRTH ORDER *************************************************************
****************************************************************************************************************************************************;
/*
%let prefixes = lbw lt37weeks_lmp lt37weeks_oe natality;
%let suffixes = black hispanic teen total unmarried;
*/

*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let prefixes = lbw natality;
%let suffixes = teen total unmarried;

%macro import_monthly_data_secondchild(syear=,eyear=);
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);

	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);

		%put ------------------------------------------------------------------------------------------;
		%put 	READING IN MONTHLY 2nd+ CHILD DATA: &prefix._&suffix._2ndchild_&syear.-&eyear..txt ;
		%put ------------------------------------------------------------------------------------------;
			

		%if %sysfunc(fileexist("&monthly_data_path_2ndchild.&prefix._&suffix._2ndchild_&syear.-&eyear..txt")) %then %do;
			proc import datafile = "&monthly_data_path_2ndchild.&prefix._&suffix._2ndchild_&syear.-&eyear..txt"
				dbms = dlm
				out = &prefix._&suffix.RAW_C2
				replace;
				delimiter = '09'X;
				getnames = yes;
				guessingrows=5200;
			run;

			proc contents data = &prefix._&suffix.RAW_C2 out=contents nodetails noprint;
			run;

			%let varlist = births month_code state_code year;* average_birth_weight average_age_of_mother;
			%do varnum = 1 %to %sysfunc(countw(&varlist.));
				%let var = %scan(&varlist.,&varnum.);
				proc sql noprint;
					select type, length into :type, :length from contents where lowcase(name) = "&var.";
				quit;
				%if &type. = 1 %then %do;
					%let &var._macro = &var.;
				%end;
				%else %if &type. = 2 %then %do;
					%let &var._macro = input(&var.,&length..);
				%end;
			%end;

			proc sql noprint;
				create table &prefix._&suffix.RAW_C2 as 
					select &births_macro. as births, &month_code_macro. as month_code, &state_code_macro. as state_code, &year_macro. as year,
					state, month, mdy(&month_code_macro.,1,&year_macro.) as month_year format=mmddyy10.
						from &prefix._&suffix.RAW_C2
							where births is not missing AND month is not missing ;
			quit;
		%end;
		%else %do;
			%put SKIPPING;
		%end;
	%end;
%end;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&prefixes.));
	%let prefix = %scan(&prefixes., &i.);
	%do j = 1 %to %sysfunc(countw(&suffixes.));
		%let suffix = %scan(&suffixes., &j.);
		%if %sysfunc(fileexist("&monthly_data_path_2ndchild.&prefix._&suffix._2ndchild_&syear.-&eyear..txt")) %then %do;
			select count(*) into :count_missing from &prefix._&suffix.RAW_C2 where births is missing;
			select count(*) into :count_total from &prefix._&suffix.RAW_C2;
			%put --------------------------------------------------------------------------------;
			%put NUMBER OF MONTHS IN &prefix._&suffix._C2 WITH MISSING DATA: &count_missing. (&count_total. total);
			%put --------------------------------------------------------------------------------;
		%end;
	%end;
%end;
quit;
%mend import_monthly_data_secondchild;
%import_monthly_data_secondchild(syear=&first_year_birth_data.,eyear=&last_year_birth_data.);



****************************************************************************************************************************************************
****************************************** IMPORT QUARTERLY BIRTH DATA, 2nd+ BIRTH ORDER ***********************************************************
****************************************************************************************************************************************************;
*%let datasets = lt37weeks_oe_teen lt37weeks_lmp_hispanic lbw_hispanic natality_black lt37weeks_lmp_teen lbw_teen lt37weeks_oe_hispanic;
*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let datasets = lbw_teen lbw_HSorless natality_HSorless;
%macro import_quarter_data_childtwo(syear=,eyear=);
%do i = 1 %to %sysfunc(countw(&datasets.));
	%let dataset = %scan(&datasets., &i.);

	%do q = 1 %to 4;

		%put ------------------------------------------------------------------------------------------;
		%put 	READING IN QUARTRLY 2nd+ CHILD DATA: &dataset._q&q._2ndchild_&syear.-&eyear..txt ;
		%put ------------------------------------------------------------------------------------------;

		proc import datafile = "&quarterly_data_path_2ndchild.&dataset._q&q._2ndchild_&syear.-&eyear..txt"
			dbms = dlm
			out = &dataset._q&q._C2
			replace;
			delimiter = '09'X;
			getnames = yes;
			guessingrows=5200;
		run;

		proc contents data = &dataset._q&q._C2 out=contents nodetails noprint;
		run;

		%let varlist = births state_code year;* average_birth_weight average_age_of_mother;
		%do varnum = 1 %to %sysfunc(countw(&varlist.));
			%let var = %scan(&varlist.,&varnum.);
			proc sql noprint;
				select type, length into :type, :length from contents where lowcase(name) = "&var.";
			quit;
			%if &type. = 1 %then %do;
				%let &var._macro = &var.;
			%end;
			%else %if &type. = 2 %then %do;
				%let &var._macro = input(&var.,&length..);
			%end;
		%end;

		proc sql noprint;
			create table &dataset._q&q._C2 as 
				select &births_macro. as births, &q. as quarter, &state_code_macro. as state_code, &year_macro. as year, state
					from &dataset._q&q._C2
						where births is not missing;
	
			create table &dataset._q&q._C2 as 
				select *, 
				case
					when quarter=1 then mdy(1,1,year)
					when quarter=2 then mdy(4,1,year)
					when quarter=3 then mdy(7,1,year)
					when quarter=4 then mdy(10,1,year)
				end as firstday_q format=mmddyy10.,
				case
					when quarter=1 then mdy(3,31,year)
					when quarter=2 then mdy(6,30,year)
					when quarter=3 then mdy(9,30,year)
					when quarter=4 then mdy(12,31,year)
				end as lastday_q format=mmddyy10.
					from &dataset._q&q._C2
						order by state, year, quarter;
		quit;
	%end;

	*** Stack the 4 quarters of data into one dataset;
	proc sql noprint;
		create table &dataset._q_C2 as 
			select *
			from &dataset._q1_C2
			%do q = 2 %to 4;
				outer union corresponding
				select * from &dataset._q&q._C2
			%end;
				order by state, year, quarter;
	quit;
%end;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&datasets.));
	%let dataset = %scan(&datasets., &i.);

	select count(*) into :count_missing from &dataset._q_C2 where births is missing;
	select count(*) into :count_total from &dataset._q_C2;
	%put --------------------------------------------------------------------------------;
	%put NUMBER OF QUARTERS IN &dataset._q_C2 WITH MISSING DATA: &count_missing. (&count_total. total);
	%put --------------------------------------------------------------------------------;
%end;
quit;
%mend import_quarter_data_childtwo;
%import_quarter_data_childtwo(syear=&first_year_birth_data.,eyear=&last_year_birth_data.);



****************************************************************************************************************************************************
******************************************* ROLL UP MONTHLY TO QUARTERLY (2nd+ BIRTH ORDER) ********************************************************
****************************************************************************************************************************************************;
*%let C2_rollup_datasets = lt37weeks_oe_unmarried lbw_unmarried lt37weeks_lmp_total natality_total lbw_total natality_unmarried 
lt37weeks_lmp_unmarried lt37weeks_oe_total natality_teen natality_hispanic;
*9/14/2018: Getting rid of black/hispanic stratification and premature estimates; 
%let C2_rollup_datasets = lbw_unmarried natality_total lbw_total natality_unmarried natality_teen;
%macro rollup_birth_data_childtwo;
proc sql noprint;
%do i = 1 %to %sysfunc(countw(&C2_rollup_datasets.));
	%let dataset = %scan(&C2_rollup_datasets., &i.);
		*** Roll up the raw birth data to the quarter level and create evariable for first day and last day of quarter;
		create table &dataset._q_C2 as 
			select *,
			case
				when month_code in (1,2,3) then 1
				when month_code in (4,5,6) then 2
				when month_code in (7,8,9) then 3
				when month_code in (10,11,12) then 4
				else .
			end as quarter,
			case
				when month_code in (1,2,3) then mdy(1,1,year)
				when month_code in (4,5,6) then mdy(4,1,year)
				when month_code in (7,8,9) then mdy(7,1,year)
				when month_code in (10,11,12) then mdy(10,1,year)
				else .
			end as firstday_q format=mmddyy10.,
			case
				when month_code in (1,2,3) then mdy(3,31,year)
				when month_code in (4,5,6) then mdy(6,30,year)
				when month_code in (7,8,9) then mdy(9,30,year)
				when month_code in (10,11,12) then mdy(12,31,year)
				else .
			end as lastday_q format=mmddyy10.
				from &dataset.RAW_C2;

		create table &dataset._q_C2 as 
			select firstday_q, lastday_q, quarter, year, state_code, state,
			case
				when count(births)=3 then sum(births)
				when count(births)~=3 then .
				else .
			end as births
				from &dataset._q_C2
					group by firstday_q, lastday_q, quarter, year, state_code, state
						order by state, year, quarter;

%end;
quit;

proc sql noprint;
%do i = 1 %to %sysfunc(countw(&C2_rollup_datasets.));
	%let dataset = %scan(&C2_rollup_datasets., &i.);

	select count(*) into :count_missing from &dataset._q_C2 where births is missing;
	select count(*) into :count_total from &dataset._q_C2;
	%put --------------------------------------------------------------------------------;
	%put NUMBER OF QUARTERS IN &dataset._q_C2 WITH MISSING DATA: &count_missing. (&count_total. total);
	%put --------------------------------------------------------------------------------;
%end;
quit;
%mend rollup_birth_data_childtwo;
%rollup_birth_data_childtwo;
