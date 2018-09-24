

**** Read in unemployment data;
%let unemployment_data_path = B:\Data\unemployment_population_data.xlsx;

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




*** Merge unemployment data with birth/larc data;
%let suffix = total;
%let prefix = natality;
proc sql noprint;
	select count(*) into :count1 from savedata.&prefix._&suffix._ldq;

	create table CHECK as 
		select a.*, b.population, b.unemployment_rate
			from savedata.&prefix._&suffix. as a
			inner join unemployment_data as b
				on year(a.firstday_q)=b.year and upcase(strip(a.state_short)) = upcase(strip(b.state_short));

	select count(*) into :count2 from CHECK;
quit;
%put &count1. &count2.;






	
