unit UClassMotoristaApp;

interface

uses
  FireDAC.Comp.Client;

type
  TAcessoMotoristaApp = record
    Existe: Boolean;
    MotoristaId: Integer;
    Login: string;
    Ativo: Boolean;
  end;

function CarregarAcessoTransportador(AEmpresa, ATransportador: Integer;
  ATransacao: TFDTransaction): TAcessoMotoristaApp;
procedure SalvarAcessoTransportador(AEmpresa, ATransportador: Integer;
  const ANome, ALogin, ASenha: string; AUsaApp: Boolean;
  var AMotoristaId: Integer; AUsuario: Integer; ATransacao: TFDTransaction);
function GerarHashSenhaMotoristaApp(const ASenha: string): string;

implementation

uses
  System.SysUtils, System.Classes, System.Hash, Winapi.Windows, Data.DB,
  FireDAC.Stan.Param, UDMBase;

const
  SCRYPT_N = 32768;
  SCRYPT_R = 8;
  SCRYPT_P = 1;
  SCRYPT_SALT_LENGTH = 16;
  PROV_RSA_FULL = 1;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CRYPT_SILENT = $00000040;

type
  HCRYPTPROV = NativeUInt;
  TUInt32Array16 = array[0..15] of UInt32;

function CryptAcquireContextA(var AProvider: HCRYPTPROV;
  AContainer, AProviderName: PAnsiChar; AProviderType, AFlags: DWORD): BOOL;
  stdcall; external 'advapi32.dll' name 'CryptAcquireContextA';
function CryptGenRandom(AProvider: HCRYPTPROV; ALength: DWORD;
  ABuffer: PByte): BOOL; stdcall; external 'advapi32.dll' name 'CryptGenRandom';
function CryptReleaseContext(AProvider: HCRYPTPROV; AFlags: DWORD): BOOL;
  stdcall; external 'advapi32.dll' name 'CryptReleaseContext';

function RotateLeft(AValue: UInt32; ACount: Integer): UInt32; inline;
begin
  Result := (AValue shl ACount) or (AValue shr (32 - ACount));
end;

function ReadUInt32LE(const AData: TBytes; AOffset: Integer): UInt32; inline;
begin
  Result := UInt32(AData[AOffset]) or
    (UInt32(AData[AOffset + 1]) shl 8) or
    (UInt32(AData[AOffset + 2]) shl 16) or
    (UInt32(AData[AOffset + 3]) shl 24);
end;

procedure WriteUInt32LE(var AData: TBytes; AOffset: Integer; AValue: UInt32); inline;
begin
  AData[AOffset] := Byte(AValue);
  AData[AOffset + 1] := Byte(AValue shr 8);
  AData[AOffset + 2] := Byte(AValue shr 16);
  AData[AOffset + 3] := Byte(AValue shr 24);
end;

procedure Salsa208(var ABlock: TBytes);
var
  OriginalValue, X: TUInt32Array16;
  I: Integer;
begin
  for I := 0 to 15 do
  begin
    OriginalValue[I] := ReadUInt32LE(ABlock, I * 4);
    X[I] := OriginalValue[I];
  end;

  for I := 0 to 3 do
  begin
    X[4] := X[4] xor RotateLeft(X[0] + X[12], 7);
    X[8] := X[8] xor RotateLeft(X[4] + X[0], 9);
    X[12] := X[12] xor RotateLeft(X[8] + X[4], 13);
    X[0] := X[0] xor RotateLeft(X[12] + X[8], 18);
    X[9] := X[9] xor RotateLeft(X[5] + X[1], 7);
    X[13] := X[13] xor RotateLeft(X[9] + X[5], 9);
    X[1] := X[1] xor RotateLeft(X[13] + X[9], 13);
    X[5] := X[5] xor RotateLeft(X[1] + X[13], 18);
    X[14] := X[14] xor RotateLeft(X[10] + X[6], 7);
    X[2] := X[2] xor RotateLeft(X[14] + X[10], 9);
    X[6] := X[6] xor RotateLeft(X[2] + X[14], 13);
    X[10] := X[10] xor RotateLeft(X[6] + X[2], 18);
    X[3] := X[3] xor RotateLeft(X[15] + X[11], 7);
    X[7] := X[7] xor RotateLeft(X[3] + X[15], 9);
    X[11] := X[11] xor RotateLeft(X[7] + X[3], 13);
    X[15] := X[15] xor RotateLeft(X[11] + X[7], 18);

    X[1] := X[1] xor RotateLeft(X[0] + X[3], 7);
    X[2] := X[2] xor RotateLeft(X[1] + X[0], 9);
    X[3] := X[3] xor RotateLeft(X[2] + X[1], 13);
    X[0] := X[0] xor RotateLeft(X[3] + X[2], 18);
    X[6] := X[6] xor RotateLeft(X[5] + X[4], 7);
    X[7] := X[7] xor RotateLeft(X[6] + X[5], 9);
    X[4] := X[4] xor RotateLeft(X[7] + X[6], 13);
    X[5] := X[5] xor RotateLeft(X[4] + X[7], 18);
    X[11] := X[11] xor RotateLeft(X[10] + X[9], 7);
    X[8] := X[8] xor RotateLeft(X[11] + X[10], 9);
    X[9] := X[9] xor RotateLeft(X[8] + X[11], 13);
    X[10] := X[10] xor RotateLeft(X[9] + X[8], 18);
    X[12] := X[12] xor RotateLeft(X[15] + X[14], 7);
    X[13] := X[13] xor RotateLeft(X[12] + X[15], 9);
    X[14] := X[14] xor RotateLeft(X[13] + X[12], 13);
    X[15] := X[15] xor RotateLeft(X[14] + X[13], 18);
  end;

  for I := 0 to 15 do
    WriteUInt32LE(ABlock, I * 4, X[I] + OriginalValue[I]);
end;

function BlockMix(const ABlock: TBytes; AR: Integer): TBytes;
var
  X, Y: TBytes;
  I, J, BlockCount: Integer;
begin
  BlockCount := 2 * AR;
  SetLength(X, 64);
  SetLength(Y, Length(ABlock));
  Move(ABlock[(BlockCount - 1) * 64], X[0], 64);

  for I := 0 to BlockCount - 1 do
  begin
    for J := 0 to 63 do
      X[J] := X[J] xor ABlock[(I * 64) + J];
    Salsa208(X);
    Move(X[0], Y[I * 64], 64);
  end;

  SetLength(Result, Length(ABlock));
  for I := 0 to AR - 1 do
  begin
    Move(Y[(2 * I) * 64], Result[I * 64], 64);
    Move(Y[(2 * I + 1) * 64], Result[(I + AR) * 64], 64);
  end;
end;

function Integerify(const ABlock: TBytes; AR: Integer): UInt64;
var
  Offset: Integer;
begin
  Offset := (2 * AR - 1) * 64;
  Result := UInt64(ReadUInt32LE(ABlock, Offset)) or
    (UInt64(ReadUInt32LE(ABlock, Offset + 4)) shl 32);
end;

function ROMix(const ABlock: TBytes; AN, AR: Integer): TBytes;
var
  V, X, Mixed: TBytes;
  I, J, BlockLength, VOffset: Integer;
begin
  BlockLength := 128 * AR;
  X := Copy(ABlock, 0, Length(ABlock));
  SetLength(V, AN * BlockLength);
  try
    for I := 0 to AN - 1 do
    begin
      Move(X[0], V[I * BlockLength], BlockLength);
      X := BlockMix(X, AR);
    end;

    SetLength(Mixed, BlockLength);
    for I := 0 to AN - 1 do
    begin
      J := Integer(Integerify(X, AR) and UInt64(AN - 1));
      VOffset := J * BlockLength;
      for J := 0 to BlockLength - 1 do
        Mixed[J] := X[J] xor V[VOffset + J];
      X := BlockMix(Mixed, AR);
    end;
    Result := X;
  finally
    FillChar(V[0], Length(V), 0);
  end;
end;

function PBKDF2SHA256OneIteration(const APassword, ASalt: TBytes;
  ALength: Integer): TBytes;
var
  Input, Digest: TBytes;
  BlockIndex, Offset, CopyLength: Integer;
begin
  SetLength(Result, ALength);
  SetLength(Input, Length(ASalt) + 4);
  if Length(ASalt) > 0 then
    Move(ASalt[0], Input[0], Length(ASalt));
  Offset := 0;
  BlockIndex := 1;
  while Offset < ALength do
  begin
    Input[Length(ASalt)] := Byte(BlockIndex shr 24);
    Input[Length(ASalt) + 1] := Byte(BlockIndex shr 16);
    Input[Length(ASalt) + 2] := Byte(BlockIndex shr 8);
    Input[Length(ASalt) + 3] := Byte(BlockIndex);
    Digest := THashSHA2.GetHMACAsBytes(Input, APassword, SHA256);
    CopyLength := Length(Digest);
    if CopyLength > ALength - Offset then
      CopyLength := ALength - Offset;
    Move(Digest[0], Result[Offset], CopyLength);
    Inc(Offset, CopyLength);
    Inc(BlockIndex);
  end;
end;

function Scrypt(const APassword, ASalt: TBytes; AN, AR, AP,
  ALength: Integer): TBytes;
var
  B, Block: TBytes;
  I, BlockLength: Integer;
begin
  BlockLength := 128 * AR;
  B := PBKDF2SHA256OneIteration(APassword, ASalt, AP * BlockLength);
  for I := 0 to AP - 1 do
  begin
    Block := Copy(B, I * BlockLength, BlockLength);
    Block := ROMix(Block, AN, AR);
    Move(Block[0], B[I * BlockLength], BlockLength);
  end;
  Result := PBKDF2SHA256OneIteration(APassword, B, ALength);
  if Length(B) > 0 then
    FillChar(B[0], Length(B), 0);
end;

function RandomSalt(ALength: Integer): string;
const
  SaltChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  Provider: HCRYPTPROV;
  RandomByte: Byte;
begin
  Result := '';
  Provider := 0;
  if not CryptAcquireContextA(Provider, nil, nil, PROV_RSA_FULL,
    CRYPT_VERIFYCONTEXT or CRYPT_SILENT) then
    RaiseLastOSError;
  try
    while Length(Result) < ALength do
    begin
      if not CryptGenRandom(Provider, 1, @RandomByte) then
        RaiseLastOSError;
      if RandomByte < 248 then
        Result := Result + SaltChars[(RandomByte mod Length(SaltChars)) + 1];
    end;
  finally
    CryptReleaseContext(Provider, 0);
  end;
end;

function BytesToHex(const AData: TBytes): string;
const
  HexDigits: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to Length(AData) - 1 do
  begin
    Result[(I * 2) + 1] := HexDigits[AData[I] shr 4];
    Result[(I * 2) + 2] := HexDigits[AData[I] and $0F];
  end;
end;

function GerarHashSenhaMotoristaApp(const ASenha: string): string;
var
  PasswordBytes, SaltBytes, DerivedKey: TBytes;
  Salt: string;
begin
  Salt := RandomSalt(SCRYPT_SALT_LENGTH);
  PasswordBytes := TEncoding.UTF8.GetBytes(ASenha);
  SaltBytes := TEncoding.UTF8.GetBytes(Salt);
  try
    DerivedKey := Scrypt(PasswordBytes, SaltBytes, SCRYPT_N, SCRYPT_R,
      SCRYPT_P, 64);
    Result := Format('scrypt:%d:%d:%d$%s$%s',
      [SCRYPT_N, SCRYPT_R, SCRYPT_P, Salt, BytesToHex(DerivedKey)]);
  finally
    if Length(PasswordBytes) > 0 then
      FillChar(PasswordBytes[0], Length(PasswordBytes), 0);
    if Length(DerivedKey) > 0 then
      FillChar(DerivedKey[0], Length(DerivedKey), 0);
  end;
end;

function NovaGuid: string;
var
  Guid: TGUID;
begin
  if CreateGUID(Guid) <> 0 then
    RaiseLastOSError;
  Result := LowerCase(Copy(GUIDToString(Guid), 2, 36));
end;

function NovaQuery(ATransacao: TFDTransaction): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := DMBase.fdconBase;
  Result.Transaction := ATransacao;
end;

function CarregarAcessoTransportador(AEmpresa, ATransportador: Integer;
  ATransacao: TFDTransaction): TAcessoMotoristaApp;
var
  Qry: TFDQuery;
begin
  Result.Existe := False;
  Result.MotoristaId := 0;
  Result.Login := '';
  Result.Ativo := False;

  Qry := NovaQuery(ATransacao);
  try
    Qry.SQL.Text :=
      'SELECT ME.MOTAPPE_MOTORISTA, ME.MOTAPPE_ATIVO, M.MOTAPP_LOGIN ' +
      'FROM TB_MOTORISTA_APP_EMPRESA ME ' +
      'JOIN TB_MOTORISTA_APP M ON M.MOTAPP_ID = ME.MOTAPPE_MOTORISTA ' +
      'WHERE ME.MOTAPPE_EMPRESA = :EMPRESA ' +
      'AND ME.MOTAPPE_TRANSPORTADOR = :TRANSPORTADOR';
    Qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
    Qry.ParamByName('TRANSPORTADOR').AsInteger := ATransportador;
    Qry.Open;
    if Qry.IsEmpty then
      Exit;

    Result.Existe := True;
    Result.MotoristaId := Qry.FieldByName('MOTAPPE_MOTORISTA').AsInteger;
    Result.Login := Qry.FieldByName('MOTAPP_LOGIN').AsString;
    Result.Ativo := Qry.FieldByName('MOTAPPE_ATIVO').AsString = 'S';
    Qry.Next;
    if not Qry.Eof then
      raise Exception.Create(
        'Existe mais de um usuário do App Motorista vinculado a este transportador.');
  finally
    Qry.Free;
  end;
end;

procedure ValidarLoginUnico(const ALogin: string; AMotoristaId: Integer;
  ATransacao: TFDTransaction);
var
  Qry: TFDQuery;
begin
  Qry := NovaQuery(ATransacao);
  try
    Qry.SQL.Text :=
      'SELECT M.MOTAPP_ID FROM TB_MOTORISTA_APP M ' +
      'WHERE UPPER(TRIM(M.MOTAPP_LOGIN)) = UPPER(TRIM(:LOGIN)) ' +
      'AND M.MOTAPP_ID <> :MOTORISTA';
    Qry.ParamByName('LOGIN').AsString := Trim(ALogin);
    Qry.ParamByName('MOTORISTA').AsInteger := AMotoristaId;
    Qry.Open;
    if not Qry.IsEmpty then
      raise Exception.Create('Usuário do App Motorista já cadastrado.');
  finally
    Qry.Free;
  end;
end;

procedure SalvarAcessoTransportador(AEmpresa, ATransportador: Integer;
  const ANome, ALogin, ASenha: string; AUsaApp: Boolean;
  var AMotoristaId: Integer; AUsuario: Integer; ATransacao: TFDTransaction);
var
  Qry: TFDQuery;
  PasswordHash: string;
  NovoMotoristaId: Integer;
begin
  Qry := NovaQuery(ATransacao);
  try
    if AUsaApp then
    begin
      if Trim(ALogin) = '' then
        raise Exception.Create('Informe o usuário do App Motorista.');
      if (AMotoristaId = 0) and (ASenha = '') then
        raise Exception.Create('Informe a senha inicial do App Motorista.');

      ValidarLoginUnico(ALogin, AMotoristaId, ATransacao);
      PasswordHash := '';
      if ASenha <> '' then
        PasswordHash := GerarHashSenhaMotoristaApp(ASenha);

      if AMotoristaId = 0 then
      begin
        Qry.SQL.Text :=
          'SELECT GEN_ID(GEN_MOTORISTA_APP_ID, 1) AS NOVO_ID FROM RDB$DATABASE';
        Qry.Open;
        NovoMotoristaId := Qry.FieldByName('NOVO_ID').AsInteger;
        Qry.Close;

        Qry.SQL.Text :=
          'INSERT INTO TB_MOTORISTA_APP (' +
          'MOTAPP_ID, MOTAPP_GUID, MOTAPP_NOME, MOTAPP_LOGIN, ' +
          'MOTAPP_SENHA_HASH, MOTAPP_ATIVO, MOTAPP_DH_CADASTRO, ' +
          'MOTAPP_USUARIO_CADASTRO) VALUES (' +
          ':ID, :GUID, :NOME, :LOGIN, :SENHA_HASH, ''S'', CURRENT_TIMESTAMP, :USUARIO)';
        Qry.ParamByName('ID').AsInteger := NovoMotoristaId;
        Qry.ParamByName('GUID').AsString := NovaGuid;
        Qry.ParamByName('NOME').AsString := Trim(ANome);
        Qry.ParamByName('LOGIN').AsString := Trim(ALogin);
        Qry.ParamByName('SENHA_HASH').AsString := PasswordHash;
        Qry.ParamByName('USUARIO').AsInteger := AUsuario;
        Qry.ExecSQL;

        Qry.SQL.Text :=
          'INSERT INTO TB_MOTORISTA_APP_EMPRESA (' +
          'MOTAPPE_EMPRESA, MOTAPPE_MOTORISTA, MOTAPPE_TRANSPORTADOR, ' +
          'MOTAPPE_ATIVO, MOTAPPE_DH_CADASTRO, MOTAPPE_USUARIO_CADASTRO) ' +
          'VALUES (:EMPRESA, :MOTORISTA, :TRANSPORTADOR, ''S'', ' +
          'CURRENT_TIMESTAMP, :USUARIO)';
        Qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
        Qry.ParamByName('MOTORISTA').AsInteger := NovoMotoristaId;
        Qry.ParamByName('TRANSPORTADOR').AsInteger := ATransportador;
        Qry.ParamByName('USUARIO').AsInteger := AUsuario;
        Qry.ExecSQL;
        AMotoristaId := NovoMotoristaId;
      end
      else
      begin
        Qry.SQL.Text :=
          'UPDATE TB_MOTORISTA_APP SET MOTAPP_NOME = :NOME, ' +
          'MOTAPP_LOGIN = :LOGIN, MOTAPP_ATIVO = ''S'', ' +
          'MOTAPP_DH_ALTERACAO = CURRENT_TIMESTAMP, ' +
          'MOTAPP_USUARIO_ALTERACAO = :USUARIO ' +
          'WHERE MOTAPP_ID = :ID';
        Qry.ParamByName('NOME').AsString := Trim(ANome);
        Qry.ParamByName('LOGIN').AsString := Trim(ALogin);
        Qry.ParamByName('USUARIO').AsInteger := AUsuario;
        Qry.ParamByName('ID').AsInteger := AMotoristaId;
        Qry.ExecSQL;

        if ASenha <> '' then
        begin
          Qry.SQL.Text :=
            'UPDATE TB_MOTORISTA_APP SET MOTAPP_SENHA_HASH = :SENHA_HASH ' +
            'WHERE MOTAPP_ID = :ID';
          Qry.ParamByName('SENHA_HASH').AsString := PasswordHash;
          Qry.ParamByName('ID').AsInteger := AMotoristaId;
          Qry.ExecSQL;
        end;

        Qry.SQL.Text :=
          'UPDATE TB_MOTORISTA_APP_EMPRESA SET ' +
          'MOTAPPE_TRANSPORTADOR = :TRANSPORTADOR, MOTAPPE_ATIVO = ''S'', ' +
          'MOTAPPE_DH_ALTERACAO = CURRENT_TIMESTAMP, ' +
          'MOTAPPE_USUARIO_ALTERACAO = :USUARIO ' +
          'WHERE MOTAPPE_EMPRESA = :EMPRESA AND MOTAPPE_MOTORISTA = :MOTORISTA';
        Qry.ParamByName('TRANSPORTADOR').AsInteger := ATransportador;
        Qry.ParamByName('USUARIO').AsInteger := AUsuario;
        Qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
        Qry.ParamByName('MOTORISTA').AsInteger := AMotoristaId;
        Qry.ExecSQL;
        if Qry.RowsAffected <> 1 then
          raise Exception.Create('Vínculo do usuário com a empresa não foi encontrado.');
      end;
    end
    else if AMotoristaId <> 0 then
    begin
      Qry.SQL.Text :=
        'UPDATE TB_MOTORISTA_APP_EMPRESA SET MOTAPPE_ATIVO = ''N'', ' +
        'MOTAPPE_DH_ALTERACAO = CURRENT_TIMESTAMP, ' +
        'MOTAPPE_USUARIO_ALTERACAO = :USUARIO ' +
        'WHERE MOTAPPE_EMPRESA = :EMPRESA AND MOTAPPE_MOTORISTA = :MOTORISTA ' +
        'AND MOTAPPE_TRANSPORTADOR = :TRANSPORTADOR';
      Qry.ParamByName('USUARIO').AsInteger := AUsuario;
      Qry.ParamByName('EMPRESA').AsInteger := AEmpresa;
      Qry.ParamByName('MOTORISTA').AsInteger := AMotoristaId;
      Qry.ParamByName('TRANSPORTADOR').AsInteger := ATransportador;
      Qry.ExecSQL;

      Qry.SQL.Text :=
        'SELECT COUNT(*) AS QTDE FROM TB_MOTORISTA_APP_EMPRESA ' +
        'WHERE MOTAPPE_MOTORISTA = :MOTORISTA AND MOTAPPE_ATIVO = ''S''';
      Qry.ParamByName('MOTORISTA').AsInteger := AMotoristaId;
      Qry.Open;
      if Qry.FieldByName('QTDE').AsInteger = 0 then
      begin
        Qry.Close;
        Qry.SQL.Text :=
          'UPDATE TB_MOTORISTA_APP SET MOTAPP_ATIVO = ''N'', ' +
          'MOTAPP_DH_ALTERACAO = CURRENT_TIMESTAMP, ' +
          'MOTAPP_USUARIO_ALTERACAO = :USUARIO WHERE MOTAPP_ID = :ID';
        Qry.ParamByName('USUARIO').AsInteger := AUsuario;
        Qry.ParamByName('ID').AsInteger := AMotoristaId;
        Qry.ExecSQL;
      end;
    end;
  finally
    if PasswordHash <> '' then
      PasswordHash := StringOfChar(#0, Length(PasswordHash));
    Qry.Free;
  end;
end;

end.
