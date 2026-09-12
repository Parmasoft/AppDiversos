inherited frmManTransportador: TfrmManTransportador
  Caption = 'Cadastro de Transportadores'
  ClientHeight = 587
  ClientWidth = 737
  OnClose = FormClose
  ExplicitWidth = 743
  ExplicitHeight = 616
  PixelsPerInch = 96
  TextHeight = 13
  inherited pnlControles: TPanel
    Top = 541
    Width = 737
    ExplicitTop = 541
    ExplicitWidth = 737
    inherited btnFechar: TBitBtn
      Left = 605
      ExplicitLeft = 605
    end
    inherited btnCancelar: TBitBtn
      Left = 477
      ExplicitLeft = 477
    end
    inherited btnConfirmar: TBitBtn
      Left = 605
      ExplicitLeft = 605
    end
  end
  inherited pnlDados: TPanel
    Width = 737
    Height = 541
    ExplicitWidth = 737
    ExplicitHeight = 541
    inherited pgcManutencao: TPageControl
      Width = 733
      Height = 537
      ParentFont = False
      OnChange = pgcManutencaoChange
      ExplicitWidth = 733
      ExplicitHeight = 537
      inherited tsDadosPrincipais: TTabSheet
        ExplicitLeft = 4
        ExplicitTop = 24
        ExplicitWidth = 725
        ExplicitHeight = 509
        inherited pnlDadosPrincipais: TPanel
          Width = 725
          Height = 509
          Padding.Left = 3
          Padding.Right = 3
          Padding.Bottom = 3
          ExplicitWidth = 725
          ExplicitHeight = 509
          object grpCliente: TGroupBox
            Left = 5
            Top = 2
            Width = 715
            Height = 151
            Align = alTop
            Caption = '| Cliente |'
            DoubleBuffered = False
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = [fsBold]
            ParentDoubleBuffered = False
            ParentFont = False
            TabOrder = 0
            object Label1: TLabel
              Left = 15
              Top = 18
              Width = 33
              Height = 13
              Caption = 'C'#243'digo'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label2: TLabel
              Left = 15
              Top = 102
              Width = 116
              Height = 13
              Caption = 'Nome Fantasia / Apelido'
              FocusControl = dbedtTRANSP_FANTASIA
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label3: TLabel
              Left = 15
              Top = 61
              Width = 97
              Height = 13
              Caption = 'Raz'#227'o Social / Nome'
              FocusControl = dbedtTRANSP_RSOCIAL_NOME
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label4: TLabel
              Left = 530
              Top = 18
              Width = 54
              Height = 13
              Caption = 'CNPJ / CPF'
              FocusControl = dbedtTRANSP_CPF_CNPJ
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label5: TLabel
              Left = 407
              Top = 101
              Width = 111
              Height = 13
              Caption = 'Inscri'#231#227'o Estadual / RG'
              FocusControl = dbedtTRANSP_IE_RG
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label6: TLabel
              Left = 142
              Top = 18
              Width = 70
              Height = 13
              Caption = 'Data Cadastro'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label21: TLabel
              Left = 278
              Top = 18
              Width = 31
              Height = 13
              Caption = 'Status'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label22: TLabel
              Left = 404
              Top = 18
              Width = 57
              Height = 13
              Caption = 'Tipo Pessoa'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object btnConsultarCNPJCPF: TSpeedButton
              Left = 674
              Top = 34
              Width = 25
              Height = 21
              Hint = 'Pesquisar Cliente'
              Glyph.Data = {
                36060000424D3606000000000000360000002800000020000000100000000100
                18000000000000060000120B0000120B00000000000000000000FF00FF314B62
                AC7D7EFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
                FFFF00FFFF00FFFF00FFFF00FF777777BDBDBDFF00FFFF00FFFF00FFFF00FFFF
                00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF5084B20F6FE1
                325F8CB87E7AFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
                FFFF00FFFF00FFFF00FFABABAB9797978B8B8BC1C1C1FF00FFFF00FFFF00FFFF
                00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF32A0FE37A1FF
                106FE2325F8BB67D79FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
                FFFF00FFFF00FFFF00FFB8B8B8BCBCBC9898988A8A8AC0C0C0FF00FFFF00FFFF
                00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF37A4FE
                379FFF0E6DDE355F89BB7F79FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00
                FFFF00FFFF00FFFF00FFFF00FFBBBBBBBCBCBC9595958B8B8BC2C2C2FF00FFFF
                00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
                37A4FE359EFF0F6FDE35608BA67B7FFF00FFFF00FFFF00FFFF00FFFF00FFFF00
                FFFF00FFFF00FFFF00FFFF00FFFF00FFBBBBBBBABABA9696968C8C8CBABABAFF
                00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
                FF00FF38A5FE329DFF156DCE444F5BFF00FF9C6B65AF887BAF887EAA8075FF00
                FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFBCBCBCB9B9B99494947E7E7EFF
                00FF979797AAAAAAABABABA5A5A5FF00FFFF00FFFF00FFFF00FFFF00FFFF00FF
                FF00FFFF00FF3BABFFA1CAE7AD8679A98373E0CFB1FFFFDAFFFFDDFCF8CFCCB2
                9FA1746BFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFBEBEBED1D1D1A8A8A8A3
                A3A3D4D4D4F1F1F1F2F2F2EBEBEBC5C5C59D9D9DFF00FFFF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFC0917DFCE9ACFFFFCCFFFFCFFFFFD0FFFFDEFFFF
                FAE3D3D1996965FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFB1B1B1DD
                DDDDEBEBEBECECECEDEDEDF2F2F2FDFDFDE3E3E3969696FF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFB08978FAD192FEF4C2FFFFD0FFFFDAFFFFF6FFFF
                FCFFFFFCB69384FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFA9A9A9D1
                D1D1E7E7E7EDEDEDF1F1F1FBFBFBFEFEFEFEFEFEB1B1B1FF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFB08978FEDA97EDB478FBEEBBFFFFD3FFFFDCFFFFF4FFFF
                F4FFFFE2E9DDBCA67B73FF00FFFF00FFFF00FFFF00FFFF00FFA9A9A9D5D5D5C1
                C1C1E3E3E3EEEEEEF1F1F1FBFBFBFBFBFBF4F4F4DCDCDCA2A2A2FF00FFFF00FF
                FF00FFFF00FFFF00FFB18A78FFDE99E9A167F4D199FEFCCCFFFFD5FFFFDAFFFF
                DCFFFFD7EFE6C5A97E75FF00FFFF00FFFF00FFFF00FFFF00FFA9A9A9D6D6D6B7
                B7B7D2D2D2EBEBEBEFEFEFF1F1F1F1F1F1EFEFEFE2E2E2A4A4A4FF00FFFF00FF
                FF00FFFF00FFFF00FFAA7F73FAE0A4F0B778EEBA7BF6DDA6FEFBCCFFFFD3FFFF
                D1FFFFD7D9C5A7A3756CFF00FFFF00FFFF00FFFF00FFFF00FFA4A4A4D9D9D9C2
                C2C2C3C3C3D8D8D8EBEBEBEEEEEEEDEDEDEFEFEFCECECE9E9E9EFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFCEB293FFFEDDF4D1A5EEBA7BF2C78FF8E1ABFCF0
                BAFCFACAA3776FFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFC1C1C1F2
                F2F2D7D7D7C3C3C3CDCDCDDBDBDBE3E3E3E9E9E99F9F9FFF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFA1746BE1D4D3FFFEEEF7CC8CF0B473F7C788FCE3
                A5C2A088A5776CFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF9D9D9DE2
                E2E2F8F8F8CECECEC0C0C0CCCCCCDADADAB7B7B79F9F9FFF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFFF00FF986865BA9587EAD7A4EAD59EE0C097A577
                6CA5776CFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FF96
                9696B3B3B3D3D3D3D0D0D0C9C9C99F9F9F9F9F9FFF00FFFF00FFFF00FFFF00FF
                FF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFA77E70A98073A4786EFF00
                FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF00FFFF
                00FFFF00FFA2A2A2A3A3A39F9F9FFF00FFFF00FFFF00FFFF00FF}
              NumGlyphs = 2
              OnClick = btnConsultarCNPJCPFClick
            end
            object lbl5: TLabel
              Left = 552
              Top = 101
              Width = 25
              Height = 13
              Caption = 'Placa'
              FocusControl = dbedtTRANSP_PLACA
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object lbl6: TLabel
              Left = 651
              Top = 101
              Width = 41
              Height = 13
              Caption = 'UF Placa'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object dbedtTRANSP_FANTASIA: TcxDBTextEdit
              Left = 15
              Top = 117
              DataBinding.DataField = 'TRANSP_FANTASIA'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 6
              Width = 386
            end
            object dbedtTRANSP_RSOCIAL_NOME: TcxDBTextEdit
              Left = 15
              Top = 76
              DataBinding.DataField = 'TRANSP_RSOCIAL_NOME'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              StyleFocused.BorderColor = clWindowFrame
              StyleFocused.BorderStyle = ebs3D
              TabOrder = 5
              Width = 684
            end
            object dbedtTRANSP_CPF_CNPJ: TcxDBTextEdit
              Left = 530
              Top = 34
              DataBinding.DataField = 'TRANSP_CPF_CNPJ'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 4
              OnExit = dbedtTRANSP_CPF_CNPJExit
              OnKeyPress = dbedtTRANSP_CPF_CNPJKeyPress
              Width = 144
            end
            object dbedtTRANSP_IE_RG: TcxDBTextEdit
              Left = 407
              Top = 117
              DataBinding.DataField = 'TRANSP_IE_RG'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 7
              Width = 139
            end
            object dbedtTRANSP_ID: TcxDBTextEdit
              Left = 15
              Top = 34
              DataBinding.DataField = 'TRANSP_ID'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              Properties.ReadOnly = True
              Style.Color = clInactiveBorder
              Style.Font.Charset = DEFAULT_CHARSET
              Style.Font.Color = clWindowText
              Style.Font.Height = -11
              Style.Font.Name = 'Tahoma'
              Style.Font.Style = [fsBold]
              Style.IsFontAssigned = True
              TabOrder = 0
              Width = 121
            end
            object dbedtTRANSP_DT_CADASTRO: TJvDBDateEdit
              Left = 142
              Top = 34
              Width = 130
              Height = 21
              DataField = 'TRANSP_DT_CADASTRO'
              DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ReadOnly = True
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
              ShowNullDate = False
              TabOrder = 1
            end
            object dbcbbTRANSP_STATUS: TJvDBComboBox
              Left = 278
              Top = 34
              Width = 120
              Height = 22
              Style = csOwnerDrawFixed
              DataField = 'TRANSP_STATUS'
              DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              Items.Strings = (
                'ATIVO'
                'INATIVO')
              ParentFont = False
              TabOrder = 2
              UpdateFieldImmediatelly = True
              Values.Strings = (
                'A'
                'I')
              ListSettings.OutfilteredValueFont.Charset = DEFAULT_CHARSET
              ListSettings.OutfilteredValueFont.Color = clRed
              ListSettings.OutfilteredValueFont.Height = -11
              ListSettings.OutfilteredValueFont.Name = 'Tahoma'
              ListSettings.OutfilteredValueFont.Style = []
            end
            object dbcbbTRANSP_TIPO_PESSOA: TJvDBComboBox
              Left = 404
              Top = 34
              Width = 120
              Height = 22
              Style = csOwnerDrawFixed
              DataField = 'TRANSP_TIPO_PESSOA'
              DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              Items.Strings = (
                'F'#205'SICA'
                'JUR'#205'DICA'
                '')
              ParentFont = False
              TabOrder = 3
              UpdateFieldImmediatelly = True
              Values.Strings = (
                'F'
                'J')
              ListSettings.OutfilteredValueFont.Charset = DEFAULT_CHARSET
              ListSettings.OutfilteredValueFont.Color = clRed
              ListSettings.OutfilteredValueFont.Height = -11
              ListSettings.OutfilteredValueFont.Name = 'Tahoma'
              ListSettings.OutfilteredValueFont.Style = []
            end
            object dbedtTRANSP_PLACA: TcxDBTextEdit
              Left = 552
              Top = 117
              DataBinding.DataField = 'TRANSP_PLACA'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 8
              Width = 93
            end
            object dbcbbTRANSP_PLACA_UF: TJvDBComboBox
              Left = 651
              Top = 117
              Width = 48
              Height = 22
              Style = csOwnerDrawFixed
              DataField = 'TRANSP_PLACA_UF'
              DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              Items.Strings = (
                'AC'
                'AL'
                'AM'
                'AP'
                'BA'
                'CE'
                'DF'
                'ES'
                'GO'
                'MA'
                'MG'
                'MS'
                'MT'
                'PA'
                'PB'
                'PE'
                'PI'
                'PR'
                'RJ'
                'RN'
                'RO'
                'RR'
                'RS'
                'SC'
                'SE'
                'SP'
                'TO')
              ParentFont = False
              TabOrder = 9
              UpdateFieldImmediatelly = True
              Values.Strings = (
                'AC'
                'AL'
                'AM'
                'AP'
                'BA'
                'CE'
                'DF'
                'ES'
                'GO'
                'MA'
                'MG'
                'MS'
                'MT'
                'PA'
                'PB'
                'PE'
                'PI'
                'PR'
                'RJ'
                'RN'
                'RO'
                'RR'
                'RS'
                'SC'
                'SE'
                'SP'
                'TO')
              ListSettings.OutfilteredValueFont.Charset = DEFAULT_CHARSET
              ListSettings.OutfilteredValueFont.Color = clRed
              ListSettings.OutfilteredValueFont.Height = -11
              ListSettings.OutfilteredValueFont.Name = 'Tahoma'
              ListSettings.OutfilteredValueFont.Style = []
            end
          end
          object grpEndereco: TGroupBox
            Left = 5
            Top = 153
            Width = 715
            Height = 152
            Align = alTop
            Caption = '| Endere'#231'o |'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 1
            object Label7: TLabel
              Left = 118
              Top = 20
              Width = 45
              Height = 13
              Caption = 'Endere'#231'o'
              FocusControl = dbedtTRANSP_ENDERECO
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label8: TLabel
              Left = 15
              Top = 62
              Width = 65
              Height = 13
              Caption = 'Complemento'
              FocusControl = dbedtTRANSP_COMPLEMENTO
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label9: TLabel
              Left = 602
              Top = 20
              Width = 37
              Height = 13
              Caption = 'N'#250'mero'
              FocusControl = dbedtTRANSP_NUMERO
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label10: TLabel
              Left = 366
              Top = 62
              Width = 28
              Height = 13
              Caption = 'Bairro'
              FocusControl = dbedtTRANSP_BAIRRO
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label11: TLabel
              Left = 15
              Top = 104
              Width = 33
              Height = 13
              Caption = 'Cidade'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label12: TLabel
              Left = 15
              Top = 20
              Width = 19
              Height = 13
              Caption = 'CEP'
              FocusControl = dbedtTRANSP_CEP
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label18: TLabel
              Left = 524
              Top = 104
              Width = 13
              Height = 13
              Caption = 'UF'
              FocusControl = dbedtTRANSP_CEP
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object lbUF: TLabel
              Left = 524
              Top = 120
              Width = 33
              Height = 21
              Alignment = taCenter
              AutoSize = False
              Color = clWhite
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = [fsBold]
              ParentColor = False
              ParentFont = False
              Transparent = False
              Layout = tlCenter
            end
            object Label19: TLabel
              Left = 563
              Top = 104
              Width = 79
              Height = 13
              Caption = 'C'#243'digo Municipio'
              FocusControl = dbedtTRANSP_CEP
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object lbCodMunicipio: TLabel
              Left = 563
              Top = 120
              Width = 136
              Height = 21
              AutoSize = False
              Color = clWhite
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentColor = False
              ParentFont = False
              Transparent = False
              Layout = tlCenter
            end
            object dbedtTRANSP_ENDERECO: TcxDBTextEdit
              Left = 118
              Top = 36
              DataBinding.DataField = 'TRANSP_ENDERECO'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 1
              Width = 478
            end
            object dbedtTRANSP_COMPLEMENTO: TcxDBTextEdit
              Left = 15
              Top = 78
              DataBinding.DataField = 'TRANSP_COMPLEMENTO'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 3
              Width = 345
            end
            object dbedtTRANSP_NUMERO: TcxDBTextEdit
              Left = 602
              Top = 36
              DataBinding.DataField = 'TRANSP_NUMERO'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 2
              Width = 97
            end
            object dbedtTRANSP_BAIRRO: TcxDBTextEdit
              Left = 366
              Top = 78
              DataBinding.DataField = 'TRANSP_BAIRRO'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 4
              Width = 333
            end
            object dbedtTRANSP_CEP: TcxDBTextEdit
              Left = 15
              Top = 36
              DataBinding.DataField = 'TRANSP_CEP'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 0
              OnExit = dbedtTRANSP_CEPExit
              Width = 97
            end
            object dbcbbTRANSP_CIDADE: TcxDBLookupComboBox
              Left = 15
              Top = 120
              DataBinding.DataField = 'TRANSP_CIDADE'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              Properties.KeyFieldNames = 'CID_ID'
              Properties.ListColumns = <
                item
                  FieldName = 'CID_NOME'
                end
                item
                  FieldName = 'est_sigla'
                end>
              Properties.ListOptions.ShowHeader = False
              Properties.ListSource = DMCidade.dsLISTA_CIDADE
              TabOrder = 5
              OnExit = dbcbbTRANSP_CIDADEExit
              Width = 503
            end
          end
          object grpContato: TGroupBox
            Left = 5
            Top = 305
            Width = 715
            Height = 109
            Align = alTop
            Caption = '| Contato |'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 2
            object Label13: TLabel
              Left = 15
              Top = 62
              Width = 42
              Height = 13
              Caption = 'Telefone'
              FocusControl = dbedtTRANSP_TELEFONE
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label14: TLabel
              Left = 245
              Top = 62
              Width = 18
              Height = 13
              Caption = 'Fax'
              FocusControl = dbedtTRANSP_FAX
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label15: TLabel
              Left = 475
              Top = 62
              Width = 33
              Height = 13
              Caption = 'Celular'
              FocusControl = dbedtTRANS_CELULAR
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label16: TLabel
              Left = 366
              Top = 20
              Width = 24
              Height = 13
              Caption = 'Email'
              FocusControl = dbedtTRANSP_EMAIL
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object Label20: TLabel
              Left = 15
              Top = 20
              Width = 39
              Height = 13
              Caption = 'Contato'
              FocusControl = dbedtTRANSP_CONTATO
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object dbedtTRANSP_TELEFONE: TcxDBTextEdit
              Left = 15
              Top = 78
              DataBinding.DataField = 'TRANSP_TELEFONE'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 2
              Width = 224
            end
            object dbedtTRANSP_FAX: TcxDBTextEdit
              Left = 245
              Top = 78
              DataBinding.DataField = 'TRANSP_FAX'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 3
              Width = 224
            end
            object dbedtTRANS_CELULAR: TcxDBTextEdit
              Left = 475
              Top = 78
              DataBinding.DataField = 'TRANSP_CELULAR'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 4
              Width = 224
            end
            object dbedtTRANSP_EMAIL: TcxDBTextEdit
              Left = 366
              Top = 36
              DataBinding.DataField = 'TRANSP_EMAIL'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              TabOrder = 1
              Width = 333
            end
            object dbedtTRANSP_CONTATO: TcxDBTextEdit
              Left = 15
              Top = 35
              DataBinding.DataField = 'TRANSP_CONTATO'
              DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
              ParentFont = False
              Properties.CharCase = ecUpperCase
              TabOrder = 0
              Width = 345
            end
          end
          object grpAppMotorista: TGroupBox
            Left = 5
            Top = 414
            Width = 715
            Height = 90
            Align = alClient
            Caption = '| Acesso ao App Motorista |'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 3
            object chkUsaAppMotorista: TCheckBox
              Left = 15
              Top = 18
              Width = 132
              Height = 17
              Caption = 'Usa App Motorista'
              TabOrder = 0
              OnClick = chkUsaAppMotoristaClick
            end
            object lblUsuarioApp: TLabel
              Left = 15
              Top = 42
              Width = 36
              Height = 13
              Caption = 'Usu'#225'rio'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object lblSenhaApp: TLabel
              Left = 330
              Top = 42
              Width = 30
              Height = 13
              Caption = 'Senha'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clNavy
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = []
              ParentFont = False
            end
            object lblSenhaAppAviso: TLabel
              Left = 487
              Top = 63
              Width = 212
              Height = 13
              Caption = 'Em branco, mant'#233'm a senha atual'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clGrayText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = [fsItalic]
              ParentFont = False
            end
            object edtUsuarioApp: TEdit
              Left = 15
              Top = 58
              Width = 300
              Height = 21
              MaxLength = 80
              TabOrder = 1
            end
            object edtSenhaApp: TEdit
              Left = 330
              Top = 58
              Width = 145
              Height = 21
              MaxLength = 120
              PasswordChar = '*'
              TabOrder = 2
            end
          end
        end
      end
      object tsObservacao: TTabSheet
        Caption = 'Observa'#231#227'o'
        ImageIndex = 2
        ExplicitLeft = 0
        ExplicitTop = 0
        ExplicitWidth = 0
        ExplicitHeight = 0
        object pnlObservacao: TPanel
          Left = 0
          Top = 0
          Width = 725
          Height = 419
          Align = alClient
          BevelInner = bvRaised
          BevelOuter = bvLowered
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = []
          Padding.Left = 3
          Padding.Top = 3
          Padding.Right = 3
          Padding.Bottom = 3
          ParentBackground = False
          ParentFont = False
          ShowCaption = False
          TabOrder = 0
          object Panel2: TPanel
            Left = 5
            Top = 358
            Width = 715
            Height = 56
            Align = alBottom
            BevelInner = bvRaised
            BevelOuter = bvLowered
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = []
            Padding.Left = 3
            Padding.Right = 3
            Padding.Bottom = 3
            ParentBackground = False
            ParentFont = False
            TabOrder = 0
            object GroupBox1: TGroupBox
              Left = 5
              Top = 2
              Width = 705
              Height = 49
              Align = alClient
              Caption = '| Legenda |'
              Color = clBtnFace
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = [fsBold]
              ParentBackground = False
              ParentColor = False
              ParentFont = False
              TabOrder = 0
              object Image1: TImage
                Left = 475
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000005
                  5E49444154484B8D54694C545714BE4D7F1A6BEB124559ECC832304001710690
                  1191196618A12A830255441150700B5111A996C6D8A676494CEC8F26FEE80F6C
                  D3D6A54D63A2696A6D1B695D4AED0FD3466B9B26CACC9B61DE1B76B79E777ACE
                  9B79F8404CFAE3DC7BEE79E77EDF59EE3BE29010BAE47708E123B94B7A8E6E7F
                  E3C9F70967A39D7592E99D427C47F7FF215B79D42644574459B14F88919ECD5E
                  BC5CB70AF70AF190EC39FC8D0178D7453F1BEDA4CFA0FBF7BECC32616F850DF7
                  0BF12FD9EA75021B835F69A8C2B193EFE1E8C747B0E7350FB6093146DFF2FE07
                  C1EC76216E9FCE588823FBAA70A4DD0BBF555899E411F97805A5F467CFFA0A1C
                  EB7E47558E7742F858073C3A7148BD546E47FA769F9C34125D382AC33E877C7E
                  3F9918838F0E5683BC6325845A5CEAE06E0FF4BA33F97E401C10E2FA371E3B8E
                  9EE882C163ED38F4411B0E1DDD058F3FDC8B174B6D1A0981E54D91C1EC08F87C
                  7CD0E105B9D58DC1162706B63A406971E02FA5E97CD7C7CEB15473E582C386F0
                  5127816FC781B75B413EDC8C63EFEFC48B4E2BEE8994CB6620984165B9757251
                  0CDE6FAFC450AB0B02CD4E941A8B516929811B2E0B9748255F979E6E0C8104CF
                  2E49C587C7DA20F466A32A773540FFC18D30F2D616F5A78A7C6EFC63F25D42BE
                  D3B8A1A7D3E2F041FB6A086C2D05A9A95895B61441B8A518AE14A7704040BE4E
                  2EA3966E343213A5143C936BC6D1A39441E7060C1DA8C5E0FE1A18EEACC5CBA5
                  394C3248E07F9DB1C4E3C02E0F04B73A506A5A8E01066F2EC29E6549484F1509
                  B84CCFD648C0FB2226399B9D8463471AB07FDF3A94F75482D2B69A5E48255EB2
                  A7E1A7D4D0819D6518685A01810602DF6447B9A910AE16256BE00785F01831B5
                  8585D389EA268A32783E2F1587F75781B27B952AEF2C87D0F6325076B821BCA3
                  540D342E077FC33255DA940FA18602E8758C97A5CC80A3614ECE40D713B81CE7
                  ADC938DC56C14F0F03CD25D4C44839A4CD85E8ABCF83D0A63CEC2D4E420A0808
                  CC39054E646199CC4C7B1C91F8BECA8C47A5D50191A8ED206D2C507D755608D4
                  59D5AB852695C0C7C8D735E9EEB83E816D923E8D9EE29D4F4C7350D9568C52FD
                  52F46DB4A16F432E48358BB1BF361BBECD8AE1C60F91FFE267E14C3818747EE7
                  F74E99635069A292D4E7A3AF6E094AB5B928556781B42E13A5AA7450AA33F087
                  6C8DE401DD7B6A763D8B409B2DA752E6A2D268477F9D0D7CEB197C3106ABB351
                  AE790524AF05A5351690569931B4260DBFCF98A7FF8C13669746C00B4BB476DA
                  6CE98E9F8943AD45E0DF60055F4D8E2AADCB06B9360BAE15C4AB671367A242D1
                  4BAFA6A87D1E33F8CA9221546E512F24CD796A764DEE81365BBA1366E140D352
                  F051C452750E523980A2C65F0BE39132BB4FE5089C4B9E8DFD1569D0E736639F
                  C38C771D44E2B1E0F9C40809016BB38B4974026DB674C7BF84038D055C0E90D6
                  66A17F6D3A2AD5997063690283AB74B18C2ECDA797237FFD3265B2D2827D4E22
                  284906DE998433E1974598368D8096E9DCD0CF897D784B3E35301BA4AA0CD55F
                  6981704D065CB3C58ECF16BEC06993C45026C1CF16BC80F2CA34B85792A23209
                  0B91A83F5AE6E9B32B57D0EF7DF534B12AFCFCE875F8BDE92C105E9B813FE72E
                  98305BF4B4A3BB89467DF08BD8173512CE40CF26E84EC54BA973B95C7D82C6EA
                  E84D473286A889814A0BB284A98957A2E0C6D9328980776D769D229270F99372
                  49AE54BCB36C91D60F76DCF63A01DD7226AAB2D7023295A6372F6ECAD9C2A29F
                  0D766D76714F026E33F85D66F5EFE589EAE1E79FE3E00E6BD190D2C1247F142D
                  C4EBD6586EE894B3C57836DA494F2092C173A65978DB6ED2C009EF5D0EC2E8B4
                  9B521AA6BAF693EE36D8C77D8C67A33DAAC7D1DD9B54F23005DC15B10BF11F91
                  934C77AC70338C0000000049454E44AE426082}
                Proportional = True
              end
              object Image2: TImage
                Left = 382
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000004724944
                  4154484BAD956D489B5714C763DDC6DAAD1FC6BE6DB0D22FDB3E6CEBCAC65E60
                  305A288C313618135A56C6B06CA55B5BC13A371553ADE25BCABA56C42AD619E2
                  2ACE051BC90B9884C4A091BCE02C51AC62A54B89254A62481E929084E7BF73EE
                  D3A8A969BB412FFCD0E7E6DEF3BFF73CE7FC1F158027429B3383EDE4E7772CFC
                  BFD49AA582C079DA09FEBDE8A6FF42992E82F2A128CEDD88A1C99616013970AB
                  43A1C59EA665DB04CE8FC7D03D9344974FC225B7840E57024DF638AAC636F0DD
                  7014C70723383A1041993682AFEE738C444EFD19458D29210236DB32B8389945
                  8B23552870C52B219095B1480FB788791998CB81E68099940CEB7A16DAC534D4
                  CE048ED3A93FBFB6BEC931ED3A2A4637D03691C6D0620E9E3804973D892D01FB
                  5A5604E780DB61118605F977C61DCFA1672E85C64949D0359B8479350B7F72EB
                  704C0B1D8686226008668A0A3CC876B165222FCAF3B39491BF5374FA842CA8B5
                  D035F202BD748A62023769136FCC6FE653F2DC12E18FC5E08EAE618E0E3A4BB1
                  98E9480ED65585337F45B7049A1D0911201FC47B3F8FD3316283D2426B272332
                  BC11C0150EE313FD977841F3229E6DD98DF7063F8661C58BD30E35C683518C2C
                  405020C095E2B827638A82B8D66438C3B278B68714AC7765D882802F9CC5C181
                  0FA13AA782AA9AA853D8DDBA07FBBB5F85ED761ABD9E9CA04080D1DDCC882096
                  1519E6DB324CCB328C4B32C616658C2E90F00A50E9D04055A3C2BBDA0FF08DA5
                  1CAF74ED4389BA4488BCD67300C6F91C3AA83C991D021AA784B15B32F4F4C646
                  02390CCF6E717D06189B4FE1A52BFB7162FC7BDE2886DADDB4798B37FADEC7A0
                  5F46BD4912D0107137057E198B43EBA37A27FA3D59F47932E8716770752A8DAB
                  6E4033E9C3D7E672DE2846FFBC0ECFB7ED456943A91078FBDA6174B964D1D90C
                  8D4201BED2456712BF4DA4F0AB33058D2389767B12AD3609CDD6143ADD414492
                  C25FC4084B514CAD7A29AD4EE8970DD005A6516F4EE0F44874333DCCA600536B
                  8AA3C19280DA1C471DFDCFB7AA36C450A99748E82E0E0D1DC1E1E123F86CF40B
                  7C6B398960E21E6D534697DF802A43083F92753C54A0421F4525B53DFFE585A7
                  C883D806D8573AFD019436EEA25C52CEE945FF603F838C4CCD42A366AA1E077A
                  3F85DA9479B4005F8F179CBC1E41B57103FD8124B8CB6F50055D9EF1E0E9A667
                  94B26CD983912503C2C975118C85AB267AD06891C5F32305F8D46C7EEE3895E6
                  0655D0520ADD3EA0CE398E5D0D4A49969C2FA1A04FE1B9F6BDA21FDE1A780777
                  72590CCC650A823305024CDE36D845CDA10C061752E8A332ADB00EE2F59E8378
                  B3EF23A534294D9CAE973BF7C1180AE00EED19260F79AC00BB25BB221B962994
                  856E214DDF08F27AD72C3A2682B844FD52A657E3D01F4771C27201C67FC2C262
                  BC6431176CF1C70B70CED91D951B2802ECEDFC11F9C920E1AC3E46250CFCEE07
                  F4745523753FAF6B9D48EC08CE143CE4E12F1B0B312CC0EFA4D1C60D44154655
                  C556CC7EAF99A21E71C445E5150BCEEC98C8C3D5F4B33106FE94D65962A82643
                  E4D37320167958C007293AF9E480EA5F0FFE04BC0B9E32850000000049454E44
                  AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object Image3: TImage
                Left = 199
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000001874944
                  4154484B63F8FFFF3F4D3156416A62AC82D8307B0CF37F648C2E8F0B631544C7
                  50035100B196601544C7300B0A6E39FC2FBEEBF8BFFCA1336D2CC8BF69FF3FFB
                  862DED2C48BF6CF53FE1821918D3C482983326FFC34E1A80314D2C083EA6FBDF
                  F7901618936501481336CC1A0BB1C063AFC67FC75D2A600C12C3A616844166C1
                  308AE18480DD56A5FFE61BE4FE1BAE91828A6007C8966058907DDDE67FD279F3
                  FF51A78CFF071DD5FDEF7D40EBBFF32ED5FF365B15FF9BAE97F9AFBF4AE2BFC6
                  12D1FF4A0B04FFCBCEE1FF2F319DE7BFD0248EFF7C7D6CFF797B58FFF3F6B1E2
                  B720E5B2C5FFA83340C38F030D3FA8F9DF65AFEA7FEB6D0AFF8DD7C8FCD7592E
                  F15F6DB1C87F857902FFA5E7F0FE179BCEF55F7012FB7FDE7EA0C148982C0BB4
                  978BFD575928FC5F6E2EC4D5245B00C220096C1816C9B273F9FE8BCFE0066392
                  23191F865920360DE2621046370817C62A888E6116F04F0046249660C087B10A
                  A263D6182620F51F9C42686201CBA805C4609081C8185D1E17C62A484D8C5590
                  7AF83F030027A00FF2BDC595610000000049454E44AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object Image4: TImage
                Left = 290
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000004614944
                  4154484BAD926B4C93571CC65F371797CD99ED83CBE2967D58B20FCB966D9971
                  B86C9F5C9625CB800D95A1388DE0C6B88E4BC18ECAB55C5AB90E689902AE500C
                  43E4520908589C290A58B002A21605A6146A814AB9B4B4E5B267E7BC2F360255
                  59C2499E2F27E7FC7EFFF3BC2F03605DD3B9F35D34BCB9C5B1C32496DEC1FF4D
                  54422D92131B086139FCDAE7EF61F17830C676BF8FB35B5F607799CCCA41FC4B
                  8FAE71F5DD1D65056957A69649AE176EC035976DB0057C05EDD76F43B5FD459C
                  DEF21C27B0CD2DD2836B5A5DBD23AC20BDC584A0A619FC742417FDE50C2C2A06
                  4D5F6EC4F017AFA1FDD3CD507DB209675F7F7EED820572C44E9EDAD1CD09322E
                  9B7058D2061FDF74E86BC9233A19F4CB19283EDE00C55B1B59F8498601935171
                  0736FBC212C6F99A2770B37D1133F340AB46C70AC27E57422028834CD685E6BC
                  ADAC80C6D8C849289C2C86492FBB0DEB53040B646A0A375916304ED23D3001BF
                  5F0B59B852694255D510C2FD43D05DBC09262527E83EC5C16998E3F29E270A68
                  2D16529F697601A3D3F3D099E65051A75E824FB2F0E2E25EE4E6B6C1DFFF0F84
                  FA1E40988F3BBDCAC26918B14CE3544027B790D2E9E42C7C9283D3CEEBEA1EA0
                  BA5AE7802727372234B4186E6E51F4AA034EC3880AD5B0DA48B98F2D077CC5E4
                  1CDCE01CEE1E49AF2E83D33029275A9709D85A087C92C0C7A6E7304C26576B0D
                  2CBCBE7E143535C32829B90589E42A52532F202CAC04DF79F0E1EE1942AFAF16
                  244B550E81B3C9293C2030EF89705ACBBEE0787CBF2F8222560B843917590161
                  63768EEB9C4E4E3BBF3B6675C0158A11C8E5B71DF0F070395CDD22F143800007
                  7829F03C748C109C0812339B609E9D838D8CFF782D03463BB252FC2114D6AC82
                  F378651C3CF018BC2392E01B9F87C381E984E744109F568F89691BA66C8BDCE4
                  263B0BBF396206CFFB0D4445C9515AAA8554AA8648A4C4D1A315D8B337165E41
                  B138C817E3E7949308955623885F44784E04B1A2733098AC30926A8649E7147E
                  EBC12C8A8A3250C07B197181DF90FFFE0C0BE7F339F8FEE038F8C4642128A314
                  7CD905086B34881456109E13418CB0123AA3057AF251071F12B8C18ACEFB93F8
                  C5EB4328925E4265C22B10057E84FDAEBBE0E1E68D1F4393E027942242528998
                  B216881AB5C856E9109DAA203C270241FC190C8C5A70CF348FBE713BBA746614
                  2B2EC27FEF3BA84EDC8CCC805711ECB90DBE47F6C02F361B21693244179D87B0
                  AA03E9CDFDC869334072750C02712DE1391144C79543AB37B3F01EBD15AD8326
                  B87B78C265C70E7CBBEB031C3AE88A30710178D9A5882E3887C4BF5A20AEEF45
                  966A88054B3B1EB279AAA04737831B061B3A86CCB8D467C4672E3BE1B6DB0B82
                  1C39124E29907C5A0971753B32CEF722934E7D450F897A9C05E7774E3C5BA0B9
                  370D0D99BEEDBE19CDDA0954750E41F6F74DE4375C87B4F106F22FF523FFB20E
                  92A53A1E811FE59982F6C169A87556A8FEB1A0A96F0A8A5E23CA3506C8D57AFC
                  A936A0B0631C27086425784D82DF884098403EDA3A64259C66D5C6FA06CC7F95
                  B7F1D04CBC4B7A0000000049454E44AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object Label17: TLabel
                Left = 183
                Top = 33
                Width = 51
                Height = 13
                Caption = 'INCLUS'#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object Label23: TLabel
                Left = 269
                Top = 33
                Width = 60
                Height = 13
                Caption = 'ALTERA'#199#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object Label24: TLabel
                Left = 365
                Top = 33
                Width = 52
                Height = 13
                Caption = 'EXCLUS'#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object Label25: TLabel
                Left = 444
                Top = 33
                Width = 81
                Height = 13
                Caption = 'CANCELAMENTO'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
            end
          end
          object dbmmoTRANSP_OBSERVACAO: TcxDBMemo
            Left = 5
            Top = 5
            Align = alClient
            DataBinding.DataField = 'TRANSP_OBS'
            DataBinding.DataSource = DMTransportador.dtsTB_TRANSPORTADOR
            ParentFont = False
            Properties.CharCase = ecUpperCase
            Properties.ScrollBars = ssVertical
            Style.Font.Charset = DEFAULT_CHARSET
            Style.Font.Color = clWindowText
            Style.Font.Height = -11
            Style.Font.Name = 'Tahoma'
            Style.Font.Style = []
            Style.IsFontAssigned = True
            TabOrder = 1
            Height = 353
            Width = 715
          end
        end
      end
      object tsAuditoria: TTabSheet
        Caption = 'Auditoria'
        ImageIndex = 1
        ExplicitLeft = 0
        ExplicitTop = 0
        ExplicitWidth = 0
        ExplicitHeight = 0
        object pnlAuditoria: TPanel
          Left = 0
          Top = 0
          Width = 725
          Height = 419
          Align = alClient
          BevelInner = bvRaised
          BevelOuter = bvLowered
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = []
          Padding.Left = 3
          Padding.Top = 3
          Padding.Right = 3
          Padding.Bottom = 3
          ParentBackground = False
          ParentFont = False
          ShowCaption = False
          TabOrder = 0
          object pnlLegenda: TPanel
            Left = 5
            Top = 358
            Width = 715
            Height = 56
            Align = alBottom
            BevelInner = bvRaised
            BevelOuter = bvLowered
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = []
            Padding.Left = 3
            Padding.Right = 3
            Padding.Bottom = 3
            ParentBackground = False
            ParentFont = False
            TabOrder = 0
            object grpLegenda: TGroupBox
              Left = 5
              Top = 2
              Width = 705
              Height = 49
              Align = alClient
              Caption = '| Legenda |'
              Color = clBtnFace
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Tahoma'
              Font.Style = [fsBold]
              ParentBackground = False
              ParentColor = False
              ParentFont = False
              TabOrder = 0
              object img7: TImage
                Left = 475
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000005
                  5E49444154484B8D54694C545714BE4D7F1A6BEB124559ECC832304001710690
                  1191196618A12A830255441150700B5111A996C6D8A676494CEC8F26FEE80F6C
                  D3D6A54D63A2696A6D1B695D4AED0FD3466B9B26CACC9B61DE1B76B79E777ACE
                  9B79F8404CFAE3DC7BEE79E77EDF59EE3BE29010BAE47708E123B94B7A8E6E7F
                  E3C9F70967A39D7592E99D427C47F7FF215B79D42644574459B14F88919ECD5E
                  BC5CB70AF70AF190EC39FC8D0178D7453F1BEDA4CFA0FBF7BECC32616F850DF7
                  0BF12FD9EA75021B835F69A8C2B193EFE1E8C747B0E7350FB6093146DFF2FE07
                  C1EC76216E9FCE588823FBAA70A4DD0BBF555899E411F97805A5F467CFFA0A1C
                  EB7E47558E7742F858073C3A7148BD546E47FA769F9C34125D382AC33E877C7E
                  3F9918838F0E5683BC6325845A5CEAE06E0FF4BA33F97E401C10E2FA371E3B8E
                  9EE882C163ED38F4411B0E1DDD058F3FDC8B174B6D1A0981E54D91C1EC08F87C
                  7CD0E105B9D58DC1162706B63A406971E02FA5E97CD7C7CEB15473E582C386F0
                  5127816FC781B75B413EDC8C63EFEFC48B4E2BEE8994CB6620984165B9757251
                  0CDE6FAFC450AB0B02CD4E941A8B516929811B2E0B9748255F979E6E0C8104CF
                  2E49C587C7DA20F466A32A773540FFC18D30F2D616F5A78A7C6EFC63F25D42BE
                  D3B8A1A7D3E2F041FB6A086C2D05A9A95895B61441B8A518AE14A7704040BE4E
                  2EA3966E343213A5143C936BC6D1A39441E7060C1DA8C5E0FE1A18EEACC5CBA5
                  394C3248E07F9DB1C4E3C02E0F04B73A506A5A8E01066F2EC29E6549484F1509
                  B84CCFD648C0FB2226399B9D8463471AB07FDF3A94F75482D2B69A5E48255EB2
                  A7E1A7D4D0819D6518685A01810602DF6447B9A910AE16256BE00785F01831B5
                  8585D389EA268A32783E2F1587F75781B27B952AEF2C87D0F6325076B821BCA3
                  540D342E077FC33255DA940FA18602E8758C97A5CC80A3614ECE40D713B81CE7
                  ADC938DC56C14F0F03CD25D4C44839A4CD85E8ABCF83D0A63CEC2D4E420A0808
                  CC39054E646199CC4C7B1C91F8BECA8C47A5D50191A8ED206D2C507D755608D4
                  59D5AB852695C0C7C8D735E9EEB83E816D923E8D9EE29D4F4C7350D9568C52FD
                  52F46DB4A16F432E48358BB1BF361BBECD8AE1C60F91FFE267E14C3818747EE7
                  F74E99635069A292D4E7A3AF6E094AB5B928556781B42E13A5AA7450AA33F087
                  6C8DE401DD7B6A763D8B409B2DA752E6A2D268477F9D0D7CEB197C3106ABB351
                  AE790524AF05A5351690569931B4260DBFCF98A7FF8C13669746C00B4BB476DA
                  6CE98E9F8943AD45E0DF60055F4D8E2AADCB06B9360BAE15C4AB671367A242D1
                  4BAFA6A87D1E33F8CA9221546E512F24CD796A764DEE81365BBA1366E140D352
                  F051C452750E523980A2C65F0BE39132BB4FE5089C4B9E8DFD1569D0E736639F
                  C38C771D44E2B1E0F9C40809016BB38B4974026DB674C7BF84038D055C0E90D6
                  66A17F6D3A2AD5997063690283AB74B18C2ECDA797237FFD3265B2D2827D4E22
                  284906DE998433E1974598368D8096E9DCD0CF897D784B3E35301BA4AA0CD55F
                  6981704D065CB3C58ECF16BEC06993C45026C1CF16BC80F2CA34B85792A23209
                  0B91A83F5AE6E9B32B57D0EF7DF534B12AFCFCE875F8BDE92C105E9B813FE72E
                  98305BF4B4A3BB89467DF08BD8173512CE40CF26E84EC54BA973B95C7D82C6EA
                  E84D473286A889814A0BB284A98957A2E0C6D9328980776D769D229270F99372
                  49AE54BCB36C91D60F76DCF63A01DD7226AAB2D7023295A6372F6ECAD9C2A29F
                  0D766D76714F026E33F85D66F5EFE589EAE1E79FE3E00E6BD190D2C1247F142D
                  C4EBD6586EE894B3C57836DA494F2092C173A65978DB6ED2C009EF5D0EC2E8B4
                  9B521AA6BAF693EE36D8C77D8C67A33DAAC7D1DD9B54F23005DC15B10BF11F91
                  934C77AC70338C0000000049454E44AE426082}
                Proportional = True
              end
              object img1: TImage
                Left = 382
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000004724944
                  4154484BAD956D489B5714C763DDC6DAAD1FC6BE6DB0D22FDB3E6CEBCAC65E60
                  305A288C313618135A56C6B06CA55B5BC13A371553ADE25BCABA56C42AD619E2
                  2ACE051BC90B9884C4A091BCE02C51AC62A54B89254A62481E929084E7BF73EE
                  D3A8A969BB412FFCD0E7E6DEF3BFF73CE7FC1F158027429B3383EDE4E7772CFC
                  BFD49AA582C079DA09FEBDE8A6FF42992E82F2A128CEDD88A1C99616013970AB
                  43A1C59EA665DB04CE8FC7D03D9344974FC225B7840E57024DF638AAC636F0DD
                  7014C70723383A1041993682AFEE738C444EFD19458D29210236DB32B8389945
                  8B23552870C52B219095B1480FB788791998CB81E68099940CEB7A16DAC534D4
                  CE048ED3A93FBFB6BEC931ED3A2A4637D03691C6D0620E9E3804973D892D01FB
                  5A5604E780DB61118605F977C61DCFA1672E85C64949D0359B8479350B7F72EB
                  704C0B1D8686226008668A0A3CC876B165222FCAF3B39491BF5374FA842CA8B5
                  D035F202BD748A62023769136FCC6FE653F2DC12E18FC5E08EAE618E0E3A4BB1
                  98E9480ED65585337F45B7049A1D0911201FC47B3F8FD3316283D2426B272332
                  BC11C0150EE313FD977841F3229E6DD98DF7063F8661C58BD30E35C683518C2C
                  405020C095E2B827638A82B8D66438C3B278B68714AC7765D882802F9CC5C181
                  0FA13AA782AA9AA853D8DDBA07FBBB5F85ED761ABD9E9CA04080D1DDCC882096
                  1519E6DB324CCB328C4B32C616658C2E90F00A50E9D04055A3C2BBDA0FF08DA5
                  1CAF74ED4389BA4488BCD67300C6F91C3AA83C991D021AA784B15B32F4F4C646
                  02390CCF6E717D06189B4FE1A52BFB7162FC7BDE2886DADDB4798B37FADEC7A0
                  5F46BD4912D0107137057E198B43EBA37A27FA3D59F47932E8716770752A8DAB
                  6E4033E9C3D7E672DE2846FFBC0ECFB7ED456943A91078FBDA6174B964D1D90C
                  8D4201BED2456712BF4DA4F0AB33058D2389767B12AD3609CDD6143ADD414492
                  C25FC4084B514CAD7A29AD4EE8970DD005A6516F4EE0F44874333DCCA600536B
                  8AA3C19280DA1C471DFDCFB7AA36C450A99748E82E0E0D1DC1E1E123F86CF40B
                  7C6B398960E21E6D534697DF802A43083F92753C54A0421F4525B53DFFE585A7
                  C883D806D8573AFD019436EEA25C52CEE945FF603F838C4CCD42A366AA1E077A
                  3F85DA9479B4005F8F179CBC1E41B57103FD8124B8CB6F50055D9EF1E0E9A667
                  94B26CD983912503C2C975118C85AB267AD06891C5F32305F8D46C7EEE3895E6
                  0655D0520ADD3EA0CE398E5D0D4A49969C2FA1A04FE1B9F6BDA21FDE1A780777
                  72590CCC650A823305024CDE36D845CDA10C061752E8A332ADB00EE2F59E8378
                  B3EF23A534294D9CAE973BF7C1180AE00EED19260F79AC00BB25BB221B962994
                  856E214DDF08F27AD72C3A2682B844FD52A657E3D01F4771C27201C67FC2C262
                  BC6431176CF1C70B70CED91D951B2802ECEDFC11F9C920E1AC3E46250CFCEE07
                  F4745523753FAF6B9D48EC08CE143CE4E12F1B0B312CC0EFA4D1C60D44154655
                  C556CC7EAF99A21E71C445E5150BCEEC98C8C3D5F4B33106FE94D65962A82643
                  E4D37320167958C007293AF9E480EA5F0FFE04BC0B9E32850000000049454E44
                  AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object img2: TImage
                Left = 199
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000001874944
                  4154484B63F8FFFF3F4D3156416A62AC82D8307B0CF37F648C2E8F0B631544C7
                  50035100B196601544C7300B0A6E39FC2FBEEBF8BFFCA1336D2CC8BF69FF3FFB
                  862DED2C48BF6CF53FE1821918D3C482983326FFC34E1A80314D2C083EA6FBDF
                  F7901618936501481336CC1A0BB1C063AFC67FC75D2A600C12C3A616844166C1
                  308AE18480DD56A5FFE61BE4FE1BAE91828A6007C8966058907DDDE67FD279F3
                  FF51A78CFF071DD5FDEF7D40EBBFF32ED5FF365B15FF9BAE97F9AFBF4AE2BFC6
                  12D1FF4A0B04FFCBCEE1FF2F319DE7BFD0248EFF7C7D6CFF797B58FFF3F6B1E2
                  B720E5B2C5FFA83340C38F030D3FA8F9DF65AFEA7FEB6D0AFF8DD7C8FCD7592E
                  F15F6DB1C87F857902FFA5E7F0FE179BCEF55F7012FB7FDE7EA0C148982C0BB4
                  978BFD575928FC5F6E2EC4D5245B00C220096C1816C9B273F9FE8BCFE0066392
                  23191F865920360DE2621046370817C62A888E6116F04F0046249660C087B10A
                  A263D6182620F51F9C42686201CBA805C4609081C8185D1E17C62A484D8C5590
                  7AF83F030027A00FF2BDC595610000000049454E44AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object img3: TImage
                Left = 290
                Top = 13
                Width = 18
                Height = 18
                Picture.Data = {
                  0B546478504E47496D61676589504E470D0A1A0A0000000D4948445200000018
                  000000180806000000E0773DF80000000467414D410000B18F0BFC6105000000
                  097048597300000B1200000B1201D2DD7EFC0000001C74455874536F66747761
                  72650041646F62652046697265776F726B732043533571B5E336000004614944
                  4154484BAD926B4C93571CC65F371797CD99ED83CBE2967D58B20FCB966D9971
                  B86C9F5C9625CB800D95A1388DE0C6B88E4BC18ECAB55C5AB90E689902AE500C
                  43E4520908589C290A58B002A21605A6146A814AB9B4B4E5B267E7BC2F360255
                  59C2499E2F27E7FC7EFFF3BC2F03605DD3B9F35D34BCB9C5B1C32496DEC1FF4D
                  54422D92131B086139FCDAE7EF61F17830C676BF8FB35B5F607799CCCA41FC4B
                  8FAE71F5DD1D65056957A69649AE176EC035976DB0057C05EDD76F43B5FD459C
                  DEF21C27B0CD2DD2836B5A5DBD23AC20BDC584A0A619FC742417FDE50C2C2A06
                  4D5F6EC4F017AFA1FDD3CD507DB209675F7F7EED820572C44E9EDAD1CD09322E
                  9B7058D2061FDF74E86BC9233A19F4CB19283EDE00C55B1B59F8498601935171
                  0736FBC212C6F99A2770B37D1133F340AB46C70AC27E57422028834CD685E6BC
                  ADAC80C6D8C849289C2C86492FBB0DEB53040B646A0A375916304ED23D3001BF
                  5F0B59B852694255D510C2FD43D05DBC09262527E83EC5C16998E3F29E270A68
                  2D16529F697601A3D3F3D099E65051A75E824FB2F0E2E25EE4E6B6C1DFFF0F84
                  FA1E40988F3BBDCAC26918B14CE3544027B790D2E9E42C7C9283D3CEEBEA1EA0
                  BA5AE7802727372234B4186E6E51F4AA034EC3880AD5B0DA48B98F2D077CC5E4
                  1CDCE01CEE1E49AF2E83D33029275A9709D85A087C92C0C7A6E7304C26576B0D
                  2CBCBE7E143535C32829B90589E42A52532F202CAC04DF79F0E1EE1942AFAF16
                  244B550E81B3C9293C2030EF89705ACBBEE0787CBF2F8222560B843917590161
                  63768EEB9C4E4E3BBF3B6675C0158A11C8E5B71DF0F070395CDD22F143800007
                  7829F03C748C109C0812339B609E9D838D8CFF782D03463BB252FC2114D6AC82
                  F378651C3CF018BC2392E01B9F87C381E984E744109F568F89691BA66C8BDCE4
                  263B0BBF396206CFFB0D4445C9515AAA8554AA8648A4C4D1A315D8B337165E41
                  B138C817E3E7949308955623885F44784E04B1A2733098AC30926A8649E7147E
                  EBC12C8A8A3250C07B197181DF90FFFE0C0BE7F339F8FEE038F8C4642128A314
                  7CD905086B34881456109E13418CB0123AA3057AF251071F12B8C18ACEFB93F8
                  C5EB4328925E4265C22B10057E84FDAEBBE0E1E68D1F4393E027942242528998
                  B216881AB5C856E9109DAA203C270241FC190C8C5A70CF348FBE713BBA746614
                  2B2EC27FEF3BA84EDC8CCC805711ECB90DBE47F6C02F361B21693244179D87B0
                  AA03E9CDFDC869334072750C02712DE1391144C79543AB37B3F01EBD15AD8326
                  B87B78C265C70E7CBBEB031C3AE88A30710178D9A5882E3887C4BF5A20AEEF45
                  966A88054B3B1EB279AAA04737831B061B3A86CCB8D467C4672E3BE1B6DB0B82
                  1C39124E29907C5A0971753B32CEF722934E7D450F897A9C05E7774E3C5BA0B9
                  370D0D99BEEDBE19CDDA0954750E41F6F74DE4375C87B4F106F22FF523FFB20E
                  92A53A1E811FE59982F6C169A87556A8FEB1A0A96F0A8A5E23CA3506C8D57AFC
                  A936A0B0631C27086425784D82DF884098403EDA3A64259C66D5C6FA06CC7F95
                  B7F1D04CBC4B7A0000000049454E44AE426082}
                Proportional = True
                Stretch = True
                Transparent = True
              end
              object lbl1: TLabel
                Left = 183
                Top = 33
                Width = 51
                Height = 13
                Caption = 'INCLUS'#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object lbl2: TLabel
                Left = 269
                Top = 33
                Width = 60
                Height = 13
                Caption = 'ALTERA'#199#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object lbl3: TLabel
                Left = 365
                Top = 33
                Width = 52
                Height = 13
                Caption = 'EXCLUS'#195'O'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
              object lbl4: TLabel
                Left = 444
                Top = 33
                Width = 81
                Height = 13
                Caption = 'CANCELAMENTO'
                Font.Charset = DEFAULT_CHARSET
                Font.Color = clWindowText
                Font.Height = -11
                Font.Name = 'Tahoma'
                Font.Style = []
                ParentFont = False
              end
            end
          end
          object cxgrdCadastro: TcxGrid
            Left = 5
            Top = 5
            Width = 715
            Height = 353
            Align = alClient
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = []
            ParentFont = False
            TabOrder = 1
            object cxgrdbtblvwCadastroDBTableView1: TcxGridDBTableView
              Navigator.Buttons.CustomButtons = <>
              DataController.DataSource = DMAuditoria.dsAUDITORIA_REGISTRO
              DataController.Summary.DefaultGroupSummaryItems = <>
              DataController.Summary.FooterSummaryItems = <
                item
                  Format = ',0'
                  Kind = skCount
                  FieldName = 'AUD_SEQUENCIA'
                  Column = cxgrdbclmnCadastroDBTableView1AUD_ACAO
                end>
              DataController.Summary.SummaryGroups = <>
              FilterRow.Visible = True
              OptionsData.CancelOnExit = False
              OptionsData.Deleting = False
              OptionsData.DeletingConfirmation = False
              OptionsData.Editing = False
              OptionsData.Inserting = False
              OptionsSelection.CellSelect = False
              OptionsView.Footer = True
              OptionsView.GroupByBox = False
              OptionsView.Indicator = True
              Styles.Content = cxstylCor1
              Styles.ContentEven = cxstylCor2
              object cxgrdbclmnCadastroDBTableView1AUD_ACAO: TcxGridDBColumn
                DataBinding.FieldName = 'AUD_ACAO'
                PropertiesClassName = 'TcxImageComboBoxProperties'
                Properties.Images = DMAuditoria.ilAuditoria
                Properties.Items = <
                  item
                    Description = 'INCLUS'#195'O'
                    ImageIndex = 0
                    Value = 'I'
                  end
                  item
                    Description = 'ALTERA'#199#195'O'
                    ImageIndex = 1
                    Value = 'A'
                  end
                  item
                    Description = 'EXCLUS'#195'O'
                    ImageIndex = 2
                    Value = 'E'
                  end
                  item
                    Description = 'CANCELAMENTO'
                    ImageIndex = 3
                    Value = 'C'
                  end>
                Properties.ShowDescriptions = False
                Width = 45
              end
              object cxgrdbclmnCadastroDBTableView1AUD_DT_LANCAMENTO: TcxGridDBColumn
                DataBinding.FieldName = 'AUD_DT_LANCAMENTO'
                Width = 149
              end
              object cxgrdbclmnCadastroDBTableView1AUD_USUARIO: TcxGridDBColumn
                DataBinding.FieldName = 'AUD_USUARIO'
                Width = 82
              end
              object cxgrdbclmnCadastroDBTableView1USU_NOME: TcxGridDBColumn
                DataBinding.FieldName = 'USU_NOME'
                Width = 320
              end
            end
            object cxgrdbtblvwCadastroDBTableView2: TcxGridDBTableView
              Navigator.Buttons.CustomButtons = <>
              DataController.DataSource = DMAuditoria.dsAUDITORIA_REGISTRO_ITEM
              DataController.DetailKeyFieldNames = 'AUDI_AUDITORIA'
              DataController.KeyFieldNames = 'AUDI_AUDITORIA'
              DataController.MasterKeyFieldNames = 'AUD_SEQUENCIA'
              DataController.Summary.DefaultGroupSummaryItems = <>
              DataController.Summary.FooterSummaryItems = <>
              DataController.Summary.SummaryGroups = <>
              OptionsData.CancelOnExit = False
              OptionsData.Deleting = False
              OptionsData.DeletingConfirmation = False
              OptionsData.Editing = False
              OptionsData.Inserting = False
              OptionsSelection.CellSelect = False
              OptionsView.GroupByBox = False
              Styles.Content = cxstylCor2
              Styles.ContentEven = cxstylCor1
              object cxgrdbclmnCadastroDBTableView2AUDI_CAMPO_DESC: TcxGridDBColumn
                DataBinding.FieldName = 'AUDI_CAMPO_DESC'
                Width = 200
              end
              object cxgrdbclmnCadastroDBTableView2AUDI_VALOR_ANTIGO: TcxGridDBColumn
                DataBinding.FieldName = 'AUDI_VALOR_ANTIGO'
                Width = 235
              end
              object cxgrdbclmnCadastroDBTableView2AUDI_VALOR_NOVO: TcxGridDBColumn
                DataBinding.FieldName = 'AUDI_VALOR_NOVO'
                Width = 235
              end
            end
            object cxgrdlvlCadastroLevel1: TcxGridLevel
              GridView = cxgrdbtblvwCadastroDBTableView1
              object cxgrdlvlCadastroLevel2: TcxGridLevel
                GridView = cxgrdbtblvwCadastroDBTableView2
              end
            end
          end
        end
      end
    end
  end
  inherited ACBrEnterTab: TACBrEnterTab
    Left = 384
    Top = 504
  end
  inherited ApplicationEvents: TApplicationEvents
    Left = 192
    Top = 496
  end
  inherited cxstylrpstryCores: TcxStyleRepository
    Left = 280
    Top = 496
    PixelsPerInch = 96
  end
end
