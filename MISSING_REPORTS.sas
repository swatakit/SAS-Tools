OPTION NOSOURCE NONOTES;

%LET LOC_SASMACRO=C:\sasmacro;
%INCLUDE "&LOC_SASMACRO.\NUMLIST.SAS";
%INCLUDE "&LOC_SASMACRO.\ARRAY.SAS";
%INCLUDE "&LOC_SASMACRO.\DO_OVER.SAS";
%INCLUDE "&LOC_SASMACRO.\MISSING_REPORTS.SAS";

/*************************
Defined formats for missing/invalids values.
**************************/
PROC FORMAT;
VALUE NM_MISS 
    .= '0' 
    99999999= '0'
    OTHER = '1'
;
VALUE $CH_MISS 
    '',' ','.','-','*'= '0' 
    'N/A','n/a','NA','N.A','-NA-','na','n.a.','n.a' = '0'
    'NULL','null','NONE','--NONE--' = '0'
    'unknown','UNKNOWN','Z_ERROR','Z_MISSING'= '0'
    '99999999','X','TESTUSER','U','C9999'= '0'
    'email@domain.com'= '0'
    OTHER = '1'
;
VALUE $NM_MISSLABEL
    '0'="MISS/INVALID"
    '1'="POPUPATED"
;
RUN;

/*****************
Mockup data
******************/
DATA SAMPLE;
    INFILE DATALINES DSD MISSOVER DELIMITER=',';
    INFORMAT USERID$5. NAME$100. GENDER$1. BIRTHDATE$8. EFFECTIVEDATE$8. EXPIRYDATE$8. PHONE$12. EMAIL$100.;
    INPUT USERID$ NAME$ GENDER$ BIRTHDATE$ EFFECTIVEDATE$ EXPIRYDATE$ PHONE$ EMAIL$;
DATALINES;
C0001,Abel,M,99999999,20140102,20140112,NA,n.a
C0002,Maggie,F,99999999,20140105,,NA,*
C0003,John,M,99999999,20140107,20140125,NA,*
C0004,Rose,M,99999999,20140107,99999999,345-466-4467,unknown
C0005,Greoge,M,19910116,20140108,20140205,,Greoge@somedomain.com
C0006,Luisa,F,20001010,20140109,20140118,,n/a
C0007,Carol,U,20011212,99999999,20140115,345-466-2367,email@domain.com
C0008,James,U,19701212,20140112,20140115,,email@domain.com
C0009,-,U,,,20140121,345-466-4467,email@domain.com
C0010,-,U,19800725,20140115,99999999,,n/a
C0011,Beth,F,20010830,20140117,20140117,,Beth@somedomain.com
C0012,Charle,,,,20140124,345-466-4888,n.a
C0013,Michael,,,20140121,20140122,,Michael@somedomain.com
C9999,TESTUSER,U,99999999,20140126,,345-645-4467,n/a
C9999,TESTUSER,U,99999999,20140128,20140129,,n/a
;
RUN;


/*****************
Missing Report of 1 single dataset
Macro :  MISSING_REPORT

Note that we have defined formats as input parameters for the macro,
the idea is that - you can have different formats designated for different datasets
******************/
%MISSING_REPORT(DSNAME=SAMPLE,
                FMT_MISSNUM=NM_MISS.,
                FMT_MISSCHAR=$CH_MISS.); 
PROC PRINT DATA=MSREPORT_SAMPLE NOOBS LABEL; RUN;

/*****************
Missing Report of multiple datasets
Macro :  MISSING_REPORT_ALL

Now we specify the library that holds the datasets and the list of targeting datasets, 
With the power of DO_OVER, the macro will loop thru all datasets and all variables
******************/
%MISSING_REPORT_ALL(TARGET_LIB=SASHELP,
                    DSNAME_LIST=CARS CLASS BASEBALL,
                    FMT_MISSNUM=NM_MISS.,
                    FMT_MISSCHAR=$CH_MISS.,
                    REPORTNAME=MSREPORT_ALL);
PROC PRINT DATA=MSREPORT_ALL NOOBS LABEL; RUN;

/*********************
Summarising the level of completeness in the dataset
With summarised %populated dataset, we can easily take a quick look at data completeness. To makethe report readible, it is recommended to classify the range of completeness into 'traffic light' bins.

In this demonstration, %populated < 50% is 'Red', 50%-75% is 'Amber', and 75% or more is 'Green' 
First, let's take a look at granular level, %populated by each variable
*******************/
PROC FORMAT;
VALUE RAG
    LOW-<50 = 'LIGHTRED'
    50-<75 = 'LIGHTORANGE'
    75 - HIGH = 'LIGHTGREEN';
 
RUN;

PROC TABULATE DATA=MSREPORT_SAMPLE MISSING ;
CLASS VAR ;
VAR P_OK ;
TABLE VAR='By Variable',P_OK='%Populated'*MEAN=''*[STYLE=[BACKGROUND=RAG.]] ;
RUN;

/*******************
Then, let's classify variables in to a group of variables. %populated by each variable group
******************/
PROC FORMAT;

VALUE $VARGROUP
    'NAME','BIRTHDATE','GENDER'='CUSTOMER DEMOGRAPHIC'
    'PHONE','EMAIL'='CUSTOMER CONTACTS'
    'EXPIRYDATE','EFFECTIVEDATE','USERID' = 'POLICY DETAILS'
	OTHER='OTHERS'
;
    
RUN;

PROC TABULATE DATA=MSREPORT_SAMPLE MISSING ;
FORMAT VAR $VARGROUP.  ;
CLASS VAR ;
VAR P_OK ;
TABLE (VAR='By Variable')ALL='Overall',(P_OK='%Populated'*(MEAN='')*[STYLE=[BACKGROUND=RAG.]]);
RUN;


