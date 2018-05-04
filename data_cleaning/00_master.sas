/*********************************************************************************************************************************************
Project: LARC reimbursement 
Description: This file runs all of the data cleaning files used to create analysis datasets from raw text files (vital statistics birth data 
and CMS state drug utilization data). 
Input: 
	birth data .txt files from S:\LARC\data\raw_data\birth_data
	state drug utilization data from S:\LARC\data\raw_data\state_drug_utilization
	LARC policy spreadsheet (state_larc_policies_DATE.csv)
Output: 
	analysis datasets in S:\LARC\data\analysis_data
	SAS formatted state drug utilization data in S:\LARC\data\raw_data\state_drug_utilization
Date modified: May 4, 2018
Author: Marisa Carlos (mbc96@cornell.edu)
**********************************************************************************************************************************************/

********NOTE: / or \ MUST BE INCLUDED AT END OF ALL PATHS TO DIRECTORIES;
************************************************* PATHS USING SHARED CISER DRIVE (S:\LARC) **************************************************;
libname util "S:\LARC\data\raw_data\state_drug_utilization";
*libname fda_data "\\rschfs1x\userth\K-Q\mbc96_TH\Documents\Datasets\FDA_Data"; *NOT CURRENTLY USED;
libname savedata "S:\LARC\data\analysis_data";

%let import_utilization_pathname = S:\LARC\data\raw_data\state_drug_utilization\; *where state drug utilization files are located;
%let birthdata_pathname = S:\LARC\data\raw_data\birth_data\monthly_all_birth_orders\; *monthly birth data, all birth orders ;
%let quarter_birthdata_path = S:\LARC\data\raw_data\birth_data\quarterly_all_birth_orders\; *quartrly birth data, all birth orders;
%let monthly_data_path_2ndchild = S:\LARC\data\raw_data\birth_data\monthly_2nd_plus_birth_orders\; *monthly birth data, 2nd+ birth orders;
%let quarterly_data_path_2ndchild = S:\LARC\data\raw_data\birth_data\quarterly_2nd_plus_birth_orders\; *quarterly birth data, 2nd+ birth orders;
%let save_stata_data_path = S:\LARC\data\analysis_data\; *path to save analysis (stata) data in;
********************************************************************************************************************************************;

****************************************************** PATHS USING NETWORK MAPPING ******************************************************;
**NOTE: To use below must map network drive B to \\tsclient\Dropbox (Personal) --- subst B: "\\tsclient\Dropbox (Personal)";
%let larc_policy_spreadsheet_path = B:\Cornell\Research\Projects\LARC_Reimbursement\state_larc_policies_2018_04_09.csv;
%let sas_code_path = B:\Cornell\Research\Projects\LARC_Reimbursement\code\data_cleaning;
********************************************************************************************************************************************;

****************************************************** SET START/END YEARS FOR DATA ******************************************************;
%let first_year_birth_data = 2007; *CHANGE IF GET NEW DATA; 
%let last_year_birth_data = 2016; *CHANGE IF GET NEW DATA;
*** Change these years to change which years of UTILIZATION data are read in - only need to change if re-doing everything from scratch
or if reading in new utilization data;
%let import_util_data_syear = 2017;
%let import_util_data_eyear = 2017;


**************************************************************** RUN CODES ****************************************************************;
%include "&sas_code_path.01_import_utilization_data.sas";
%include "&sas_code_path.02_create_LARC_util_rollup.sas";
%include "&sas_code_path.03_import_birth_data.sas";
%include "&sas_code_path.04_create_analysis_data.sas";
********************************************************************************************************************************************;