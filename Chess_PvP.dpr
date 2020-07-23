program Chess_PvP;

uses
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {Form1},
  ReplacePawnUnit in 'ReplacePawnUnit.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
