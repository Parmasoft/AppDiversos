unit UClassConfereCarga;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  UDMConfereCarga;

type
  TConfereCarga = class
  private
    class procedure LiberarManifestoParaMotoristaApp(
      AQry: TFDQuery;
      const AEmpresa, ACarga, AConferencia, AManifesto, AUsuario: Integer
    );
  public
    class function GerarConferencia(
      const AEmpresa, APedidoVenda, AUsuario: Integer;
      out ACfcId: Integer;
      out AMensagem: string
    ): Boolean;

    class function RegistrarLeitura(
      const AEmpresa, ACfcId: Integer;
      const ACodigoLido: string;
      const AUsuario: Integer;
      out AMensagem: string
    ): Boolean;

    class function RegistrarLeituraPedidoC(
      const AEmpresa, ACfcId: Integer;
      const ACodigoLido: string;
      const AUsuario: Integer;
      out AMensagem: string
    ): Boolean;

    class function FinalizarConferencia(
      const AEmpresa, ACfcId, AUsuario: Integer;
      out AMensagem: string
    ): Boolean;

    class procedure AbrirDadosConferencia(
      const AEmpresa, ACfcId: Integer
    );

    class function GerarConferenciaCarga(const AEmpresa, ACarga: Integer): Integer;

    class function IncluirPedidoConferencia(
      AEmpresa, ACfcgId, APedido, AUsuario: Integer;
      out AMensagem: string): Boolean;

    class function LimparPedidoConferencia(
      AEmpresa, ACfcgId, APedido, AUsuario: Integer;
      out AMensagem: string): Boolean;

    class function DeletarPedidoConferencia(
      AEmpresa, ACfcgId, APedido, AUsuario: Integer;
      out AMensagem: string): Boolean;

    class procedure SincronizarPedidosDaCarga(
      AEmpresa, ACfcgId, ACarga, AUsuario: Integer;
      out AMensagemAviso: string);

  end;

implementation

{ TConfereCarga }

class procedure TConfereCarga.LiberarManifestoParaMotoristaApp(
  AQry: TFDQuery;
  const AEmpresa, ACarga, AConferencia, AManifesto, AUsuario: Integer
);
var
  vTransportador: Integer;
  vMotorista: Integer;
  vMotoristaManifesto: Integer;
  vManifestoTemMotorista: Boolean;
  vMotoristaAtivo: string;
  vStatusManifesto: string;
begin
  if AManifesto <= 0 then
    raise Exception.Create('Manifesto da carga nao foi gerado.');

  AQry.Close;
  AQry.SQL.Clear;
  AQry.SQL.Add('SELECT CARGM_STATUS, CARGM_MOTORISTA_APP');
  AQry.SQL.Add('FROM TB_CARGA_MANIFESTO');
  AQry.SQL.Add('WHERE CARGM_EMPRESA = :EMPRESA');
  AQry.SQL.Add('  AND CARGM_ID = :MANIFESTO');
  AQry.SQL.Add('  AND CARGM_CARGA = :CARGA');
  AQry.SQL.Add('  AND CARGM_CONFERENCIA = :CONFERENCIA');
  AQry.ParamByName('EMPRESA').AsInteger := AEmpresa;
  AQry.ParamByName('MANIFESTO').AsInteger := AManifesto;
  AQry.ParamByName('CARGA').AsInteger := ACarga;
  AQry.ParamByName('CONFERENCIA').AsInteger := AConferencia;
  AQry.Open;

  if AQry.IsEmpty then
    raise Exception.Create('Manifesto da carga nao encontrado apos o fechamento.');

  vStatusManifesto := Trim(AQry.FieldByName('CARGM_STATUS').AsString);
  vManifestoTemMotorista := not AQry.FieldByName('CARGM_MOTORISTA_APP').IsNull;
  if vManifestoTemMotorista then
    vMotoristaManifesto := AQry.FieldByName('CARGM_MOTORISTA_APP').AsInteger
  else
    vMotoristaManifesto := 0;

  AQry.Close;
  AQry.SQL.Clear;
  AQry.SQL.Add('SELECT CARG_TRANSPORTADOR');
  AQry.SQL.Add('FROM TB_CARGA');
  AQry.SQL.Add('WHERE CARG_EMPRESA = :EMPRESA');
  AQry.SQL.Add('  AND CARG_ID = :CARGA');
  AQry.ParamByName('EMPRESA').AsInteger := AEmpresa;
  AQry.ParamByName('CARGA').AsInteger := ACarga;
  AQry.Open;

  if AQry.IsEmpty then
    raise Exception.Create('Carga nao encontrada para liberar o Manifesto.');

  if AQry.FieldByName('CARG_TRANSPORTADOR').IsNull then
  begin
    AQry.Close;
    Exit;
  end;

  vTransportador := AQry.FieldByName('CARG_TRANSPORTADOR').AsInteger;
  if vTransportador <= 0 then
  begin
    AQry.Close;
    Exit;
  end;

  AQry.Close;
  AQry.SQL.Clear;
  AQry.SQL.Add('SELECT E.MOTAPPE_MOTORISTA, M.MOTAPP_ATIVO');
  AQry.SQL.Add('FROM TB_MOTORISTA_APP_EMPRESA E');
  AQry.SQL.Add('JOIN TB_MOTORISTA_APP M');
  AQry.SQL.Add('  ON M.MOTAPP_ID = E.MOTAPPE_MOTORISTA');
  AQry.SQL.Add('WHERE E.MOTAPPE_EMPRESA = :EMPRESA');
  AQry.SQL.Add('  AND E.MOTAPPE_TRANSPORTADOR = :TRANSPORTADOR');
  AQry.SQL.Add('  AND E.MOTAPPE_ATIVO = ''S''');
  AQry.ParamByName('EMPRESA').AsInteger := AEmpresa;
  AQry.ParamByName('TRANSPORTADOR').AsInteger := vTransportador;
  AQry.Open;

  if AQry.IsEmpty then
  begin
    AQry.Close;
    Exit;
  end;

  vMotorista := AQry.FieldByName('MOTAPPE_MOTORISTA').AsInteger;
  vMotoristaAtivo := Trim(AQry.FieldByName('MOTAPP_ATIVO').AsString);
  AQry.Next;
  if not AQry.Eof then
    raise Exception.CreateFmt(
      'Mais de um Motorista App ativo esta vinculado ao transportador %d na empresa %d.',
      [vTransportador, AEmpresa]
    );

  if not SameText(vMotoristaAtivo, 'S') then
    raise Exception.CreateFmt(
      'O Motorista App %d vinculado ao transportador %d esta inativo.',
      [vMotorista, vTransportador]
    );

  if SameText(vStatusManifesto, 'G') then
  begin
    AQry.Close;
    AQry.SQL.Clear;
    AQry.SQL.Add('SELECT *');
    AQry.SQL.Add('FROM SP_LIBERA_CARGA_MANIFESTO(');
    AQry.SQL.Add('  :EMPRESA, :MANIFESTO, :MOTORISTA, :USUARIO)');
    AQry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    AQry.ParamByName('MANIFESTO').AsInteger := AManifesto;
    AQry.ParamByName('MOTORISTA').AsInteger := vMotorista;
    AQry.ParamByName('USUARIO').AsInteger := AUsuario;
    AQry.Open;

    if AQry.IsEmpty then
      raise Exception.Create('SP_LIBERA_CARGA_MANIFESTO nao retornou resultado.');

    if not SameText(AQry.FieldByName('RETORNO').AsString, 'OK') then
      raise Exception.Create(AQry.FieldByName('MENSAGEM').AsString);

    AQry.Close;
    Exit;
  end;

  if SameText(vStatusManifesto, 'L') or SameText(vStatusManifesto, 'F') then
  begin
    if (not vManifestoTemMotorista) or (vMotoristaManifesto <> vMotorista) then
      raise Exception.CreateFmt(
        'Manifesto %d ja esta atribuido a outro Motorista App.',
        [AManifesto]
      );

    AQry.Close;
    Exit;
  end;

  raise Exception.CreateFmt(
    'Status %s do Manifesto %d nao permite liberacao para o App.',
    [vStatusManifesto, AManifesto]
  );
end;

class function TConfereCarga.IncluirPedidoConferencia(
  AEmpresa, ACfcgId, APedido, AUsuario: Integer;
  out AMensagem: string): Boolean;
var
  qry: TFDQuery;
begin
  Result := False;
  AMensagem := '';

  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qry.SQL.Clear;
    qry.SQL.Add('select * from SP_INC_PEDIDO_CONF_CARGA(:EMPRESA, :CONFERE_CARGA, :PEDIDO, :USUARIO)');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('CONFERE_CARGA').AsInteger := ACfcgId;
    qry.ParamByName('PEDIDO').AsInteger := APedido;
    qry.ParamByName('USUARIO').AsInteger := AUsuario;

    qry.Open;

    AMensagem := qry.FieldByName('MENSAGEM').AsString;
    Result := qry.FieldByName('RETORNO').AsString = 'OK';

  finally
    qry.Free;
  end;
end;

class function TConfereCarga.LimparPedidoConferencia(
  AEmpresa, ACfcgId, APedido, AUsuario: Integer;
  out AMensagem: string): Boolean;
var
  qry: TFDQuery;
begin
  Result := False;
  AMensagem := '';

  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qry.SQL.Clear;
    qry.SQL.Add('SELECT *');
    qry.SQL.Add('FROM SP_LIMPA_PEDIDO_CONF_CARGA(:EMPRESA, :CONFERE_CARGA, :PEDIDO, :USUARIO)');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('CONFERE_CARGA').AsInteger := ACfcgId;
    qry.ParamByName('PEDIDO').AsInteger := APedido;
    qry.ParamByName('USUARIO').AsInteger := AUsuario;

    qry.Open;

    AMensagem := qry.FieldByName('MENSAGEM').AsString;
    Result := SameText(qry.FieldByName('RETORNO').AsString, 'OK');

  finally
    qry.Free;
  end;
end;

class function TConfereCarga.DeletarPedidoConferencia(
  AEmpresa, ACfcgId, APedido, AUsuario: Integer;
  out AMensagem: string): Boolean;
var
  qry: TFDQuery;
begin
  Result := False;
  AMensagem := '';

  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qry.SQL.Clear;
    qry.SQL.Add('SELECT *');
    qry.SQL.Add('FROM SP_DEL_PEDIDO_CONF_CARGA(:EMPRESA, :CONFERE_CARGA, :PEDIDO, :USUARIO)');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('CONFERE_CARGA').AsInteger := ACfcgId;
    qry.ParamByName('PEDIDO').AsInteger := APedido;
    qry.ParamByName('USUARIO').AsInteger := AUsuario;

    qry.Open;

    AMensagem := qry.FieldByName('MENSAGEM').AsString;
    Result := SameText(qry.FieldByName('RETORNO').AsString, 'OK');

  finally
    qry.Free;
  end;
end;

class function TConfereCarga.GerarConferencia(
  const AEmpresa, APedidoVenda, AUsuario: Integer;
  out ACfcId: Integer;
  out AMensagem: string
): Boolean;
var
  qry: TFDQuery;
begin
  Result := False;
  ACfcId := 0;
  AMensagem := '';

  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qry.SQL.Clear;
    qry.SQL.Add('SELECT *');
    qry.SQL.Add('FROM SP_GERA_CONFERE_CARGA(:EMPRESA, :PEDIDO_VENDA, :USUARIO)');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('PEDIDO_VENDA').AsInteger := APedidoVenda;
    qry.ParamByName('USUARIO').AsInteger := AUsuario;

    qry.Open;

    if not qry.IsEmpty then
    begin
      AMensagem := qry.FieldByName('MENSAGEM').AsString;

      if not qry.FieldByName('CFC_ID_GERADO').IsNull then
        ACfcId := qry.FieldByName('CFC_ID_GERADO').AsInteger;

      Result := SameText(qry.FieldByName('RETORNO').AsString, 'OK');
    end;
  finally
    qry.Free;
  end;
end;

class function TConfereCarga.RegistrarLeitura(
    const AEmpresa, ACfcId: Integer;
    const ACodigoLido: string;
    const AUsuario: Integer;
    out AMensagem: string
  ): Boolean;
  var
    qry: TFDQuery;
    vCodigo: string;
  begin
    Result := False;
    AMensagem := '';

    vCodigo := UpperCase(Trim(ACodigoLido));

    // Etiqueta C = etiqueta normal do pedido/conferência.
    // Não passa pela procedure antiga de rolo.
    if Copy(vCodigo, 1, 1) = 'C' then
    begin
      Result := RegistrarLeituraPedidoC(
        AEmpresa,
        ACfcId,
        vCodigo,
        AUsuario,
        AMensagem
      );
      Exit;
    end;


  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qry.SQL.Clear;
    qry.SQL.Add('SELECT *');
    qry.SQL.Add('FROM SP_REG_LEITURA_CARGA(:EMPRESA, :CFC_ID, :CODIGO_LIDO, :USUARIO)');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('CFC_ID').AsInteger := ACfcId;
    //qry.ParamByName('CODIGO_LIDO').AsString := Trim(ACodigoLido);
    qry.ParamByName('CODIGO_LIDO').AsString := vCodigo;
    qry.ParamByName('USUARIO').AsInteger := AUsuario;

    qry.Open;

    if not qry.IsEmpty then
    begin
      AMensagem := qry.FieldByName('MENSAGEM').AsString;
      Result := SameText(qry.FieldByName('RETORNO').AsString, 'OK');
    end;
  finally
    qry.Free;
  end;
end;

class function TConfereCarga.RegistrarLeituraPedidoC(
  const AEmpresa, ACfcId: Integer;
  const ACodigoLido: string;
  const AUsuario: Integer;
  out AMensagem: string
): Boolean;
var
  qryConf: TFDQuery;
  qryItem: TFDQuery;
  qryExec: TFDQuery;
  vCodigo: string;
  vPedidoCodigo: Integer;
  vProdutoCodigo: Integer;
  //vQtdeInt: Integer;
  vQtdeInt: Int64;
  vQuantidade: Double;
  vPedidoConferencia: Integer;
  vSequenciaItem: Integer;
  vItemPedido: Integer;
  vQtdePedido: Double;
  vQtdeCarregada: Double;
  vQtdeFalta: Double;
  vSeqLeitura: Integer;
  vIniciouTransacao: Boolean;
begin
  Result := False;
  AMensagem := '';
  vIniciouTransacao := False;

  vCodigo := UpperCase(Trim(ACodigoLido));

  if not (Length(vCodigo) in [19, 21]) then
  begin
    AMensagem := 'Código inválido !!!';
    Exit;
  end;

  if Copy(vCodigo, 1, 1) <> 'C' then
  begin
    AMensagem := 'Código inválido !!!';
    Exit;
  end;

  vPedidoCodigo := StrToIntDef(Copy(vCodigo, 2, 6), 0);
  vProdutoCodigo := StrToIntDef(Copy(vCodigo, 8, 7), 0);

  if Length(vCodigo) = 19 then
  begin
    vQtdeInt := StrToIntDef(Copy(vCodigo, 15, 5), 0);
    vQuantidade := vQtdeInt / 100;
  end
  else
  begin
    vQtdeInt := StrToIntDef(Copy(vCodigo, 15, 7), 0);
    vQuantidade := vQtdeInt / 10000;
  end;


  if vPedidoCodigo <= 0 then
  begin
    AMensagem := 'Pedido inválido na etiqueta C.';
    Exit;
  end;

  if vProdutoCodigo <= 0 then
  begin
    AMensagem := 'Produto inválido !!!';
    Exit;
  end;

  if vQuantidade <= 0 then
  begin
    AMensagem := 'Quantidade inválida !!!';
    Exit;
  end;

  qryConf := TFDQuery.Create(nil);
  qryItem := TFDQuery.Create(nil);
  qryExec := TFDQuery.Create(nil);
  try
    qryConf.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qryConf.Transaction := DMConfereCarga.fdtransConfereCARGA;

    qryItem.Connection := qryConf.Connection;
    qryItem.Transaction := qryConf.Transaction;

    qryExec.Connection := qryConf.Connection;
    qryExec.Transaction := qryConf.Transaction;

    if not DMConfereCarga.fdtransConfereCARGA.Active then
    begin
      DMConfereCarga.fdtransConfereCARGA.StartTransaction;
      vIniciouTransacao := True;
    end;

    // Busca a conferência aberta e confirma o pedido dela.
    qryConf.SQL.Clear;
    qryConf.SQL.Add('SELECT CFCG_STATUS');
    qryConf.SQL.Add('FROM TB_CONFERE_CARGA');
    qryConf.SQL.Add('WHERE CFCG_EMPRESA = :EMPRESA');
    qryConf.SQL.Add('  AND CFCG_ID = :CFC_ID');

    qryConf.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qryConf.ParamByName('CFC_ID').AsInteger := ACfcId;
    qryConf.Open;

    if qryConf.IsEmpty then
    begin
      AMensagem := 'Conferência não encontrada.';
      if vIniciouTransacao then
        DMConfereCarga.fdtransConfereCARGA.Rollback;
      Exit;
    end;

    if not SameText(Trim(qryConf.FieldByName('CFCG_STATUS').AsString), 'A') then
    begin
      AMensagem := 'Conferência não aberta.';
      if vIniciouTransacao then
        DMConfereCarga.fdtransConfereCARGA.Rollback;
      Exit;
    end;

    // Busca o produto dentro dos itens da conferência de carga.
    qryItem.SQL.Clear;
    qryItem.SQL.Add('SELECT');
    qryItem.SQL.Add('    CFCGI_SEQUENCIA,');
    qryItem.SQL.Add('    CFCGI_ITEM_PEDIDO,');
    qryItem.SQL.Add('    CFCGI_QTDE_PEDIDO,');
    qryItem.SQL.Add('    CFCGI_QTDE_CARREGADA');
    qryItem.SQL.Add('FROM TB_CONFERE_CARGA_ITEM');
    qryItem.SQL.Add('WHERE CFCGI_EMPRESA = :EMPRESA');
    qryItem.SQL.Add('  AND CFCGI_CONFERE_CARGA = :CFC_ID');
    qryItem.SQL.Add('  AND CFCGI_PEDIDO_VENDA = :PEDIDO');
    qryItem.SQL.Add('  AND CFCGI_PRODUTO = :PRODUTO');
    qryItem.SQL.Add('  AND CFCGI_STATUS <> ''C''');

    qryItem.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qryItem.ParamByName('CFC_ID').AsInteger := ACfcId;
    qryItem.ParamByName('PEDIDO').AsInteger := vPedidoCodigo;
    qryItem.ParamByName('PRODUTO').AsInteger := vProdutoCodigo;
    qryItem.Open;

    if qryItem.IsEmpty then
    begin
      AMensagem :=
        'Item ' + IntToStr(vProdutoCodigo) +
        ' não pertence a Carga!';

      if vIniciouTransacao then
        DMConfereCarga.fdtransConfereCarga.Rollback;
      Exit;
    end;

    vSequenciaItem := qryItem.FieldByName('CFCGI_SEQUENCIA').AsInteger;
    vItemPedido := qryItem.FieldByName('CFCGI_ITEM_PEDIDO').AsInteger;
    vQtdePedido := qryItem.FieldByName('CFCGI_QTDE_PEDIDO').AsFloat;
    vQtdeCarregada := qryItem.FieldByName('CFCGI_QTDE_CARREGADA').AsFloat;
    vQtdeFalta := vQtdePedido - vQtdeCarregada;

    if vQuantidade > (vQtdeFalta + 0.0001) then
    begin
      
      AMensagem := 'ITEM JÁ COLETADO.';

      if vIniciouTransacao then
        DMConfereCarga.fdtransConfereCarga.Rollback;
      Exit;
    end;

    // Próxima sequência da leitura.
    qryExec.SQL.Clear;
    qryExec.SQL.Add('SELECT COALESCE(MAX(CFCGL_SEQUENCIA), 0) + 1 AS PROX');
    qryExec.SQL.Add('FROM TB_CONFERE_CARGA_LEITURA');
    qryExec.SQL.Add('WHERE CFCGL_EMPRESA = :EMPRESA');
    qryExec.SQL.Add('  AND CFCGL_CONFERE_CARGA = :CFC_ID');

    qryExec.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qryExec.ParamByName('CFC_ID').AsInteger := ACfcId;
    qryExec.Open;

    vSeqLeitura := qryExec.FieldByName('PROX').AsInteger;
    qryExec.Close;

    // Grava leitura C.
    qryExec.SQL.Clear;
    qryExec.SQL.Add('INSERT INTO TB_CONFERE_CARGA_LEITURA (');

    qryExec.SQL.Add('    CFCGL_EMPRESA,');
    qryExec.SQL.Add('    CFCGL_CONFERE_CARGA,');
    qryExec.SQL.Add('    CFCGL_SEQUENCIA,');
    qryExec.SQL.Add('    CFCGL_ITEM_CONFERE,');
    qryExec.SQL.Add('    CFCGL_PEDIDO_VENDA,');
    qryExec.SQL.Add('    CFCGL_ITEM_PEDIDO,');
    qryExec.SQL.Add('    CFCGL_PRODUTO,');
    qryExec.SQL.Add('    CFCGL_CODIGO_LIDO,');
    qryExec.SQL.Add('    CFCGL_TIPO_CODIGO,');
    qryExec.SQL.Add('    CFCGL_ROLO_ID,');
    qryExec.SQL.Add('    CFCGL_QUANTIDADE,');
    qryExec.SQL.Add('    CFCGL_DT_LEITURA,');
    qryExec.SQL.Add('    CFCGL_USUARIO,');
    qryExec.SQL.Add('    CFCGL_STATUS');

    qryExec.SQL.Add(') VALUES (');
    qryExec.SQL.Add('    :EMPRESA,');
    qryExec.SQL.Add('    :CFC_ID,');
    qryExec.SQL.Add('    :SEQUENCIA,');
    qryExec.SQL.Add('    :ITEM_CONFERE,');
    qryExec.SQL.Add('    :PEDIDO_VENDA,');
    qryExec.SQL.Add('    :ITEM_PEDIDO,');
    qryExec.SQL.Add('    :PRODUTO,');
    qryExec.SQL.Add('    :CODIGO_LIDO,');
    qryExec.SQL.Add('    ''C'',');
    qryExec.SQL.Add('    NULL,');
    qryExec.SQL.Add('    :QUANTIDADE,');
    qryExec.SQL.Add('    CURRENT_TIMESTAMP,');
    qryExec.SQL.Add('    :USUARIO,');
    qryExec.SQL.Add('    ''A''');
    qryExec.SQL.Add(')');

    qryExec.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qryExec.ParamByName('CFC_ID').AsInteger := ACfcId;
    qryExec.ParamByName('SEQUENCIA').AsInteger := vSeqLeitura;
    qryExec.ParamByName('ITEM_CONFERE').AsInteger := vSequenciaItem;
    qryExec.ParamByName('PEDIDO_VENDA').AsInteger := vPedidoCodigo;
    qryExec.ParamByName('ITEM_PEDIDO').AsInteger := vItemPedido;
    qryExec.ParamByName('PRODUTO').AsInteger := vProdutoCodigo;
    qryExec.ParamByName('CODIGO_LIDO').AsString := vCodigo;
    qryExec.ParamByName('QUANTIDADE').AsFloat := vQuantidade;
    qryExec.ParamByName('USUARIO').AsInteger := AUsuario;
    qryExec.ExecSQL;

    // Atualiza quantidade carregada do item.
    qryExec.SQL.Clear;

    qryExec.SQL.Add('UPDATE TB_CONFERE_CARGA_ITEM');
    qryExec.SQL.Add('SET CFCGI_QTDE_CARREGADA = CFCGI_QTDE_CARREGADA + :QUANTIDADE,');
    qryExec.SQL.Add('    CFCGI_STATUS = CASE');
    qryExec.SQL.Add('      WHEN (CFCGI_QTDE_CARREGADA + :QUANTIDADE) >= CFCGI_QTDE_PEDIDO THEN ''F''');
    qryExec.SQL.Add('      ELSE ''A''');
    qryExec.SQL.Add('    END');
    qryExec.SQL.Add('WHERE CFCGI_EMPRESA = :EMPRESA');
    qryExec.SQL.Add('  AND CFCGI_CONFERE_CARGA = :CFC_ID');
    qryExec.SQL.Add('  AND CFCGI_SEQUENCIA = :SEQUENCIA_ITEM');


    qryExec.ParamByName('QUANTIDADE').AsFloat := vQuantidade;
    qryExec.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qryExec.ParamByName('CFC_ID').AsInteger := ACfcId;
    qryExec.ParamByName('SEQUENCIA_ITEM').AsInteger := vSequenciaItem;
    qryExec.ExecSQL;

    if vIniciouTransacao then
      DMConfereCarga.fdtransConfereCarga.Commit;

    AMensagem := 'Leitura com sucesso.';
    Result := True;
  except
    on E: Exception do
    begin
      if vIniciouTransacao and DMConfereCarga.fdtransConfereCarga.Active then
        DMConfereCarga.fdtransConfereCarga.Rollback;

      AMensagem := E.Message;
      Result := False;
    end;
  end;

  qryConf.Free;
  qryItem.Free;
  qryExec.Free;
end;

class function TConfereCarga.FinalizarConferencia(
  const AEmpresa, ACfcId, AUsuario: Integer;
  out AMensagem: string
): Boolean;
var
  qry: TFDQuery;
  trans: TFDTransaction;
  vCarga: Integer;
  vManifesto: Integer;
begin
  Result := False;
  AMensagem := '';

  trans := TFDTransaction.Create(nil);
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    trans.Connection := qry.Connection;
    qry.Transaction := trans;

    try
      trans.StartTransaction;

      qry.SQL.Clear;
      qry.SQL.Add('SELECT CFCG_CARGA');
      qry.SQL.Add('FROM TB_CONFERE_CARGA');
      qry.SQL.Add('WHERE CFCG_EMPRESA = :EMPRESA');
      qry.SQL.Add('  AND CFCG_ID = :CFC_ID');
      qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
      qry.ParamByName('CFC_ID').AsInteger := ACfcId;
      qry.Open;

      if qry.IsEmpty then
        raise Exception.Create('Conferencia de carga nao encontrada.');

      if qry.FieldByName('CFCG_CARGA').IsNull then
        raise Exception.Create('Carga da conferencia nao informada.');

      vCarga := qry.FieldByName('CFCG_CARGA').AsInteger;
      if vCarga <= 0 then
        raise Exception.Create('Carga da conferencia invalida.');

      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('SELECT *');
      qry.SQL.Add('FROM SP_FIN_CONFERE_CARGA(:EMPRESA, :CFC_ID, :USUARIO)');
      qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
      qry.ParamByName('CFC_ID').AsInteger := ACfcId;
      qry.ParamByName('USUARIO').AsInteger := AUsuario;
      qry.Open;

      if qry.IsEmpty then
        raise Exception.Create('SP_FIN_CONFERE_CARGA nao retornou resultado.');

      AMensagem := qry.FieldByName('MENSAGEM').AsString;
      if not SameText(qry.FieldByName('RETORNO').AsString, 'OK') then
        raise Exception.Create(AMensagem);

      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('SELECT *');
      qry.SQL.Add('FROM SP_GERA_CARGA_PARADAS(:EMPRESA, :CARGA, :USUARIO)');
      qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
      qry.ParamByName('CARGA').AsInteger := vCarga;
      qry.ParamByName('USUARIO').AsInteger := AUsuario;
      qry.Open;

      if qry.IsEmpty then
        raise Exception.Create('SP_GERA_CARGA_PARADAS nao retornou resultado.');

      AMensagem := qry.FieldByName('MENSAGEM').AsString;
      if not SameText(qry.FieldByName('RETORNO').AsString, 'OK') then
        raise Exception.Create(AMensagem);

      qry.Close;
      qry.SQL.Clear;
      qry.SQL.Add('SELECT *');
      qry.SQL.Add('FROM SP_GERA_CARGA_MANIFESTO(:EMPRESA, :CARGA, :CONFERENCIA, :USUARIO)');
      qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
      qry.ParamByName('CARGA').AsInteger := vCarga;
      qry.ParamByName('CONFERENCIA').AsInteger := ACfcId;
      qry.ParamByName('USUARIO').AsInteger := AUsuario;
      qry.Open;

      if qry.IsEmpty then
        raise Exception.Create('SP_GERA_CARGA_MANIFESTO nao retornou resultado.');

      AMensagem := qry.FieldByName('MENSAGEM').AsString;
      if not SameText(qry.FieldByName('RETORNO').AsString, 'OK') then
        raise Exception.Create(AMensagem);

      if qry.FieldByName('MANIFESTO').IsNull then
        vManifesto := 0
      else
        vManifesto := qry.FieldByName('MANIFESTO').AsInteger;

      qry.Close;

      LiberarManifestoParaMotoristaApp(
        qry,
        AEmpresa,
        vCarga,
        ACfcId,
        vManifesto,
        AUsuario
      );

      trans.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        if qry.Active then
          qry.Close;
        if trans.Active then
          trans.Rollback;

        AMensagem := E.Message;
        Result := False;
      end;
    end;
  finally
    qry.Free;
    trans.Free;
  end;
end;
class procedure TConfereCarga.AbrirDadosConferencia(
  const AEmpresa, ACfcId: Integer
);
begin
  with DMConfereCarga.fdqryCONFERE_CARGA do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CFCG_ID').AsInteger := ACfcId;
    Open;
  end;

  with DMConfereCarga.fdqryPEDIDOS_CARGA do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CFCG_ID').AsInteger := ACfcId;
    Open;
  end;

  with DMConfereCarga.fdqryITENS_PENDENTES do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CFCG_ID').AsInteger := ACfcId;
    Open;
  end;

  with DMConfereCarga.fdqryLEITURAS do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CFCG_ID').AsInteger := ACfcId;
    Open;
  end;

  with DMConfereCarga.fdqryTOTAIS do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CFCG_ID').AsInteger := ACfcId;
    Open;
  end;
end;

class function TConfereCarga.GerarConferenciaCarga(
  const AEmpresa, ACarga: Integer): Integer;
begin
  Result := 0;

  with DMConfereCarga.fdqryGERA_CONFERE_CARGA do
  begin
    Close;
    ParamByName('EMPRESA').AsInteger := AEmpresa;
    ParamByName('CARGA').AsInteger := ACarga;
    Open;

    if IsEmpty then
      raise Exception.Create('Não foi possível gerar/abrir a conferência da carga.');

    if not FieldByName('CFCG_ID').IsNull then
      Result := FieldByName('CFCG_ID').AsInteger;

    if Result <= 0 then
      //raise Exception.Create(FieldByName('MENSAGEM').AsString);
      Exit(0);
  end;
end;

class procedure TConfereCarga.SincronizarPedidosDaCarga(
  AEmpresa, ACfcgId, ACarga, AUsuario: Integer;
  out AMensagemAviso: string);
var
  qry: TFDQuery;
  vMensagem: string;
  vPedido: Integer;
begin
  AMensagemAviso := '';

  qry := TFDQuery.Create(nil);
  try
    qry.Connection := DMConfereCarga.fdqryLISTA_CONFERE_CARGA.Connection;
    qry.Transaction := DMConfereCarga.fdtransConfereCarga;

    qry.SQL.Clear;
    qry.SQL.Add('SELECT DISTINCT CARGI_PEDIDO');
    qry.SQL.Add('FROM TB_CARGA_ITEM CI');
    qry.SQL.Add('WHERE CI.CARGI_EMPRESA = :EMPRESA');
    qry.SQL.Add('  AND CI.CARGI_CARGA = :CARGA');
    qry.SQL.Add('  AND NOT EXISTS (');
    qry.SQL.Add('      SELECT 1');
    qry.SQL.Add('      FROM TB_CONFERE_CARGA_PEDIDO CP');
    qry.SQL.Add('      WHERE CP.CFCGP_EMPRESA = CI.CARGI_EMPRESA');
    qry.SQL.Add('        AND CP.CFCGP_CONFERE_CARGA = :CONFERE');
    qry.SQL.Add('        AND CP.CFCGP_PEDIDO_VENDA = CI.CARGI_PEDIDO');
    qry.SQL.Add('  )');

    qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    qry.ParamByName('CARGA').AsInteger := ACarga;
    qry.ParamByName('CONFERE').AsInteger := ACfcgId;

    qry.Open;

    while not qry.Eof do
    begin
      vPedido := qry.FieldByName('CARGI_PEDIDO').AsInteger;

      if not IncluirPedidoConferencia(
        AEmpresa,
        ACfcgId,
        vPedido,
        AUsuario,
        vMensagem) then
      begin
        raise Exception.Create(
          'Pedido ' + IntToStr(vPedido) + ': ' + vMensagem
        );
      end;

      qry.Next;
    end;

  finally
    qry.Free;
  end;
end;

end.
