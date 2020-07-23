unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TPieceType=(ptPawn,ptKnight,ptBishop,ptRook,ptQueen,ptKing);
  TSide=(sBlack,sWhite);

  TDirection=(dLeftDown,dLeft,dLeftUp,dUp,dRightUp,dRight,dRightDown,dDown,dInvalid);

  TPiece=class // Абстрактный класс фигурки для наследования
   protected
    fX,fY:Integer;
    fOX,fOY:Integer;
    fPT:TPieceType;
    fS:TSide;
    fWM:Boolean;
    function fOriginalPosition:Boolean;
   published
    property X:Integer read fX;
    property Y:Integer read fY;
    property PieceType:TPieceType read fPT;
    property Side:TSide read fS;
    property WasMoved:Boolean read fWM write fWM;
    property OriginalPosition:Boolean read fOriginalPosition;
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; virtual; abstract;
    function Capture(X,Y:Integer;Stay:Boolean=False):Boolean;
    function Teleport(X,Y:Integer;Stay:Boolean=False):Boolean;
    constructor Create(X,Y:Integer;PT:TPieceType;Side:TSide);
  end;

  TTurnState=record // Информация о том, чей ход, и держит ли игрок фигурку в руках. Если держит, то ссылку на эту фигурку.
   HoldingPiece,White:Boolean;
   HeldPiece:TPiece;
  end;

  TPawn=class(TPiece) // Пешка
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide;Revived:Boolean=False);
  end;

  TKnight=class(TPiece) // Конь
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide);
  end;

  TBishop=class(TPiece) // Слон
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide);
  end;

  TRook=class(TPiece) // Ладья
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide);
  end;

  TQueen=class(TPiece) // Ферзь
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide);
  end;

  TKing=class(TPiece) // Король
   published
    function Move(X,Y:Integer;Stay:Boolean=False):Boolean; override;
    constructor Create(X,Y:Integer;Side:TSide);
  end;

  TForm1 = class(TForm)
    B_Restart: TButton;
    L_Side: TLabel;
    L_Check: TLabel;
    L_Notify: TLabel;
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure B_RestartClick(Sender: TObject);
  private
    { Private declarations }
  public
    procedure InitChess;
    procedure FieldClick(X,Y:Integer);
  end;

  TLastCapturedPiece=record // Информация о последней "съеденной" фигурке
   X,Y:Integer;
   Side:TSide;
   PieceType:TPieceType;
   WasCapturedRightNow:Boolean;
  end;

const
  CELL_SIZE=40; // Ширина клетки в пикселях

var
  Form1: TForm1;
  Pieces:array of TPiece;
  TurnState:TTurnState;
  LastCapturedPiece:TLastCapturedPiece;
  LastTurnCheck:Boolean;


implementation
uses ReplacePawnUnit;

{$R *.dfm}

procedure ShowMsg(caption,msg:String;uType:Cardinal=MB_OK or MB_ICONINFORMATION); // Вывод сообщения отдельным окном. Не используется.
begin
 MessageBox(Form1.Handle,PWideChar(msg),PWideChar(caption),uType);
end;

procedure AlertMsg(caption,msg:String); // Вывод сообщения под игровым полем
begin
 //ShowMsg(caption,msg,MB_OK or MB_ICONWARNING);
 Form1.L_Notify.Caption:=msg;
end;

function GetDirection(OX,OY,NX,NY:Integer):TDirection; // Определение направления по двум точкам
var
 xc,yc:ShortInt;
begin
 if OX=NX then xc:=0
 else if OX>NX then xc:=1
 else if OX<NX then xc:=-1;
 if OY=NY then yc:=0
 else if OY>NY then yc:=1
 else if OY<NY then yc:=-1;
 Result:=dInvalid;
 if xc=1 then
  begin
   case yc of
    0: Result:=dLeft;
    1: if (OX-NX)=(OY-NY) then Result:=dLeftUp;
    -1: if (OX-NX)=(NY-OY) then Result:=dLeftDown;
   end;
  end
 else if xc=-1 then
  begin
   case yc of
    0: Result:=dRight;
    1: if (NX-OX)=(OY-NY) then Result:=dRightUp;
    -1: if (NX-OX)=(NY-OY) then Result:=dRightDown;
   end;
  end
 else if xc=0 then
  begin
   case yc of
    0: Result:=dInvalid;
    1: Result:=dUp;
    -1: Result:=dDown;
   end;
  end;
end;

procedure InvertDirection(var Direction:TDirection); // Инвертировать направление
begin
 case Direction of
  dLeftDown: Direction:=dRightUp;
  dLeft: Direction:=dRight;
  dLeftUp: Direction:=dRightDown;
  dUp: Direction:=dDown;
  dRightUp: Direction:=dLeftDown;
  dRight: Direction:=dLeft;
  dRightDown: Direction:=dLeftUp;
  dDown: Direction:=dUp;
 end;
end;

function GetDistance(OX,OY,NX,NY:Integer):Integer; // Определение дистанции в клеточках между двумя точками
var
 dx,dy:Integer;
begin
 dx:=abs(NX-OX);
 dy:=abs(NY-OY);
 if dx=0 then
  Result:=dy
 else
  begin
   Result:=dx;
   if (dy<>0) and (dy<>dx) then Result:=0;
  end;
end;

function IsThereAPiece(X,Y:Integer;var Piece:TPiece):Boolean; // Определяет, есть ли фигурка в указанной клеточке
// Для этого выполняется поиск по всем фигуркам, так как технически никакого поля нет
var
 i,L:Integer;
begin
 Result:=False;
 Piece:=nil;
 L:=Length(Pieces);
 if L>0 then
  for i := 0 to L-1 do
   if Assigned(Pieces[i]) then
    if (Pieces[i].X=X) and
       (Pieces[i].Y=Y) then
        begin
         Piece:=Pieces[i];
         Result:=True;
         Exit;
        end;
end;

function DestroyPiece(X,Y:Integer):Boolean; // Уничтожает фигурку в указанной клеточке
var
 i,L:Integer;
begin
 Result:=False;
 L:=Length(Pieces);
 if L>0 then
  for i := 0 to L-1 do
   if Assigned(Pieces[i]) then
    if (Pieces[i].X=X) and
       (Pieces[i].Y=Y) then
        begin
         FreeAndNil(Pieces[i]);
         Result:=True;
         Exit;
        end;
end;

procedure DestroyAllPieces; // Уничтожает все фигурки
var
 i,L:Integer;
begin
 L:=Length(Pieces);
 if L>0 then
  for i := 0 to L-1 do
   if Assigned(Pieces[i]) then
    FreeAndNil(Pieces[i]);
end;

function ReplacePawn(X,Y:Integer;NewType:TPieceType):Boolean; // Превращение пешки в указанной клеточке
var
 i,L:Integer;
 oS:TSide;
begin
 Result:=False;
 L:=Length(Pieces);
 if L>0 then
  for i := 0 to L-1 do
   if Assigned(Pieces[i]) then
    if (Pieces[i].X=X) and
       (Pieces[i].Y=Y) then
       if Pieces[i].PieceType=ptPawn then
        begin
         oS:=Pieces[i].Side;
         FreeAndNil(Pieces[i]);
         case NewType of
           ptKnight:
            Pieces[i]:=TKnight.Create(X,Y,oS);
           ptBishop:
            Pieces[i]:=TBishop.Create(X,Y,oS);
           ptRook:
            Pieces[i]:=TRook.Create(X,Y,oS);
           ptQueen:
            Pieces[i]:=TQueen.Create(X,Y,oS);
         end;
         Result:=Assigned(Pieces[i]);
         Exit;
        end;
end;

procedure ReviveCapturedPiece(X,Y:Integer;PT:TPieceType;Side:TSide); // Воскрешение фигурок для отката хода
var
 i,L:Integer;
begin
 L:=Length(Pieces);
 if L>0 then
  for i := 0 to L-1 do
   if not Assigned(Pieces[i]) then
    case PT of
      ptPawn: Pieces[i]:=TPawn.Create(X,Y,Side,True);
      ptKnight: Pieces[i]:=TKnight.Create(X,Y,Side);
      ptBishop: Pieces[i]:=TBishop.Create(X,Y,Side);
      ptRook: Pieces[i]:=TRook.Create(X,Y,Side);
      ptQueen: Pieces[i]:=TQueen.Create(X,Y,Side);
      ptKing: Pieces[i]:=TKing.Create(X,Y,Side);
    end;
end;

function IsThereAPiecesOnTheWay(OX,OY:Integer;Direction:TDirection;Distance:Integer):Boolean; // Задаётся начальная позиция, направление и дистанция. Показывает, есть ли на пути фигурки
var
 i:Integer;
 tmp:TPiece;
 bd:TDirection;
begin
 Result:=False;
 bd:=Direction;
 if not TurnState.White then InvertDirection(bd);
 if (Distance>0) and (bd<>dInvalid) then
  for i := 1 to Distance do
   begin
    case bd of
      dLeftDown:
       begin
        OX:=OX-1;
        OY:=OY+1;
       end;
      dLeft: OX:=OX-1;
      dLeftUp:
       begin
        OX:=OX-1;
        OY:=OY-1;
       end;
      dUp: OY:=OY-1;
      dRightUp:
       begin
        OX:=OX+1;
        OY:=OY-1;
       end;
      dRight: OX:=OX+1;
      dRightDown:
       begin
        OX:=OX+1;
        OY:=OY+1;
       end;
      dDown: OY:=OY+1;
    end;
    if IsThereAPiece(OX,OY,tmp) then
     begin
      Result:=True;
      Exit;
     end;
   end;
end;

function GetPieceNameByType(PT:TPieceType):String; // Название фигурки
begin
 case PT of
   ptPawn: Result:='Пешка';
   ptKnight: Result:='Конь';
   ptBishop: Result:='Слон';
   ptRook: Result:='Ладья';
   ptQueen: Result:='Ферзь';
   ptKing: Result:='Король';
 end;
end;

function IsThereAreCheckForSide(S:TSide):Boolean; // Проверяет, есть ли шах для указанной стороны
var
 KX,KY,i,L:Integer;
begin
 Result:=False;
 L:=Length(Pieces);
 if L>0 then
  begin
   for i := 0 to L-1 do
    if Assigned(Pieces[i]) then
     if Pieces[i].Side=S then
      if Pieces[i].PieceType=ptKing then
       begin
        KX:=Pieces[i].X;
        KY:=Pieces[i].Y;
        Break;
       end;
   for i := 0 to L-1 do
    if Assigned(Pieces[i]) then
     if Pieces[i].Side<>S then
      if Pieces[i].Move(KX,KY,True) then
       begin
        Result:=True;
        Exit;
       end;
  end;
end;

function IsThereAreCheck(var S:TSide):Boolean; // Проверяет, есть ли шах, и если есть, возвращает сторону в параметре-переменной
begin
 Result:=False;
 if IsThereAreCheckForSide(sBlack) then
  begin
   Result:=True;
   S:=sBlack;
  end
 else if IsThereAreCheckForSide(sWhite) then
  begin
   Result:=True;
   S:=sWhite;
  end
end;

constructor TPiece.Create(X,Y:Integer;PT:TPieceType;Side:TSide); // Создание экземпляра фигурки
begin
 inherited Create;
 fX:=X;
 fY:=Y;
 fOX:=X;
 fOY:=Y;
 fPT:=PT;
 fS:=Side;
 fWM:=False;
end;

function TPiece.fOriginalPosition:Boolean; // Проверяет, стоит ли фигурка на своей изначальной позиции
begin
 Result:=(fX=fOX) and (fY=fOY);
end;

function TPiece.Teleport(X,Y:Integer;Stay:Boolean=False):Boolean; // Перемещение фигурки на заданную клетку, игнорируя правила, по которым она ходит, если клетка пуста
var
 tmp:TPiece;
 OX,OY:Integer;
begin
 Result:=not IsThereAPiece(X,Y,tmp);
 if (Result) and (not Stay) then
  begin
   fX:=X;
   fY:=Y;
   fWM:=True;
  end;
end;

function TPiece.Capture(X,Y:Integer;Stay:Boolean=False):Boolean; // Взятие фигуркой другой фигурки, если на указанном поле она имеется
var
 tmp:TPiece;
begin
 Result:=False;
 if IsThereAPiece(X,Y,tmp) then
  if tmp.Side<>fS then
   begin
    if Stay then
     begin
      Result:=True;
      Exit;
     end;
    LastCapturedPiece.X:=tmp.X;
    LastCapturedPiece.Y:=tmp.Y;
    LastCapturedPiece.Side:=tmp.Side;
    LastCapturedPiece.PieceType:=tmp.PieceType;
    LastCapturedPiece.WasCapturedRightNow:=True;
    Result:=DestroyPiece(X,Y);
    Teleport(X,Y);
   end;
end;

constructor TPawn.Create(X,Y:Integer;Side:TSide;Revived:Boolean=False); // Создание пешки
begin
 inherited Create(X,Y,ptPawn,Side);
 fWM:=Revived;
end;

function TPawn.Move(X,Y:Integer;Stay:Boolean=False):Boolean; // Сделать ход пешкой в указанную клеточку, если это соответствует правилам
var
 Direction:TDirection;
 Distance:Integer;
 wc:Boolean;
begin
 Result:=False;
 Direction:=GetDirection(fX,fY,X,Y);
 Distance:=GetDistance(fX,fY,X,Y);
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if not TurnState.White then InvertDirection(Direction);
 if (abs(fX-X)=1) and (Distance=1) and ((Direction=dLeftUp) or (Direction=dRightUp))then
  Result:=Capture(X,Y,Stay);
 if Result then Exit;
 if Distance>0 then
  if ((Distance<3) and (not fWM)) or (Distance=1) then
   if Direction=dUp then
    if not IsThereAPiecesOnTheWay(fX,fY,Direction,Distance) then
     begin
      Result:=Teleport(X,Y,Stay);
      if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
     end;
end;

constructor TKnight.Create(X,Y:Integer;Side:TSide); // Создать коня
begin
 inherited Create(X,Y,ptKnight,Side);
end;

function TKnight.Move(X,Y:Integer;Stay:Boolean=False):Boolean;  // Сделать ход конём в указанную клеточку, если это соответствует правилам
var
 wc:Boolean;
begin
 Result:=False;
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if ((X>0) and (X<8)) or
    ((Y>0) and (Y<8)) then
 if ((abs(fY-Y)=2) and (abs(fX-X)=1)) or
    ((abs(fY-Y)=1) and (abs(fX-X)=2)) then
     begin
      Result:=Capture(X,Y,Stay);
      if not Result then
       begin
        Result:=Teleport(X,Y,Stay);
        if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
       end;
     end;
end;

constructor TBishop.Create(X,Y:Integer;Side:TSide); // Создать слона
begin
 inherited Create(X,Y,ptBishop,Side);
end;

function TBishop.Move(X,Y:Integer;Stay:Boolean=False):Boolean; // Сделать ход слоном в указанную клеточку, если это соответствует правилам
var
 Direction:TDirection;
 Distance:Integer;
 wc:Boolean;
begin
 Result:=False;
 Direction:=GetDirection(fX,fY,X,Y);
 Distance:=GetDistance(fX,fY,X,Y);
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if not TurnState.White then InvertDirection(Direction);
 if Distance>0 then
  case Direction of
   dLeftDown, dLeftUp, dRightUp, dRightDown:
    begin
     if not IsThereAPiecesOnTheWay(fX,fY,Direction,Distance-1) then
      begin
       Result:=Capture(X,Y,Stay);
       if not Result then
        begin
         Result:=Teleport(X,Y,Stay);
         if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
        end;
      end;
    end;
  end;
end;

constructor TRook.Create(X,Y:Integer;Side:TSide); // Создать ладью
begin
 inherited Create(X,Y,ptRook,Side);
end;

function TRook.Move(X,Y:Integer;Stay:Boolean=False):Boolean; // Сделать ход ладьёй в указанную клеточку, если это соответствует правилам
var
 Direction:TDirection;
 Distance:Integer;
 wc:Boolean;
begin
 Result:=False;
 Direction:=GetDirection(fX,fY,X,Y);
 Distance:=GetDistance(fX,fY,X,Y);
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if not TurnState.White then InvertDirection(Direction);
 if Distance>0 then
  case Direction of
   dLeft, dRight, dUp, dDown:
    begin
     if not IsThereAPiecesOnTheWay(fX,fY,Direction,Distance-1) then
      begin
       Result:=Capture(X,Y,Stay);
       if not Result then
        begin
         Result:=Teleport(X,Y,Stay);
         if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
        end;
      end;
    end;
  end;
end;

constructor TQueen.Create(X,Y:Integer;Side:TSide); // Создать ферзя
begin
 inherited Create(X,Y,ptQueen,Side);
end;

function TQueen.Move(X,Y:Integer;Stay:Boolean=False):Boolean; // Сделать ход ферзём в указанную клеточку, если это соответствует правилам
var
 Direction:TDirection;
 Distance:Integer;
 wc:Boolean;
begin
 Result:=False;
 Direction:=GetDirection(fX,fY,X,Y);
 Distance:=GetDistance(fX,fY,X,Y);
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if not TurnState.White then InvertDirection(Direction);
 if Distance>0 then
  case Direction of
   dLeft, dRight, dUp, dDown, dLeftDown, dLeftUp, dRightUp, dRightDown:
    begin
     if not IsThereAPiecesOnTheWay(fX,fY,Direction,Distance-1) then
      begin
       Result:=Capture(X,Y,Stay);
       if not Result then
        begin
         Result:=Teleport(X,Y,Stay);
         if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
        end;
      end;
    end;
  end;
end;

constructor TKing.Create(X,Y:Integer;Side:TSide); // Создать короля
begin
 inherited Create(X,Y,ptKing,Side);
end;

function TKing.Move(X,Y:Integer;Stay:Boolean=False):Boolean; // Сделать ход королём в указанную клеточку, если это соответствует правилам
var
 Direction:TDirection;
 Distance:Integer;
 wc:Boolean;
begin
 Result:=False;
 Direction:=GetDirection(fX,fY,X,Y);
 Distance:=GetDistance(fX,fY,X,Y);
 wc:=LastCapturedPiece.WasCapturedRightNow;
 if not TurnState.White then InvertDirection(Direction);
 if Distance=1 then
  case Direction of
   dLeft, dRight, dUp, dDown, dLeftDown, dLeftUp, dRightUp, dRightDown:
    begin
     if not IsThereAPiecesOnTheWay(fX,fY,Direction,Distance-1) then
      begin
       Result:=Capture(X,Y,Stay);
       if not Result then
        begin
         Result:=Teleport(X,Y,Stay);
         if (Result) and (wc) and (not Stay) then LastCapturedPiece.WasCapturedRightNow:=False;
        end;
      end;
    end;
  end;
end;

procedure TForm1.InitChess; // Начало новой игры. Удаление фигурок с поля, расстановка новых, передача хода белым
var
 i:Integer;
begin
 DestroyAllPieces;
 SetLength(Pieces,32);
 for i := 0 to 7 do // Пешки белые
  Pieces[i]:=TPawn.Create(0+i,6,sWhite);
 for i := 8 to 15 do // Пешки чёрные
  Pieces[i]:=TPawn.Create(0+i-8,1,sBlack);
 // Ладьи
 Pieces[16]:=TRook.Create(0,0,sBlack);
 Pieces[17]:=TRook.Create(7,0,sBlack);
 Pieces[18]:=TRook.Create(0,7,sWhite);
 Pieces[19]:=TRook.Create(7,7,sWhite);
 // Кони
 Pieces[20]:=TKnight.Create(1,0,sBlack);
 Pieces[21]:=TKnight.Create(6,0,sBlack);
 Pieces[22]:=TKnight.Create(1,7,sWhite);
 Pieces[23]:=TKnight.Create(6,7,sWhite);
 // Слоны
 Pieces[24]:=TBishop.Create(2,0,sBlack);
 Pieces[25]:=TBishop.Create(5,0,sBlack);
 Pieces[26]:=TBishop.Create(2,7,sWhite);
 Pieces[27]:=TBishop.Create(5,7,sWhite);
 // Ферзи
 Pieces[28]:=TQueen.Create(3,0,sBlack);
 Pieces[29]:=TQueen.Create(3,7,sWhite);
 // Короли
 Pieces[30]:=TKing.Create(4,0,sBlack);
 Pieces[31]:=TKing.Create(4,7,sWhite);
 TurnState.HoldingPiece:=False;
 TurnState.White:=True;
 LastCapturedPiece.WasCapturedRightNow:=False;
 LastTurnCheck:=False;
 L_Check.Caption:='';
end;

procedure TForm1.B_RestartClick(Sender: TObject); // Нажатие кнопки начала новой игры
begin
 InitChess;
 Form1.Repaint;
end;

procedure TForm1.FieldClick(X,Y:Integer); // Обработка события нажатия на клеточку
var
 tmp:TPiece;
 tmps:TSide;
 ans:Integer;
 OX,OY:Integer;
 WM,P:Boolean;
begin
 if TurnState.HoldingPiece then
  begin
   OX:=TurnState.HeldPiece.X;
   OY:=TurnState.HeldPiece.Y;
   WM:=TurnState.HeldPiece.WasMoved;
   P:=False;
   if IsThereAPiece(X,Y,tmp) then
    P:=tmp.Side=TurnState.HeldPiece.Side;
   if (X=OX) and (Y=OY) then
    TurnState.HoldingPiece:=False
   else if P then
    TurnState.HeldPiece:=tmp
   else if TurnState.HeldPiece.Move(X,Y) then
    begin
     if TurnState.HeldPiece.PieceType=ptPawn then
      case TurnState.HeldPiece.Side of
       sWhite:
        if TurnState.HeldPiece.Y=0 then
         begin
          repeat
           ans:=Form2.ShowModal;
          until ans=mrOK;
          ReplacePawn(TurnState.HeldPiece.X,TurnState.HeldPiece.Y,Choice);
         end;
       sBlack:
        if TurnState.HeldPiece.Y=7 then
         begin
          repeat
           ans:=Form2.ShowModal;
          until ans=mrOK;
          ReplacePawn(TurnState.HeldPiece.X,TurnState.HeldPiece.Y,Choice);
         end;
      end;
     TurnState.White:=not TurnState.White;
     if IsThereAreCheckForSide(TurnState.HeldPiece.Side) then
      begin
       TurnState.White:=not TurnState.White;
       AlertMsg('Неверный ход','Нельзя сделать этот ход, так как он поставит твоего короля под удар!');
       TurnState.HeldPiece.Teleport(OX,OY);
       TurnState.HeldPiece.WasMoved:=WM;
       if LastCapturedPiece.WasCapturedRightNow then
        ReviveCapturedPiece(
         LastCapturedPiece.X,
         LastCapturedPiece.Y,
         LastCapturedPiece.PieceType,
         LastCapturedPiece.Side);
       Exit;
      end;
     TurnState.White:=not TurnState.White;
     if IsThereAreCheck(tmps) then
      begin
       if LastTurnCheck then
        begin
         AlertMsg('Неверный ход','Нельзя сделать этот ход, так как после него твой король останется под ударом!');
         TurnState.HeldPiece.Teleport(OX,OY);
         TurnState.HeldPiece.WasMoved:=WM;
         if LastCapturedPiece.WasCapturedRightNow then
          ReviveCapturedPiece(
           LastCapturedPiece.X,
           LastCapturedPiece.Y,
           LastCapturedPiece.PieceType,
           LastCapturedPiece.Side);
         Exit;
        end;
       case tmps of
        sBlack: L_Check.Caption:='Шах чёрным!';
        sWhite: L_Check.Caption:='Шах белым!';
       end;
       LastTurnCheck:=True;
      end
     else
      begin
       L_Check.Caption:='';
       LastTurnCheck:=False;
      end;
     TurnState.HoldingPiece:=False;
     TurnState.White:=not TurnState.White;
     L_Notify.Caption:='';
    end
   else
    begin
     AlertMsg('Неверный ход','Нельзя походить сюда!');
    end;
  end
 else
  begin
   if IsThereAPiece(X,Y,tmp) then
    if (TurnState.White=(tmp.Side=sWhite)) then
     begin
      TurnState.HeldPiece:=tmp;
      TurnState.HoldingPiece:=True;
     end;
  end;
 Form1.Repaint;
end;

procedure TForm1.FormCreate(Sender: TObject); // Начало игры при запуске
begin
 InitChess;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton; // При нажатии на поле, определяет на какую клеточку было совершено нажатие
  Shift: TShiftState; X, Y: Integer);
begin
 if Button=mbLeft then
  if (X>8) and (X<(CELL_SIZE*8+8)) and
     (Y>8) and (Y<(CELL_SIZE*8+8)) then
      begin
       X:=(X-8) div CELL_SIZE;
       Y:=(Y-8) div CELL_SIZE;
       if not TurnState.White then
        begin
         X:=7-X;
         Y:=7-Y;
        end;
       FieldClick(X,Y);
      end;
end;

procedure TForm1.FormPaint(Sender: TObject); // Отрисовка игрового поля
var
 fc:TCanvas;
 i,j,ni,nj:Integer;
 lul:Boolean;
 tp:TPiece;
 Image:String;
begin
 fc:=Form1.Canvas; // Да, я в курсе про with, но он меня бесит и вообще он костыль и не нужен
 lul:=True;
 fc.Brush.Style:=bsSolid;
 if TurnState.White then
  L_Side.Caption:='Ход белых'
 else
  L_Side.Caption:='Ход чёрных';
 for i := 0 to 7 do
 for j := 0 to 7 do
  begin
   if lul then
    fc.Brush.Color:=clWhite
   else
    fc.Brush.Color:=clSilver;
   if j<7 then lul:=not lul;
   if TurnState.White then
    begin
     ni:=i;
     nj:=j;
    end
   else
    begin
     ni:=7-i;
     nj:=7-j;
    end;
   if TurnState.HoldingPiece then
    begin
     if (ni=TurnState.HeldPiece.X) and (nj=TurnState.HeldPiece.Y) then
      fc.Brush.Color:=clLime
     else if TurnState.HeldPiece.Move(ni,nj,True) then
      if TurnState.HeldPiece.Capture(ni,nj,True) then
       fc.Brush.Color:=clRed
      else
       fc.Brush.Color:=clYellow;
    end;
   fc.Rectangle(8+CELL_SIZE*i,8+CELL_SIZE*j,8+CELL_SIZE*(i+1),8+CELL_SIZE*(j+1));
   fc.Font.Size:=30;
   fc.Brush.Style:=bsClear;
   if IsThereAPiece(ni,nj,tp) then
    begin
     if tp.Side=sWhite then
      begin
       case tp.PieceType of
        ptPawn: Image:='♙';
        ptKnight: Image:='♘';
        ptBishop: Image:='♗';
        ptRook: Image:='♖';
        ptQueen: Image:='♕';
        ptKing: Image:='♔';
       end;
      end
     else
      begin
       case tp.PieceType of
        ptPawn: Image:='♟';
        ptKnight: Image:='♞';
        ptBishop: Image:='♝';
        ptRook: Image:='♜';
        ptQueen: Image:='♛';
        ptKing: Image:='♚';
       end;
      end;
     fc.TextOut(8+CELL_SIZE*i,2+CELL_SIZE*j,Image);
    end;
  end;
end;

end.
