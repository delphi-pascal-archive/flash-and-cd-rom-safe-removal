program SafeRemoval;

uses
  Forms,
  uMain in 'uMain.pas' {dlgSafeRemoval};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TdlgSafeRemoval, dlgSafeRemoval);
  Application.Run;
end.
