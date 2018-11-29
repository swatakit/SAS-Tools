/*
Auther: Siraprapa Watakit
Last Modify: November 2018
*/


/*
Macro to generate INDIVIDUAL missing report of a dataset.

*@param DSNAME This is the target dataset to calculate %missing 
*@param FMT_MISSNUM pre-defined NUM missing formats. 
*@param FMT_MISSCHAR pre-defined CHAR missing formats.
*@return MISSREPORT_[DSNAME] an output dataset from macro.
*/
%macro MISSING_REPORT(DSNAME,FMT_MISSNUM=NM_MISS.,FMT_MISSCHAR=$CH_MISS.);

%PUT;
%PUT INDIVIDUAL MISSING REPORT;
%PUT ***************************************;
%PUT TARGET LIBRARY AND DATASET NAME ARE;
%PUT DSNAME : &DSNAME.;
%PUT ***************************************;

%IF %SYSFUNC(EXIST(&DSNAME))=0 %THEN %DO; 
	%PUT ;
	%PUT CANNOT FIND &DSNAME. ; 
	%PUT PLEASE MAKE SURE THAT &DSNAME. IS EXIST;
	%PUT ;
	%GOTO PROGQUIT;
%END;

ODS LISTING CLOSE; ODS OUTPUT ONEWAYFREQS=TABLES;

PROC FREQ DATA=&DSNAME.;
TABLES _ALL_ / MISSING;
FORMAT _NUMERIC_ &FMT_MISSNUM.  _CHARACTER_ &FMT_MISSCHAR.;
RUN;

ODS OUTPUT CLOSE; ODS LISTING;

%let N_DSNAME= %substr(&DSNAME.,%index(&DSNAME.,%str(.))+1);

DATA &N_DSNAME._RPT;
LENGTH VAR $32; 
DO UNTIL (LAST.TABLE); 
	 SET TABLES; 
	 BY TABLE NOTSORTED;
	 ARRAY NAMES(*) F_: ;
	 SELECT (NAMES(_N_)); 
	 WHEN ('0') DO; 
	 MISS = FREQUENCY;
	 P_MISS = PERCENT;
	 END;
	 WHEN ('1') DO; 
	 OK = FREQUENCY;
	 P_OK = PERCENT;
	 END;
	 END;
END;
	MISS = COALESCE(MISS,0); 
	OK = COALESCE(OK,0);
	P_MISS = COALESCE(P_MISS,0);
	P_OK = COALESCE(P_OK,0);
	VAR = SCAN(TABLE,-1); 
	KEEP VAR MISS OK P_: ; 
	FORMAT MISS OK COMMA7. P_: 5.1;
	LABEL
	MISS = 'N_MISSING'
	OK = 'N_POPULATED'
	P_MISS = '%_MISSING'
	P_OK = '%_POPULATED'
	VAR = 'VARIABLE'
	;
RUN;

PROC SORT DATA=&N_DSNAME._RPT; BY VAR; RUN;
PROC CONTENTS DATA=&DSNAME. NOPRINT OUT=DATAPROFILE(KEEP=NAME TYPE LENGTH); RUN;

PROC SQL;
CREATE TABLE MSREPORT_&N_DSNAME. AS
(
	SELECT VAR, MISS, P_MISS, OK, P_OK, TYPE, LENGTH 
	FROM &N_DSNAME._RPT LTAB
	LEFT JOIN DATAPROFILE RTAB
	ON LTAB.VAR=RTAB.NAME
);
RUN; QUIT;

PROC DATASETS LIBRARY=WORK NOLIST;
MODIFY MSREPORT_&N_DSNAME.;
ATTRIB TYPE LENGTH LABEL='';
RUN;QUIT;

PROC DELETE DATA=TABLES &N_DSNAME._RPT DATAPROFILE; RUN;
%PROGQUIT:
%mend;


/*
Private Method - Do not modify.
*/
%macro COUNTMISSALL(DSNAME);

	%PUT ***************************************;
	%PUT PROCESSING &DSNAME.;
	%PUT ;
	ODS LISTING CLOSE;
	ODS OUTPUT ONEWAYFREQS=TABLES;

	PROC FREQ DATA=&TARGET_LIB..&DSNAME.;
	TABLES _ALL_ / MISSING;
	FORMAT _NUMERIC_ &NM.  _CHARACTER_ &CH.;
	RUN;

	ODS OUTPUT CLOSE;
	ODS LISTING;

	DATA &DSNAME._RPT;
		LENGTH VAR $32;
		 
		DO UNTIL (LAST.TABLE); 
			 SET TABLES; 
			 BY TABLE NOTSORTED;
			 ARRAY NAMES(*) F_: ;
			 SELECT (NAMES(_N_)); 
			 WHEN ('0') DO; 
			 MISS = FREQUENCY;
			 P_MISS = PERCENT;
			 END;
			 WHEN ('1') DO; 
			 OK = FREQUENCY;
			 P_OK = PERCENT;
			 END;
			 END;
		END;
			MISS = COALESCE(MISS,0); 
			OK = COALESCE(OK,0);
			P_MISS = COALESCE(P_MISS,0);
			P_OK = COALESCE(P_OK,0);
			VAR = SCAN(TABLE,-1); 
			KEEP VAR MISS OK P_: ; 
			FORMAT MISS OK COMMA7. P_: 5.1;
			LABEL
			MISS = 'N_MISSING'
			OK = 'N_POPULATED'
			P_MISS = '%_MISSING'
			P_OK = '%_POPULATED'
			VAR = 'VARIABLE'
		;
	RUN;

	PROC SORT DATA=&DSNAME._RPT OUT=RP; BY DESCENDING MISS ; RUN;

	PROC SQL;
		CREATE TABLE &DSNAME._RPT AS
		(
		SELECT UPCASE("&DSNAME.") AS DSNAME LENGTH=32 , UPCASE(VAR) AS VAR, MISS, P_MISS, OK, P_OK
		FROM RP
		)
	;
	RUN;QUIT;

	PROC DELETE DATA=RP; RUN;

%mend;


/*

Macro to generate ALL missing report of a ALL-SPECIFIED datasets.
The macros assumed that missing/invalid formats are already defined.

 Similar to MISSING_REPORT macro, the macro will calculate %_missing, %_populated
			but for all variables of all specified datasets.			
			you can define additional pattern of missing/invalid data and target dataset names
			at the <b>0_FORMATS.SAS</b> section.			
			Note that the targeted library need not to be the 'WORK' library



Credits:
This program would not be made possible with out
[1] http://www.lexjansen.com
[2] and Ted Clay's ARRAY and DO_OVER macros

*@param TARGET_LIB library contains all target datasets. 
*@param DSNAME_LIST all the target dataset to calculate %missing 
*@param FMT_MISSNUM pre-defined NUM missing formats. 
*@param FMT_MISSCHAR pre-defined CGAR missing formats

*@return MSREPORT_ALL an output dataset from macro.
*/

%macro MISSING_REPORT_ALL(TARGET_LIB,DSNAME_LIST,FMT_MISSNUM=NM_MISS.,FMT_MISSCHAR=$CH_MISS.,REPORTNAME=MSREPORT_ALL);

%LET KEEP_LIST=LIBNAME MEMNAME NAME TYPE LENGTH;
%PUT ;
%PUT MULTIPLE MISSING REPORTS;
%PUT ***************************************;
%PUT TARGET LIBRARY AND DATASET NAME(S) ARE;
%PUT LIBRARY: &TARGET_LIB.;
%PUT DSNAME : &DSNAME_LIST.;
%PUT ***************************************;

%LET NM=&FMT_MISSNUM.;
%LET CH=&FMT_MISSCHAR.;

%DO_OVER(VALUES=&DSNAME_LIST.,MACRO=COUNTMISSALL);QUIT;

DATA REPORTALL_LIST;
	SET %DO_OVER(VALUES=&DSNAME_LIST.,PHRASE=?_RPT);;
RUN;

%LET DELELE_LIST_1=%DO_OVER(VALUES=&DSNAME_LIST.,PHRASE=?_RPT);
PROC DELETE DATA=&DELELE_LIST_1. TABLES; RUN;

/*
Private Method - Do not modify.
*/
%macro DATAPROFILE(DSNAME);
	PROC CONTENTS DATA=&TARGET_LIB..&DSNAME. NOPRINT OUT=&DSNAME._D(KEEP=&KEEP_LIST.); RUN;
%mend;

%DO_OVER(VALUES=&DSNAME_LIST.,MACRO=DATAPROFILE);

DATA DATAPROFILE;
	SET %DO_OVER(VALUES=&DSNAME_LIST.,PHRASE=?_D);;
	NAME=UPCASE(NAME);
RUN;
%LET DELELE_LIST=%DO_OVER(VALUES=&DSNAME_LIST.,PHRASE=?_D);;
PROC DELETE DATA=&DELELE_LIST.; RUN;

PROC SQL;
CREATE TABLE &REPORTNAME. AS
(
	SELECT LIBNAME,DSNAME, VAR, MISS, P_MISS, OK, P_OK,  TYPE, LENGTH 
	FROM REPORTALL_LIST LTAB
	LEFT JOIN DATAPROFILE RTAB
	ON LTAB.DSNAME=RTAB.MEMNAME
	AND LTAB.VAR=RTAB.NAME
)
;
RUN; QUIT;

PROC DELETE DATA=REPORTALL_LIST DATAPROFILE; RUN;

%PUT ...MISSING_REPORT_ALL COMPLTETED...;

%mend;
