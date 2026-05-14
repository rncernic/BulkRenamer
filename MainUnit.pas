{*******************************************************************************
  Unit:        MainUnit
  Project:     Bulk File Renamer
  Description: Main form unit for a Lazarus / Free Pascal bulk file renaming
               utility. The user picks a folder, optionally filters files by
               mask, then applies a configurable pipeline of transformations
               (trim, find/replace, between-delimiters removal, prefix/suffix,
               numbering) to produce new names. A preview is shown before
               anything is committed to disk.

  Compiler:    Free Pascal (mode objfpc)
  Framework:   Lazarus LCL

  DISCLAIMER:  Documentation generated using Antropic's Clause Opus 4.7
*******************************************************************************}

unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Buttons, Spin, FileUtil, LazFileUtils, LCLType,
  UAboutBox;

type

  { TfrmMain
    ----------
    Main application form. Holds all UI controls, the list of source file
    paths (FOriginalNames) and the logic that builds preview names and
    performs the actual rename on disk. }
  TfrmMain = class(TForm)
    // ---- Action buttons ----
    btnBrowse: TButton;        // Opens the folder picker
    btnFilterFiles: TButton;   // Re-scans folder using the current mask/options
    btnPreview: TButton;       // Recomputes the "New name" column
    btnRename: TButton;        // Commits the rename to disk

    // ---- Scan / scope options ----
    chkIncludeExt: TCheckBox;    // If true, transformations also see the extension
    chkRecursive: TCheckBox;     // Recurse into subfolders
    chkOnlyFiles: TCheckBox;     // Exclude directories from the listing
    chkCaseSensitive: TCheckBox; // Case sensitivity for Find & Replace

    // ---- Numbering options ----
    chkUseNumber: TCheckBox;     // Enable numbering insertion

    // ---- Trim options ----
    chkTrimStartChars: TCheckBox; // Trim N characters from the start
    chkTrimEndChars: TCheckBox;   // Trim N characters from the end
    chkTrimStartDelim: TCheckBox; // Trim up to a delimiter from the start
    chkTrimEndDelim: TCheckBox;   // Trim from a delimiter to the end
    chkTrimStartLast: TCheckBox;  // Use last occurrence of start delimiter
    chkTrimEndLast: TCheckBox;    // Use last occurrence of end delimiter

    // ---- Between-delimiters options ----
    chkBetweenEnable: TCheckBox;     // Enable the between-delimiters operation
    chkBetweenKeepDelims: TCheckBox; // Keep the delimiters, only replace inner part
    chkBetweenFirstOnly: TCheckBox;  // Apply only to the first match

    // ---- Combo / edit / spin controls ----
    cmbNumPosition: TComboBox;  // 0 = number as prefix, 1 = number as suffix
    edtFolder: TEdit;           // Source folder path
    edtFind: TEdit;             // Find string
    edtReplace: TEdit;          // Replace string
    edtPrefix: TEdit;           // Prefix to prepend
    edtSuffix: TEdit;           // Suffix to append
    edtFilter: TEdit;           // File mask (e.g. *.jpg)
    edtNumberSep: TEdit;        // Separator between number and name (e.g. "_")
    edtTrimStartDelim: TEdit;   // Delimiter for "trim from start"
    edtTrimEndDelim: TEdit;     // Delimiter for "trim from end"
    edtBetweenOpen: TEdit;      // Opening delimiter for between-removal
    edtBetweenClose: TEdit;     // Closing delimiter for between-removal
    edtBetweenReplace: TEdit;   // Replacement text for the matched section

    // ---- Group boxes (visual grouping in the UI) ----
    grpFolder: TGroupBox;
    grpFind: TGroupBox;
    grpPrefixSuffix: TGroupBox;
    grpNumbering: TGroupBox;
    grpTrim: TGroupBox;
    grpBetween: TGroupBox;

    // ---- Static labels ----
    lblFind: TLabel;
    lblReplace: TLabel;
    lblPrefix: TLabel;
    lblSuffix: TLabel;
    lblStart: TLabel;
    lblPadding: TLabel;
    lblPosition: TLabel;
    lblSep: TLabel;
    lblStatus: TLabel;             // Status bar text at the bottom
    lblTrimStartCount: TLabel;
    lblTrimEndCount: TLabel;
    lblBetweenOpen: TLabel;
    lblBetweenClose: TLabel;
    lblBetweenReplace: TLabel;

    // ---- File listing ----
    lvFiles: TListView; // Three columns: Original name | New name | Status

    // ---- Layout panels ----
    pnlFileList: TPanel;
    pnlApply: TPanel;
    pnlNumbering: TPanel;
    pnlPrefixSuffix: TPanel;
    pnlFindNReplace: TPanel;
    pnlTrim: TPanel;
    pnlFolder: TPanel;

    SelectDirectoryDialog: TSelectDirectoryDialog; // Folder picker dialog
    spbAbout: TSpeedButton;                        // "About" button

    // ---- Spin edits ----
    spnStart: TSpinEdit;          // Starting number for numbering
    spnPadding: TSpinEdit;        // Zero-padding width for numbering
    spnTrimStartCount: TSpinEdit; // How many chars to trim from start
    spnTrimEndCount: TSpinEdit;   // How many chars to trim from end

    // ---- Event handlers ----
    procedure btnBrowseClick(Sender: TObject);
    procedure btnFilterFilesClick(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnRenameClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure spbAboutClick(Sender: TObject);

  private
    { FOriginalNames
      Holds the *full* paths of every source item currently shown in lvFiles.
      The index in this list corresponds one-to-one with the index of the
      matching row in the list view. After a successful rename the entry
      is updated to the new full path so the user can chain operations. }
    FOriginalNames: TStringList;

    { BuildNewName
      Applies the full transformation pipeline to a single file name and
      returns the resulting target name (including extension when relevant).
      Index is the file's zero-based position in FOriginalNames and is used
      to compute the per-file sequence number. }
    function BuildNewName(const OrigFileName: string; Index: Integer): string;

    { RefreshPreview
      Recomputes the "New name" and "Status" columns for every row based on
      the current control values. Also flags empty results and duplicates. }
    procedure RefreshPreview;

  public

  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

uses
  StrUtils;

{ ============================================================================
  Helpers
  ============================================================================ }

{ RemoveBetween
  --------------
  Remove (or replace) the substring that sits between an opening and a closing
  delimiter inside S. The delimiters can each be more than one character and
  may differ from each other (e.g. "[" / "]", "<<" / ">>", "BEGIN" / "END").

  Parameters:
    S            : the input string
    OpenDelim    : opening delimiter to look for
    CloseDelim   : closing delimiter that must appear *after* OpenDelim
    IncludeDelims: True  -> the delimiters themselves are removed together
                            with the inner content, replaced by Replacement
                   False -> the delimiters are kept; only the inner content
                            is replaced by Replacement
    FirstOnly    : True  -> stop after the first match
                   False -> process every match found
    Replacement  : text that takes the place of the matched section
                   (or just the inner content, depending on IncludeDelims)

  Behavior notes:
    * If either delimiter is empty, the input is returned unchanged.
    * Unmatched openers (no closing delimiter after them) terminate the loop
      and the remainder of the string is appended untouched.
    * The function never raises on bad input; worst case it returns S as-is. }
function RemoveBetween(const S, OpenDelim, CloseDelim: string;
  IncludeDelims, FirstOnly: Boolean; const Replacement: string): string;
var
  P1, P2: Integer;
  Work, Acc: string;
begin
  Result := S;
  if (OpenDelim = '') or (CloseDelim = '') then Exit;

  Work := S;   // remaining text still to be scanned
  Acc := '';   // accumulator of the rebuilt string

  while True do
  begin
    // Look for the next opening delimiter
    P1 := Pos(OpenDelim, Work);
    if P1 = 0 then
    begin
      // No more matches -> keep the rest of Work as-is
      Acc := Acc + Work;
      Break;
    end;

    // Look for a closing delimiter strictly after the opener
    P2 := PosEx(CloseDelim, Work, P1 + Length(OpenDelim));
    if P2 = 0 then
    begin
      // Opener without a matching closer -> bail out, keep remainder
      Acc := Acc + Work;
      Break;
    end;

    // Everything before the opener is preserved verbatim
    Acc := Acc + Copy(Work, 1, P1 - 1);

    // Then either drop the whole "open..close" span or keep the delimiters
    if IncludeDelims then
      Acc := Acc + Replacement
    else
      Acc := Acc + OpenDelim + Replacement + CloseDelim;

    // Advance past the closing delimiter for the next iteration
    Work := Copy(Work, P2 + Length(CloseDelim), MaxInt);

    if FirstOnly then
    begin
      Acc := Acc + Work;
      Break;
    end;
  end;

  Result := Acc;
end;

{ ============================================================================
  TfrmMain
  ============================================================================ }

{ FormCreate
  -----------
  One-time form initialization: creates FOriginalNames, sets the window
  caption from the version history declared in UAboutBox, populates the
  numbering-position combo, sets sane defaults for the spin edits and the
  filter, and prepares the three columns of lvFiles. }
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FOriginalNames := TStringList.Create;

  // Window title shows app name + current version + release date
  frmMain.Caption := APPLICATION_NAME + ' v. ' + VERSION_HISTORY[0].Version +
                     ' (' + VERSION_HISTORY[0].Date + ')';

  // Numbering position combo: 0 = prefix, 1 = suffix
  cmbNumPosition.Items.Clear;
  cmbNumPosition.Items.Add('Prefix (before name)');
  cmbNumPosition.Items.Add('Suffix (after name)');
  cmbNumPosition.ItemIndex := 1;

  // Sensible defaults
  edtFilter.Text := '*';
  edtNumberSep.Text := '_';
  spnStart.Value := 1;
  spnPadding.Value := 3;
  spnTrimStartCount.Value := 0;
  spnTrimEndCount.Value := 0;

  // Build the listview columns programmatically so they always exist
  // even if the .lfm file is missing them.
  lvFiles.Columns.Clear;
  with lvFiles.Columns.Add do
  begin
    Caption := 'Original name';
    Width := 320;
  end;
  with lvFiles.Columns.Add do
  begin
    Caption := 'New name';
    Width := 320;
  end;
  with lvFiles.Columns.Add do
  begin
    Caption := 'Status';
    Width := 100;
  end;
  lvFiles.ViewStyle := vsReport;
  lblStatus.Caption := 'Ready.';
end;

{ spbAboutClick
  --------------
  Show the About box defined in UAboutBox. }
procedure TfrmMain.spbAboutClick(Sender: TObject);
begin
  ShowAboutBox;
end;

{ btnBrowseClick
  ---------------
  Open the folder picker. If the user accepts, copy the chosen path into
  the folder edit and re-scan it immediately so the listview reflects the
  newly selected folder without an extra click. }
procedure TfrmMain.btnBrowseClick(Sender: TObject);
begin
  if SelectDirectoryDialog.Execute then
  begin
    edtFolder.Text := SelectDirectoryDialog.FileName;
    btnFilterFilesClick(nil);
  end;
end;

{ btnFilterFilesClick
  --------------------
  (Re)scan the configured folder using the current mask and the
  recursive / only-files options. Populates both FOriginalNames and the
  list view, then calls RefreshPreview so the "New name" column is filled
  in for the freshly loaded items. }
procedure TfrmMain.btnFilterFilesClick(Sender: TObject);
var
  Dir, Mask: string;
  Found: TStringList;
  i: Integer;
begin
  Dir := Trim(edtFolder.Text);
  if (Dir = '') or (not DirectoryExists(Dir)) then
  begin
    ShowMessage('Please select a valid folder.');
    Exit;
  end;

  Mask := Trim(edtFilter.Text);
  if Mask = '' then Mask := '*';

  FOriginalNames.Clear;
  lvFiles.Items.BeginUpdate;
  try
    lvFiles.Items.Clear;

    // FindAllFiles is provided by FileUtil; it walks the directory tree
    // (optionally recursing) and returns matching paths.
    Found := FindAllFiles(Dir, Mask, chkRecursive.Checked);
    try
      Found.Sort;
      for i := 0 to Found.Count - 1 do
      begin
        // Skip subdirectories when the user only wants files
        if chkOnlyFiles.Checked and DirectoryExists(Found[i]) then Continue;

        FOriginalNames.Add(Found[i]);
        with lvFiles.Items.Add do
        begin
          Caption := ExtractFileName(Found[i]);
          SubItems.Add(''); // new name (filled by RefreshPreview)
          SubItems.Add(''); // status   (filled by RefreshPreview)
        end;
      end;
    finally
      Found.Free;
    end;
  finally
    lvFiles.Items.EndUpdate;
  end;

  lblStatus.Caption := Format('%d items loaded.', [FOriginalNames.Count]);
  RefreshPreview;
end;

{ BuildNewName
  -------------
  Apply the full transformation pipeline to a single file name.

  Pipeline (executed in order):
    0. Split the input into NameOnly + Ext.
       If chkIncludeExt is checked, the extension is folded into the
       working string and reset to '' so it isn't re-appended at the end
       -- in that mode every transformation also sees the extension.
    1. Trim N characters from the start.
    2. Trim N characters from the end.
    3. Trim up to (and including) a delimiter at the start, optionally
       using the LAST occurrence instead of the first.
    4. Trim from a delimiter to the end, optionally using the LAST
       occurrence instead of the first.
    5. Find & Replace, with optional case sensitivity. Always replaces
       every occurrence (rfReplaceAll).
    6. Remove / replace text between two delimiters (see RemoveBetween).
    7. Add prefix and suffix.
    8. Insert a zero-padded sequence number, either as prefix or as
       suffix, separated by edtNumberSep.

  Returns the full target filename (with extension if not folded in). }
function TfrmMain.BuildNewName(const OrigFileName: string; Index: Integer): string;
var
  NameOnly, Ext, Working, NumStr, Sep: string;
  FindStr, ReplStr: string;
  Flags: TReplaceFlags;
  N, P: Integer;
  Delim: string;
begin
  // ---- Step 0: separate base name from extension --------------------------
  Ext := ExtractFileExt(OrigFileName);
  NameOnly := ExtractFileName(OrigFileName);
  if Ext <> '' then
    NameOnly := Copy(NameOnly, 1, Length(NameOnly) - Length(Ext));

  if chkIncludeExt.Checked then
  begin
    // Treat the extension as part of the editable name
    Working := ExtractFileName(OrigFileName);
    Ext := '';
  end
  else
    Working := NameOnly;

  // ---- Step 1: trim from start by character count -------------------------
  if chkTrimStartChars.Checked then
  begin
    N := spnTrimStartCount.Value;
    if N > 0 then
    begin
      if N >= Length(Working) then
        Working := ''
      else
        Working := Copy(Working, N + 1, MaxInt);
    end;
  end;

  // ---- Step 2: trim from end by character count ---------------------------
  if chkTrimEndChars.Checked then
  begin
    N := spnTrimEndCount.Value;
    if N > 0 then
    begin
      if N >= Length(Working) then
        Working := ''
      else
        Working := Copy(Working, 1, Length(Working) - N);
    end;
  end;

  // ---- Step 3: trim from start up to a delimiter --------------------------
  // Removes everything up to AND INCLUDING the chosen delimiter.
  if chkTrimStartDelim.Checked then
  begin
    Delim := edtTrimStartDelim.Text;
    if Delim <> '' then
    begin
      if chkTrimStartLast.Checked then
        P := RPos(Delim, Working)   // last occurrence
      else
        P := Pos(Delim, Working);   // first occurrence
      if P > 0 then
        Working := Copy(Working, P + Length(Delim), MaxInt);
    end;
  end;

  // ---- Step 4: trim from a delimiter to the end ---------------------------
  // Removes the delimiter and everything after it.
  if chkTrimEndDelim.Checked then
  begin
    Delim := edtTrimEndDelim.Text;
    if Delim <> '' then
    begin
      if chkTrimEndLast.Checked then
        P := RPos(Delim, Working)   // last occurrence
      else
        P := Pos(Delim, Working);   // first occurrence
      if P > 0 then
        Working := Copy(Working, 1, P - 1);
    end;
  end;

  // ---- Step 5: find & replace ---------------------------------------------
  FindStr := edtFind.Text;
  ReplStr := edtReplace.Text;
  if FindStr <> '' then
  begin
    Flags := [rfReplaceAll];
    if not chkCaseSensitive.Checked then
      Include(Flags, rfIgnoreCase);
    Working := StringReplace(Working, FindStr, ReplStr, Flags);
  end;

  // ---- Step 6: between-delimiters removal/replacement ---------------------
  if chkBetweenEnable.Checked then
  begin
    Working := RemoveBetween(
      Working,
      edtBetweenOpen.Text,
      edtBetweenClose.Text,
      not chkBetweenKeepDelims.Checked, // IncludeDelims = NOT KeepDelims
      chkBetweenFirstOnly.Checked,
      edtBetweenReplace.Text);
  end;

  // ---- Step 7: prefix / suffix --------------------------------------------
  Working := edtPrefix.Text + Working + edtSuffix.Text;

  // ---- Step 8: numbering --------------------------------------------------
  if chkUseNumber.Checked then
  begin
    // Compute the per-file integer and pad it with leading zeros
    NumStr := IntToStr(spnStart.Value + Index);
    while Length(NumStr) < spnPadding.Value do
      NumStr := '0' + NumStr;

    Sep := edtNumberSep.Text;
    case cmbNumPosition.ItemIndex of
      0: Working := NumStr + Sep + Working;  // before the name
      1: Working := Working + Sep + NumStr;  // after the name
    end;
  end;

  // Re-attach extension (empty when chkIncludeExt was set)
  Result := Working + Ext;
end;

{ RefreshPreview
  ---------------
  Recompute the "New name" and "Status" columns for every row.

  Status values:
    'EMPTY!'      -> transformation produced an empty filename
    'unchanged'   -> new name matches the original
    'DUPLICATE'   -> another row in the current batch produces the same name
    'will rename' -> safe to rename

  Duplicate detection is case-insensitive (Windows-friendly) and operates
  only within the current batch -- it does not check files already on disk
  outside this list. }
procedure TfrmMain.RefreshPreview;
var
  i: Integer;
  NewName: string;
  SeenNames: TStringList;
begin
  if FOriginalNames.Count = 0 then Exit;

  SeenNames := TStringList.Create;
  try
    SeenNames.Sorted := True;
    SeenNames.Duplicates := dupIgnore; // silently ignore re-adds
    SeenNames.CaseSensitive := False;

    lvFiles.Items.BeginUpdate;
    try
      for i := 0 to FOriginalNames.Count - 1 do
      begin
        NewName := BuildNewName(FOriginalNames[i], i);
        lvFiles.Items[i].SubItems[0] := NewName;

        if NewName = '' then
          lvFiles.Items[i].SubItems[1] := 'EMPTY!'
        else if NewName = ExtractFileName(FOriginalNames[i]) then
          lvFiles.Items[i].SubItems[1] := 'unchanged'
        else if SeenNames.IndexOf(NewName) >= 0 then
          lvFiles.Items[i].SubItems[1] := 'DUPLICATE'
        else
          lvFiles.Items[i].SubItems[1] := 'will rename';

        SeenNames.Add(NewName);
      end;
    finally
      lvFiles.Items.EndUpdate;
    end;
  finally
    SeenNames.Free;
  end;
end;

{ btnPreviewClick
  ----------------
  User-facing wrapper around RefreshPreview that also updates the status bar
  to remind the user to verify before committing. }
procedure TfrmMain.btnPreviewClick(Sender: TObject);
begin
  RefreshPreview;
  lblStatus.Caption :=
    'Preview updated. Review the "New name" column before renaming.';
end;

{ btnRenameClick
  ---------------
  Commit the rename to disk.

  Steps:
    1. Force a fresh preview so the column values match the current options.
    2. Scan for problematic rows (EMPTY! / DUPLICATE) and ask the user to
       confirm proceeding while skipping those rows.
    3. Ask for a final confirmation showing the total count.
    4. For each row:
         - skip if target is empty, unchanged, duplicate, or already exists
         - otherwise call RenameFileUTF8 and update the row's status
    5. Update FOriginalNames with the new full path on success, so chained
       operations on the same listing keep working.
    6. Show a summary in the status bar. }
procedure TfrmMain.btnRenameClick(Sender: TObject);
var
  i, OkCount, FailCount, SkipCount: Integer;
  OldFull, NewFull, NewName, Dir: string;
  HasDup, HasEmpty: Boolean;
begin
  if FOriginalNames.Count = 0 then
  begin
    ShowMessage('No files loaded.');
    Exit;
  end;

  RefreshPreview;

  // Pre-flight: see if there are any rows that need user acknowledgement
  HasDup := False;
  HasEmpty := False;
  for i := 0 to lvFiles.Items.Count - 1 do
  begin
    if lvFiles.Items[i].SubItems[1] = 'DUPLICATE' then HasDup := True;
    if lvFiles.Items[i].SubItems[1] = 'EMPTY!' then HasEmpty := True;
  end;

  if HasEmpty then
    if MessageDlg('Some target names are empty. They will be skipped. Continue?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  if HasDup then
    if MessageDlg('Some target names are duplicates. Duplicates will be skipped. Continue?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  if MessageDlg(Format('Rename %d items?', [FOriginalNames.Count]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  OkCount := 0;
  FailCount := 0;
  SkipCount := 0;

  lvFiles.Items.BeginUpdate;
  try
    for i := 0 to FOriginalNames.Count - 1 do
    begin
      OldFull := FOriginalNames[i];
      NewName := lvFiles.Items[i].SubItems[0];
      Dir := ExtractFilePath(OldFull);
      NewFull := Dir + NewName;

      // Skip if the new name is empty or identical to the old one
      if (NewName = '') or (NewName = ExtractFileName(OldFull)) then
      begin
        lvFiles.Items[i].SubItems[1] := 'skipped';
        Inc(SkipCount);
        Continue;
      end;

      // Skip duplicates flagged by RefreshPreview
      if lvFiles.Items[i].SubItems[1] = 'DUPLICATE' then
      begin
        lvFiles.Items[i].SubItems[1] := 'skipped (dup)';
        Inc(SkipCount);
        Continue;
      end;

      // Don't overwrite an existing file or directory on disk
      if FileExists(NewFull) or DirectoryExists(NewFull) then
      begin
        lvFiles.Items[i].SubItems[1] := 'exists - skipped';
        Inc(SkipCount);
        Continue;
      end;

      // RenameFileUTF8 handles non-ASCII paths correctly on every platform
      if RenameFileUTF8(OldFull, NewFull) then
      begin
        lvFiles.Items[i].SubItems[1] := 'renamed';
        // Keep FOriginalNames in sync so further passes operate on the new path
        FOriginalNames[i] := NewFull;
        lvFiles.Items[i].Caption := NewName;
        Inc(OkCount);
      end
      else
      begin
        lvFiles.Items[i].SubItems[1] := 'FAILED';
        Inc(FailCount);
      end;
    end;
  finally
    lvFiles.Items.EndUpdate;
  end;

  lblStatus.Caption := Format('Done. Renamed: %d, Skipped: %d, Failed: %d',
    [OkCount, SkipCount, FailCount]);
end;

end.
