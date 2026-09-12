unit UClassTransportador;

interface

uses UClassGlobal, UDMTransportador, DB, FireDAC.Comp.Client, UDMBase, SysUtils, UClassCidade;

Type
  TTransportador = class
  Protected
    FTranspId                   : Integer;
    FTranspRSocialNome          : string;
    FTranspTipoPessoa           : string;
    FTranspFantasiaApelido      : string;
    FTranspCnpjCpf              : string;
    FTranspIeRg                 : string;
    FTranspEndereco             : string;
    FTranspComplemento          : string;
    FTranspNumero               : string;
    FTranspBairro               : string;
    FTranspCidade               : TCidade;
    FTranspCep                  : string;
    FTranspTelefone             : string;
    FTranspFax                  : string;
    FTranspCelular              : string;
    FTranspEmail                : string;
    FTranspContato              : string;
    FTranspObservacao           : string;
    FTranspDtCadastro           : TDate;
    FTranspDtNascimento         : TDate;
    FTranspStatus               : string;
    FTranspPlaca                : string;
    FTranspPlacaUF              : string;

  Published
    property TranspId              : Integer read FTranspId                 write FTranspId               ;
    property TranspRSocialNome     : string  read FTranspRSocialNome        write FTranspRSocialNome      ;
    property TranspTipoPessoa      : string  read FTranspTipoPessoa         write FTranspTipoPessoa       ;
    property TranspFantasiaApelido : string  read FTranspFantasiaApelido    write FTranspFantasiaApelido  ;
    property TranspCnpjCpf         : string  read FTranspCnpjCpf            write FTranspCnpjCpf          ;
    property TranspIeRg            : string  read FTranspIeRg               write FTranspIeRg             ;
    property TranspEndereco        : string  read FTranspEndereco           write FTranspEndereco         ;
    property TranspComplemento     : string  read FTranspComplemento        write FTranspComplemento      ;
    property TranspNumero          : string  read FTranspNumero             write FTranspNumero           ;
    property TranspBairro          : string  read FTranspBairro             write FTranspBairro           ;
    property TranspCidade          : TCidade read FTranspCidade             write FTranspCidade           ;
    property TranspCep             : string  read FTranspCep                write FTranspCep              ;
    property TranspTelefone        : string  read FTranspTelefone           write FTranspTelefone         ;
    property TranspFax             : string  read FTranspFax                write FTranspFax              ;
    property TranspCelular         : string  read FTranspCelular            write FTranspCelular          ;
    property TranspEmail           : string  read FTranspEmail              write FTranspEmail            ;
    property TranspContato         : string  read FTranspContato            write FTranspContato          ;
    property TranspObservacao      : string  read FTranspObservacao         write FTranspObservacao       ;
    property TranspDtCadastro      : TDate   read FTranspDtCadastro         write FTranspDtCadastro       ;
    property TranspDtNascimento    : TDate   read FTranspDtNascimento       write FTranspDtNascimento     ;
    property TranspStatus          : string  read FTranspStatus             write FTranspStatus           ;
    property TranspPlaca           : string  read FTranspPlaca              write FTranspPlaca            ;
    property TranspPlacaUF         : string  read FTranspPlacaUF            write FTranspPlacaUF          ;
  end;

  procedure AbrirQueryLista();
  procedure FecharQueryLista();
  procedure AbrirQueryPesquisa();
  procedure FecharQueryPesquisa();
  procedure FinalizarCadastro(Botao, Acao: string; AUsaApp: Boolean;
    const ALoginApp, ASenhaApp: string; var AMotoristaAppId: Integer);
  procedure FiltrarQuery(pCampo, pValor: String; pTodaParte: Boolean);
  procedure IniciarCadastro(Acao: string; pAbertura: TParametro);
  procedure AbrirQuery(pAbertura: TParametro);
  function ExisteCNPJCPF(pCliente: Integer; pCNPJ: string): Boolean;
  function RetornarDadosTransportador(pTransportador: Integer; pCNPJCPF: String = ''): TTransportador;
  function RetornaQueryPesquisa : TFDQuery;

  procedure ExportarTranspEmpresasHeranca();
  procedure ExcluirTranspEmpresaHeranca();

  function IncluirTransportador(pObjTransportador: TTransportador; pTransacao: TFDTransaction) : Integer;

  var
    // Querys para Lançar a Auditoria
    QryAnterior, QryNovo: TFDQuery;

implementation

uses UClassAuditoria, UClassEmpresa, UDMEmpresa, UClassExportarCadastro,
  UClassMotoristaApp;

procedure AbrirQueryLista;
begin
  DMTransportador.fdqryLista_TRANSPORTADOR.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
  DMTransportador.fdqryLista_TRANSPORTADOR.Open();
end;

procedure FecharQueryLista;
begin
  DMTransportador.fdqryLista_TRANSPORTADOR.Close;
  if (DMTransportador.fdtransTransportador.Active) then
    DMTransportador.fdtransTransportador.Commit;
end;

procedure AbrirQueryPesquisa;
begin
  DMTransportador.fdqryPESQUISA_TRANSPORTADOR.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
  DMTransportador.fdqryPESQUISA_TRANSPORTADOR.Open();
end;

procedure FecharQueryPesquisa;
begin
  DMTransportador.fdqryPESQUISA_TRANSPORTADOR.Close;
  if (DMTransportador.fdtransTransportador.Active) then
    DMTransportador.fdtransTransportador.Commit;
end;

procedure FiltrarQuery(pCampo, pValor: String; pTodaParte: Boolean);
var
  SqlPadrao: String;
begin
  DMTransportador.fdqryLista_TRANSPORTADOR.Close;
  SqlPadrao := TGlobal.GetInstance.RetornarCorpoSql(DMTransportador.fdqryLista_TRANSPORTADOR);
  DMTransportador.fdqryLista_TRANSPORTADOR.SQL.Clear;
  DMTransportador.fdqryLista_TRANSPORTADOR.SQL.Add(SqlPadrao);
  DMTransportador.fdqryLista_TRANSPORTADOR.SQL.Add(' where ( tb_transportador.transp_empresa = '+IntToStr(TGlobal.GetInstance.EmpId)+' )');
  if (pValor <> EmptyStr) then
    DMTransportador.fdqryLista_TRANSPORTADOR.SQL.Add(' and (UPPER('+pCampo+') like ' + QuotedStr(Trim(TGlobal.GetInstance.iif(pTodaParte, '%'+pValor, pValor))+ '%')+')');
  DMTransportador.fdqryLista_TRANSPORTADOR.SQL.Add(' order by tb_transportador.transp_id desc');
  DMTransportador.fdqryLista_TRANSPORTADOR.Open();
end;

procedure AbrirQuery(pAbertura: TParametro);
begin
  UClassCidade.AbrirQueryLista;
  DMTransportador.fdqryTB_TRANSPORTADOR.Close;
  DMTransportador.fdqryTB_TRANSPORTADOR.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
  DMTransportador.fdqryTB_TRANSPORTADOR.ParamByName('transp_id').AsInteger := pAbertura.pInteger01;
  DMTransportador.fdqryTB_TRANSPORTADOR.Open;
end;

procedure FinalizarCadastro(Botao, Acao: string; AUsaApp: Boolean;
  const ALoginApp, ASenhaApp: string; var AMotoristaAppId: Integer);
var
  vTranspID, vTranspNome: string; // Variavel para armazenar ID e Nome para Auditoria
begin
  if (Botao = 'CON') then
  begin
    vTranspID := DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsString;
    vTranspNome := DMTransportador.fdqryTB_TRANSPORTADORTRANSP_RSOCIAL_NOME.AsString;
    if (Acao = 'I') or (Acao = 'A') or (Acao = 'V') then
    begin
      if (DMTransportador.fdqryTB_TRANSPORTADOR.State in [dsEdit, dsInsert]) then
        DMTransportador.fdqryTB_TRANSPORTADOR.Post;

      if (Acao = 'I') or (Acao = 'A') then
        UClassMotoristaApp.SalvarAcessoTransportador(
          DMTransportador.fdqryTB_TRANSPORTADORTRANSP_EMPRESA.AsInteger,
          DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger,
          DMTransportador.fdqryTB_TRANSPORTADORTRANSP_RSOCIAL_NOME.AsString,
          ALoginApp, ASenhaApp, AUsaApp, AMotoristaAppId,
          TGlobal.GetInstance.UsuId, DMTransportador.fdtransTransportador);

      // Exportar grupo para empresas que herdam dessa
      if (Acao = 'I') or (Acao = 'A') then
        UClassTransportador.ExportarTranspEmpresasHeranca();
    end
    else
    if (Acao = 'E') then
    begin
    // Excluir transportador das Empresas que herdam dessa
      UClassTransportador.ExcluirTranspEmpresaHeranca();
      DMTransportador.fdqryTB_TRANSPORTADOR.Delete;
    end;
    // Auditar se for diferente de Visualizar
    if (Acao <> 'V') then
    begin
      QryNovo := DMTransportador.fdqryTB_TRANSPORTADOR;
      UClassAuditoria.AuditarQuery('TB_TRANSPORTADOR', 'TRANSPORTADORES', vTranspID, vTranspNome, Acao, getNow, QryAnterior, QryNovo, DMTransportador.fdtransTransportador, TGlobal.GetInstance.UsuId);
    end;
    if (DMTransportador.fdtransTransportador.Active) then
      DMTransportador.fdtransTransportador.Commit;
  end;
  if (Botao = 'CAN') then
  begin
    if (DMTransportador.fdqryTB_TRANSPORTADOR.State in [dsEdit]) then
      DMTransportador.fdqryTB_TRANSPORTADOR.Cancel;
    if (DMTransportador.fdtransTransportador.Active) then
      DMTransportador.fdtransTransportador.Rollback;
  end;
  DMTransportador.fdqryTB_TRANSPORTADOR.Close;
  UClassCidade.FecharQueryLista;
  // Fehar Query que mostra auditoria do registro
  UClassAuditoria.FecharQueryAuditoriaRegistro;
end;

procedure IniciarCadastro(Acao: string; pAbertura: TParametro);
begin
  DMTransportador.fdtransTransportador.StartTransaction;
  DMTransportador.fdqryTB_TRANSPORTADOR.Close;
  if (Acao = 'I') then
  begin
    // 1 - Abrir o dataset
    pAbertura.pInteger01 := 0;
    AbrirQuery(pAbertura);

    // 2 - Incluir o novo registro
    DMTransportador.fdqryTB_TRANSPORTADOR.Insert;

    // 3 - Buscar o ultimo sequencial e empresa
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_EMPRESA.AsInteger := TGlobal.GetInstance.EmpId;
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger := TGlobal.GetInstance.proximoID('TB_TRANSPORTADOR');

    // 4 - Preecher os campos chave
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_DT_CADASTRO.AsDateTime := getDate;
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_STATUS.AsString := 'A';
    DMTransportador.fdqryTB_TRANSPORTADORTRANSP_TIPO_PESSOA.AsString := 'F';

  end;
  if (Acao = 'A') then
  begin
    // 1 - Abrir o dataset
    AbrirQuery(pAbertura);
    // 2 - Colocar o dataset em modo de edição
    DMTransportador.fdqryTB_TRANSPORTADOR.Edit;

    // Copiar Query para Auditar
    QryAnterior := TFDQuery.Create(nil);
    QryAnterior.Connection := DMBase.fdconBase;
    QryAnterior.Transaction := DMTransportador.fdtransTransportador;
    QryAnterior.Close;
    QryAnterior.SQL.Clear;
    QryAnterior.SQL.Text := DMTransportador.fdqryTB_TRANSPORTADOR.SQL.Text;
    QryAnterior.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
    QryAnterior.ParamByName('transp_id').AsInteger := pAbertura.pInteger01;
    QryAnterior.Open;

  end;
  if (Acao = 'E') or (Acao = 'V') then
  begin
    // 1 - Abrir o dataset
    AbrirQuery(pAbertura);
  end;
end;

function ExisteCNPJCPF(pCliente: Integer; pCNPJ: string): Boolean;
var
  Query: TFDQuery;
  existe: Boolean;
begin
  Query := TFDQuery.Create(nil);
  existe := False;
  try
    Query.Connection := DMBase.fdconBase;
    Query.Transaction := DMTransportador.fdtransTransportador;
    Query.Close;
    Query.SQL.Clear;
    Query.SQL.Add('select '''' from tb_transportador ');
    Query.SQL.Add('where ');
    Query.SQL.Add('  (tb_transportador.transp_empresa = :transp_empresa) and ');
    Query.SQL.Add('  (tb_transportador.transp_id <> :cli_id) and ');
    Query.SQL.Add('  (tb_transportador.transp_cpf_cnpj = :transp_cpf_cnpj) ');
    Query.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
   // Query.ParamByName('transp_id').AsInteger := pCliente;
    Query.ParamByName('transp_cpf_cnpj').AsString := pCNPJ;
    Query.Open;
    if (Query.RecordCount > 0) then
      existe := True;
    Query.Close;
  finally
    FreeAndNil(Query);
  end;
  Result := existe;
end;

function RetornarDadosTransportador(pTransportador: Integer; pCNPJCPF: String = ''): TTransportador;
var
  Query: TFDQuery;
  vObjTransportador: TTransportador;
begin
  vObjTransportador := TTransportador.Create;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := DMBase.fdconBase;
    Query.Transaction := DMTransportador.fdtransTransportador;
    Query.Close;
    Query.SQL.Clear;
    Query.SQL.Add('select                                             ');
    Query.SQL.Add('    tb_transportador.transp_empresa,               ');
    Query.SQL.Add('    tb_transportador.transp_id,                    ');
    Query.SQL.Add('    tb_transportador.transp_rsocial_nome,          ');
    Query.SQL.Add('    tb_transportador.transp_fantasia,              ');
    Query.SQL.Add('    tb_transportador.transp_cpf_cnpj,              ');
    Query.SQL.Add('    tb_transportador.transp_ie_rg,                 ');
    Query.SQL.Add('    tb_transportador.transp_dt_cadastro,           ');
    Query.SQL.Add('    tb_transportador.transp_email,                 ');
    Query.SQL.Add('    tb_transportador.transp_endereco,              ');
    Query.SQL.Add('    tb_transportador.transp_telefone,              ');
    Query.SQL.Add('    tb_transportador.transp_fax,                   ');
    Query.SQL.Add('    tb_transportador.transp_cidade,                ');
    Query.SQL.Add('    tb_transportador.transp_obs,                   ');
    Query.SQL.Add('    tb_transportador.transp_tipo_pessoa,           ');
    Query.SQL.Add('    tb_transportador.transp_placa,                 ');
    Query.SQL.Add('    tb_transportador.transp_placa_uf,              ');
    Query.SQL.Add('    tb_transportador.transp_status,                ');
    Query.SQL.Add('    tb_transportador.transp_cep,                   ');
    Query.SQL.Add('    tb_transportador.transp_numero,                ');
    Query.SQL.Add('    tb_transportador.transp_complemento,           ');
    Query.SQL.Add('    tb_transportador.transp_bairro,                ');
    Query.SQL.Add('    tb_transportador.transp_contato,               ');
    Query.SQL.Add('    tb_transportador.transp_celular                ');
    Query.SQL.Add('from tb_transportador                                    ');
    Query.SQL.Add('where                                                     ');
    Query.SQL.Add('      (tb_transportador.transp_empresa = :transp_empresa) ');

    if (pTransportador > 0) then
      Query.SQL.Add('   and (tb_transportador.transp_id = :transp_id)         ');

    if (pCNPJCPF <> EmptyStr) then
    begin
      Query.SQL.Add('   and (tb_transportador.transp_cpf_cnpj = :transp_cpf_cnpj) ');
      Query.SQL.Add(' order by tb_transportador.transp_status                         ');
    end;

    Query.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;

    if (pTransportador > 0) then
      Query.ParamByName('transp_id').AsInteger := pTransportador;

    if (pCNPJCPF <> EmptyStr) then
      Query.ParamByName('transp_cpf_cnpj').AsString := pCNPJCPF;

    Query.Open;
    if (Query.RecordCount > 0) then
    begin
      vObjTransportador.TranspId              :=   Query.FieldByName('transp_id').AsInteger;
      vObjTransportador.TranspRSocialNome     :=   Query.FieldByName('transp_rsocial_nome').AsString;
      vObjTransportador.TranspTipoPessoa      :=   Query.FieldByName('transp_tipo_pessoa').AsString;
      vObjTransportador.TranspFantasiaApelido :=   Query.FieldByName('transp_fantasia').AsString;
      vObjTransportador.TranspCnpjCpf         :=   Query.FieldByName('transp_cpf_cnpj').AsString;
      vObjTransportador.TranspIeRg            :=   Query.FieldByName('transp_ie_rg').AsString;
      vObjTransportador.TranspEndereco        :=   Query.FieldByName('transp_endereco').AsString;
      vObjTransportador.TranspComplemento     :=   Query.FieldByName('transp_complemento').AsString;
      vObjTransportador.TranspNumero          :=   Query.FieldByName('transp_numero').AsString;
      vObjTransportador.TranspBairro          :=   Query.FieldByName('transp_bairro').AsString;
      vObjTransportador.TranspCidade          :=   UClassCidade.RetornarDadosCidade(Query.FieldByName('transp_cidade').AsInteger, EmptyStr);
      vObjTransportador.TranspCep             :=   Query.FieldByName('transp_cep').AsString;
      vObjTransportador.TranspTelefone        :=   Query.FieldByName('transp_telefone').AsString;
      vObjTransportador.TranspFax             :=   Query.FieldByName('transp_fax').AsString;
      vObjTransportador.TranspCelular         :=   Query.FieldByName('transp_celular').AsString;
      vObjTransportador.TranspEmail           :=   Query.FieldByName('transp_email').AsString;
      vObjTransportador.TranspContato         :=   Query.FieldByName('transp_contato').AsString;
      vObjTransportador.TranspDtCadastro      :=   Query.FieldByName('transp_dt_cadastro').AsDateTime;
      vObjTransportador.TranspStatus          :=   Query.FieldByName('transp_status').AsString;
      vObjTransportador.TranspPlaca           :=   Query.FieldByName('transp_placa').AsString;
      vObjTransportador.TranspPlacaUF         :=   Query.FieldByName('transp_placa_uf').AsString;
    end
    else
      vObjTransportador.FTranspId := 0;

    Query.Close;
  finally
    FreeAndNil(Query);
  end;
  Result := vObjTransportador;
end;

function RetornaQueryPesquisa : TFDQuery;
begin
  DMTransportador.fdqryPESQUISA_TRANSPORTADOR.ParamByName('transp_empresa').AsInteger := TGlobal.GetInstance.EmpId;
  Result := DMTransportador.fdqryPESQUISA_TRANSPORTADOR;
end;

procedure ExportarTranspEmpresasHeranca();
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := DMBase.fdconBase;
    Query.Transaction := DMTransportador.fdtransTransportador;
    Query.Close;
    Query.SQL.Clear;

    Query.SQL.Add(' update or insert into TB_TRANSPORTADOR (TRANSP_EMPRESA, TRANSP_ID, TRANSP_RSOCIAL_NOME, TRANSP_FANTASIA,                  ');
    Query.SQL.Add('                                         TRANSP_CPF_CNPJ, TRANSP_IE_RG, TRANSP_DT_CADASTRO, TRANSP_EMAIL,                  ');
    Query.SQL.Add('                                         TRANSP_ENDERECO, TRANSP_FAX, TRANSP_CIDADE, TRANSP_OBS, TRANSP_TIPO_PESSOA,       ');
    Query.SQL.Add('                                         TRANSP_PLACA, TRANSP_STATUS, TRANSP_CEP, TRANSP_NUMERO, TRANSP_COMPLEMENTO,       ');
    Query.SQL.Add('                                         TRANSP_BAIRRO, TRANSP_CONTATO, TRANSP_TELEFONE, TRANSP_CELULAR, TRANSP_PLACA_UF)  ');
    Query.SQL.Add(' values (:TRANSP_EMPRESA, :TRANSP_ID, :TRANSP_RSOCIAL_NOME, :TRANSP_FANTASIA, :TRANSP_CPF_CNPJ, :TRANSP_IE_RG,             ');
    Query.SQL.Add('         :TRANSP_DT_CADASTRO, :TRANSP_EMAIL, :TRANSP_ENDERECO, :TRANSP_FAX, :TRANSP_CIDADE, :TRANSP_OBS,                   ');
    Query.SQL.Add('         :TRANSP_TIPO_PESSOA, :TRANSP_PLACA, :TRANSP_STATUS, :TRANSP_CEP, :TRANSP_NUMERO, :TRANSP_COMPLEMENTO,             ');
    Query.SQL.Add('         :TRANSP_BAIRRO, :TRANSP_CONTATO, :TRANSP_TELEFONE, :TRANSP_CELULAR, :TRANSP_PLACA_UF)                             ');
    Query.SQL.Add(' matching (TRANSP_EMPRESA, TRANSP_ID)                                                                                      ');

    // Abrir Query de empresas que herdam dessa
    UClassEmpresa.AbrirQueryEmpresaHeranca(TGlobal.GetInstance.EmpId);
    // Verificar se existem empresas que herdam
    if not(DMEmpresa.fdqryEMPRESAS_HERANCA.RecordCount > 0) then
      Exit;
    // Percorre Empresas
    DMEmpresa.fdqryEMPRESAS_HERANCA.First;
    while not(DMEmpresa.fdqryEMPRESAS_HERANCA.Eof) do
    begin
      if (DMEmpresa.fdqryEMPRESAS_HERANCAEMPC_HERDA_TRANSPORTADOR.AsString = 'S') then
        UClassExportarCadastro.ExportarCadastro(Query, DMTransportador.fdqryTB_TRANSPORTADOR, 'TRANSP_EMPRESA', DMEmpresa.fdqryEMPRESAS_HERANCAEMPC_EMPRESA.AsInteger);
      DMEmpresa.fdqryEMPRESAS_HERANCA.Next;
    end;
  finally
    FreeAndNil(Query);
  end;
end;

procedure ExcluirTranspEmpresaHeranca();
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := DMBase.fdconBase;
    Query.Transaction := DMTransportador.fdtransTransportador;
    Query.Close;
    Query.SQL.Clear;

    Query.SQL.Add(' delete from TB_TRANSPORTADOR         ');
    Query.SQL.Add(' where (TRANSP_EMPRESA = :empresa) and   ');
    Query.SQL.Add('       (TRANSP_ID = :codigo)             ');

    // Abrir Query de empresas que herdam dessa
    UClassEmpresa.AbrirQueryEmpresaHeranca(TGlobal.GetInstance.EmpId);
    // Verificar se existem empresas que herdam
    if not(DMEmpresa.fdqryEMPRESAS_HERANCA.RecordCount > 0) then
      Exit;
    // Percorre Empresas
    DMEmpresa.fdqryEMPRESAS_HERANCA.First;
    while not(DMEmpresa.fdqryEMPRESAS_HERANCA.Eof) do
    begin
      if (DMEmpresa.fdqryEMPRESAS_HERANCAEMPC_HERDA_TRANSPORTADOR.AsString = 'S') then
        UClassExportarCadastro.ExcluirCadastro(Query, DMEmpresa.fdqryEMPRESAS_HERANCAEMPC_EMPRESA.AsInteger, DMTransportador.fdqryTB_TRANSPORTADORTRANSP_ID.AsInteger);
      DMEmpresa.fdqryEMPRESAS_HERANCA.Next;
    end;
    UClassEmpresa.FecharQueryEmpresaHeranca();
  finally
    FreeAndNil(Query);
  end;
end;

function IncluirTransportador(pObjTransportador: TTransportador; pTransacao: TFDTransaction) : Integer;
var
  Query: TFDQuery;
  vTransportadorId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := DMBase.fdconBase;
    Query.Transaction := pTransacao;
    Query.Close;
    Query.SQL.Clear;
    Query.SQL.Add('     insert into TB_TRANSPORTADOR (TRANSP_ID, TRANSP_EMPRESA, TRANSP_RSOCIAL_NOME, TRANSP_FANTASIA, TRANSP_CPF_CNPJ,     ');
    Query.SQL.Add('                               TRANSP_IE_RG, TRANSP_DT_CADASTRO, TRANSP_EMAIL, TRANSP_ENDERECO, TRANSP_FAX,              ');
    Query.SQL.Add('                               TRANSP_CIDADE, TRANSP_OBS, TRANSP_TIPO_PESSOA, TRANSP_PLACA, TRANSP_STATUS, TRANSP_CEP,   ');
    Query.SQL.Add('                               TRANSP_NUMERO, TRANSP_COMPLEMENTO, TRANSP_BAIRRO, TRANSP_CONTATO, TRANSP_TELEFONE,        ');
    Query.SQL.Add('                               TRANSP_CELULAR, TRANSP_PLACA_UF)                                                          ');
    Query.SQL.Add(' values (:TRANSP_ID, :TRANSP_EMPRESA, :TRANSP_RSOCIAL_NOME, :TRANSP_FANTASIA, :TRANSP_CPF_CNPJ, :TRANSP_IE_RG,           ');
    Query.SQL.Add('         :TRANSP_DT_CADASTRO, :TRANSP_EMAIL, :TRANSP_ENDERECO, :TRANSP_FAX, :TRANSP_CIDADE, :TRANSP_OBS,                 ');
    Query.SQL.Add('         :TRANSP_TIPO_PESSOA, :TRANSP_PLACA, :TRANSP_STATUS, :TRANSP_CEP, :TRANSP_NUMERO, :TRANSP_COMPLEMENTO,           ');
    Query.SQL.Add('         :TRANSP_BAIRRO, :TRANSP_CONTATO, :TRANSP_TELEFONE, :TRANSP_CELULAR, :TRANSP_PLACA_UF)                           ');

    vTransportadorId := TGlobal.GetInstance.proximoID('TB_TRANSPORTADOR');  //pObjTransportador.TranspId;
    Query.ParamByName('TRANSP_EMPRESA').AsInteger         := TGlobal.GetInstance.EmpId;
    Query.ParamByName('TRANSP_ID').AsInteger              := vTransportadorId;
    Query.ParamByName('TRANSP_RSOCIAL_NOME').AsString     := pObjTransportador.TranspRSocialNome;
    Query.ParamByName('TRANSP_FANTASIA').AsString         := pObjTransportador.TranspFantasiaApelido;
    Query.ParamByName('TRANSP_CPF_CNPJ').AsString         := pObjTransportador.TranspCnpjCpf;
    Query.ParamByName('TRANSP_IE_RG').AsString            := pObjTransportador.TranspIeRg;
    Query.ParamByName('TRANSP_DT_CADASTRO').AsDate        := pObjTransportador.TranspDtCadastro;
    Query.ParamByName('TRANSP_EMAIL').AsString            := pObjTransportador.TranspEmail;
    Query.ParamByName('TRANSP_ENDERECO').AsString         := pObjTransportador.TranspEndereco;
    Query.ParamByName('TRANSP_FAX').AsString              := pObjTransportador.TranspFax;
    if Assigned(pObjTransportador.TranspCidade) then
      Query.ParamByName('TRANSP_CIDADE').AsInteger          := pObjTransportador.TranspCidade.CidId
    else
      Query.ParamByName('TRANSP_CIDADE').clear;
    Query.ParamByName('TRANSP_OBS').AsString              := pObjTransportador.TranspObservacao;
    Query.ParamByName('TRANSP_PLACA').AsString            := pObjTransportador.TranspPlaca;
    Query.ParamByName('TRANSP_STATUS').AsString           := pObjTransportador.TranspStatus;
    Query.ParamByName('TRANSP_CEP').AsString              := pObjTransportador.TranspCep;
    Query.ParamByName('TRANSP_NUMERO').AsString           := pObjTransportador.TranspNumero;
    Query.ParamByName('TRANSP_COMPLEMENTO').AsString      := pObjTransportador.TranspComplemento;
    Query.ParamByName('TRANSP_BAIRRO').AsString           := pObjTransportador.TranspBairro;
    Query.ParamByName('TRANSP_CONTATO').AsString          := pObjTransportador.TranspContato;
    Query.ParamByName('TRANSP_TELEFONE').AsString         := pObjTransportador.TranspTelefone;
    Query.ParamByName('TRANSP_CELULAR').AsString          := pObjTransportador.TranspCelular;
    Query.ParamByName('TRANSP_PLACA_UF').AsString         := pObjTransportador.TranspPlacaUF;

    Query.ExecSQL;
//    if (pTransacao.Active) then
//      pTransacao.CommitRetaining;
    Query.Close;
  finally
    FreeAndNil(Query);
  end;
  Result := vTransportadorId;
end;


end.
