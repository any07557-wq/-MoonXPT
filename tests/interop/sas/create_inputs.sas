/* PREPARED, NOT EXECUTED. Requires licensed SAS Foundation with XPORT Engine.
   MOONXPT_SAS_WORK must name a new directory with existing ref/ and moon/ dirs. */
%let runroot=%sysget(MOONXPT_SAS_WORK);
%put MOONXPT_SAS_VERSION=&sysvlong4;
%put MOONXPT_SAS_PLATFORM=&sysscp;
libname ref "&runroot/ref";

data ref.TEST_A(label='Numeric and character');
  length N 8 TXT $12;
  label N='Numeric measurement' TXT='Text bytes';
  format N best12.2; informat N best12.;
  N=1.25; TXT='alpha'; output;
  N=-3.5; TXT='a,b'; output;
  N=.; TXT='tail  '; output;
run;
data ref.TEST_B(label='Different schema');
  length CODE $3 VALUE 8;
  CODE='X1'; VALUE=0; output;
  CODE='Y2'; VALUE=123; output;
run;
data ref.EMPTY; length X 8; stop; run;
data ref.SHORT;
  length TEXT $4;
  TEXT='ABCD'; output; TEXT='    '; output;
run;
data ref.FULLBL; length TEXT $80; TEXT=' '; output; run;
data ref.TAGS;
  length VALUE 8;
  array tags[28] _temporary_ (. .A .B .C .D .E .F .G .H .I .J .K .L .M
                            .N .O .P .Q .R .S .T .U .V .W .X .Y .Z ._);
  do i=1 to dim(tags); VALUE=tags[i]; output; end;
  drop i;
run;

libname xsingle xport "&runroot/sas_single.xpt";
proc copy in=ref out=xsingle memtype=data; select TEST_A; run;
libname xsingle clear;
libname xmulti xport "&runroot/sas_multi.xpt";
proc copy in=ref out=xmulti memtype=data;
  select TEST_A TEST_B EMPTY SHORT FULLBL TAGS;
run;
libname xmulti clear;
proc contents data=ref._all_ nods; run;
%put MOONXPT_CREATE_DONE;
