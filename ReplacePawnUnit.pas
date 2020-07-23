unit ReplacePawnUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, MainUnit;

type
  TForm2 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;
  Choice:TPieceType;

implementation

{$R *.dfm}

// Окно с выбором, во что превратится пешка
procedure TForm2.Button1Click(Sender: TObject);
begin
 Choice:=ptQueen;
end;

procedure TForm2.Button2Click(Sender: TObject);
begin
 Choice:=ptRook;
end;

procedure TForm2.Button3Click(Sender: TObject);
begin
 Choice:=ptBishop;
end;

procedure TForm2.Button4Click(Sender: TObject);
begin
 Choice:=ptKnight;
end;

end.
