/* PREPARED, NOT EXECUTED. XPORT Engine only; CPORT is not used. */
%let runroot=%sysget(MOONXPT_SAS_WORK);
libname ref "&runroot/ref";
libname imported "&runroot/imported";
libname xin xport "&runroot/moon/moon_multi.xpt";
proc contents data=xin._all_ nods; run;
proc copy in=xin out=imported memtype=data; run;
libname xin clear;

%macro compare_one(name);
  proc contents data=imported.&name; run;
  proc compare base=ref.&name compare=imported.&name
    method=absolute criterion=0 listall;
  run;
  %put MOONXPT_COMPARE|&name|&sysinfo;
%mend;
%compare_one(TEST_A);
%compare_one(TEST_B);
%compare_one(EMPTY);
%compare_one(SHORT);
%compare_one(FULLBL);
%compare_one(TAGS);

/* Single-member direction is separate from multi-member reading. */
libname one xport "&runroot/moon/TEST_A.xpt";
proc compare base=ref.TEST_A compare=one.TEST_A method=absolute criterion=0 listall; run;
%put MOONXPT_COMPARE|SINGLE|&sysinfo;
libname one clear;
%put MOONXPT_READ_DONE;
