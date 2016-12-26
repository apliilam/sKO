program StockOutsourceManager;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, som_main
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='Stock Keyword Outsourcing v1.0';
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(Tsom_mForm, som_mForm);
  Application.Run;
end.

