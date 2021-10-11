object dlgSafeRemoval: TdlgSafeRemoval
  Left = 226
  Top = 131
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Flash and CD-ROM Safe Removal'
  ClientHeight = 386
  ClientWidth = 394
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 17
  object gbVolumes: TGroupBox
    Left = 8
    Top = 8
    Width = 377
    Height = 145
    Caption = ' Drives '
    TabOrder = 0
    object lbVolumes: TListBox
      Left = 8
      Top = 24
      Width = 361
      Height = 113
      ItemHeight = 17
      TabOrder = 0
    end
  end
  object gbLog: TGroupBox
    Left = 8
    Top = 184
    Width = 377
    Height = 193
    Caption = ' Log '
    TabOrder = 1
    object memLog: TMemo
      Left = 8
      Top = 24
      Width = 361
      Height = 161
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object btnRemove: TButton
    Left = 168
    Top = 160
    Width = 217
    Height = 25
    Action = acRemoval
    TabOrder = 2
  end
  object ActionList1: TActionList
    Left = 32
    Top = 40
    object acRemoval: TAction
      Caption = 'Safe removal selected drive'
      OnExecute = acRemovalExecute
      OnUpdate = acRemovalUpdate
    end
  end
end
