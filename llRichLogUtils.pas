UNIT llRichLogUtils;

// OLD LOG based on RichEdit

{=============================================================================================================
   Gabriel Moraru
   2023.06
   See Copyright.txt

   A simple but effective visual log control/library.
   The programmer can send messages to the log that will be shown or not, depending on the chousen verbosity level of the log (see Verbosity property).
   **Visual/Non-visual**
   There is a non-visual log (TRamLog) and a visual log (TRichLog). The idea is that your non-visual objects can send data to the non-viusal log, for example in a batch job. At the end of the batch all collected messages can be shown in the visual log.
   Alternativelly, if you connect the TRamLog to the visual log, the messages are shown in real time, as the batch job progreeses.
   There is a pre-defined form that holds the log. To show it, call CreateLogForm in FormLog.pas
   The purpose is to have one single log window per application that will receive messages from the entire application.
   **Verbosity:**
     Supports several verbosity levels (verbose, info, warnings, errors, etc).
     Receives only messages that are above the specified verbosity threshold.
     For example, if the log is set to show only warnings and errors and you send a messages marked as "verbose", then the messages will not be shown.
     Each verbosity level has a predefined color.
   **I/O**
   The log can be save to disk to a binary file so it can be restored when the next app startup.
   Tester:
     c:\Myprojects\LightSaber\Demo\LightLog\
=============================================================================================================}

INTERFACE

USES
   System.SysUtils, Vcl.Graphics, ccColors;

TYPE
  TLogVerb= (lvrVerbose, lvrHints, lvrInfos, lvrImportant, lvrWarnings, lvrErrors);

CONST
  ctLogVerb  = clGray;
  ctLogHint  = clDkGray;
  ctLogInfo  = clBlack;
  ctLogImprt = clPurpleDk;    // TColor($5E005E); 
  ctLogWarn  = clOrangeDark;  // TColor($0058DF);
  ctLogError = clRed;

CONST
  DefaultVerbosity= lvrInfos;

function Verbosity2String(Verbosity: TLogVerb): string;



IMPLEMENTATION


function Verbosity2String(Verbosity: TLogVerb): string;
begin
 case Verbosity of
   lvrVerbose   : Result := 'Verbose';
   lvrHints     : Result := 'Hints';
   lvrInfos     : Result := 'Info';      { This is the default level of verbosity }
   lvrImportant : Result := 'Important';
   lvrWarnings  : Result := 'Warnings';
   lvrErrors    : Result := 'Errors';
 else
   Raise Exception.Create('Invalid verbosity');
 end;
end;


function Verbosity2Color(Verbosity: TLogVerb): TColor;
begin
 CASE Verbosity of
  //lvDebug    : Result:= clSilverLight;
  lvrVerbose  : Result:= clSilverDark;
  lvrHints    : Result:= clGray;
  lvrInfos    : Result:= clBlack;
  lvrImportant: Result:= clOrangeDk;
  lvrWarnings : Result:= clOrange;
  lvrErrors   : Result:= clRed;
 else
   RAISE exception.Create('Invalid log verbosity!');
 end;
end;






end.