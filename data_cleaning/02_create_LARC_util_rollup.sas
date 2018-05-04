/***************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file creates state-quarter counts of LARC utilization. It classifies a drug as an LARC if its name is any of the following:
NEXPLANON MIRENA PARAGARD SKYLA LILETTA KYLEENA IMPLANON
Input: 
	SAS formatted state drug utilization data in S:\LARC\data\raw_data\state_drug_utilization (../&birthdata_pathname.)
Output: 
	state-quarter counts of LARC utilization in S:\LARC\data\raw_data\state_drug_utilization (../&birthdata_pathname.)
Date modified: May 4, 2018
Author: Marisa Carlos (mbc96@cornell.edu)

Unresolved issues: Need to figure out what the difference is between units and num_rx;
***************************************************************************************************************************************/

**** Create subset of state utilization data that is JUST the IUDs and implant;
%macro larc_subset(syear=,eyear=,suppression_value=);
**** Create subset of utilization data with LARC obs;
%let larc_list = NEXPLANON MIRENA PARAGARD SKYLA LILETTA KYLEENA IMPLANON;
%let where_macro = upcase(product_name) contains "NEXPLANON";
%do i = 2 %to %sysfunc(countw(&larc_list.));
	%let larc = %scan(&larc_list., &i.);
	%let where_macro = &where_macro. OR upcase(product_name) contains "&larc.";
%end;
%do year = &syear. %to &eyear.;
	*Create subset of state drug utilization data that has the obs for LARC;
	proc sql noprint;
		create table larc_util_&year. as 
			select utilization_type, state, quarter format=best12., suppression_used, &year. as year,
			units_reimbursed, number_of_prescriptions as num_rx_orig, 
			medicaid_amount_reimbursed, non_medicaid_amount_reimbursed , 
			labeler_code, product_code, package_size,
			case
				when upcase(suppression_used)="TRUE" then &suppression_value.
				when upcase(suppression_used)="FALSE" then  number_of_prescriptions
				else .
			end as number_of_prescriptions,
			case
				%do i = 1 %to %sysfunc(countw(&larc_list.));
					%let larc = %scan(&larc_list., &i.);
					when upcase(product_name) contains "&larc." then "&larc."
				%end;
				else "ERROR" 
			end as product_name_group
				from util.state_drug_data_&year. 
					where (&where_macro.) AND state~='XX'
						order by state, utilization_type;
	quit;
%end;
%mend larc_subset;
%larc_subset(syear=2009,eyear=2017,suppression_value=5);


*** Roll up to the state-quarter level for each type of birth control;
%macro rollup1(syear=,eyear=,suppression_value=);
%do year = &syear. %to &eyear.;
	proc sql noprint;
		create table rollup_&year. as 
			select state, year, quarter, utilization_type, product_name_group, 
			sum(number_of_prescriptions) as num_rx,
			sum(units_reimbursed) as num_units,
			sum(case when upcase(suppression_used)="TRUE" then 1 else 0 end) as num_suppression,
			sum(case when upcase(suppression_used)="FALSE" then 1 else 0 end) as num_no_suppression,
			sum(case when upcase(suppression_used)="TRUE" then &suppression_value. else 0 end) as sum_rx_suppression,
			sum(case when upcase(suppression_used)="FALSE" then number_of_prescriptions else 0 end) as sum_rx_no_suppression
				from larc_util_&year. 
					group by state, quarter, year, product_name_group, utilization_type;
	quit;
%end;

%let larc_list = NEXPLANON MIRENA PARAGARD SKYLA LILETTA KYLEENA IMPLANON;
proc sql noprint;
	create table util.st_qtr_larcbrand_&syear.to&eyear.(drop=check) as 
		select *,
		%do i = 1 %to %sysfunc(countw(&larc_list.));
			%let larc = %scan(&larc_list., &i.);
			case
				when product_name_group = "&larc." then 1
				else 0
			end as &larc.,
		%end;
		1 as check
		from rollup_&syear. 
		%do yr = &syear.+1 %to &eyear.;
		outer union corresponding
		select *,
		%do i = 1 %to %sysfunc(countw(&larc_list.));
			%let larc = %scan(&larc_list., &i.);
			case
				when product_name_group = "&larc." then 1
				else 0
			end as &larc.,
		%end;
		1 as check
		from rollup_&yr.
		%end;
		;
quit;
%mend rollup1;
%rollup1(syear=2009, eyear=2017, suppression_value=5);


data years;
	input year_l;
	datalines;
2007
2008
2009
2010
2011
2012
2013
2014
2015
2016
2017
;

data quarters;
	input quarter_l;
	datalines;
1
2
3
4
;

proc sql noprint;
	create table states as
		select distinct statecode as state_l
			from sashelp.zipcode
				where statecode not in ('FM', 'GM', 'GU', 'MH', 'MP', 'PW', 'PR', 'VI');
quit;
proc sql noprint;
	create table state_year_quarters as 
		select *
			from states, years, quarters
				order by state_l, year_l, quarter_l;
quit;
***********************************************************************************************************************************************************;
*************************************************** CODE BELOW NEEDS TO BE UPDATED ONCE WE GET NEW DATA ***************************************************;
***********************************************************************************************************************************************************;
proc sql noprint;
	create table state_year_quarters as 
		select *
			from state_year_quarters
				where year_l~=2017 OR quarter_l in (1,2,3);
quit;
***********************************************************************************************************************************************************;
***********************************************************************************************************************************************************;
***********************************************************************************************************************************************************;

%macro rollup2(syear=,eyear=);
%let larc_list = NEXPLANON MIRENA PARAGARD SKYLA LILETTA KYLEENA IMPLANON;
proc sql noprint;
	create table rollup_state_year_quarter(drop=check) as 
		select state, year, quarter, sum(num_units) as num_units,
		sum(num_rx) as num_rx, sum(sum_rx_suppression) as num_suppression, sum(sum_rx_no_suppression) as num_no_suppression,
		%do i = 1 %to %sysfunc(countw(&larc_list.));
			%let larc = %scan(&larc_list.,&i.);
			max(&larc.) as any_&larc.,
		%end; 
		1 as check
			from util.st_qtr_larcbrand_&syear.to&eyear.
				group by state, year, quarter;
quit;

proc sql noprint;
	create table util.larc_state_year_q_&syear.to&eyear. as 
		select *
			from state_year_quarters as a
			left join 
			rollup_state_year_quarter as b
			on a.state_l = b.state AND a.year_l=b.year AND a.quarter_l = b.quarter
				where a.year_l>=&syear. and a.year_l<=&eyear.
					order by state_l, year_l, quarter_l;
quit;
%mend rollup2;
%rollup2(syear=2009, eyear=2017);
