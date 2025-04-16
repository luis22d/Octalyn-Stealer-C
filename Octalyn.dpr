program Octalyn;

{$R *.dres}

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Light');
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
