unit som_main;

{$mode objfpc}{$H+}

interface

uses
  windows, Classes, SysUtils, FileUtil, SynEdit, SynHighlighterAny, Forms,
  Controls, Graphics, Dialogs, StdCtrls, Buttons, ExtCtrls, ComCtrls, INIFiles,
  Process, Types, LCLType, LCLIntf;

type

  { Tsom_mForm }

  Tsom_mForm = class(TForm)
    somEdit_Copyright: TEdit;
    somEdit_PreviewMaxSize: TEdit;
    somEdit_Suffix: TEdit;
    somGroupBox_Rename: TGroupBox;
    somCheckBox_PrwNameToOrig: TCheckBox;
    somCheckBox_PrwTitleToOrigName: TCheckBox;
    somEdit_FromPreviewFolder: TEdit;
    somEdit_OriginalFolder: TEdit;
    somEdit_ToPreviewFolder: TEdit;
    somGroupBox_Setting: TGroupBox;
    somLabel_Copyright: TLabel;
    somLabel_FilesCount: TLabel;
    somLabel_PreviewMaxSize: TLabel;
    somLabel_Suffix: TLabel;
    somListBox_Files: TListBox;
    somProgressBar1: TProgressBar;
    somSpeedButton_AddFiles: TSpeedButton;
    somSpeedButton_ClearFiles: TSpeedButton;
    somSpeedButton_CopyMetadataMode: TSpeedButton;
    somSpeedButton_DeleteFile: TSpeedButton;
    somSpeedButton_Do: TSpeedButton;
    somSpeedButton_Log: TSpeedButton;
    somSpeedButton_CreatePreviewMode: TSpeedButton;
    somSynAnySyn: TSynAnySyn;
    somSynEdit: TSynEdit;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure somCheckBox_PrwNameToOrigChange(Sender: TObject);
    procedure somCheckBox_PrwTitleToOrigNameChange(Sender: TObject);
    procedure somGroupBox_FromOutsourceClick(Sender: TObject);

    procedure EnabledOff;
    procedure EnabledOn;
    procedure ReadSetting;
    procedure somListBox_FilesDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure somSpeedButton_AddFilesClick(Sender: TObject);
    procedure somSpeedButton_ClearFilesClick(Sender: TObject);
    procedure somSpeedButton_CopyMetadataModeClick(Sender: TObject);
    procedure somSpeedButton_DoClick(Sender: TObject);
    procedure somSpeedButton_CreatePreviewModeClick(Sender: TObject);
    procedure somSpeedButton_DeleteFileClick(Sender: TObject);
    procedure somSpeedButton_LogClick(Sender: TObject);
    procedure WriteSetting;
    procedure UpdateMyF;
    procedure CreatePreview;
    procedure CopyMetadata;
    procedure UnColorAll;
  private
    { private declarations }
  public
    { public declarations }
  end;

  myFile = Record
    fullFileName,
    fullFileName2,
    FileNamePath,
    FileName,
    FileNameNoExt,
    Copyright,
    Copyright2,
    Title                 : String;
  end;

  findFileCopyrights = Record
    fullFileName,
    Copyright,
    Title                 : String;
  end;

var
  som_mForm: Tsom_mForm;
  StartingPoint : TPoint;
  myF: array of myFile;
  Fcopyright: array of findFileCopyrights;
  SysPath,OriginFilePath: string;
  clPRWmode, clMTDmode: TColor;
  maxApp,minApp: integer;
  ErrMessage: boolean;

implementation

{$R *.lfm}

{ Tsom_mForm }


procedure AddToLog(str: string);
var
  i: integer;
begin
 som_mForm.somSynEdit.Lines.Add(str);
 for i:=0 to som_mForm.somSynAnySyn.KeyWords.Count-1 do
     if pos(som_mForm.somSynAnySyn.KeyWords.Strings[i],UpperCase(str))>0 then
       begin
         ErrMessage:= true;
         som_mForm.Height:=maxApp;
         som_mForm.somSynEdit.SelectAll;
         som_mForm.somSynEdit.SelectLine(true);
         som_mForm.Repaint;
       end;
end;

function GenRandomChar: string;    /// генерация рандомных символов и чисел
const
  CustomChar = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' ;
var
  sGen: string ;
  i: integer;
begin
 randomize;
 sGen:='';
  for i:=1 to 512 do
    begin
      sGen:= sGen + CustomChar[Random(Length(CustomChar) + 1)] ;
    end;
  result:='sKO'+sGen;
end;


procedure ShowProgress(FilesCount, CurrentFile: integer);
begin
 som_mForm.somProgressBar1.Max:=FilesCount;
 som_mForm.somProgressBar1.Position:=CurrentFile;
 if FilesCount=CurrentFile then som_mForm.somProgressBar1.Position:=0;
end;

procedure Tsom_mForm.somListBox_FilesDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
 with somListBox_Files.Canvas do
   begin
     if (odSelected in State)
       then Brush.Color := clGray // цвет выделения
       else Brush.Color := somListBox_Files.Color;

     FillRect(ARect);
     if Index >= 0
       then TextOut(ARect.Left + 2, ARect.Top, somListBox_Files.Items[Index]);
   end;
end;

function StrFromIni(section,key,DefaultValue:string):string;
var
  ini : TIniFile;
begin
  ini:= TIniFile.Create(SysPath+'setting.ini');
  try
    result:= ini.ReadString(section, key, DefaultValue);
  finally
    FreeAndNil(ini);
  end;
end;

function StrToIni(section,key,Value:string):boolean;
var
  ini : TIniFile;
begin
  ini:= TIniFile.Create(SysPath+'setting.ini');
  try
    try
      ini.WriteString(section, key, Value);
      result:=true;
    except
      result:=false;
    end;
  finally
    FreeAndNil(ini);
  end;
end;



{процедура для запуска сторонней программы с ожиданием выполнения}
function RunWinProgram(cmdLine, Waiting: string): boolean;
var
  AProcess: TProcess;
begin
 AProcess := TProcess.Create(nil);
 try
   try
     AProcess.CommandLine := UTF8toSys(cmdLine);
     if Waiting='yes' then AProcess.Options := AProcess.Options + [poWaitOnExit, poUsePipes];
     if Waiting='no' then AProcess.Options := AProcess.Options + [poUsePipes];
     AProcess.ShowWindow:= swoHIDE;
     AProcess.Execute;
     result:=true;
   except
     result:=false;
     AddToLog(UTF8toSys('cmdLine_Not_Complite: '+cmdLine));
   end;
 finally
   FreeAndNil(AProcess);
 end;
end;


function ReadCopyright(FileName: string): string;
var
  AProcess: TProcess;
  AStringList: TStringList;
begin
  AProcess := TProcess.Create(nil);
  AStringList := TStringList.Create;
  AProcess.CommandLine := UTF8toSys('sys\exiftool.exe -d "%d.%m.%Y" -s3 -Copyright "'+FileName+'"');
  AProcess.Options := AProcess.Options + [poWaitOnExit, poUsePipes];
  AProcess.ShowWindow := swoHIDE;
  AProcess.Execute;
  AStringList.LoadFromStream(AProcess.Output);
  if AStringList.Count<>0 then
    begin
      result:=AStringList.Strings[0];
    end
  else
    begin
      result:='';
    end;
  FreeAndNil(AStringList);
  FreeAndNil(AProcess);
end;



procedure ReadTitleCopyright(const FileName: string; var fTitle,fCopyright: string);
var
  AProcess: TProcess;
  AStringList: TStringList;
begin
  AProcess := TProcess.Create(nil);
  AStringList := TStringList.Create;
  AProcess.CommandLine := UTF8toSys('sys\exiftool.exe -d "%d.%m.%Y" -s3 -title -Copyright "'+FileName+'"');
  AProcess.Options := AProcess.Options + [poWaitOnExit, poUsePipes];
  AProcess.ShowWindow := swoHIDE;
  AProcess.Execute;
  AStringList.LoadFromStream(AProcess.Output);
  if AStringList.Count>1 then
    begin
      fTitle:=AStringList.Strings[0];
      fCopyright:=AStringList.Strings[1];
    end
  else
    begin
      fTitle:='';
      fCopyright:='';
    end;
    FreeAndNil(AStringList);
    FreeAndNil(AProcess);
end;


procedure MakeThumb(MaxSize, FileName, FileName_Th: string);  // convert.exe c русскими буквами не работает
var
  str: string;
begin
  str:= 'sys\convert.exe -define jpeg:size=280x280 "'+FileName+'" -thumbnail '+MaxSize+'x'+MaxSize+' "'+FileName_Th+'"';
  RunWinProgram(str, 'yes');
end;


procedure Tsom_mForm.somSpeedButton_AddFilesClick(Sender: TObject);
var
  i: integer;
  OpenDlg: TOpenDialog;
begin
  OpenDlg:= TOpenDialog.Create(self);
  OpenDlg.Name:='OpenDialog_Files1';
  OpenDlg.Options:=[ofAllowMultiselect,ofAutoPreview,ofFileMustExist];
  OpenDlg.Filter :='Only JPG-files|*.jpg';   //  'Image files only|*.jpg;*.png';
  //OpenDlg.FilterIndex := 1;
  //OpenDlg.InitialDir := GetCurrentDir;
  if DirectoryExistsUTF8(somEdit_OriginalFolder.Text) then
    OpenDlg.InitialDir := somEdit_OriginalFolder.Text;

  if OpenDlg.Execute then
    begin
      for i := 0 to OpenDlg.Files.Count -1 do
        begin
        somListBox_Files.Items.Add(OpenDlg.Files.Strings[i]);
        AddToLog('file_Added: "'+ExtractFileName(OpenDlg.Files.Strings[i])+'"');
        end;
      UpdateMyF;
    end;
  OpenDlg.Free;
end;

procedure Tsom_mForm.somSpeedButton_ClearFilesClick(Sender: TObject);
begin
  somListBox_Files.Clear;
  somLabel_FilesCount.Caption:='(0)';
  UpdateMyF;
end;


procedure Tsom_mForm.somSpeedButton_CreatePreviewModeClick(Sender: TObject);
var
  i: integer;
begin
  (Sender as TSpeedButton).Flat:=false;
  somSpeedButton_CopyMetadataMode.Flat:=true;
  somSpeedButton_Do.Caption:='АРБАЙТЭН - сделать превью';
  UnColorAll;
  EnabledOn;

  somEdit_FromPreviewFolder.Enabled:=false;
  somEdit_ToPreviewFolder.Enabled:=true;
  somGroupBox_Setting.Visible:=true;
  somGroupBox_Rename.Visible:=false;

  somEdit_OriginalFolder.Color:=clPRWmode;    //clSilver  clMTDmode  clPRWmode
  somEdit_ToPreviewFolder.Color:=clPRWmode;
  somListBox_Files.Color:=clPRWmode;
  somEdit_PreviewMaxSize.Color:=clPRWmode;
  somEdit_Suffix.Color:=clPRWmode;
end;

procedure Tsom_mForm.somSpeedButton_CopyMetadataModeClick(Sender: TObject);
begin
  (Sender as TSpeedButton).Flat:=false;
   somSpeedButton_CreatePreviewMode.Flat:=true;
   somSpeedButton_Do.Caption:='АРБАЙТЭН - копировать Метаданные с превью';
   UnColorAll;
   EnabledOn;

   somEdit_ToPreviewFolder.Enabled:=false;
   somGroupBox_Setting.Visible:=false;
   somEdit_FromPreviewFolder.Enabled:=true;
   somGroupBox_Rename.Visible:=true;

   somEdit_OriginalFolder.Color:=clMTDmode;    //clSilver  clMTDmode  clPRWmode
   somEdit_FromPreviewFolder.Color:=clMTDmode;
   somListBox_Files.Color:=clMTDmode;
   somEdit_Suffix.Color:=clSilver;
end;

procedure Tsom_mForm.CreatePreview;
var
  i: integer;
  str,prwFileName,RandCopyright: string;
begin
 if Length(myF)<>0 then
   begin
     for i:=0 to Length(myF)-1 do
       begin
         prwFileName:=somEdit_ToPreviewFolder.Text+'\'+myF[i].FileNameNoExt+somEdit_Suffix.Text+'.jpg';
         MakeThumb(somEdit_PreviewMaxSize.Text, myF[i].fullFileName, prwFileName);
         if FileExistsUTF8(prwFileName) then       // сделан ли превью
           begin
             AddToLog('preview_Created: "'+ExtractFileName(prwFileName)+'"');
             RandCopyright:=GenRandomChar;
             //стираем весь EXIF и ставим копирайт
             str:= 'sys\exiftool.exe -all= -overwrite_original -tagsfromfile @ -ICC_Profile -ThumbnailImage -Copyright="'+RandCopyright+'" -EXIF:DateTimeOriginal "'+prwFileName+'"';
             RunWinProgram(str, 'yes');
             str:= 'sys\exiftool.exe -overwrite_original -Copyright="'+RandCopyright+'" "'+myF[i].fullFileName+'"';
             RunWinProgram(str, 'yes');
           end
         else
           begin
             AddToLog('preview_Not_Created for: "'+ExtractFileName(myF[i].FileName)+'"');
           end;
         ShowProgress(Length(myF), i+1);
       end;
   end;
end;




function CutEndSlash(Str: string): string;
begin
  if Copy(Str,Length(Str),Length(Str))='\' then
    Result := Copy(Str,1,Length(Str)-1)
  else
    Result := Str;
end;

function DelDuobleSlash(s:string):string;
begin
  result:=stringReplace(s, '\\', '\', [rfReplaceAll]);
end;


// Fcopyright
procedure GetCopyrightFromDir(Dir: string);
var
  fs: TSearchRec;
  n: integer;
begin
 SetLength(Fcopyright,0);
 n:=0;
 if FindFirstUTF8(DelDuobleSlash(Dir+'\*.jpg'), faAnyFile, fs)=0 then
   repeat
     Inc(n);
     SetLength(Fcopyright, n);
     Fcopyright[n-1].fullFileName:=DelDuobleSlash(Dir+'\'+fs.Name);
     Fcopyright[n-1].Copyright:=ReadCopyright(Fcopyright[n-1].fullFileName);
   until FindNextUTF8(fs)<>0;
 FindCloseUTF8(fs);
end;



procedure Tsom_mForm.CopyMetadata;
var
  i,j: integer;
  str,origFullFileName,prwFullFileName,origFullFileNameNew: string;
begin
 if Length(myF)<>0 then
   begin
     GetCopyrightFromDir(somEdit_OriginalFolder.Text); // заносим в массив все файлы оригиналов
     for i:=0 to Length(myF)-1 do
       begin
         ReadTitleCopyright(myF[i].fullFileName, myF[i].Title, myF[i].Copyright);    //читаем тайтл и копирайт превью
         myF[i].Copyright:=ReadCopyright(myF[i].fullFileName);     //читаем копирайт превью
         for j:=0 to Length(Fcopyright)-1 do
           begin
             if (myF[i].Copyright)=(Fcopyright[j].Copyright) then
               begin
                 myF[i].fullFileName2:=Fcopyright[j].fullFileName;
                 myF[i].Copyright2:=Fcopyright[j].Copyright;
               end;
           end;

         origFullFileName:=myF[i].fullFileName2;
         prwFullFileName:=myF[i].fullFileName;

         if FileExistsUTF8(origFullFileName) then
           begin
             AddToLog('file_found: "'+ExtractFileName(origFullFileName)+'"');
             //стираем весь EXIF
             str:= 'sys\exiftool.exe -all= -overwrite_original -tagsfromfile @ -ICC_Profile -ThumbnailImage -EXIF:DateTimeOriginal "'+origFullFileName+'"';
             RunWinProgram(str, 'yes');

             //копировать Metadata
             str:= 'sys\exiftool.exe -G0:1 -overwrite_original -TagsFromFile "'+prwFullFileName+'" "-all:all>all:all" -Copyright="'+somEdit_Copyright.Text+'" "'+origFullFileName+'"';
             RunWinProgram(str, 'yes');

 /////Rename File
             if (somCheckBox_PrwNameToOrig.Checked) or
                (somCheckBox_PrwTitleToOrigName.Checked) then
               begin
                 // get origName by prwName
                 if somCheckBox_PrwNameToOrig.Checked then
                   origFullFileNameNew:=ExtractFilePath(origFullFileName)+ExtractFileName(prwFullFileName);
                 // get origName by prwTitle
                 if somCheckBox_PrwTitleToOrigName.Checked then
                   origFullFileNameNew:=ExtractFilePath(origFullFileName)+myF[i].Title+ExtractFileExt(origFullFileName);

                 if not FileExistsUTF8(origFullFileNameNew) then
                   begin  //Rename
                     if RenameFileUTF8(origFullFileName,origFullFileNameNew) then
                       begin
                         AddToLog('file_renamed to: "'+ExtractFileName(origFullFileName)+'"');
                       end
                     else
                       begin
                         AddToLog('file_Not_renamed for Preview: "'+ExtractFileName(prwFullFileName)+'"');
                       end;
                   end
                 else
                   begin
                     MessageDlg('Что делать, Карл, что делать???',
                                   '...данные перенесены, но переименовать Оригинал неполучится '+LineEnding+
                                   '(файл с таким именем уже существует):'+LineEnding+
                                   ExtractFileName(origFullFileNameNew), mtConfirmation, [mbClose], 0);
                     AddToLog('file_Not_renamed for Preview: "'+ExtractFileName(prwFullFileName)+'"');
                   end;
               end;
           end
         else
           begin
             AddToLog('file_Not_found for this Preview: "'+ExtractFileName(prwFullFileName)+'"');
           end;
         ShowProgress(Length(myF), i+1);
       end;
   end;
end;

procedure Tsom_mForm.somSpeedButton_DoClick(Sender: TObject);
var
  str,ErrStr: string;
begin
 ErrStr:='';
/// CreatePreviewMode
  if somSpeedButton_CreatePreviewMode.Flat=false then
    begin
      /// проверки
      if not DirectoryExistsUTF8(somEdit_ToPreviewFolder.Text) then
        begin
          showmessage('Папка для вывода превью отсутствует');
          Exit;
        end;
      if somListBox_Files.Count=0 then
        begin
          showmessage('Файлы надо добавить');
          Exit;
        end;
      if CutEndSlash(somEdit_OriginalFolder.Text)=CutEndSlash(somEdit_ToPreviewFolder.Text) then
        if Length(somEdit_Suffix.Text)=0 then
          begin
            showmessage('Папка для вывода превью совпадает с папкой Оригиналов...'+LineEnding+'Суффикс надо добавить');
            Exit;
          end;
      ///

      CreatePreview;
      str:='process is completed';
      if ErrMessage then
        begin
          ErrStr:= 'есть проблемы..., возможно это:'+LineEnding+
                   ' - русские буквы в пути(названии)'+LineEnding+
                   ' - или что-то еще..';
        end;
    end;

/// CopyMetadataMode
  if somSpeedButton_CopyMetadataMode.Flat=false then
    begin
      /// проверки
      if not DirectoryExistsUTF8(somEdit_OriginalFolder.Text) then
        begin
          showmessage('Папка оригинальных файлов отсутствует');
          Exit;
        end;
      if somListBox_Files.Count=0 then
        begin
          showmessage('Превью надо добавить');
          Exit;
        end;
      ///

      CopyMetadata;
      str:='process is completed';
      if ErrMessage then
        begin
          ErrStr:= 'есть проблемы..., возможно это:'+LineEnding+
                   ' - русские буквы в пути(названии)'+LineEnding+
                   ' - Original-файл был изменен после изготовления Preview-файла'+LineEnding+
                   ' - или что-то еще..';
        end;
    end;

  str:=str+LineEnding+LineEnding+ErrStr;
  MessageBox(Self.Handle, PChar(UTF8ToSys(str)), PChar('Information'), MB_OK+MB_ICONINFORMATION);
  ErrMessage:= false;
end;



procedure Tsom_mForm.somSpeedButton_DeleteFileClick(Sender: TObject);
var
  n:integer;
begin
  if somListBox_Files.Count<>0 then
    if somListBox_Files.SelCount > 0 then
      begin
        n:=somListBox_Files.Items.IndexOf(somListBox_Files.GetSelectedText);
        somListBox_Files.Items.Delete(n);
        if somListBox_Files.Count>0 then
          if somListBox_Files.Count>n then
            somListBox_Files.Selected[n]:=true
          else
            if (somListBox_Files.Count=n) then
              somListBox_Files.Selected[n-1]:=true;
      end;
  UpdateMyF;
end;

procedure Tsom_mForm.somSpeedButton_LogClick(Sender: TObject);
begin
  if Height>minApp then Height:=minApp else Height:=maxApp;
end;




procedure Tsom_mForm.ReadSetting;
var
  ini : TIniFile;
begin
  ini:= TIniFile.Create(SysPath+'setting.ini');
  try
    somEdit_OriginalFolder.Text:= ini.ReadString('main','OriginalFolder','');
    somEdit_ToPreviewFolder.Text:= ini.ReadString('main','ToPreviewFolder','');
    somEdit_FromPreviewFolder.Text:= ini.ReadString('main','FromPreviewFolder','');
    somEdit_PreviewMaxSize.Text:=ini.ReadString('main','PreviewMaxSize','600');
    somEdit_Copyright.Text:=ini.ReadString('main','Copyright','');
    somCheckBox_PrwNameToOrig.Checked:=ini.ReadBool('main', 'PrwNameToOrig', false);
    somCheckBox_PrwTitleToOrigName.Checked:=ini.ReadBool('main', 'PrwTitleToOrigName', false);

    somEdit_Suffix.Text:= ini.ReadString('main','Suffix','');
  finally
    FreeAndNil(ini);
  end;
end;



procedure Tsom_mForm.WriteSetting;
var
  ini : TIniFile;
begin
  ini:= TIniFile.Create(SysPath+'setting.ini');
  try
    ini.WriteString('main','OriginalFolder',somEdit_OriginalFolder.Text);
    ini.WriteString('main','ToPreviewFolder',somEdit_ToPreviewFolder.Text);
    ini.WriteString('main','FromPreviewFolder',somEdit_FromPreviewFolder.Text);
    ini.WriteString('main','PreviewMaxSize',somEdit_PreviewMaxSize.Text);
    ini.WriteString('main','Copyright',somEdit_Copyright.Text);
    ini.WriteBool('main', 'PrwNameToOrig', somCheckBox_PrwNameToOrig.Checked);
    ini.WriteBool('main', 'PrwTitleToOrigName', somCheckBox_PrwTitleToOrigName.Checked);


    ini.WriteString('main','Suffix',somEdit_Suffix.Text);
  finally
    FreeAndNil(ini);
  end;
end;


procedure Tsom_mForm.EnabledOff;
var
  i: integer;
begin
  somSpeedButton_CreatePreviewMode.Flat:=true;
  somSpeedButton_CopyMetadataMode.Flat:=true;

  for i:=0 to som_mForm.ControlCount-1 do
    if som_mForm.Controls[i].Tag<>12345 then
    som_mForm.Controls[i].Enabled:=false;
end;
procedure Tsom_mForm.EnabledOn;
var
  i: integer;
begin
  for i:=0 to som_mForm.ControlCount-1 do
    som_mForm.Controls[i].Enabled:=true;
end;


procedure Tsom_mForm.UnColorAll;
begin
  somEdit_OriginalFolder.Color:=clSilver;    //clSilver  clMTDmode  clPRWmode
  somEdit_ToPreviewFolder.Color:=clSilver;
  somEdit_FromPreviewFolder.Color:=clSilver;
  somListBox_Files.Color:=clSilver;
  somEdit_PreviewMaxSize.Color:=clSilver;
  somEdit_Suffix.Color:=clSilver;
end;





procedure Tsom_mForm.FormCreate(Sender: TObject);
begin
  Application.HintPause:= 50;
  Application.HintHidePause:=10240;
  SysPath:= ExtractFilePath(ParamStr(0))+'sys\';
  maxApp:=690;
  minApp:=520;
  Height:=minApp;
  ReadSetting;
   clPRWmode:= RGBToColor(200, 185, 169);
   clMTDmode:= RGBToColor(174, 192, 176);

  EnabledOff;
  ErrMessage:=false;


  somListBox_Files.Canvas.Brush.Color:=clRed;
end;


///////////////////////////////////////
// DragDrop files
procedure Tsom_mForm.FormDropFiles(Sender: TObject;
  const FileNames: array of String);
var
  i: Integer;
  p: TPoint;
  somEdit: TEdit;
begin
  GetCursorPos(p);
///
  if somListBox_Files.Enabled then
    begin
      if FindDragTarget(p, True) is TListbox then   // drop to Listbox
        begin
          for i := Low(FileNames) to High(FileNames) do
            if (ExtractFileExt(FileNames[i])='.jpg') or
               (ExtractFileExt(FileNames[i])='.JPG') then
              begin
                somListBox_Files.Items.Add(FileNames[i]);
                AddToLog('file_Added: "'+ExtractFileName(FileNames[i])+'"');
              end
            else
              begin
                AddToLog('file_Not_Added: "'+ExtractFileName(FileNames[i])+'"');
              end;
          UpdateMyF;
        end;
    end;
///
  if (FindDragTarget(p, True) is TEdit) and (Length(FileNames)=1) then   // drop to TEdit
    begin
      somEdit:= (FindDragTarget(p, True) as TEdit);
      if somEdit.HelpKeyword='pathName' then
        if DirectoryExistsUTF8(FileNames[0]) then somEdit.Text:=FileNames[0];
    end;
  ErrMessage:=false;
end;

procedure Tsom_mForm.somCheckBox_PrwNameToOrigChange(Sender: TObject);
begin
 if somCheckBox_PrwNameToOrig.Checked then somCheckBox_PrwTitleToOrigName.Checked:=false;
end;

procedure Tsom_mForm.somCheckBox_PrwTitleToOrigNameChange(Sender: TObject);
begin
 if somCheckBox_PrwTitleToOrigName.Checked then somCheckBox_PrwNameToOrig.Checked:=false;
end;

// DragDrop files
///////////////////////////////////////


procedure Tsom_mForm.UpdateMyF;   /// Update File List
var
  i: integer;
  MyListBox: TListBox;
begin
  MyListBox:=somListBox_Files;
  if MyListBox.Count<>0 then
    begin
      setlength(myF,0);
      setlength(myF,MyListBox.Count);
      for i:=0 to Length(myF)-1 do
        begin
          if FileExistsUTF8(MyListBox.Items.Strings[i]) then
            begin
              myF[i].fullFileName:= MyListBox.Items.Strings[i];
              myF[i].FileNamePath:= ExtractFilePath(MyListBox.Items.Strings[i]);
              myF[i].FileName:=ExtractFileName(MyListBox.Items.Strings[i]);
              myF[i].FileNameNoExt:= ChangeFileExt(ExtractFileName(MyListBox.Items.Strings[i]),'');
              if somSpeedButton_CreatePreviewMode.Flat=false then somEdit_OriginalFolder.Text:=myF[i].FileNamePath;
              if somSpeedButton_CopyMetadataMode.Flat=false then somEdit_FromPreviewFolder.Text:=myF[i].FileNamePath;
            end
          else
            begin
              myF[i].fullFileName:= '';
              myF[i].FileNamePath:='';
              myF[i].FileName:='';
              myF[i].FileNameNoExt:='';
            end;
        end;
      MyListBox.Selected[0]:=true;
    end;
  somLabel_FilesCount.Caption:='('+IntToStr(MyListBox.Count)+')';
end;

procedure Tsom_mForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  WriteSetting;
end;


procedure Tsom_mForm.somGroupBox_FromOutsourceClick(Sender: TObject);
begin
  somEdit_OriginalFolder.Enabled:=true;
  somEdit_ToPreviewFolder.Enabled:=false;
  somEdit_FromPreviewFolder.Enabled:=true;
end;



end.

