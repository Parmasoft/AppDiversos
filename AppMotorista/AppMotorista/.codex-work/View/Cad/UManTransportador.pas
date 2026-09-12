unit UManTransportador;

interface

uses
  Winapi.Messages, Winapi.Windows, System.SysUtils, System.Variants, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, UManPadrao, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls, cxContainer,
  cxDBLookupComboBox, JvDBCombobox,
  JvDBControls, cxTextEdit, cxDBEdit,
  Data.DB,
  cxGridLevel,
  cxGridDBTableView, cxGrid, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxEdit, cxStyles, cxCustomData, cxFilter, cxData,
  cxDataStorage, cxNavigator, cxDBData, cxImageComboBox, cxGridCustomTableView,
  cxGridTableView, cxGridCustomView, dxGDIPlusClasses, cxMaskEdit,
  cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, JvExStdCtrls, JvCombobox,
  Vcl.Mask, JvExMask, JvToolEdit, cxClasses, Vcl.AppEvnts, ACBrBase,
  ACBrEnterTab, dxSkinsCore, dxSkinBlack, dxSkinBlue, dxSkinBlueprint,
  dxSkinCaramel, dxSkinCoffee, dxSkinDarkRoom, dxSkinDarkSide,
  dxSkinDevExpressDarkStyle, dxSkinDevExpressStyle, dxSkinFoggy,
  dxSkinGlassOceans, dxSkinHighContrast, dxSkiniMaginary, dxSkinLilian,
  dxSkinLiquidSky, dxSkinLondonLiquidSky, dxSkinMcSkin, dxSkinMetropolis,
  dxSkinMetropolisDark, dxSkinMoneyTwins, dxSkinOffice2007Black,
  dxSkinOffice2007Blue, dxSkinOffice2007Green, dxSkinOffice2007Pink,
  dxSkinOffice2007Silver, dxSkinOffice2010Black, dxSkinOffice2010Blue,
  dxSkinOffice2010Silver, dxSkinOffice2013DarkGray, dxSkinOffice2013LightGray,
  dxSkinOffice2013White, dxSkinPumpkin, dxSkinSeven, dxSkinSevenClassic,
  dxSkinSharp, dxSkinSharpPlus, dxSkinSilver, dxSkinSpringTime, dxSkinStardust,
  dxSkinSummer2008, dxSkinTheAsphaltWorld, dxSkinsDefaultPainters,
  dxSkinValentine, dxSkinVS2010, dxSkinWhiteprint, dxSkinXmas2008Blue,
  dxSkinscxPCPainter, cxMemo, ACBrCEP;

type
  TfrmManTransportador = class(TFrmManPadrao)
    grpCliente: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label21: TLabel;
    Label22: TLabel;
    dbedtTRANSP_FANTASIA: TcxDBTextEdit;
    dbedtTRANSP_RSOCIAL_NOME: TcxDBTextEdit;
    dbedtTRANSP_CPF_CNPJ: TcxDBTextEdit;
    dbedtTRANSP_IE_RG: TcxDBTextEdit;
    dbedtTRANSP_ID: TcxDBTextEdit;
    dbedtTRANSP_DT_CADASTRO: TJvDBDateEdit;
    dbcbbTRANSP_STATUS: TJvDBComboBox;
    dbcbbTRANSP_TIPO_PESSOA: TJvDBComboBox;
    grpEndereco: TGroupBox;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label18: TLabel;
    lbUF: TLabel;
    Label19: TLabel;
    lbCodMunicipio: TLabel;
    dbedtTRANSP_ENDERECO: TcxDBTextEdit;
    dbedtTRANSP_COMPLEMENTO: TcxDBTextEdit;
    dbedtTRANSP_NUMERO: TcxDBTextEdit;
    dbedtTRANSP_BAIRRO: TcxDBTextEdit;
    dbedtTRANSP_CEP: TcxDBTextEdit;
    dbcbbTRANSP_CIDADE: TcxDBLookupComboBox;
    grpContato: TGroupBox;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label20: TLabel;
    dbedtTRANSP_TELEFONE: TcxDBTextEdit;
    dbedtTRANSP_FAX: TcxDBTextEdit;
    dbedtTRANS_CELULAR: TcxDBTextEdit;
    dbedtTRANSP_EMAIL: TcxDBTextEdit;
    dbedtTRANSP_CONTATO: TcxDBTextEdit;
    tsAuditoria: TTabSheet;
    pnlAuditoria: TPanel;
    pnlLegenda: TPanel;
    grpLegenda: TGroupBox;
    img7: TImage;
    img1: TImage;
    img2: TImage;
    img3: TImage;
    lbl1: TLabel;
    lbl2: TLabel;
    lbl3: TLabel;
    lbl4: TLabel;
    btnConsultarCNPJCPF: TSpeedButton;
    lbl5: TLabel;
    dbedtTRANSP_PLACA: TcxDBTextEdit;
    lbl6: TLabel;
    dbcbbTRANSP_PLACA_UF: TJvDBComboBox;
    cxgrdCadastro: TcxGrid;
    cxgrdbtblvwCadastroDBTableView1: TcxGridDBTableView;
    cxgrdbclmnCadastroDBTableView1AUD_ACAO: TcxGridDBColumn;
    cxgrdbclmnCadastroDBTableView1AUD_DT_LANCAMENTO: TcxGridDBColumn;
    cxgrdbclmnCadastroDBTableView1AUD_USUARIO: TcxGridDBColumn;
    cxgrdbclmnCadastroDBTableView1USU_NOME: TcxGridDBColumn;
    cxgrdbtblvwCadastroDBTableView2: TcxGridDBTableView;
    cxgrdbclmnCadastroDBTableView2AUDI_CAMPO_DESC: TcxGridDBColumn;
    cxgrdbclmnCadastroDBTableView2AUDI_VALOR_ANTIGO: TcxGridDBColumn;
    cxgrdbclmnCadastroDBTableView2AUDI_VALOR_NOVO: TcxGridDBColumn;
    cxgrdlvlCadastroLevel1: TcxGridLevel;
    cxgrdlvlCadastroLevel2: TcxGridLevel;
    tsObservacao: TTabSheet;
    pnlObservacao: TPanel;
    Panel2: TPanel;
    GroupBox1: TGroupBox;
    Image1: TImage;
    Image2: TImage;
    Image3: TImage;
    Image4: TImage;
    Label17: TLabel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    dbmmoTRANSP_OBSERVACAO: TcxDBMemo;
    grpAppMotorista: TGroupBox;
    chkUsaAppMotorista: TCheckBox;
    lblUsuarioApp: TLabel;
    lblSenhaApp: TLabel;
    lblSenhaAppAviso: TLabel;
    edtUsuarioApp: TEdit;
    edtSenhaApp: TEdit;
    procedure FormShow(Sender: TObject);
    procedure btnConfirmarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure dbcbbTRANSP_CIDADEExit(Sender: TObject);
    procedure dbedtTRANSP_CPF_CNPJExit(Sender: TObject);
    procedure dbedtTRANSP_CPF_CNPJKeyPress(Sender: TObject; var Key: Char);
    procedure pgcManutencaoChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure dbedtTRANSP_CEPExit(Sender: TObject);
    procedure btnConsultarCNPJCPFClick(Sender: TObject);
    procedure chkUsaAppMotoristaClick(Sender: TObject);
  private
    { Private declarations }
    FMotoristaAppId: Integer;
    function ValidarCampos(var mensagem: string): Boolean;
    procedure FormatarCampos();
    procedure AjustarControlesTela;
    procedure CarregarDadosCidade();
    procedure CarregarAcessoApp;
    procedure AtualizarControlesApp;
  public
    { Public declarations }
  end;

var
  frmManTransportador: TfrmManTransportador;
  vCNPJ_CPF, vCEP, vIE: String;

implementation

{$R *.dfm}

uses UClassGlobal, UDMTransportador, UClassCidade, UClassTransportador,
  UClassAuditoria, UDMAuditoria, UManConsultaCPF, UManConsultaCNPJ, UDMBase,
  UDMCidade, UClassMotoristaApp;

procedure TFrmManTransportador.AjustarControlesTela;
begin
  pnlDados.Enabled := True;
  pgcManutencao.ActivePage := tsDadosPrincipais;
  pnlDadosPrincipais.Enabled := (Acao = 'I') or (Acao = 'A');
  vCNPJ_CPF := DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.Value;
  vCEP := DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.Value;
  CarregarDadosCidade();
  FormatarCampos();
  CarregarAcessoApp;
  AtualizarControlesApp;

  // Habilitar aba de auditoria se Usuário tiver acesso ao formulário de Movimentação de Auditoria
  tsAuditoria.TabVisible := TGlobal.GetInstance.HabilitarFuncoesForm('act_Mov_Auditoria').pNomeAcao <> EmptyStr;
end;

procedure TFrmManTransportador.AtualizarControlesApp;
var
  PodeEditar: Boolean;
begin
  PodeEditar := (Acao = 'I') or (Acao = 'A');
  chkUsaAppMotorista.Enabled := PodeEditar;
  edtUsuarioApp.Enabled := PodeEditar and chkUsaAppMotorista.Checked;
  edtSenhaApp.Enabled := PodeEditar and chkUsaAppMotorista.Checked;
end;

procedure TFrmManTransportador.CarregarAcessoApp;
var
  Acesso: TAcessoMotoristaApp;
begin
  FMotoristaAppId := 0;
  chkUsaAppMotorista.Checked := False;
  edtUsuarioApp.Clear;
  edtSenhaApp.Clear;

  if DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger = 0 then
    Exit;

  Acesso := UClassMotoristaApp.CarregarAcessoTransportador(
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_EMPRESA.AsInteger,
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger,
    DMTransportador.fdtransTransportador);
  if not Acesso.Existe then
    Exit;

  FMotoristaAppId := Acesso.MotoristaId;
  chkUsaAppMotorista.Checked := Acesso.Ativo;
  edtUsuarioApp.Text := Acesso.Login;
end;

procedure TfrmManTransportador.chkUsaAppMotoristaClick(Sender: TObject);
begin
  AtualizarControlesApp;
end;

procedure TFrmManTransportador.CarregarDadosCidade;
Var
  vCidade: TCidade;
begin
  lbUF.Caption := EmptyStr;
  vCidade := TCidade.Create;
  try
    if (not (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CIDADE.AsInteger > 0)) then
      exit;
    vCidade := UClassCidade.RetornarDadosCidade(DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CIDADE.AsInteger, EmptyStr);
    lbUF.Caption := vCidade.CidUF;
    lbCodMunicipio.Caption := vCidade.CidCodMunicipio;
    // Busca CEP da cidade se estiver Incluindo ou alterando e CEP estiver Vazio
    if ((Acao = 'I') or (Acao = 'A')) and (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.AsString = EmptyStr)then
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.AsString := vCidade.CidCep;
    // se Não encontrar CIDADE para o ID informado
    if (vCidade.CidId = 0) then
    begin
      MessageDlg('Não existe Cidade Cadastrada para o ID informado', mtWarning, [mbOK], 0);
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CIDADE.Clear;
      dbcbbTRANSP_CIDADE.SetFocus;
    end;
  finally
    vCidade.Free;
  end;
end;

procedure TfrmManTransportador.dbcbbTRANSP_CIDADEExit(Sender: TObject);
begin
  inherited;
  try
    CarregarDadosCidade();
  except
    on E : Exception do
    begin
      MessageDlg(TGlobal.GetInstance.TraduzirErro(E.Message, DMTransportador.fdqryTB_TRANSPORTADOR), mtWarning, [mbOK], 0);
    end;
  end;
end;

procedure TfrmManTransportador.dbedtTRANSP_CEPExit(Sender: TObject);
var
   i : integer;
   pEstado, pCidade: string;
   vHint: THintWindow;
begin
  inherited;
  vCEP := dbedtTRANSP_CEP.Text;
  FormatarCampos;

  if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ENDERECO.AsString = EmptyStr) then
  begin
    try
      vHint := Tglobal.GetInstance.MensagemAviso('AGUARDE! CONSULTANDO O CEP...', 100);

      DMBase.ACBrCEP.WebService := TACBrCEPWebService(TGlobal.GetInstance.EmpcBuscaCEP);
      DMBase.ACBrCEP.BuscarPorCEP(TGlobal.GetInstance.FormatarCampo('CEP', DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.AsString));

      for i := 0 to DMBase.ACBrCEP.Enderecos.Count -1 do
      begin
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ENDERECO.AsString    := TGlobal.GetInstance.SubstituirCaracterEspecial(DMBase.ACBrCEP.Enderecos[i].Tipo_Logradouro + ' ' + DMBase.ACBrCEP.Enderecos[i].Logradouro, False);
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_COMPLEMENTO.AsString := TGlobal.GetInstance.SubstituirCaracterEspecial(DMBase.ACBrCEP.Enderecos[i].Complemento, False);

        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_BAIRRO.AsString      := TGlobal.GetInstance.SubstituirCaracterEspecial(DMBase.ACBrCEP.Enderecos[i].Bairro, False);

        pCidade := DMBase.ACBrCEP.Enderecos[i].Municipio;
        pEstado := DMBase.ACBrCEP.Enderecos[i].UF;

        if (pCidade = 'Diamante-Ubá') then
          pCidade := 'DIAMANTE';

        if (pCidade = EmptyStr) then
        begin
          pCidade := 'UBA';
          pEstado := 'MG';
        end;

        pCidade := UpperCase(TGlobal.GetInstance.SubstituirCaracterEspecial(pCidade, False));

        //Procuro estado
        if (DMCidade.fdqryLISTA_ESTADO.Locate('EST_SIGLA', pEstado)) then
        begin
          if (DMCidade.fdqryLISTA_CIDADE.Locate('CID_NOME; CID_ESTADO', VarArrayOf([pCidade, DMCidade.fdqryLISTA_ESTADOEST_ID.AsInteger]), [])) then
          begin
            DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CIDADE.AsInteger := DMCidade.fdqryLISTA_CIDADECID_ID.AsInteger;
            CarregarDadosCidade;
          end;
        end
      end;
    finally
      FreeAndNil(vHint);
    end;
  end;
end;

procedure TfrmManTransportador.dbedtTRANSP_CPF_CNPJExit(Sender: TObject);
begin
  inherited;
  vCNPJ_CPF := dbedtTRANSP_CPF_CNPJ.Text;
  FormatarCampos();
end;

procedure TfrmManTransportador.dbedtTRANSP_CPF_CNPJKeyPress(Sender: TObject; var Key: Char);
begin
  inherited;
  if (not(TGlobal.GetInstance.VerificarCaracterNumerais(key))) then
    key := #0;
end;

function TfrmManTransportador.ValidarCampos(var mensagem: string): Boolean;
begin
  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'RAZÃO SOCIAL', dbedtTRANSP_RSOCIAL_NOME.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_RSOCIAL_NOME.SetFocus;
    Result := False;
    Exit;
  end;

  // Validar CNPJ
  if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString = 'J') then
  begin
    if not(TGlobal.GetInstance.ValidarDocumento(mensagem, 'CNPJ','', vCNPJ_CPF)) then
    begin
      pgcManutencao.ActivePage := tsDadosPrincipais;
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.Clear;
      dbedtTRANSP_CPF_CNPJ.SetFocus;
       Result := False;
      Exit;
    end
    else
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.AsString := vCNPJ_CPF;

  // Validar IE
    if not (TGlobal.GetInstance.ValidarDocumento(mensagem, 'IE',lbUF.Caption , dbedtTRANSP_IE_RG.text)) then
    begin
      pgcManutencao.ActivePage := tsDadosPrincipais;
      dbedtTRANSP_IE_RG.SetFocus;
      Result := false;
     Exit;
    end;
  end
  else
  if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString = 'F') then
  begin
    if not(TGlobal.GetInstance.ValidarDocumento(mensagem, 'CPF','', vCNPJ_CPF)) then
    begin
      pgcManutencao.ActivePage := tsDadosPrincipais;
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.Clear;
      dbedtTRANSP_CPF_CNPJ.SetFocus;
       Result := False;
      Exit;
    end
    else
      DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.AsString := vCNPJ_CPF;
  end;
  if UClassTransportador.ExisteCNPJCPF(DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger, vCNPJ_CPF) then
  begin
    mensagem := TGlobal.GetInstance.iif(DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString = 'J','CNPJ', 'CPF') +' já cadastrado ';
    pgcManutencao.ActivePage := tsDadosPrincipais;
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.Clear;
    dbedtTRANSP_CPF_CNPJ.SetFocus;
    Result := False;
    Exit;
  end;

  // Endereço
  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'ENDEREÇO', dbedtTRANSP_ENDERECO.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_ENDERECO.SetFocus;
    Result := False;
    Exit;
  end;

  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'NÚMERO', dbedtTRANSP_NUMERO.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_NUMERO.SetFocus;
    Result := False;
    Exit;
  end;

  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'BAIRRO', dbedtTRANSP_BAIRRO.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_BAIRRO.SetFocus;
    Result := False;
    Exit;
  end;

  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'CIDADE', dbcbbTRANSP_CIDADE.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbcbbTRANSP_CIDADE.SetFocus;
    Result := False;
    Exit;
  end;

  if not(TGlobal.GetInstance.ValidarCampos(mensagem, 'CEP', dbedtTRANSP_CEP.Text)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_CEP.SetFocus;
    Result := False;
    Exit;
  end;

  // Validar Cep
  if not (TGlobal.GetInstance.ValidarDocumento(mensagem, 'CEP','', vCEP)) then
  begin
    pgcManutencao.ActivePage := tsDadosPrincipais;
    dbedtTRANSP_CEP.SetFocus;
    Result := false;
    Exit;
  end
  else
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.AsString := vCEP;

  if chkUsaAppMotorista.Checked then
  begin
    if Trim(edtUsuarioApp.Text) = EmptyStr then
    begin
      mensagem := 'Informe o USUÁRIO do App Motorista.';
      pgcManutencao.ActivePage := tsDadosPrincipais;
      edtUsuarioApp.SetFocus;
      Result := False;
      Exit;
    end;

    if (FMotoristaAppId = 0) and (edtSenhaApp.Text = EmptyStr) then
    begin
      mensagem := 'Informe a SENHA inicial do App Motorista.';
      pgcManutencao.ActivePage := tsDadosPrincipais;
      edtSenhaApp.SetFocus;
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

procedure TfrmManTransportador.btnCancelarClick(Sender: TObject);
begin
  inherited;
  try
    if (((Acao = 'A') or (Acao = 'I'))
    and (MessageDlg('Deseja cancelar '+TGlobal.GetInstance.iif((Acao = 'A'), 'Alteração', 'Inclusão')+' no Transportador?', mtConfirmation, mbYesNo, 0) = mrNo)) then
        Exit;
    UClassTransportador.FinalizarCadastro('CAN', Acao, False, EmptyStr,
      EmptyStr, FMotoristaAppId);
    Self.Close;
  except
    on E : Exception do
    begin
      MessageDlg(TGlobal.GetInstance.TraduzirErro(E.Message, DMTransportador.fdqryTB_TRANSPORTADOR), mtWarning, [mbOK], 0);
    end;
  end;
end;

procedure TfrmManTransportador.btnConfirmarClick(Sender: TObject);
begin
  inherited;
  try
    // se Empresa herda de outra empresa então não pode Alterar nem Incluir nem Excluir
    if (Acao <> 'V') and (TGlobal.GetInstance.EmpcHerda = 'S') and (TGlobal.GetInstance.EmpcHerdaTransportador = 'S') then
      raise Exception.Create('Não é possível aplicar essa ação pois essa empresa herda os transportadores de outra empresa - VERIFIQUE!');
    //.......................................................................................................

    if ((Acao = 'I') or (Acao = 'A')) and (not(ValidarCampos(mensagem)))   then
      raise Exception.Create(mensagem);
    if ((Acao = 'E')and (MessageDlg('Deseja excluir o Transportador?', mtConfirmation, mbYesNo, 0) = mrNo)) then
        Exit;
    UClassTransportador.FinalizarCadastro('CON', Acao,
      chkUsaAppMotorista.Checked, Trim(edtUsuarioApp.Text),
      edtSenhaApp.Text, FMotoristaAppId);
    Self.Close;
  except
    on E : Exception do
    begin
      MessageDlg(TGlobal.GetInstance.TraduzirErro(E.Message, DMTransportador.fdqryTB_TRANSPORTADOR), mtWarning, [mbOK], 0);
    end;
  end;
end;

procedure TfrmManTransportador.btnConsultarCNPJCPFClick(Sender: TObject);
begin
  inherited;
  if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString = 'F') then
  begin
    // Consultar CPF
    try
      FrmManConsultaCPF := TFrmManConsultaCPF.Create(Self, 'IMP', ParametroAbertura);

      FrmManConsultaCPF.edtCPF.Text := Trim(dbedtTRANSP_CPF_CNPJ.Text);

      if (FrmManConsultaCPF.ShowModal = mrOk) then
      begin
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_RSOCIAL_NOME.AsString := FrmManConsultaCPF.ACBrConsultaCPF.Nome;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.AsString := TGlobal.GetInstance.RemoveMascara(FrmManConsultaCPF.ACBrConsultaCPF.CPF);
        FormatarCampos;
      end;
    finally
      FrmManConsultaCPF.Release;
    end;
  end
  else
  if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString = 'J') then
  begin
    // Consultar CNPJ
    try
      FrmManConsultaCNPJ := TFrmManConsultaCNPJ.Create(Self, 'IMP', ParametroAbertura);
      FrmManConsultaCNPJ.medtCNPJ.Text := Trim(dbedtTRANSP_CPF_CNPJ.Text);
      if (FrmManConsultaCNPJ.ShowModal = mrOk) then
      begin
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_RSOCIAL_NOME.AsString     := FrmManConsultaCNPJ.ACBrConsultaCNPJ.RazaoSocial;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CPF_CNPJ.AsString         := TGlobal.GetInstance.RemoveMascara(FrmManConsultaCNPJ.ACBrConsultaCNPJ.CNPJ);
//        DMFornecedor.fdqryTB_FORNECEDORFOR_DT_NASCIMENTO.AsDateTime  := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Abertura;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_FANTASIA.AsString         := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Fantasia;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ENDERECO.AsString         := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Endereco;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_NUMERO.AsString           := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Numero;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_COMPLEMENTO.AsString      := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Complemento;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_BAIRRO.AsString           := FrmManConsultaCNPJ.ACBrConsultaCNPJ.Bairro;
        DMTransportador.fdqryTB_TRANSPORTADORTRANSP_CEP.AsString              := TGlobal.GetInstance.RemoveMascara(FrmManConsultaCNPJ.ACBrConsultaCNPJ.CEP);
        FormatarCampos;
      end;
    finally
      FrmManConsultaCNPJ.Release;
    end;
  end;
end;

procedure TfrmManTransportador.FormatarCampos;
begin
  if dbedtTRANSP_CPF_CNPJ.Text <> EmptyStr then
  begin
    if (DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.Value = 'F') then
      dbedtTRANSP_CPF_CNPJ.Text := TGlobal.getInstance.FormatarCampo('CPF', dbedtTRANSP_CPF_CNPJ.Text)
    else if DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.Value = 'J' then
      dbedtTRANSP_CPF_CNPJ.Text := TGlobal.getInstance.FormatarCampo('CNPJ', dbedtTRANSP_CPF_CNPJ.Text);
  end;
  if dbedtTRANSP_CEP.Text <> EmptyStr then
  begin
    dbedtTRANSP_CEP.Text := TGlobal.getInstance.FormatarCampo('CEP', dbedtTRANSP_CEP.Text);
  end;
end;

procedure TfrmManTransportador.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  inherited;
  if (DMAuditoria.fdqryAUDITORIA_REGISTRO.Active) then
    DMAuditoria.fdqryAUDITORIA_REGISTRO.Close;
end;

procedure TfrmManTransportador.FormShow(Sender: TObject);
begin
  vAction := 'act_Cad_Transportador';
  inherited;
  try
    if (Acao = 'I') then
      TGlobal.GetInstance.VerificarRegistrosDemo('TB_TRANSPORTADOR', 'transp_empresa');
  except
    on E : Exception do
    begin
      MessageDlg(TGlobal.GetInstance.TraduzirErro(E.Message, DMTransportador.fdqryTB_TRANSPORTADOR), mtWarning, [mbOK], 0);
      podeFechar := True;
      PostMessage(Self.Handle, WM_CLOSE, 0, 0);
    end;
  end;
  try
    UClassTransportador.IniciarCadastro(Acao, ParametroAbertura);
    AjustarControlesTela();
    if ((Acao = 'I') or (Acao = 'A')) then
      dbcbbtransp_TIPO_PESSOA.SetFocus;
  except
    on E : Exception do
    begin
      MessageDlg(TGlobal.GetInstance.TraduzirErro(E.Message, DMTransportador.fdqryTB_TRANSPORTADOR), mtWarning, [mbOK], 0);
    end;
  end;
end;

procedure TfrmManTransportador.pgcManutencaoChange(Sender: TObject);
begin
  inherited;
  if (pgcManutencao.ActivePage = tsAuditoria) then
  begin
    // Abrir Query Auditoria
    UClassAuditoria.AbrirQueryAuditoriaRegistro('TB_TRANSPORTADOR', DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsString, DMTransportador.fdtransTransportador);
    exit;
  end;

  if (pgcManutencao.ActivePage = tsObservacao) then
  begin
    dbmmoTRANSP_OBSERVACAO.SetFocus;
    Exit;
  end;

end;

end.
