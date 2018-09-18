/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file reads in the LARC utilization data from state medicaid offices, merges it with LARC policy info, and creates 
state datasets for analysis.
Input: 
	formatted xlsx workbooks for each state (e.g. UT.xlsx) in complete/formatted_data/
	LARC policy spreadsheet (&larc_policy_spreadsheet_path.)
	read-in text birth data from 03_import_birthdata.sas 
Output: 
	anlaysis data files (.dta) stored in &save_stata_data_path.
Date modified: September 17, 2018
Author: Marisa Carlos (mbc96@cornell.edu)
***************************************************************************************************************************************/

filename tmp pipe &LARC_data_path_pipe.;
data larc_files;
  infile tmp dlm="¬";
  length file_name $2000;
  input file_name;
run;

proc sql noprint;
	select substr(file_name,1,2) into :states_with_larc_data separated by " " from larc_files;
quit;

%macro readin_larc_data;
%do i = 1 %to %sysfunc(countw(&states_with_larc_data.));
	%let state = %scan(&states_with_larc_data.,&i.);
	%put STATE = &state.;

	proc import
		datafile = "&LARC_data_path.&state..xlsx"
		dbms=xlsx
		out = &state.
		replace;
		getnames=yes;
	run;

	*Save list of variable names, lengths, types into dataset;
	proc contents data=&state. out=contents noprint nodetails; run;

	*** convert character variables to numeric;
	%let num_vars = ;
	%let char_vars = ;
	proc sql noprint;
		select name into :num_vars separated by ", " from contents where type=1;
		select "input(" || strip(name) || "," || put(length,1.) || ".) as " || strip(name) into :char_vars separated by ", " from contents where type=2;
		select count(*) into :count_num from contents where type=1;
		select count(*) into :count_char from contents where type=2;
		%if &count_num.=0 %then %do;
			%let select_macro = &char_vars.;
		%end;
		%if &count_char.=0 %then %do;
			%let select_macro = &num_vars.;
		%end;
		%else %do;
			%let select_macro = &num_vars., &char_vars.;
		%end;
	quit;

	proc sql noprint;
		create table &state. as 
			select "&state." as state, &select_macro.
				from &state.;
	quit;
	%if &i.=1 %then %do;
		proc sql noprint;
			create table savedata.larc_utilization as 
				select *
					from &state.;
		quit;
	%end;
	%else %do;
		proc sql noprint;
			create table savedata.larc_utilization as 
				select *
					from savedata.larc_utilization
					outer union corresponding
					select * from &state.;
		quit;
	%end;
%end;

** Add quarter information if missing it;
proc sql noprint;
	create table savedata.larc_utilization as 
		select *,
		case
			when quarter_orig is not missing then quarter_orig
			when month in (1,2,3) then 1
			when month in (4,5,6) then 2
			when month in (7,8,9) then 3
			when month in (10,11,12) then 4
		end as quarter
			from savedata.larc_utilization(rename=(quarter = quarter_orig));
quit;

** Roll up to the quarter level;
proc sql noprint;
	create table savedata.larc_utilization as 
		select state, year, quarter, sum(count_total) as larc_count,
		case
			when quarter = 1 then mdy(1,1,year)
			when quarter = 2 then mdy(4,1,year) 
			when quarter = 3 then mdy(7,1,year)
			when quarter = 4 then mdy(10,1,year)
		end as firstday_q,
		case
			when quarter = 1 then mdy(3,31,year)
			when quarter = 2 then mdy(6,30,year) 
			when quarter = 3 then mdy(9,30,year)
			when quarter = 4 then mdy(12,31,year)
		end as lastday_q
			from savedata.larc_utilization
				group by state, year, quarter, firstday_q, lastday_q;
quit;
%mend readin_larc_data;
%readin_larc_data;




