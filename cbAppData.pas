﻿UNIT cbAppData;

{=============================================================================================================
   Gabriel Moraru
   2024.05
   See Copyright.txt
--------------------------------------------------------------------------------------------------------------
   Via class you can:
      - Get application's appdata folder (the folder where you save temporary, app-related and ini files)
      - Get application's command line parameters
      - Get application's version

      - Force single instance (allow only one instance of your program to run). Second inst sends its command line to the first inst then shutsdown
      - Detect if the application is running for the firs this in a computer

      - Application self-restart
      - Application self-delete

      - Easily create new forms and set its font to be the same as main forms' font.
      - Change the font for all running forms

      - Log error messages to a special window that is automatically created
      - Basic support for Uninstaller (The Uninstaller can find out there the app was installed)
      - Basic support for licensing (trial period) system. See Proteus for details.

      - etc

   The global AppData var will store the object (app wide).
   The AppName variable is the central part of this class. It is used by App/Ini file/MesageBox/etc.

   It is CRITICAL to create the AppData object as soon as the application starts.
   Prefferably in the DPR file before creating the main form!
   Probalby it can even be created in the Initialization section.

 ____________________________________________________________________________________________________________

   LOG
     TAppData class also creates the Log form. See: FormLog.pas

 ____________________________________________________________________________________________________________

   USAGE

     In the DPR file replace the code with:
       uses
         FastMM4,
         Vcl.Forms,
         FormRamLog,
         cbINIFile,
         cbAppData,
         MainForm in 'MainForm.pas' {frmMain _;
       begin
         AppData:= TAppData.Create('MyCollApp');
         AppData.CreateMainForm(TMainForm, MainForm, False, True);   // Main form
         AppData.CreateForm(TSecondFrom, frmSecond);                 // Secondary form(s)
         TfrmRamLog.CreateGlobalLog;                                 // Log (optional)
         Application.Run;
       end.

     OnFormCreate
        OnFormCreate and OnFormShow is the worst place to initialize your code.
        Instead, your form can implement the LateInitialize message handler.
        This will be called after the form was fully created and the application finished initializing.
        Example:
            TfrmMain = class(TForm)
             private
               procedure LateInitialize(VAR Msg: TMessage); message MSG_LateFormInit; // Called after the main form was fully initilized
            end;

     Not necessary anymore:
         Application.Title := AppData.AppName;
         Application.ShowMainForm:= True;
         MainForm.Show;
         Not necessary to free AppData. It frees itself.


     The "AppData.Initializing" Flag
        Once the program is fully initialized set Initializing to False.
        Details: Set it to false once your app finished initializing (usually after you finished creating all forms).
        Used by SaveForm in cbINIFile.pas (and few other places) to signal not to save the form if the application
        has crashed whill still in the initialization phase.
        If you don't set it to false earlyer, AppData will set it to false at the end of CreateMainForm


 ____________________________________________________________________________________________________________

   MainFormOnTaskbar:

      [TASKBAR]
         if TRUE = A taskbar button represents the application's main form & displays its caption.
         if FALSE= A taskbar button represents the application's (hidden) main window & displays the application's Title.

      [Modality]
          if TRUE = All child forms will stay on top of the MainForm.
                    Bad since we don't really want "modal" forms all over in our app.
                    When we do want a child form to stay on top, then we make it modal or use fsStayOnTop.

      [AERO]
          Windows Aero effects (Live taskbar thumbnails, Dynamic Windows, Windows Flip, Windows Flip 3D)
          if False = Aero effects work
          if False = Aero effects do not work

      Details
          https://stackoverflow.com/questions/66720721/
          https://stackoverflow.com/questions/14587456/how-can-i-stop-my-application-showing-on-the-taskbar

      BX: This must be FALSE in order to make 'Start minimized' option work

 ____________________________________________________________________________________________________________
   Demo app:
      c:\MyProjects\Project support\Template - Empty app\StarterProject.dpr
=============================================================================================================}

INTERFACE

USES
  Winapi.Windows, Winapi.Messages, Winapi.ShlObj, Winapi.ShellAPI,
  System.Win.Registry, System.IOUtils, System.AnsiStrings, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Consts,
  ccCore, ccIniFile, cbINIFile, cbLogRam;

CONST
  MSG_LateFormInit = WM_APP + 4711;         { Old name: MSG_LateFormInit/MSG_LateAppInit  }

TYPE
  THintType = (htOff,                      // Turn off the embeded help system
               htTooltips,                 // Show help as tool-tips
               htStatBar);                 // Show help in status bar

  TAppData= class(TObject)
  private
    FShowOnError: Boolean;    // Automatically show the visual log form when warnings/errors are added to the log. This way the user is informed about the problems.
    FFont: TFont;
    FLastFolder: string;
    FSingleInstClassName: string;          { Used by the Single Instance mechanism. } {Old name: AppWinClassName }
    FRunningFirstTime: Boolean;
    FHideHint: Integer;
    procedure SetGuiProperties(Form: TForm);
    procedure setHideHint(const Value: Integer);
    procedure setShowOnError(const Value: Boolean);
    CONST
      Signature: AnsiString= 'AppDataSettings';{ Do not change it! }
      DefaultHomePage= 'https://www.GabrielMoraru.com';
    class VAR FCreated: Boolean;     { Sanity check }
    class VAR FAppName: string;
    function  getLastUsedFolder: string;
    procedure setFont(aFont: TFont);
    procedure LoadSettings;
    procedure SaveSettings;
    procedure RegisterUninstaller;
    function  RunSelfAtWinStartUp(Active: Boolean): Boolean;
  protected
    CopyDataID: DWORD;          // For SingleInstance. This is a unique message ID for our applications. Used when we send the command line to the first running instance via WM_COPYDATA
  public
    RamLog: TRamLog;

    { Product details }
    CompanyName    : string;    // Optional. Used by the 'About' form
    CompanyHome    : WebURL;    // Company's home page
    ProductHome    : WebURL;    // Product's home page
    ProductOrder   : WebURL;    // Product's order page
    ProductSupport : WebURL;    // Product's user manual
    ProductWelcome : WebURL;    // Product's welcome page (gives a short introduction on how the product works).
    ProductUninstal: WebURL;    // Ask user why he uninstalled the product (feedback)

   {--------------------------------------------------------------------------------------------------
      App Single Instance
   --------------------------------------------------------------------------------------------------}
    property  SingleInstClassName: string read FSingleInstClassName;
    procedure ResurectInstance(CONST CommandLine: string);
    function  InstanceRunning: Boolean;
    procedure SetSingleInstanceName(var Params: TCreateParams);
    function  ExtractData(VAR Msg: TWMCopyData; OUT s: string): Boolean;
    {}
    class VAR Initializing: Boolean;
    class VAR SignalInitEnd: Boolean;  // If true, AppData will set the 'Initializing' field automatically to false once the main form was loaded. Set it to False in apps with more than one form or apps that require a bit more sophisticated initialization procedure

    constructor Create(CONST aAppName: string; CONST WindowClassName: string= ''; aSignalInitEnd: Boolean= TRUE; MultiThreaded: Boolean= FALSE); virtual;
    destructor Destroy; override;      // This is called automatically by "Finalization" in order to call it as late as possible }

   {--------------------------------------------------------------------------------------------------
      User settings
   --------------------------------------------------------------------------------------------------}
    var
      UserPath     : string;           // User defined path where to save (large) files. Useful when the program needs to save large amounts of data that we don't want to put on a SSD drive.
      AutoStartUp  : Boolean;          // Start app at Windows startup
      StartMinim   : Boolean;          // Start minimized
      Minimize2Tray: Boolean;          // Minimize to tray
      HintType     : THintType;        // Turn off the embeded help system
      Opacity      : Integer;          // Form opacity
      //MultiThreaded: Boolean;          // Necessary for the RamLog
    property HideHint: Integer read FHideHint write setHideHint;       // Hide hint after x ms.

   {--------------------------------------------------------------------------------------------------
      App path/name
   --------------------------------------------------------------------------------------------------}
    function CurFolder: string;        // The folder where the exe file is located. Old name: AppDir
    function SysDir: string;
    function CheckSysDir: Boolean;
    class function IniFile: string;
    class function AppDataFolder(ForceDir: Boolean= FALSE): string;
    function AppDataFolderAllUsers: string;

    function AppShortName:  string;
    property LastUsedFolder: string read getLastUsedFolder write FLastFolder;

    class property AppName:  string read FAppName;

    procedure WriteAppDataFolder;
    function  ReadAppDataFolder(CONST UninstalledApp: string): string;

    procedure WriteInstalationFolder;
    function  ReadInstalationFolder(CONST UninstalledApp: string): string;


   {--------------------------------------------------------------------------------------------------
      Dialog boxes
   --------------------------------------------------------------------------------------------------}
   function PromptToSaveFile (VAR FileName: string; CONST Filter: string = ''; CONST DefaultExt: string= ''; CONST Title: string= ''): Boolean;
   function PromptToLoadFile (VAR FileName: string; CONST Filter: string = '';                               CONST Title: string= ''): Boolean;
   function PromptForFileName(VAR FileName: string; SaveDialog: Boolean; CONST Filter: string = ''; CONST DefaultExt: string= ''; CONST Title: string= ''; CONST InitialDir: string = ''): Boolean;


   {--------------------------------------------------------------------------------------------------
      App Control
   --------------------------------------------------------------------------------------------------}
    property  RunningFirstTime: Boolean read FRunningFirstTime;    // Returns true if the application is running for the first time in this computer.
    procedure Restore;
    procedure Restart;
    procedure SelfDelete;

    function  RunFileAtWinStartUp(CONST FilePath: string; Active: Boolean): Boolean;

    procedure CreateMainForm  (aClass: TFormClass; OUT Reference; MainFormOnTaskbar: Boolean= FALSE; Show: Boolean= TRUE; Loading: TFormLoading= flPosOnly);

    procedure CreateForm      (aClass: TFormClass; OUT Reference; Show: Boolean= TRUE; Loading: TFormLoading= flPosOnly; Owner: TWinControl= NIL; Parented: Boolean= FALSE; CreateBeforeMainForm: Boolean= FALSE);  overload;
    procedure CreateFormHidden(aClass: TFormClass; OUT Reference; Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL);

    procedure CreateFormModal (aClass: TFormClass; OUT Reference; Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL); overload;   // Do I need this?
    procedure CreateFormModal (aClass: TFormClass;                Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL); overload;

    procedure SetMaxPriority;
    procedure HideFromTaskbar;

    property  Font: TFont read FFont write setFont;


    {-------------------------------------------------------------------------------------------------
      App Version
   --------------------------------------------------------------------------------------------------}
    class function GetVersionInfo(ShowBuildNo: Boolean= False): string;
    function  GetVersionInfoV      : string;               // Returns version without Build number. Example: v1.0.0
    function  GetVersionInfoMajor: Word;
    function  GetVersionInfoMinor: Word;

    procedure MainFormCaption(const Caption: string);


   {--------------------------------------------------------------------------------------------------
      BetaTester tools
   --------------------------------------------------------------------------------------------------}
    class function RunningHome: Boolean;
    function  BetaTesterMode: Boolean;
    function  IsHardCodedExp(Year, Month, Day: word): Boolean;

    class procedure RaiseIfStillInitializing;

   {--------------------------------------------------------------------------------------------------
      App Log
   --------------------------------------------------------------------------------------------------}
    procedure LogEmptyRow;
    procedure LogBold  (CONST Msg: string);
    procedure LogError (CONST Msg: string);
    procedure LogHint  (CONST Msg: string);
    procedure LogImpo  (CONST Msg: string);
    procedure LogInfo  (CONST Msg: string);
    procedure LogMsg   (CONST Msg: string);
    procedure LogVerb  (CONST Msg: string);
    procedure LogWarn  (CONST Msg: string);
    procedure LogClear;

    procedure PopUpLogWindow;

    property ShowLogOnError: Boolean read FShowOnError write setShowOnError;       // Automatically show the visual log form when warnings/errors are added to the log. This way the user is informed about the problems.
  end;



{-------------------------------------------------------------------------------------------------
   Command line
--------------------------------------------------------------------------------------------------}
function  CommandLinePath: string;
procedure ExtractPathFromCmdLine(MixedInput: string; OUT Path, Parameters: string);
function  FindCmdLineSwitch(const Switch: string; IgnoreCase: Boolean): Boolean; deprecated 'Use System.SysUtils.FindCmdLineSwitch';


VAR                      //ToDo: make sure AppData is unique (make it Singleton)
   AppData: TAppData;    // This obj is automatically freed on app shutdown (via FINALIZATION)

IMPLEMENTATION

USES
  cbVersion, ccIO, ccTextFile, cbRegistry, cbDialogs, cbCenterControl; // FormRamLog;

{-------------------------------------------------------------------------------------------------------------
 Parameters
    AppName
       Should contain only I/O-safe characters (so no ? <> * % /).
       It is used to generate the INI file that will store the form position/size.
    WindowClassName - [Optional]
       Used in InstanceRunning to detect if the the application is already running, by looking to a form with this Class Name.
       Needed ONLY if you use the Single Instance functionality.
       This string must be unique in the whole computer! No other app is allowed to have this ID.
       If you leave it empty, the aAppName is used. But AppName might not be that unique, or you might want to change it during the time.
-------------------------------------------------------------------------------------------------------------}
constructor TAppData.Create(CONST aAppName: string; CONST WindowClassName: string= ''; aSignalInitEnd: Boolean= TRUE; MultiThreaded: Boolean= FALSE);
begin
  Application.Initialize;                         // Note: Emba: Although Initialize is the first method called in the main project source code, it is not the first code that is executed in a GUI application. For example, in Delphi, the application first executes the initialization section of all the units used by the Application.

  inherited Create;
  SignalInitEnd:= aSignalInitEnd;
  Initializing:= True;                            // Used in cv_IniFile.pas. Set it to false once your app finished initializing.

  { Sanity check }
  if FCreated
  then RAISE Exception.Create('Error! AppData aready constructed!')
  else FCreated:= TRUE;

  { App single instance }
  if WindowClassName = ''
  then FSingleInstClassName:= aAppName
  else FSingleInstClassName:= WindowClassName;    // We use FSingleInstClassName to identify the window/instance (when we check for an existing instance)
  { Register a unique message ID for this applications. Used when we send the command line to the first running instance via WM_COPYDATA.
    We can do this only once per app so the best place is the Initialization section. However, since AppData is created only once, we can also do it here, in the constructor.
    https://stackoverflow.com/questions/35516347/sendmessagewm-copydata-record-string }
  CopyDataID:= RegisterWindowMessage('CubicCopyDataID');

  { App name }
  Assert(System.IOUtils.TPath.HasValidPathChars(aAppName, FALSE), 'Invalid characters in AppName'+ aAppName);
  Assert(aAppName > '', 'AppName is empty!');
  FAppName:= aAppName;
  Application.Title:= aAppName;
  ForceDirectories(AppDataFolder);               // Force the creation of AppData folder.

  { App first run }
  FRunningFirstTime:= NOT FileExists(IniFile);

  { Log }
  { Warning: We cannot use Application.CreateForm here because this will make the Log the main form! }
  Assert(RamLog = NIL, 'Log already created!');  // Call this as soon as possible so it can catch all Log messages generated during app start up. A good place might be in your DPR file before Application.CreateForm(TMainForm, frmMain)
  RamLog:= TRamLog.Create(ShowLogOnError, NIL, MultiThreaded);

  LogVerb(AppName+ GetVersionInfoV+ ' started.');

  { App hint }
  Application.HintColor     := $c0c090;
  Application.HintShortPause:= 40;               // Specifies the time period to wait before bringing up a hint if another hint has already been shown. Windows' default is 50 ms
  Application.UpdateFormatSettings:= FALSE;      // more http://www.delphi3000.com/articles/article_4462.asp?SK=

  { App settings }
  if FileExists(IniFile)
  then LoadSettings
  else
    begin
      { Default settings }
      AutoStartUp  := TRUE;
      StartMinim   := FALSE;
      Minimize2Tray:= TRUE;                      // Minimize to tray
      HintType     := htTooltips;                // Turn off the embeded help system
      HideHint     := 4000;                      // Hide hint after x ms.
      Opacity      := 250;
      UserPath     := AppDataFolder;
    end;

  { Product details }
  CompanyName    := 'SciVance';
  CompanyHome    := DefaultHomePage;
  ProductHome    := DefaultHomePage;
  ProductOrder   := DefaultHomePage;
  ProductSupport := DefaultHomePage;
  ProductWelcome := DefaultHomePage;
  ProductUninstal:= DefaultHomePage;
end;


{ Destroy is called automatically by "Finalization".
  Here at this point the AppData var is already nil! I don't know why.
  So we need to destroy the Log form before this! }
destructor TAppData.Destroy;
begin
  SaveSettings;
  FreeAndNil(RamLog); // Call this as late as possible
  inherited;
end;


{-------------------------------------------------------------------------------------------------------------
   FORMS
-------------------------------------------------------------------------------------------------------------}
{ 1. Create the form
  2. Set the font of the new form to be the same as the font of the MainForm
  3. Show it }
procedure TAppData.CreateMainForm(aClass: TFormClass; OUT Reference; MainFormOnTaskbar: Boolean= FALSE; Show: Boolean= TRUE; Loading: TFormLoading= flPosOnly);
begin
  Assert(Vcl.Dialogs.UseLatestCommonDialogs= TRUE);      { This is true anyway by default, but I check it to remember myself about it. Details: http://stackoverflow.com/questions/7944416/tfileopendialog-requires-windows-vista-or-later }
  Assert(Application.MainForm = NIL, 'MainForm already exists!');
  Assert(Font = NIL,                 'AppData.Font already assigned!');

  Application.MainFormOnTaskbar := MainFormOnTaskbar;
  Application.ShowMainForm      := Show;      // Must be false if we want to prevent form flicker during skin loading at startup

  Application.CreateForm(aClass, Reference);

  MainFormCaption('Initializing...');

  SetGuiProperties(TForm(Reference));

  if (Loading = flFull) OR (Loading = flPosOnly) then
   begin
     // Load form

     // ISSUE HERE!
     // At this point we can only load "standard" Delphi components.
     // Loading of our Light components can only be done in cv_IniFile.pas -> TIniFileVCL
     //
     // For the moment the work around is to manually call cv_IniFile.LoadForm(Self, flFull) in TfrmMain.LateInitialize
     cbINIFile.LoadFormBase(TForm(Reference), Loading);

     { Write path to app in registry }
     if RunningFirstTime
     then RegisterUninstaller;
   end;

  // if the program is off-screen, bring it on-screen
  CorrectFormPositionScreen(TForm(Reference));

  // Ignore the "Show" parameter if "StartMinimized" is active
  if StartMinim
  then Application.Minimize
  else
     if Show
     then TForm(Reference).Show;

  // This will send a message to the mainform. The user must implement in the main form a procedure to captures this message.
  // This is the ONLY correct place where we can properly initialize the application (see "Delphi in all its glory") for details.
  PostMessage(TForm(Reference).Handle, MSG_LateFormInit, 0, 0);

  if SignalInitEnd
  then Initializing:= FALSE;

  MainFormCaption('');
end;


{ Create secondary form }
{ Load indicates if the GUI settings are remembered or not }
procedure TAppData.CreateForm(aClass: TFormClass; OUT Reference; Show: Boolean= TRUE; Loading: TFormLoading= flPosOnly; Owner: TWinControl= NIL; Parented: Boolean= FALSE; CreateBeforeMainForm: Boolean= FALSE);
begin
  if CreateBeforeMainForm
  then
    begin
      // We allow the Log form to be created before the main form.
      if Owner = NIL
      then TComponent(Reference):= aClass.Create(Application)  // Owned by Application. But we cannot use Application.CreateForm here because then, this form will be the main form!
      else TComponent(Reference):= aClass.Create(Owner);       // Owned by Owner

      //ToDo 4: For the case where the frmLog is created before the MainForm: copy the frmLog.Font from the MainForm AFTER the main MainForm created.
    end
  else
    begin
      if Application.MainForm = NIL
      then RAISE Exception.Create('Probably you forgot to create the main form with AppData.CreateMainForm!');

      if Owner = NIL
      then Application.CreateForm(aClass, Reference)        // Owned by Application
      else TComponent(Reference):= aClass.Create(Owner);    // Owned by Owner
    end;

  // Center form in the Owner
  if (Owner <> NIL)
  AND Parented then
    begin
      TForm(Reference).Parent:= Owner;
      CenterChild(TForm(Reference), Owner);
    end;

  // Font, snap, alpha
  SetGuiProperties(TForm(Reference));

  // Load previous form settings/position
  cbINIFile.LoadFormBase(TForm(Reference), Loading);

  if Show
  then TForm(Reference).Show;

  // Window fully constructed. Now we can let user start its own initialization process.
  PostMessage(TForm(Reference).Handle, MSG_LateFormInit, 0, 0);
end;


{ Create secondary form }
procedure TAppData.CreateFormHidden(aClass: TFormClass; OUT Reference; Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL);
begin
  CreateForm(aClass, Reference, FALSE, Loading, ParentWnd);
end;


{ Create secondary form }
procedure TAppData.CreateFormModal(aClass: TFormClass; Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL);
VAR Reference: TForm;
begin
  CreateForm(aClass, Reference, FALSE, Loading, ParentWnd);
  Reference.ShowModal;
end;


{ Create secondary form }
//ToDo: Do I need this? Since the form is modal, I should never need the Reference? To be deleted
procedure TAppData.CreateFormModal(aClass: TFormClass; OUT Reference; Loading: TFormLoading= flPosOnly; ParentWnd: TWinControl= NIL);
begin
  CreateFormModal(aClass, Loading, ParentWnd);
end;


procedure TAppData.SetGuiProperties(Form: TForm);
begin
  // Font
  if Form = Application.MainForm
  then Self.Font:= Form.Font   // We TAKE the font from the main form. Then we apply it to all existing and all future windows.
  else
    if Self.Font <> nil
    then Form.Font:= Self.Font;  // We set the same font for secondary forms

  // Fix issues with snap to edge of the screen
  if cbVersion.IsWindows8Up
  then Form.SnapBuffer:= 4
  else Form.SnapBuffer:= 10;

  // Form transparency
  Form.AlphaBlendValue := Opacity;
  Form.AlphaBlend:= Opacity< 255;
end;




{-------------------------------------------------------------------------------------------------------------
   APP PATH
-------------------------------------------------------------------------------------------------------------}

{ Returns the folder where the EXE file resides.
  The path ended with backslash. Works with UNC paths. Example: c:\Program Files\MyCoolApp\ }
function TAppData.CurFolder: string;
begin
  Result:= ExtractFilePath(Application.ExeName);
end;


{ Returns the folder where the EXE file resides plus one extra folder called 'System'
  The path ended with backslash. Works with UNC paths. Example: c:\Program Files\MyCoolApp\System\ }
function TAppData.SysDir: string;
begin
  Result:= CurFolder+ Trail('system');
end;


{ Check if the System folder exists. If not, we should kill the program! }
function TAppData.CheckSysDir: Boolean;
begin
  Result:= DirectoryExists(AppData.SysDir);

  if NOT Result
  then MesajError('The program was not properly installed! The "System" folder is missing.');
end;


{ Returns ONLY the name of the app (exe name without extension) }
function TAppData.AppShortName: string;
begin
 Result:= ExtractOnlyName(Application.ExeName);
end;


{ Returns the last folder used when the user opened a LoadFile/SaveFile dialog box }
//ToDo: save this to a INI file
function TAppData.getLastUsedFolder: string;
begin
 if FLastFolder = ''
 then Result:= GetMyDocuments
 else Result:= FLastFolder;
end;


{ Returns the path to current user's AppData folder on Windows, and to the current user's home directory on Mac OS X.
  Cannot be used at design-time because AppName is not set!
  Example
     Win XP: c:\Documents and Settings\UserName\Application Data\AppName\
     Vista+: c:\Documents and Settings\UserName\AppData\Roaming\
  if ForceDir then it creates the folder (full path) where the INI file will be written. }
class function TAppData.AppDataFolder(ForceDir: Boolean = FALSE): string;
begin
 Assert(AppName > '', 'AppName is empty!');
 Assert(System.IOUtils.TPath.HasValidFileNameChars(AppName, FALSE), 'Invalid chars in AppName: '+ AppName);

 Result:= Trail(Trail(TPath.GetHomePath)+ AppName);

 if ForceDir
 then ForceDirectories(Result);
end;



{ Example: 'C:\Documents and Settings\All Users\Application Data\AppName' }
function TAppData.AppDataFolderAllUsers: string;

   function GetSpecialFolder: string;  // This was copied here from cmIO, cmIO.Win.pas because we don't a circular reference to that file.
   begin
    SetLength(Result, MAX_PATH);
    ShGetFolderPath(0, CSIDL_COMMON_APPDATA, 0, 0, PChar(Result));
    VAR i:= Pos(#0, Result);
    if i> 0
    then SetLength(Result, pred(i));
    Result:= Trail (Result);
   end;

begin
 Assert(AppName > '', 'AppName is empty!');
 Assert(System.IOUtils.TPath.HasValidFileNameChars(AppName, FALSE), 'Invalid chars in AppName: '+ AppName);

 Result:= Trail(GetSpecialFolder+ AppName);
 if NOT DirectoryExists(Result)
 then ForceDirectories(Result);
end;


{ Returns the name of the INI file (where we will write application's settings).
  It is based on the name of the application. Example: c:\Documents and Settings\Bere\Application Data\MyApp\MyApp.ini }
class function TAppData.IniFile: string;
begin
 //Assert(AppData <> NIL, 'AppData is already gone!'); // This happens when I close the form.

 Assert(AppName > '', 'AppName is empty!');
 Assert(TPath.HasValidFileNameChars(AppName, FALSE), 'Invalid chars in AppName: '+ AppName);

 Result:= AppDataFolder+ AppName+ '.ini';
end;






{-----------------------------------------------------------------------------------------------------------------------
   APP UTILS
-----------------------------------------------------------------------------------------------------------------------}

{ Returns true if the application is "home" (in the computer where it was created). This is based on the presence of a DPR file that has the same name as the exe file. }
class function TAppData.RunningHome: Boolean;
begin
 Result:= FileExists(ChangeFileExt(Application.ExeName, '.dpr'));
end;


{ Returns true if a file called 'betatester' exists in application's folder or in application's system folder. }
function TAppData.BetaTesterMode: Boolean;
begin
 Result:= FileExists(SysDir+ 'betatester') OR FileExists(CurFolder+ 'betatester');
end;


{ Check if today is past the specified (expiration) date.
  If a file called 'dvolume.bin' exists, then the check is overridden.
  Good for checking exiration dates. }
function TAppData.IsHardCodedExp(Year, Month, Day: word): Boolean;
VAR
   s: string;
   HardCodedDate: TDateTime;
begin
 if FileExists(CurFolder+ 'dvolume.bin')         { If file exists, ignore the date passed as parameter and use the date written in file }
 then
   begin
     s:= StringFromFile(CurFolder+ 'dvolume.bin');
     HardCodedDate:= StrToInt64Def(s, 0);
     Result:= round(HardCodedDate- Date) <= 0;     { For example: 2016.07.18 is 3678001053146ms. One day more is: 3678087627949 }
   end
 else
   begin
     HardCodedDate:= EncodeDate(Year, Month, Day);
     Result:= round(HardCodedDate- Date) <= 0;
   end;
end;









{--------------------------------------------------------------------------------------------------
   APPLICATION / WIN START UP
--------------------------------------------------------------------------------------------------}

{ Run the specified application at Windows startup }
function TAppData.RunFileAtWinStartUp(CONST FilePath: string; Active: Boolean): Boolean;                             { Porneste anApp odata cu windows-ul }
VAR Reg: TRegistry;
begin
 Result:= FALSE;
 TRY
  Reg:= TRegistry.Create;
  TRY
   Reg.LazyWrite:= TRUE;
   Reg.RootKey:= HKEY_CURRENT_USER;                                                                { This is set by default by the constructor }
   if Reg.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Run', TRUE) then
     begin
      if Active
      then Reg.WriteString(ExtractOnlyName(FilePath),'"'+ FilePath + '"')                                { I got once an error here: ERegistryexception-Failed to set data for 'App-Name2'. Probably cause by an anti-virus }
      else Reg.DeleteValue(ExtractOnlyName(FilePath));
      Reg.CloseKey;
      Result:= TRUE;
     end;
  FINALLY
    FreeAndNil(Reg);
  END;
 except
   Result:= FALSE;                                                                                 { To catch possible issues caused by antivirus programs that won't let the program write to 'autorun' section }
 END;
end;


{ Run THIS application at Windows startup }
function TAppData.RunSelfAtWinStartUp(Active: Boolean): Boolean;
begin
  Result:= RunFileAtWinStartUp(ParamStr(0), Active);
end;








{--------------------------------------------------------------------------------------------------
   APPLICATION Control
--------------------------------------------------------------------------------------------------}
procedure TAppData.Restart;
begin
  VAR PAppName:= PChar(Application.ExeName);
  Winapi.ShellAPI.ShellExecute({Handle} 0, 'open', PAppName, nil, nil, SW_SHOWNORMAL);   { Handle does not work. Replaced with 0. }
  Application.Terminate;
end;


{ This is a bit dirty! It creates a BAT that deletes the EXE. Some antiviruses might block this behavior? }
procedure TAppData.SelfDelete;
CONST
   BatCode = ':delete_exe' + CRLFw +'del "%s"' + CRLFw +'if exist "%s" goto delete_exe' + CRLFw +'del "%s"';
VAR
 List    : TStringList;
 PI      : TProcessInformation;
 SI      : TStartupInfo;
 BatPath : string;
begin
  BatPath:= GetTempFolder+ ChangeFileExt(AppShortName, '.BAT');   // make it in temp
  List := TStringList.Create;
  TRY
    VAR S := Format(BatCode, [Application.ExeName, Application.ExeName, BatPath]);
    List.Text := S;
    List.SaveToFile(BatPath);
  FINALLY
    FreeAndNil(List);
  END;

  FillChar(SI, SizeOf(SI), 0);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;

  if CreateProcess( NIL, PChar(BatPath), NIL, NIL, False, IDLE_PRIORITY_CLASS, NIL, NIL, SI, PI) then
   begin
     CloseHandle(PI.hThread);
     CloseHandle(PI.hProcess);
   end;

  Application.Terminate;                                                                            { This is mandatory }
end;



{--------------------------------------------------------------------------------------------------
   SCREEN
--------------------------------------------------------------------------------------------------}
{ Bring the application back to screen (if minimized, in background, hidden) }
procedure TAppData.Restore;
begin
  Application.MainForm.Visible:= TRUE;
  if Application.MainForm.WindowState = wsMinimized
  then Application.MainForm.WindowState:= TWindowState.wsNormal;

  //Use Restore to restore the application to its previous size before it was minimized. When the user restores the application to normal size, Restore is automatically called.
  //Note: Don't confuse the Restore method, which restores the entire application, with restoring a form or window to its original size. To minimize, maximize, and restore a window or form, change the value of its WindowState property.
  {if IsIconic(Application.Handle) then } Application.Restore;
  SetForegroundWindow(Application.MainForm.Handle);
  Application.BringToFront;
end;


{ Hides Application's TaskBar Button
  Source: http://stackoverflow.com/questions/14811935/how-to-hide-an-application-from-taskbar-in-windows-7
  If Application.MainFormOnTaskbar is true, a taskbar button represents the application's main form and displays its caption.
  All child forms will stay on top of the MainForm (bad)! If False, a taskbar button represents the application's (hidden) main window and bears the application's Title. Must be True to use Windows (Vista) Aero effects (ive taskbar thumbnails, Dynamic Windows, Windows Flip, Windows Flip 3D). https://stackoverflow.com/questions/66720721/ }     //Do this in DPR
procedure TAppData.HideFromTaskbar;
begin
 ShowWindow(Application.Handle, SW_HIDE);
 //ShowWindow(MainForm.Handle, SW_HIDE);     //this also hides the form from the screen

{ Code below not working in Win7 !!!
  ShowWindow(Application.Handle, SW_HIDE);
  SetWindowLongPtr(Application.Handle, GWL_EXSTYLE, GetWindowLongPtr(Application.Handle, GWL_EXSTYLE) OR WS_EX_TOOLWINDOW);}      { getWindowLong_ was replaced with getWindowLongPtr for 64 bit compatibility. Details: http://docwiki.embarcadero.com/RADStudio/Seattle/en/Converting_32-bit_Delphi_Applications_to_64-bit_Windows }
end;





{--------------------------------------------------------------------------------------------------
   VERSION INFO
--------------------------------------------------------------------------------------------------}


function TAppData.GetVersionInfoMajor: Word;
VAR FixedInfo: TVSFixedFileInfo;
begin
 if GetVersionInfoFile(Application.ExeName, FixedInfo)
 then Result:= HiWord(FixedInfo.dwFileVersionMS)
 else Result:= 0;
end;


function TAppData.GetVersionInfoMinor: Word;
VAR FixedInfo: TVSFixedFileInfo;
begin
 if GetVersionInfoFile(Application.ExeName, FixedInfo)
 then Result:= LoWord(FixedInfo.dwFileVersionMS)
 else Result:= 0;
end;



{ Returns version with/without build number.
  Example:
     1.0.0.999
     1.0.0
  See also: CheckWin32Version }
class function TAppData.GetVersionInfo(ShowBuildNo: Boolean= False): string;
VAR FixedInfo: TVSFixedFileInfo;
begin
  FixedInfo.dwSignature:= 0;
  if cbVersion.GetVersionInfoFile(Application.ExeName, FixedInfo)
  then
     begin
      Result:= IntToStr(HiWord(FixedInfo.dwFileVersionMS))+'.'+ IntToStr(LoWord(FixedInfo.dwFileVersionMS))+'.'+ IntToStr(HiWord(FixedInfo.dwFileVersionLS));
      if ShowBuildNo
      then Result:= Result+ '.'+ IntToStr(LoWord(FixedInfo.dwFileVersionLS));
     end
  else Result:= '0';
end;


{ Returns version without build number. Example: v1.0.0.
  Automatically adds the v in front of the number. }
function TAppData.GetVersionInfoV: string;
begin
 Result:= ' v'+ GetVersionInfo(False);
end;






{-------------------------------------------------------------------------------------------------------------
   OTHERS
-------------------------------------------------------------------------------------------------------------}
// Apply this font to all existing forms.
procedure TAppData.setFont(aFont: TFont);
begin
  if FFont = NIL
  then FFont:= aFont   // We set the font for the first time.
  else
    begin
      // Note: FormCount also counts invisible forms and forms created TFrom.Create(Nil).
      FFont:= aFont;
      for VAR i:= 0 to Screen.CustomFormCount - 1 DO    // FormCount => forms currently displayed on the screen. CustomFormCount = as FormCount but also includes the property pages
        Screen.Forms[i].Font:= aFont;
    end;
end;


class procedure TAppData.RaiseIfStillInitializing;
CONST
   AppStillInitializingMsg = 'Application not properly initialized.'+#13#10#13#10+ 'PLEASE REPORT the steps necessary to reproduce this bug and restart the application.';
begin
 if AppData.Initializing
 then RAISE Exception.Create(AppStillInitializingMsg);
end;


{ Set this process to maximum priority. Usefull when measuring time }
procedure TAppData.SetMaxPriority;
begin
 SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS); //  https://stackoverflow.com/questions/13631644/setthreadpriority-and-setpriorityclass
end;





{-------------------------------------------------------------------------------------------------------------
   SINGLE INSTANCE
--------------------------------------------------------------------------------------------------------------
   This allows us to detect if an instance of this program is already running.
   If so, we can send the command line of this second instance to the first instance, and shutdown this second instance.
   I would have loved to have all the code in a single procedure but unfortunately this is not possible. Three procedures are required.

   Usage:
    In DPR write:
     AppData:= TAppData.Create('MyCoolAppName', ctAppWinClassName);

     if AppData.InstanceRunning
     then TAppData.ResurectInstance(ParamStr(1))
     else
      begin
       Application.Initialize;
       Application.CreateForm(TMainForm, MainForm);
       Application.Run;
      end;

    In MainForm:
      procedure TMainFrom.CreateParams(var Params: TCreateParams);
      begin
        inherited;
        AppData.SetSingleInstanceName(Params);
      end;

  ctAppWinClassName is a constant representing your application name/ID. This string must be unique.
  We use it in InstanceRunning to detect if the the application is already running, by looking to a form with this Class Name.

  Check BioniX/Baser for a full example.

  Links:
    https://stackoverflow.com/questions/35516347/sendmessagewm-copydata-record-string
    https://stackoverflow.com/questions/8688078/preventing-multiple-instances-but-also-handle-the-command-line-parameters
    https://stackoverflow.com/questions/23031208/delphi-passing-running-parameters-to-other-instance-via-wm-copydata-gives-wrong
    https://github.com/delphidabbler/articles/blob/master/article-13-pt2.pdf

  Alternative implementation:
    cmMutexSingleInstance.pas
-------------------------------------------------------------------------------------------------------------}

{ Application's main form needs to implement WMCopyData.
  Warning: We should never use PostMessage() with the WM_COPYDATA message because the data that is passed to the receiving application is only valid during the call. Finally, be aware that the call to SendMessage will not return untill the message is processed.

  Recommendation:
    1. The receiver procedure should also restore (bring to front) that instance.
    2. We should close this second instance after we sent the message to the first instance.
 }
procedure TAppData.ResurectInstance(CONST CommandLine: string);
VAR
   Window: HWND;
   DataToSend: TCopyDataStruct;
begin
  { Prepare the data you want to send }
  DataToSend.dwData := CopyDataID;  // Registered unique ID for LighSaber apps
  DataToSend.cbData := Length(CommandLine) * SizeOf(Char);
  DataToSend.lpData := PChar(CommandLine);

  Window:= WinApi.Windows.FindWindow(PWideChar(SingleInstClassName), NIL);    // This is a copy of csWindow.FindTopWindowByClass
  SendMessage(Window, WM_COPYDATA, 0, LPARAM(@DataToSend));
  {
  Winapi.Windows.ShowWindow(Window, SW_SHOWNORMAL);
  Winapi.Windows.SetForegroundWindow(Window);   }
end;


{ Returns True if an instance of this application was found already running }
function TAppData.InstanceRunning: Boolean;
begin
  Result:= WinApi.Windows.FindWindow(PWideChar(SingleInstClassName), NIL) > 0;
end;


{ Give a unique name to our form.
  We need to call this in TMainForm.CreateParams(var Params: TCreateParams)  }
procedure TAppData.SetSingleInstanceName(VAR Params: TCreateParams);
begin
  // Copies a null-terminated string. StrCopy is designed to copy up to 255 characters from the source buffer into the destination buffer. If the source buffer contains more than 255 characters, the procedure will copy only the first 255 characters.
  System.SysUtils.StrCopy(Params.WinClassName, PChar(SingleInstClassName));
  //Hint: This would work if WindowClassName would be a constant: Params.WinClassName:= WindowClassName
end;


{ Extract the data (from them Msg) that was sent to us by the second instance.
  Returns True if the message was indeed for us AND it is not empty.
  Returns the extracted data in 's'.
  It will also bring the first instance to foreground }
function TAppData.ExtractData(VAR Msg: TWMCopyData; OUT s: string): Boolean;
begin
 s:= '';
 Result:= FALSE;
 if Msg.CopyDataStruct.dwData = CopyDataID then { Only react on this specific message }
   begin
    if Msg.CopyDataStruct.cbData > 0 then       { Do we receive an empty string? }
      begin
        SetString(s, PChar(Msg.CopyDataStruct.lpData), Msg.CopyDataStruct.cbData div SizeOf(Char)); { We need a true copy of the data before it disappear }
        Msg.Result:= 2006;                      { Send something back as positive answer }
        Result:= TRUE;
      end;
    Restore;
   end;
end;






{--------------------------------------------------------------------------------------------------
   UNINSTALLER
---------------------------------------------------------------------------------------------------
   READ/WRITE folders to registry
   This is used by the Uninstaller.
   See c:\MyProjects\Project support\Cubic Universal Uninstaller\Uninstaller.dpr
--------------------------------------------------------------------------------------------------}
CONST
   RegKey: string= 'Software\CubicDesign\';

procedure TAppData.WriteAppDataFolder;                                           { Called by the original app }
begin
 RegWriteString(HKEY_CURRENT_USER, RegKey+ AppName, 'App data path', AppDataFolder);                                                                                                                              {Old name: WriteAppGlobalData }
end;


function TAppData.ReadAppDataFolder(CONST UninstalledApp: string): string;       { Called by the uninstaller }
begin
 Result:= RegReadString(HKEY_CURRENT_USER, RegKey+ UninstalledApp, 'App data path');
end;


{------------------------
   Instalation Folder
------------------------}
procedure TAppData.WriteInstalationFolder;                                     { Called by the original app }                                                                                                                                       {Old name: WriteAppGlobalData }
begin
 RegWriteString(HKEY_CURRENT_USER, RegKey+ AppName, 'Install path', CurFolder);
end;


function TAppData.ReadInstalationFolder(CONST UninstalledApp: string): string;  { Called by the uninstaller }
begin
 Result:= RegReadString(HKEY_CURRENT_USER, RegKey+ UninstalledApp, 'Install path');
end;




{-------------------------------------------------------------------------------------------------------------
   Prompt To Save/Load File

   These functions are also duplicated in cmIO, cmIO.Win.
   The difference is that there, those functions cannot read/write the LastUsedFolder var so the app cannot remmeber last use folder.

   Example: PromptToSaveFile(s, cGraphUtil.JPGFtl, 'txt');

   DefaultExt:
     Extensions longer than three characters are not supported!
     Do not include the dot (.)
-------------------------------------------------------------------------------------------------------------}
function TAppData.PromptToSaveFile(VAR FileName: string; CONST Filter: string = ''; CONST DefaultExt: string= ''; CONST Title: string= ''): Boolean;
VAR InitialDir: string;
begin
 if FileName > '' then
   if IsFolder(FileName)
   then InitialDir:= FileName
   else InitialDir:= ExtractFilePath(FileName);

 Result:= PromptForFileName(FileName, TRUE, Filter, DefaultExt, Title, InitialDir);
end;


Function TAppData.PromptToLoadFile(VAR FileName: string; CONST Filter: string = ''; CONST Title: string= ''): Boolean;
VAR InitialDir: string;
begin
 if FileName > '' then
   if IsFolder(FileName)
   then InitialDir:= FileName
   else InitialDir:= ExtractFilePath(FileName);

 Result:= PromptForFileName(FileName, FALSE, Filter, '', Title, InitialDir);
end;


{ Based on Vcl.Dialogs.PromptForFileName.
  AllowMultiSelect cannot be true, because I return a single file name (cannot return a Tstringlist)  }
Function TAppData.PromptForFileName(VAR FileName: string; SaveDialog: Boolean; CONST Filter: string = ''; CONST DefaultExt: string= ''; CONST Title: string= ''; CONST InitialDir: string = ''): Boolean;
VAR
  Dialog: TOpenDialog;
begin
  if SaveDialog
  then Dialog := TSaveDialog.Create(NIL)
  else Dialog := TOpenDialog.Create(NIL);
  TRY
    { Options }
    Dialog.Options := Dialog.Options + [ofEnableSizing, ofForceShowHidden];
    if SaveDialog
    then Dialog.Options := Dialog.Options + [ofOverwritePrompt]
    else Dialog.Options := Dialog.Options + [ofFileMustExist];

    Dialog.Title := Title;
    Dialog.DefaultExt := DefaultExt;

    if Filter = ''
    then Dialog.Filter := Vcl.Consts.sDefaultFilter
    else Dialog.Filter := Filter;

    if InitialDir= ''
    then Dialog.InitialDir:= Self.AppDataFolder  // Customization
    else Dialog.InitialDir:= InitialDir;

    Dialog.FileName := FileName;

    Result := Dialog.Execute;

    if Result then
      begin
        FileName:= Dialog.FileName;
        Self.LastUsedFolder:= ExtractFilePath(FileName);  // Customization
      end;
  FINALLY
    FreeAndNil(Dialog);
  END;
end;






{-------------------------------------------------------------------------------------------------------------
   TOOLS
   APP COMMAND LINE
-------------------------------------------------------------------------------------------------------------}

{ Returns the path sent as command line param. Tested ok. }
function CommandLinePath: string;
begin
 if ParamCount > 0
 then Result:= Trim(ParamStr(1))     { Do we have parameter into the command line? }
 else Result := '';
end;


{ Recieves a full path and returns the path and the parameters separately }
procedure ExtractPathFromCmdLine(MixedInput: string; OUT Path, Parameters: string);
VAR i: Integer;
begin
 Assert(Length(MixedInput) > 0, 'Command line length is 0!');

 Path:= '';
 Parameters:= '';
 MixedInput:= Trim(MixedInput);

  // Check if the first character is a double quote
 if MixedInput[1]<> '"'
 then Path:= MixedInput
 else
   { Copy all between ""}
   for i:= 2 to Length(MixedInput) DO                                                   { This supposes that " is on the first position }
    if MixedInput[i]= '"' then                                                          { Find next " character }
     begin
      // ToDo: use ccCore.ExtractTextBetween
      Path:= CopyTo(MixedInput, 1+1, i-1);   // Exclude the double quotes               { +1 si -1 because we want to exclude "" }
      Parameters:= Trim(System.COPY(MixedInput, i+1, MaxInt));
      Break;
     end;
end;   { See also: http://delphi.about.com/od/delphitips2007/qt/parse_cmd_line.htm }


function FindCmdLineSwitch(const Switch: string; IgnoreCase: Boolean): Boolean;
begin
  Result:= System.SysUtils.FindCmdLineSwitch(Switch, IgnoreCase);
end;




{-------------------------------------------------------------------------------------------------------------
   LOG
   ---
   SEND MESSAGES DIRECTLY TO LOG WND
-------------------------------------------------------------------------------------------------------------}
procedure TAppData.LogVerb(CONST Msg: string);
begin
 RamLog.AddVerb(Msg);   // This will call NotifyLogObserver
end;


procedure TAppData.LogHint(CONST Msg: string);
begin
 RamLog.AddHint(Msg);    // This will call NotifyLogObserver
end;


procedure TAppData.LogInfo(CONST Msg: string);
begin
 RamLog.AddInfo(Msg);    // This will call NotifyLogObserver
end;


procedure TAppData.LogImpo(CONST Msg: string);
begin
 RamLog.AddImpo(Msg);    // This will call NotifyLogObserver
end;


procedure TAppData.LogWarn(CONST Msg: string);
begin
 RamLog.AddWarn(Msg);    // This will call NotifyLogObserver
end;


procedure TAppData.LogError(CONST Msg: string);
begin
 RamLog.AddError(Msg);   // This will call NotifyLogObserver
end;


procedure TAppData.LogMsg(CONST Msg: string);  { Always show this message, no matter the verbosity of the log. Equivalent to Log.AddError but the msg won't be shown in red. }
begin
 RamLog.AddMsg(Msg);     // This will call NotifyLogObserver
end;


procedure TAppData.LogBold(CONST Msg: string);
begin
 RamLog.AddBold(Msg);    // This will call NotifyLogObserver
end;


procedure TAppData.LogClear;
begin
 RamLog.clear;
end;


procedure TAppData.LogEmptyRow;
begin
 RamLog.AddEmptyRow;
end;


procedure TAppData.setShowOnError(const Value: Boolean);
begin
  FShowOnError:= Value;
  RamLog.ShowonError:= Value;
end;


procedure TAppData.PopUpLogWindow;
begin
  RamLog.PopUpWindow;
end;










procedure TAppData.MainFormCaption(CONST Caption: string);
begin
 if Caption= ''
 then Application.MainForm.Caption:= AppName+ ' '+ GetVersionInfoV
 else Application.MainForm.Caption:= AppName+ ' '+ GetVersionInfoV+ ' - ' + Caption;
end;


procedure TAppData.setHideHint(const Value: Integer);
begin
  FHideHint := Value;
  Application.HintHidePause:= Value;       // Specifies the time interval to wait before hiding the Help Hint if the mouse has not moved from the control or menu item. Windows' default is 2500 ms
end;





{--------------------------------------------------------------------------------------------------
   UNINSTALLER

   Utility functions for c:\MyProjects\Project support\Universal Uninstaller\Uninstaller.dpr
--------------------------------------------------------------------------------------------------}
(*del

procedure TAppData.AddUninstallerToCtrlPanel(CONST UninstallerExePath: string);          { UninstallerExePath= Full path to the EXE file that represents the uninstaller; ProductName= the uninstaller will be listed with this name. Keep it simple without special chars like '\'. Example: 'BioniX Wallpaper' }
begin
 RegWriteString(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'+ AppName, 'DisplayName', AppName);
 RegWriteString(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'+ AppName, 'UninstallString', UninstallerExePath);
end; *)




procedure TAppData.RegisterUninstaller;
begin
 //del AddUninstallerToCtrlPanel(AppData.SysDir+ 'Uninstall.exe');                 { Puts uninstaller in 'Add/remove programs' in Control Panel }

 RegWriteString(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'+ AppName, 'DisplayName', AppName);
 RegWriteString(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'+ AppName, 'UninstallString', AppData.SysDir+ 'Uninstall.exe');

 AppData.WriteAppDataFolder;
 AppData.WriteInstalationFolder;
end;





{--------------------------------------------------------------------------------------------------
   LOAD/SAVE Settings
--------------------------------------------------------------------------------------------------}

procedure TAppData.SaveSettings;
begin
  VAR IniFile := TIniFileEx.Create('AppData Settings', IniFile);
  try
    IniFile.Write('AutoStartUp', AutoStartUp);
    IniFile.Write('StartMinim', StartMinim);
    IniFile.Write('Minimize2Tray', Minimize2Tray);
    IniFile.Write('HideHint', HideHint);
    IniFile.Write('Opacity', Opacity);
    IniFile.Write('ShowOnError', ShowLogOnError);
    IniFile.Write('HintType', Ord(HintType));
  finally
    FreeAndNil(IniFile);
  end;
end;


procedure TAppData.LoadSettings;
begin
  VAR IniFile := TIniFileEx.Create('AppData Settings', IniFile);
  try
    AutoStartUp   := IniFile.Read('AutoStartUp', False);
    StartMinim    := IniFile.Read('StartMinim', False);
    Minimize2Tray := IniFile.Read('Minimize2Tray', False);
    HideHint      := IniFile.Read('HideHint', 2500);
    Opacity       := IniFile.Read('Opacity', 250);
    ShowLogOnError:= IniFile.Read('ShowOnError', True);
    HintType      := THintType(IniFile.Read('HintType', 0));
  finally
    FreeAndNil(IniFile);
  end;

  RunSelfAtWinStartUp(AutoStartUp);
end;



initialization

FINALIZATION
begin
  FreeAndNil(AppData);
end;


end.


