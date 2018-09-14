/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file imports the CMS state drug utilization data from .csv files downloaded from cms.gov into SAS format
Input: 
	state drug utilization data from &import_utilization_pathname.
Output: 
	SAS formatted state drug utilization data in util library
Date modified: May 4, 2018
Author: Marisa Carlos (mbc96@cornell.edu)

NOTE: As of 5/2018, this file is NOT being used b/c of inability to use CMS state drug utilization files to accurately measure LARC use 
(dont include 340b providers, etc.)
***************************************************************************************************************************************/

%macro import_drug_data(syear=,eyear=);
**** Set informat macros;
%let Utilization_Type = $4.; %let State = $2.; %let Labeler_Code = $5.; %let Product_Code = $4.; %let Package_Size = $2.; %let Year = best32.;
%let Quarter = best32.; %let Product_Name = $20.; %let Suppression_Used = $5.; %let Units_Reimbursed = best32.; %let Number_of_Prescriptions = best32.;
%let Total_Amount_Reimbursed = best32.; %let Medicaid_Amount_Reimbursed = best32.; %let Non_Medicaid_Amount_Reimbursed = best32.; %let Quarter_begin = $5.;
%let Quarter_Begin_Date = $12.; %let _latitude = best32.; %let _longitude = best32.; %let latitude = best32.; %let longitude = best32.; 
%let Location = $22.; %let NDC = $16.;

***NOTE: format macros are different than informat for best32.;

%do data_year = &syear. %to &eyear.;
	*** First read in variable names and the ORDER that they are in in the CSV file; 
	options obs=1;
	proc import datafile = "&import_utilization_pathname.State_Drug_Utilization_Data_&data_year..csv"
		dbms = csv
		out = varnames
		replace;
		getnames = no;
		guessingrows=1;
	run;
	options obs=max;

	*** Use proc contents to get var names and order of variables;
	proc contents data=varnames out=contents noprint nodetails;
	run;
	*** Get the number of variables;
	proc sql noprint; select max(varnum) into :num_vars from contents; quit;
	%put NUM VARS: &num_vars.;

	*** Write the informat macro;
	%let informat_macro = ;
	proc sql noprint;
		%do i = 1 %to &num_vars.;
			select strip(upcase(translate(strip(var&i.),'_',' '))) into :name from varnames;
			%let var&i._format = &&&name..;
		%end;
		select
			%do i = 1 %to &num_vars.;
				" informat "||strip(upcase(translate(strip(var&i.),'_',' ')))||" &&var&i._format. ;" ||
			%end;
			''
			into :informat_macro
				from varnames;
	quit;
	%put &informat_macro.;

	*** Write the format macro;
	%let format_macro = ;
	proc sql noprint;
		%do i = 1 %to &num_vars.;
			select strip(upcase(translate(strip(var&i.),'_',' '))) into :name from varnames;
			%if &&&name..='best32.' %then %do;
				%let var&i._format = best12.;
			%end;
			%else %do;
				%let var&i._format = &&&name..;
			%end;
		%end;
		select
			%do i = 1 %to &num_vars.;
				" format "||strip(upcase(translate(strip(var&i.),'_',' ')))||" &&var&i._format. ;" ||
			%end;
			''
			into :format_macro
				from varnames;
	quit;
	%put &format_macro.;
	

	*** Write the input macro;
	%let inputt_macro = ;
	proc sql noprint;
		%do i = 1 %to &num_vars.;
			select strip(upcase(translate(strip(var&i.),'_',' '))) into :name from varnames;
			%let var&i._format = &&&name..;

			%let num_dollar_signs = %sysfunc(countc(&&var&i._format.,'$'));
			%if &num_dollar_signs. = 1 %then %do;
				%let var&i._dollar_sign = $;
			%end;
			%else %if &num_dollar_signs. = 0 %then %do;
				%let var&i._dollar_sign = ;
			%end;
		%end;
		select
			%do i = 1 %to &num_vars.;
				strip(upcase(translate(strip(var&i.),'_',' ')))||" &&var&i._dollar_sign. " ||
			%end;
			''
			into :input_macro
				from varnames;
	quit;
	%put &input_macro.;


	**** Read in the data;
	data util.state_drug_data_&data_year.;
	  %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
	  infile "&import_utilization_pathname.State_Drug_Utilization_Data_&data_year..csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2;
	     &informat_macro.
	     &format_macro.
	  input &input_macro.;
	if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
	run;

%end;
%mend import_drug_data;
%import_drug_data(syear=&import_util_data_syear.,eyear=&import_util_data_eyear.);
