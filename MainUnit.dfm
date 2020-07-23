object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #1064#1072#1093#1084#1072#1090#1099
  ClientHeight = 370
  ClientWidth = 473
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnMouseDown = FormMouseDown
  OnPaint = FormPaint
  PixelsPerInch = 96
  TextHeight = 13
  object L_Side: TLabel
    Left = 336
    Top = 8
    Width = 61
    Height = 25
    Caption = 'L_Side'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object L_Check: TLabel
    Left = 336
    Top = 39
    Width = 77
    Height = 25
    Caption = 'L_Check'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clMaroon
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object L_Notify: TLabel
    Left = 144
    Top = 336
    Width = 321
    Height = 26
    AutoSize = False
    WordWrap = True
  end
  object B_Restart: TButton
    Left = 8
    Top = 336
    Width = 129
    Height = 25
    Caption = #1053#1086#1074#1072#1103' '#1080#1075#1088#1072
    TabOrder = 0
    OnClick = B_RestartClick
  end
end
