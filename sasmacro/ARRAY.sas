/*      a.k.a. MACARRAY( ).  

Function: Define one or more Macro Arrays
   A macro array is a list of macro variables sharing the same prefix and a numerical suffix. 
   The suffix numbers run from 1 up to a highest number.  The value of this highest number, 
   or the length of the array, is stored in an additional macro variable with the same prefix,
   plus the letter “N”.  The prefix is also referred to as the name of the macro array.
   For example, "AA1", "AA2", "AA3", etc., plus "AAN".  All such variables are declared GLOBAL.
   This macro creates one or more macro arrays, and stores in them character values from a SAS
   dataset or view, or an explicit list of values.

Authors: Ted Clay, M.S.   tclay@ashlandhome.net  (541) 482-6435
        David Katz, M.S. www.davidkatzconsulting.com
    "Please keep, use and pass on the ARRAY and DO_OVER macros with this
        authorship note.  -Thanks "

Full documentation with examples appears in SUGI Proceedings, March 2006, 
   "Tight Looping With Macro Arrays" by Ted Clay
Please send improvements, fixes or comments to Ted Clay.

Parameters: 
  ARRAYPOS and 
  ARRAY are equivalent parameters.  One or the other, but not both, 
           is required.  Note that ARRAYPOS is the only position parameter. 
         = Identifier(s) for the macro array(s) to be defined. 
  DATA = Dataset or view source of list. 
               Dataset options OK, such as WHERE=.
  VAR  = Variable(s) containing values to put in list. If multiple array names
            are specified in ARRAYPOS or ARRAY then the same number of variables
            must be listed.  
  VALUES  = An explicit list of character strings to put in the list.
            If present, VALUES are used rather than DATA and VAR.  The VALUES
            parameter can only be used when only one array name is specified in
            the ARRAYPOS or ARRAY parameters. Can be a numbered list, eg 1-10, a01-A20.
  DELIM = Character used to separate values in VALUES parameter.  Blank is default.

  DEBUG = N/Y. Default=N.  If Y, certain debugging statements are activated.

REQUIRED OTHER MACRO: Requires NUMLIST if using numbered lists in VALUES parameter.

How the program works.
  When the VALUES parameter is used, it is parsed into individual words using the scan function.

  With the DATA parameter, each observation of data to be loaded into one or more macro
  arrays, _n_ determines the numeric suffix.  Each one is declared GLOBAL using "call execute"
  which is acted upon by the SAS macro processor immediately.  Without this "global" setting,
  "Call symput" would by default put the new macro variables in the local symbol table, which
  would not be accessible outside this macro.  Because "call execute" only is handling macro
  statements, the following statement will normally appear on the SAS log:
  NOTE: CALL EXECUTE routine executed successfully, but no SAS statements were generated.

History
7/14/05 handle char variable value containing single quote
1/19/06 values can be a a numbered list with dash, e.g. AA1-AA20 or 1993-2005.
4/1/06 simplified process of making variables global.

*/
%macro ARRAY(arraypos, array=, data=, var=, values=, delim=%STR( ), debug=N);
	%LOCAL prefixes PREFIXN manum _VAR_N iter i val;

	%* Get array names (prefixes) from either the keyword or positional parameter;
	%if &ARRAY= %then
		%let PREFIXES=&ARRAYPOS;
	%else %let PREFIXES=&ARRAY;

	%* Parse the list of macro array names;
	%do MANUM = 1 %to 999;
		%let prefix&MANUM=%scan(&prefixes,&MAnum,' ');

		%if &&prefix&MANUM ne %then
			%DO;
				%let PREFIXN=&MAnum;
				%global &&prefix&MANUM..N;

				%* initialize length to zero;
				%let &&prefix&MANUM..N=0;
			%END;
		%else %goto out1;
	%end;

%out1:

	%if &DEBUG=Y %then
		%put PREFIXN is &PREFIXN;

	%* Parse the VAR parameter;
	%let _VAR_N=0;

	%do MANUM = 1 %to 999;
		%let _var_&MANUM=%scan(&VAR,&MAnum,' ');

		%if %str(&&_var_&MANUM) ne %then
			%let _VAR_N=&MAnum;
		%else %goto out2;
	%end;

%out2:

	%IF &PREFIXN=0 %THEN
		%PUT ERROR: No macro array names are given;
	%ELSE %IF %LENGTH(%STR(&DATA)) >0 and &_VAR_N=0 %THEN
		%PUT ERROR: DATA parameter is used but VAR parameter is blank;
	%ELSE %IF %LENGTH(%STR(&DATA)) >0 and &_VAR_N ne &PREFIXN %THEN
		%PUT ERROR: The number of variables in the VAR parameter is not equal to the number of arrays;
	%ELSE %IF %LENGTH(%STR(&VALUES)) >0 and &PREFIXN NE 1 %THEN
		%PUT ERROR: Only one macro array can be created using the VALUES= parameter;
	%ELSE
		%DO;
			%*------------------------------------------------------;
			%*  CASE 1: VALUES parameter is used
			%*------------------------------------------------------;
			%IF %LENGTH(%STR(&VALUES)) >0 %THEN
				%DO;
					%* Check for numbered list of form xxx-xxx and expand it using NUMLIST macro.;
					%IF (%INDEX(%STR(&VALUES),-) GT 0) and 
						(%SCAN(%str(&VALUES),1,-) NE ) and 
						(%SCAN(%str(&VALUES),2,-) NE ) and 
						(%SCAN(%str(&VALUES),3,-) EQ ) %THEN
						%LET VALUES=%NUMLIST(&VALUES);

					%DO ITER=1 %TO 9999;
						%LET VAL=%SCAN(%STR(&VALUES),&ITER,%STR(&DELIM));

						%IF %QUOTE(&VAL) NE %THEN
							%DO;
								%GLOBAL &PREFIX1.&ITER;
								%LET &PREFIX1&ITER=&VAL;
								%LET &PREFIX1.N=&ITER;
							%END;
						%ELSE %goto out3;
					%END;

			%out3:
				%END;
			%ELSE
				%DO;
					%*------------------------------------------------------;
					%*  CASE 2: DATA and VAR parameters used
					%*------------------------------------------------------;
					%* Get values from one or more variables in a dataset or view;
					data _null_;
						set &DATA end = lastobs;

						%DO J=1 %to &PREFIXN;
							call execute('%GLOBAL '||"&&PREFIX&J.."||left(put(_n_,5.)) );
							call symput(compress("&&prefix&J"||left(put(_n_,5.))), trim(left(&&_VAR_&J)));

							if lastobs then
								call symput(compress("&&prefix&J"||"N"), trim(left(put(_n_,5.))));
						%END;
					run;

					%* Write message to the log;
					%IF &DEBUG=Y %then
						%DO J=1 %to &PREFIXN;
							%PUT &&&&PREFIX&J..N is &&&&&&PREFIX&J..N;
						%END;
				%END;
		%END;
%MEND;