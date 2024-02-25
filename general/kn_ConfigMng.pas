unit kn_ConfigMng;

(****** LICENSE INFORMATION **************************************************

 - This Source Code Form is subject to the terms of the Mozilla Public
 - License, v. 2.0. If a copy of the MPL was not distributed with this
 - file, You can obtain one at http://mozilla.org/MPL/2.0/.

------------------------------------------------------------------------------
 (c) 2007-2023 Daniel Prado Velasco <dprado.keynote@gmail.com> (Spain) [^]
 (c) 2000-2005 Marek Jedlinski <marek@tranglos.com> (Poland)

 [^]: Changes since v. 1.7.0. Fore more information, please see 'README.md'
     and 'doc/README_SourceCode.txt' in https://github.com/dpradov/keynote-nf

 *****************************************************************************)

interface

uses
   Winapi.Windows,
   System.Classes,
   System.IniFiles,
   System.SysUtils,
   Vcl.Forms,
   Vcl.Controls,
   Vcl.Dialogs,
   Vcl.Menus,
   TB97Ctls,
   TB97Tlbr
   ;

    // config management
    procedure ReadCmdLine;
    procedure SaveOptions;
    procedure ReadOptions;
    procedure LoadToolbars;
    procedure SaveToolbars;
    procedure SaveDefaults;
    procedure LoadDefaults;
    procedure AdjustOptions;
//    procedure SetupToolbarButtons;
//    procedure ResolveToolbarRTFv3Dependencies;
    function LoadCustomKeyboard : boolean;
    procedure CustomizeKeyboard;


implementation

uses
   gf_files,  // Important. Needed (among other things) to use TMemIniFileHelper (.ReadString, .WriteString)
   kn_Info,
   kn_INI,
   kn_Const,
   kn_global,
   kn_Chest,
   kn_OptionsNew,
   dll_Keyboard,
   kn_Macro,
   kn_Plugins,
   kn_StyleObj,
   kn_Dllmng,
   kn_DLLinterface,
   kn_LanguagesMng,
   kn_MacroMng,
   kn_VCLControlsMng,
   kn_TemplateMng,
   kn_PluginsMng,
   kn_Main
   ;


resourcestring
  STR_KeybdError = 'Error in keyboard customization procedure: ';
  STR_TabIcons = ' Customize Tab icons (%s) ';
  STR_InvalidCLA = 'Invalid command line arguments:';
  STR_ErrorLoading = 'Error while loading custom keyboard configuration from %s: "%s"';
  STR_ErrorNonFatal  = 'There was a non-fatal error while loading defaults: ' + #13 +
                        '%s' + #13#13 +  'Some settings may have been reset to defaults.';


procedure ReadCmdLine;
var
  i : integer;
  s, ext, errstr : string;
begin

  errstr := '';
  for i := 1 to ParamCount do  begin
    s := AnsiLowerCase( ParamStr( i ));

    case s[1] of
       '-', '/' : begin // assume switch { BUG: if a filename begins with '-', we're screwed }
          delete( s, 1, 1 );


          if ( s = swMinimize ) then
             opt_Minimize := true
          else
          {if ( s = swSetup ) then
             opt_Setup := true
          else}
{$IFDEF KNT_DEBUG}
          if ( s.StartsWith(swDebug) ) then begin
             opt_Debug := true;
             delete( s, 1, swDebug.Length );
             if s <> '' then begin
                try
                   log.MaxDbgLevel:= StrToInt(s);
                except
                end;
             end
             else
                log.MaxDbgLevel:= 1;          /// default max dbg level = 1
          end
          else
{$ELSE}
          if ( s = swDebug ) then
             opt_Debug := true
          else
{$ENDIF}
          if ( s = swNoReadOpt ) then
             opt_NoReadOpt := true
          else
          if ( s = swNoSaveOpt ) then
             opt_NoSaveOpt := true
          else
          if ( s = swNoDefaults ) then
             opt_NoDefaults := true
          else
          if ( s = swNoReg ) then
             opt_NoRegistry := true
          else
          if ( s = swRegExt ) then
             opt_RegExt := true
          else
          if ( s = swSaveDefIcn ) then
             opt_SaveDefaultIcons := true
          else
          if ( s = swSaveToolbars ) then
             opt_SaveToolbars := true
          else
{$IFDEF KNT_DEBUG}
          if ( s = swSaveMenus ) then
             opt_SaveMenus := true
{$ENDIF}
          else
          if ( s = swNoUserIcn ) then
             opt_NoUserIcons := true
          else
          if ( s = swUseOldFormat ) then
             _USE_OLD_KEYNOTE_FILE_FORMAT := true // GLOBAL var, used by TTabNote and TNoteFile
          else
          if ( s = swClean ) then
             opt_Clean := true
          else
          if ( s.StartsWith(swJmp) ) then begin
             // Jump to the KNT link indicated in quotes (in any of the recognized formats. Ex: "file:///*1|10|201|0")
             // Note: '-jmp"file:///*8|479|0|0"' is converted to '-jmpfile:///*8|479|0|0'
              _GLOBAL_URLText:= Copy(s, Length(swJmp)+1);
          end
          else
            errstr := errstr + #13 + ParamStr( i );

       end
       else begin
          // not a switch, so it's a filename.
          // Let's see what kind of file.
          ext := extractfileext(s);
          s:= GetAbsolutePath(ExtractFilePath(Application.ExeName), ParamStr(i));

          if (( ext = ext_KeyNote ) or ( ext = ext_Encrypted ) or ( ext = ext_DART )) then
             NoteFileToLoad := s
          else
          if ( ext = ext_INI ) then begin
             INI_FN := s;
             opt_NoRegistry := true;
          end
          else
          if ( ext = ext_ICN ) then
             ICN_FN := s
          else
          if ( ext = ext_DEFAULTS ) then
             DEF_FN := s
          else
          if ( ext = ext_MGR ) then
              MGR_FN := s
          else
          if ( ext = ext_Macro ) then begin
             StartupMacroFile := s;
             CmdLineFileName := s; // will be passed to other instance
          end
          else
          if ( ext = ext_Plugin ) then begin
             StartupPluginFile := s;
             CmdLineFileName := s; // will be passed to other instance
          end
          else
             NoteFileToLoad := s;

       end;

    end;
  end;

  if (errstr <> '' ) then
      MessageDlg( STR_InvalidCLA + #13 + errstr, mtWarning, [mbOK], 0 );

  if NoteFileToLoad = '' then
     _GLOBAL_URLText := '';

end; // ReadCmdLine







procedure SaveOptions;
begin
  if opt_NoSaveOpt then exit;

  try
    SaveKeyNoteOptions( INI_FN,
      KeyOptions,
      TabOptions,
      FindOptions,
      EditorOptions,
      ClipOptions,
      TreeOptions,
      ResPanelOptions
      );
  except
  end;
end; // SaveOptions


procedure ReadOptions;
begin
  if opt_NoReadOpt then exit;
  if ( not fileexists( INI_FN )) then begin
    FirstTimeRun := true;
    exit;
  end;

  LoadKeyNoteOptions( INI_FN,
    KeyOptions,
    TabOptions,
    FindOptions,
    EditorOptions,
    ClipOptions,
    TreeOptions,
    ResPanelOptions
    );
end; // ReadOptions


procedure SaveDefaults;
begin
  if opt_NoDefaults then exit;

  SaveKeyNoteDefaults(
    DEF_FN,
    DefaultEditorProperties,
    DefaultEditorChrome,
    DefaultTabProperties,
    DefaultTreeProperties,
    DefaultTreeChrome
  );
end; // SaveDefaults


procedure LoadDefaults;
begin
  if ( opt_NoDefaults or ( not fileexists( DEF_FN ))) then exit;

  try
    LoadKeyNoteDefaults(
      false,
      DEF_FN,
      DefaultEditorProperties,
      DefaultEditorChrome,
      DefaultTabProperties,
      DefaultTreeProperties,
      DefaultTreeChrome
    );

  except
    on E : Exception do
    begin
      showmessage( Format(STR_ErrorNonFatal , [E.Message]) );
    end;
  end;
end; // LoadDefaults


procedure SaveToolbars;
var
  IniFile : TMemIniFile;
  section : string;
  i, cnt : integer;
  tb : TToolbarButton97;
  ts : TToolbarSep97;
begin

  if opt_NoSaveOpt then exit;

  IniFile := TMemIniFile.Create( Toolbar_FN );

  try
    try
      with IniFile do begin
         with Form_Main do begin
            section := 'MainToolbar';
            cnt := pred( Toolbar_Main.ControlCount );
            for i := 0 to cnt do begin
              if ( Toolbar_Main.Controls[i] is TToolbarButton97 ) then begin
                 tb := ( Toolbar_Main.Controls[i] as TToolbarButton97 );
                 writebool( section, tb.name, tb.Visible );
              end
              else
              if ( Toolbar_Main.Controls[i] is TToolbarSep97 ) then begin
                 ts := ( Toolbar_Main.Controls[i] as TToolbarSep97 );
                 writebool( section, ts.name, ts.Visible );
              end
          end;

          section := 'FormatToolbar';
          cnt := pred( Toolbar_Format.ControlCount );
          for i := 0 to cnt do begin
              if ( Toolbar_Format.Controls[i] is TToolbarButton97 ) then begin
                 tb := ( Toolbar_Format.Controls[i] as TToolbarButton97 );
                 writebool( section, tb.name, tb.Visible );
              end
              else
              if ( Toolbar_Format.Controls[i] is TToolbarSep97 ) then begin
                 ts := ( Toolbar_Format.Controls[i] as TToolbarSep97 );
                 writebool( section, ts.name, ts.Visible );
              end
          end;

          section := 'Special';
          writebool( section, 'FontNameCombo', Combo_Font.Visible );
          writebool( section, 'FontSizeCombo', Combo_FontSize.Visible );
          writebool( section, 'ZoomCombo', Combo_Zoom.Visible );
          writebool( section, 'FontColorButton', TB_Color.Visible );
          writebool( section, 'FontHighlightButton', TB_Hilite.Visible );
        end;

     end;
     IniFile.UpdateFile;

    except
    end;

  finally
    IniFile.Free;
  end;

end; // SaveToolbars


procedure LoadToolbars;
var
  IniFile : TMemIniFile;
  section, compname : string;
  list : TStringList;
  i, cnt : integer;
  myC : TComponent;
begin
  if ( opt_NoReadOpt or ( not fileexists( Toolbar_FN ))) then exit;

  IniFile := TMemIniFile.Create( Toolbar_FN );
  list := TStringList.Create;

  try
    try
      with IniFile do begin
          section := 'MainToolbar';
          readsection( section, list );
          cnt := pred( list.Count );

          for i := 0 to cnt do begin
            compname := list[i];
            myC := Form_Main.findcomponent( compname );
            if assigned(myC) then begin
               if (myC is TToolbarButton97 ) then
                  (myC as TToolbarButton97 ).Visible := ReadBool( section, compname, true )
               else
               if (myC is TToolbarSep97 ) then
                  (myC as TToolbarSep97 ).Visible := ReadBool( section, compname, true );
            end;
          end;

          list.Clear;
          section := 'FormatToolbar';
          readsection( section, list );
          cnt := pred( list.Count );

          for i := 0 to cnt do begin
            compname := list[i];
            myC := Form_Main.findcomponent( compname );
            if assigned( myC ) then begin
               if ( myC is TToolbarButton97 ) then
                  (myC as TToolbarButton97 ).Visible := ReadBool( section, compname, true )
               else
               if ( myC is TToolbarSep97 ) then
                  (myC as TToolbarSep97 ).Visible := ReadBool( section, compname, true );
            end;
          end;

          section := 'Special';
          with Form_Main do begin
             Combo_Font.Visible := ReadBool( section, 'FontNameCombo', true );
             Combo_FontSize.Visible := ReadBool( section, 'FontSizeCombo', true );
             Combo_Zoom.Visible := ReadBool( section, 'ZoomCombo', true );
             TB_Color.Visible := ReadBool( section, 'FontColorButton', true );
             TB_Hilite.Visible := ReadBool( section, 'FontHighlightButton', true );
          end;

      end;

    except
    end;
  finally
    IniFile.Free;
    list.Free;
  end;

end; // LoadToolbars


function LoadCustomKeyboard : boolean;
var
  IniFile : TMemIniFile;
  itemname, keyname : String;
  KeyList : TStringList;
  i, cnt, keyvalue : integer;
  Category : TCommandCategory;
  myMenuItem : TMenuItem;
  kOC: TKeyOtherCommandItem;
  Group: TGroupCommand;
  IsMenu: boolean;

begin
  result := false;
  if ( opt_NoReadOpt or ( not fileexists( Keyboard_FN ))) then exit;

  IniFile := TMemIniFile.Create( Keyboard_FN );
  KeyList := TStringList.Create;
  ClearObjectList(OtherCommandsKeys);

  try
    try

      with IniFile do begin

         for Category := low( TCommandCategory ) to high( TCommandCategory ) do begin
           Keylist.Clear;
           ReadSectionValues( KeyboardConfigSections[Category], KeyList );   // At this file this problem doesn't affect: TMemIniFile Doesn't Handle Quoted Strings Properly (http://qc.embarcadero.com/wc/qcmain.aspx?d=4519)

           IsMenu:= Category in [ccMenuMain .. ccMenuTree];

           cnt := KeyList.Count;
           for i := 0 to cnt -1 do begin
              itemname := KeyList.Names[i];
              keyname  := KeyList.Values[itemname];
              if keyname = '' then continue;

              keyvalue := StrToIntDef( keyname, 0);

               // Don't allow shortcuts CTR-C, Ctrl-V, Ctrl-X. This combinations will be managed indepently
               if (keyvalue = 16451) or (keyvalue=16470) or (keyvalue = 16472) then
                  keyvalue:= 0;

               if IsMenu then begin
                  myMenuItem := TMenuItem( Form_Main.FindComponent( itemname ));
                  if assigned( myMenuItem ) then
                     myMenuItem.ShortCut := keyvalue;
               end
               else if keyvalue <> 0 then begin
                  kOC:= TKeyOtherCommandItem.Create;
                  kOC.Name := itemname;
                  kOC.Category:= Category;
                  kOC.Shortcut := keyvalue;
                  OtherCommandsKeys.Add(kOC);
               end;

           end;
         end;
      end;

    except
      on E : Exception do
        MessageDlg(Format(STR_ErrorLoading, [Keyboard_FN, E.Message] ), mtError, [mbOK], 0 );
    end;

  finally
    IniFile.Free;
    KeyList.Free;
  end;

end; // LoadCustomKeyboard


procedure BuildOtherCommandsList (const OtherCommandsList: TList);

  function GetCurrentShortCut(Category: TOtherCommandCategory; Command: string): TShortCut;
  var
     i: integer;
     Koc: TKeyOtherCommandItem;
  begin
       for i:= 0 to OtherCommandsKeys.Count-1 do begin
          Koc:= OtherCommandsKeys[i];
          if (Koc.Category = Category) and Koc.Name.Equals(Command) then
             Exit(Koc.Shortcut)
       end;
       exit(0);
  end;

  procedure CreateItems (Categ: TCommandCategory; Strs: TStrings);
  var
     i: integer;
     kOC: TKeyCommandItem;
  begin
      for i := 0 to Strs.Count - 1 do begin
         kOC:= TKeyCommandItem.Create;
         kOC.Category:= Categ;
         kOC.Name:= Strs[i];
         kOC.Caption:= kOC.Name;
         kOC.Path:= kOC.Name;
         if Categ = ccMacro then
            kOC.Hint:= TMacro( Strs.Objects[i] ).Description;
         kOC.Shortcut:= GetCurrentShortCut(Categ, kOC.Name);
         OtherCommandsList.Add(kOC);
      end;
  end;

begin
   EnumerateMacros;
   CreateItems(ccMacro, Macro_List);

   LoadTemplateList;
   CreateItems(ccTemplate, Form_Main.ListBox_ResTpl.Items);

   EnumeratePlugins;
   CreateItems(ccPlugin, Plugin_List);

   LoadStyleManagerInfo( Style_FN );
   CreateItems(ccStyle, StyleManager);

   CreateItems(ccFont, Form_Main.Combo_Font.Items);
end;


procedure CustomizeKeyboard;
var
  KeyList : TList;
  KeyCustomMenus : TKeyCustomMenus;
  DlgCustomizeKeyboard : DlgCustomizeKeyboardProc;
  // DlgAboutKeyNote : DlgAboutKeyNoteProc;
  DllHandle : THandle;
begin
  DllHandle:= 0;
  @DlgCustomizeKeyboard := GetMethodInDLL(DLLHandle, 'DlgCustomizeKeyboard');
  if not assigned(DlgCustomizeKeyboard) then exit;

  //Restore these shortcuts momentarily to show them in the configuration screen
  if TMenuItem( Form_Main.FindComponent( 'MMEditPaste' )).ShortCut = 0 then
     TMenuItem( Form_Main.FindComponent( 'MMEditPaste' )).ShortCut:= ShortCut(Ord('V'), [ssCtrl]); // 16470;
  if TMenuItem( Form_Main.FindComponent( 'MMEditCopy' )).ShortCut = 0 then
     TMenuItem( Form_Main.FindComponent( 'MMEditCopy' )).ShortCut:= ShortCut(Ord('C'), [ssCtrl]); // 16451;
  if TMenuItem( Form_Main.FindComponent( 'MMEditCut' )).ShortCut = 0 then
     TMenuItem( Form_Main.FindComponent( 'MMEditCut' )).ShortCut:= ShortCut(Ord('X'), [ssCtrl]);  // 16472;

  KeyCustomMenus[ccMenuMain] := Form_Main.Menu_Main;
  KeyCustomMenus[ccMenuTree] := Form_Main.Menu_TV;

  KeyList := TList.Create;
  try
    try
      BuildKeyboardList( KeyCustomMenus, KeyList );
      BuildOtherCommandsList (KeyList);

      if DlgCustomizeKeyboard(Application.Handle, PChar( Keyboard_FN ), KeyList, KeyOptions.HotKey) then begin
          screen.Cursor := crHourGlass;
          try
             LoadCustomKeyboard;
          finally
             screen.Cursor := crDefault;
          end;
      end;

      TMenuItem( Form_Main.FindComponent( 'MMEditPaste' )).ShortCut := 0;
      TMenuItem( Form_Main.FindComponent( 'MMEditCopy' )).ShortCut := 0;
      TMenuItem( Form_Main.FindComponent( 'MMEditCut' )).ShortCut := 0;

    except
      on E : Exception do
        messagedlg( STR_KeybdError + E.Message, mtError, [mbOK], 0 );
    end;

  finally
    FreeLibrary( DllHandle );
    ClearObjectList( KeyList );
    KeyList.Free;
  end;

end; // CustomizeKeyboard

procedure AdjustOptions;
var
  Form_Options : TForm_OptionsNew;
  tmpicnfn : string;
  oldHotKey : Word;
  oldLanguageUI : string;
  FN: string;
begin
  with Form_Options do begin
      Form_Options := TForm_OptionsNew.Create( Form_Main );
      try
          myOpts := KeyOptions;
          myTabOpts := TabOptions;
          myClipOpts := ClipOptions;
          myTreeOpts := TreeOptions;
          myEditorOptions := EditorOptions;
          myTreeOptions := TreeOptions;
          myFindOpts := FindOptions;
          ShowHint := KeyOptions.ShowTooltips;

          Icons_Change_Disable :=
            ( opt_NoUserIcons or
            ( assigned( NoteFile ) and ( NoteFile.TabIconsFN = _NF_Icons_BuiltIn )));

          if ( not Icons_Change_Disable ) then begin
            tmpicnfn := extractfilename( ICN_FN );
            if assigned( NoteFile ) then begin
              if (( NoteFile.TabIconsFN <> _NF_Icons_BuiltIn ) and
                 ( NoteFile.TabIconsFN <> '' )) then
                tmpicnfn := extractfilename( NoteFile.TabIconsFN );
            end;
            GroupBox_TabIcons.Caption := Format( STR_TabIcons, [tmpicnfn] );
          end;

        if ( Form_Options.ShowModal = mrOK ) then begin
          screen.Cursor := crHourGlass;
          try

            oldHotKey := KeyOptions.HotKey; // save previous state
            oldLanguageUI := KeyOptions.LanguageUI;

            KeyOptions := Form_Options.myOpts;
            TabOptions := Form_Options.myTabOpts;
            ClipOptions := Form_Options.myClipOpts;
            TreeOptions := Form_Options.myTreeOpts;
            EditorOptions := Form_Options.myEditorOptions;
            TreeOptions := Form_Options.myTreeOptions;
            FindOptions := Form_Options.myFindOpts;

            // update hotkey only if settings changed
            if (( HotKeySuccess <> KeyOptions.HotKeyActivate ) or ( KeyOptions.HotKey <> oldHotKey )) then begin
              Form_Main.HotKeyProc( false );
              if KeyOptions.HotKeyActivate then
                 Form_Main.HotKeyProc( true );
            end;

            if Form_Options.Icons_Changed then begin
              // icons were changed, save them
              if assigned( NoteFile ) then begin
                if ( NoteFile.TabIconsFN = '' ) then
                  SaveCategoryBitmapsUser( ICN_FN )
                else
                  SaveCategoryBitmapsUser( NoteFile.TabIconsFN );
              end
              else
                 SaveCategoryBitmapsUser( ICN_FN );
            end;

            if oldLanguageUI <> KeyOptions.LanguageUI then
               ApplyLanguageUI (KeyOptions.LanguageUI);

            SaveOptions;
            with Form_Main do begin
              UpdateFormState;
              UpdateTabState;
              UpdateStatusBarState;
              UpdateResPanelState;
            end;

            if ( assigned( NoteFile ) and assigned( NoteFile.ClipCapNote )) then
              LoadTrayIcon( ClipOptions.SwitchIcon );

          finally
            screen.Cursor := crDefault;
          end;
        end
        else
           if Form_Options.Icon_Change_Canceled then
              LoadTabImages( true );

      finally
        Form_Options.Free;
      end;
  end;

end; // AdjustOptions

end.
