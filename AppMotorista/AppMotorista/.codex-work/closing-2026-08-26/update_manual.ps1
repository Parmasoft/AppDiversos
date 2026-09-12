param(
  [Parameter(Mandatory = $true)]
  [string]$DocumentPath
)

$word = $null
$document = $null

function Add-Heading {
  param([object]$Selection, [string]$Text, [int]$Level)
  $Selection.Style = if ($Level -eq 1) { -2 } elseif ($Level -eq 2) { -3 } else { -4 }
  $Selection.TypeText($Text)
  $Selection.TypeParagraph()
}

function Add-Paragraph {
  param([object]$Selection, [string]$Text)
  $Selection.Style = -1
  $Selection.Font.Name = 'Arial'
  $Selection.Font.Size = 11
  $Selection.TypeText($Text)
  $Selection.TypeParagraph()
}

function Add-Bullet {
  param([object]$Selection, [string]$Text)
  Add-Paragraph $Selection ("• " + $Text)
}

function Add-Code {
  param([object]$Selection, [string[]]$Lines)
  foreach ($line in $Lines) {
    $Selection.Style = -1
    $Selection.Font.Name = 'Consolas'
    $Selection.Font.Size = 9
    $Selection.TypeText($line)
    $Selection.TypeParagraph()
  }
  $Selection.Font.Name = 'Arial'
  $Selection.Font.Size = 11
}

try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  $missing = [Type]::Missing
  $document = $word.Documents.Open(
    $DocumentPath,
    $false,
    $false,
    $false,
    $missing,
    $missing,
    $false,
    $missing,
    $missing,
    $missing,
    $missing,
    $false,
    $true
  )
  $document.Activate()
  $selection = $word.Selection
  $selection.EndKey(6) | Out-Null
  $selection.InsertBreak(7)

  Add-Heading $selection 'FECHAMENTO OPERACIONAL DO APP MOTORISTA — 26/08/2026' 1
  Add-Paragraph $selection 'Este capítulo consolida o cadastro real do Motorista App pelo Transportador, a liberação automática do Manifesto, a homologação do Paulo e da Carga 527, a leitura normal C/R no Flutter, as regras de ordenação/navegação e o ponto exato de continuidade. Ele complementa e atualiza os capítulos históricos anteriores; não apaga o histórico do projeto.'

  Add-Heading $selection '1. ESTADO CONSOLIDADO' 2
  Add-Bullet $selection 'Manifesto, autenticação do Motorista App, API de viagens e backend da Conferência Normal C/R estão implementados e homologados.'
  Add-Bullet $selection 'A leitura física pelo App foi homologada no aparelho e persistiu a entrega no backend.'
  Add-Bullet $selection 'O último ajuste visual e de navegação está IMPLEMENTADO / AGUARDANDO TESTE FÍSICO.'
  Add-Bullet $selection 'A câmera está implementada e testada automaticamente, mas ainda não foi homologada fisicamente.'
  Add-Bullet $selection 'Último Controle de Versão: actScript171 / versão 1.1.0.71. Nenhum script novo foi criado nesta etapa.'
  Add-Bullet $selection 'Flutter oficial: E:\Jorginho\AppMotorista\AppMotorista.'
  Add-Bullet $selection 'API oficial: E:\Jorginho\AppMotorista\ApiMotorista.'
  Add-Bullet $selection 'Banco da homologação local: localhost:E:\Dados Clientes\GramDecor\DADOS.FDB; Empresa 10.'

  Add-Heading $selection '2. CADASTRO DO MOTORISTA APP PELO TRANSPORTADOR' 2
  Add-Paragraph $selection 'A carga determina quem realizará o transporte por TB_CARGA.CARG_TRANSPORTADOR. Na própria tela Dados Principais do Cadastro de Transportadores foi incluída a área Acesso ao App Motorista, com Usa App Motorista, Usuário e Senha. Não foi criada uma nova aba e não foram criados campos de usuário/senha em TB_TRANSPORTADOR.'
  Add-Code $selection @(
    'Transportador',
    '→ TB_MOTORISTA_APP_EMPRESA.MOTAPPE_TRANSPORTADOR',
    '→ TB_MOTORISTA_APP_EMPRESA.MOTAPPE_MOTORISTA',
    '→ TB_MOTORISTA_APP.MOTAPP_ID',
    '→ login e hash de senha oficiais do Motorista App'
  )
  Add-Bullet $selection 'Vínculo ativo na empresa e motorista global ativo significam que o Transportador usa o App.'
  Add-Bullet $selection 'A senha não é exibida nem persistida em texto puro. Senha vazia na alteração preserva o hash atual; senha informada gera hash scrypt compatível com a API.'
  Add-Bullet $selection 'O login segue as estruturas oficiais e a unicidade global do Motorista App.'
  Add-Bullet $selection 'A desativação inativa o vínculo sem apagar histórico. Uma reativação reutiliza o vínculo existente.'
  Add-Bullet $selection 'Mais de um Motorista App ativo para a mesma Empresa + Transportador é inconsistência; o sistema não escolhe arbitrariamente.'
  Add-Paragraph $selection 'Motorista próprio homologado: Transportador 22 — PAULO HENRIQUE GONÇALVES, vinculado ao MOTAPP_ID 4 na Empresa 10. A autenticação real foi validada no aparelho. A senha usada nunca deve ser registrada em documentação.'
  Add-Paragraph $selection 'Transportador terceirizado: transportadoras externas, ônibus e terceiros sem Motorista App vinculado não recebem a carga no App. A Conferência termina normalmente e o Manifesto permanece sem liberação para o App. Esse resultado é válido e não representa erro.'
  Add-Paragraph $selection 'Fontes do cadastro: View\Cad\UManTransportador.pas/.dfm; Controller\UClassTransportador.pas; Controller\UClassMotoristaApp.pas; ParmaGestor.dpr e ParmaGestor.dproj. Métodos centrais: CarregarAcessoTransportador, SalvarAcessoTransportador, ValidarLoginUnico e GerarHashSenhaMotoristaApp.'

  Add-Heading $selection '3. GERAÇÃO E LIBERAÇÃO AUTOMÁTICA DO MANIFESTO' 2
  Add-Paragraph $selection 'Na Conferência de Carga normal não existe F12 para finalizar. A leitura do último item deixa a consulta de pendências vazia; TFrmManConfereCarga.edtCodigoKeyDown chama TConfereCarga.FinalizarConferencia.'
  Add-Code $selection @(
    'edtCodigoKeyDown',
    '→ TConfereCarga.FinalizarConferencia',
    '→ SP_FIN_CONFERE_CARGA',
    '→ SP_GERA_CARGA_PARADAS',
    '→ SP_GERA_CARGA_MANIFESTO'
  )
  Add-Paragraph $selection 'O Manifesto nasce em G. Depois do sucesso das rotinas atuais e antes do commit, Controller\UClassConfereCarga.pas executa:'
  Add-Code $selection @(
    'SP_GERA_CARGA_MANIFESTO',
    '→ TConfereCarga.LiberarManifestoParaMotoristaApp',
    '→ SP_LIBERA_CARGA_MANIFESTO',
    '→ Commit'
  )
  Add-Paragraph $selection 'LiberarManifestoParaMotoristaApp lê TB_CARGA.CARG_TRANSPORTADOR e procura vínculo ativo para a mesma Empresa + Transportador em TB_MOTORISTA_APP_EMPRESA, confirmando também TB_MOTORISTA_APP.MOTAPP_ATIVO = S.'
  Add-Bullet $selection 'Exatamente um motorista válido: atribui o MOTAPP_ID, muda o Manifesto G → L e disponibiliza a viagem em Minhas viagens desse motorista.'
  Add-Bullet $selection 'Nenhum motorista vinculado: finaliza a Conferência normalmente e não libera o Manifesto ao App.'
  Add-Bullet $selection 'Mais de um vínculo válido ou outra inconsistência: não escolhe motorista arbitrariamente; a falha participa da mesma transação.'
  Add-Bullet $selection 'Manifesto já L/F para o mesmo motorista é tratado de forma idempotente; motorista diferente não é sobrescrito.'
  Add-Paragraph $selection 'Fontes diretamente envolvidas: View\Mov\UManConfereCarga.pas e Controller\UClassConfereCarga.pas.'

  Add-Heading $selection '4. HOMOLOGAÇÃO DO PAULO E DA CARGA 527' 2
  Add-Bullet $selection 'Paulo foi configurado com acesso ao App pelo Cadastro de Transportadores.'
  Add-Bullet $selection 'O vínculo Transportador 22 → Empresa 10 → MOTAPP_ID 4 funcionou.'
  Add-Bullet $selection 'O login real foi validado no aparelho físico.'
  Add-Bullet $selection 'A Carga 527 foi criada pelo fluxo normal.'
  Add-Bullet $selection 'Seu Manifesto foi atribuído e liberado automaticamente pelo processo novo.'
  Add-Bullet $selection 'A Carga 527 apareceu em Minhas viagens; Viagem, Paradas e Pedidos abriram corretamente.'
  Add-Paragraph $selection 'O usuário temporário MOTAPP_ID 1, Motorista Homologacao, login A, foi retirado de uso sem exclusão física. Motorista e vínculo estão inativos, todas as sessões históricas estão revogadas e o login não autentica nem renova. Manifesto 5 e Carga 504 foram preservados e não foram transferidos para Paulo.'

  Add-Heading $selection '5. LEITURA NORMAL C/R NO FLUTTER' 2
  Add-Paragraph $selection 'A primeira versão da tela Pedido usava TextField convencional, abria o teclado Android, ocupava área excessiva e não reproduzia a operação da Separação. Ela foi substituída pelo padrão auditado/adaptado de E:\Jorginho\BarCode\BarCodeNovo, especialmente ScannerPage, Separação de Pedido e Separação de Requisição.'
  Add-Bullet $selection 'Leitor físico/HID por KeyboardListener, sem TextField operacional e sem necessidade de teclado virtual.'
  Add-Bullet $selection 'Caracteres enviados por ENTER/numpad ENTER; KeyUp ignorado; backspace suportado.'
  Add-Bullet $selection 'Foco restaurado e leitor preparado imediatamente após cada resposta.'
  Add-Bullet $selection 'Bloqueio enquanto existe requisição em andamento e debounce de 800 ms.'
  Add-Bullet $selection 'Câmera disponível por botão compacto; CameraScannerScreen usa mobile_scanner, câmera traseira, Code 128/QR e noDuplicates.'
  Add-Bullet $selection 'Leitor físico e câmera convergem para o mesmo _submit e DeliveryScannerController.'
  Add-Bullet $selection 'Endpoint oficial: POST /api/v1/motorista/viagens/{manifesto_guid}/paradas/{parada}/pedidos/{pedido}/leituras.'
  Add-Bullet $selection 'O Flutter envia o código; o backend escolhe a ocorrência C/R, trata ROLO_ID, censuras, multiplicidade, idempotência, concorrência e conclusão.'
  Add-Paragraph $selection 'Arquivos finais principais: lib\viagens\screens\order_screen.dart, camera_scanner_screen.dart, stop_screen.dart, trip_detail_screen.dart e trips_screen.dart; lib\viagens\services\delivery_scanner_controller.dart, hardware_barcode_buffer.dart, delivery_operation_guid.dart e trips_service.dart; lib\viagens\utils\delivery_progress.dart; models/repository do contrato de leitura; pubspec e AndroidManifest.'

  Add-Heading $selection '6. TESTE FÍSICO JÁ COMPROVADO' 2
  Add-Bullet $selection 'A leitura física da etiqueta funcionou.'
  Add-Bullet $selection 'O backend registrou a entrega.'
  Add-Bullet $selection 'Pendente/Entregue e a ocorrência foram atualizados.'
  Add-Bullet $selection 'Pedido e Parada puderam ser concluídos.'
  Add-Bullet $selection 'A releitura posterior recebeu corretamente a censura de que todas as ocorrências daquela etiqueta já haviam sido entregues, comprovando a persistência da primeira leitura.'
  Add-Paragraph $selection 'A câmera ainda não foi testada fisicamente e não está homologada no aparelho.'

  Add-Heading $selection '7. REGRAS VISUAIS E OPERACIONAIS PARA CONCLUÍDOS' 2
  Add-Code $selection @(
    'PEDIDO:',
    'Pendentes → primeiro',
    'Entregues → final, amarelo-claro, permanecem visíveis',
    '',
    'PARADA:',
    'Pedidos pendentes → primeiro',
    'Pedidos concluídos → final, amarelo-claro, sem reentrada',
    '',
    'VIAGEM:',
    'Paradas pendentes → primeiro',
    'Paradas concluídas → final, amarelo-claro, sem reabertura'
  )
  Add-Paragraph $selection 'A ordenação é uma partição estável: preserva a ordem original dentro de cada grupo e não volta a ordenar por produto/código após aplicar o estado operacional.'

  Add-Heading $selection '8. NAVEGAÇÃO DEPOIS DA LEITURA' 2
  Add-Bullet $selection 'Ainda existem etiquetas no Pedido: permanece no Pedido, atualiza dados/contadores/lista e prepara a próxima leitura.'
  Add-Bullet $selection 'Pedido e Parada concluídos, com outra Parada pendente: retorna diretamente para Viagem, recarrega o backend, coloca a próxima pendente acima e a concluída amarela/bloqueada abaixo.'
  Add-Bullet $selection 'Última etiqueta do último Pedido da última Parada: recarrega o detalhe oficial, confirma todos os Pedidos e Paradas em E, retorna diretamente para Minhas viagens, recarrega a lista e mostra Carga descarregada com sucesso.'
  Add-Paragraph $selection 'A conclusão total não é fabricada por contador local. TripDetailScreen recarrega o detalhe oficial e tripIsCompleted exige estados E no retorno do backend antes de propagar TripDetailResult.completed para TripsScreen.'

  Add-Heading $selection '9. ÚLTIMA IMPLEMENTAÇÃO — AINDA NÃO HOMOLOGADA FISICAMENTE' 2
  Add-Paragraph $selection 'IMPLEMENTADO / AGUARDANDO TESTE FÍSICO. Ainda dependem de uma nova Carga/Pedido/etiquetas: Pendentes primeiro e Entregues amarelos no final dentro do Pedido; retorno automático; bloqueio de concluídos; salto direto para Minhas viagens na conclusão total; mensagem final da descarga.'
  Add-Code $selection @(
    'flutter analyze → No issues found',
    'flutter test    → 33 testes aprovados'
  )
  Add-Paragraph $selection 'Os testes automáticos usaram fakes e não chamaram endpoint real nem alteraram Firebird.'

  Add-Heading $selection '10. PENDÊNCIA — COMUNICAÇÃO LOCAL FLUTTER ↔ API E DIAGNÓSTICO' 2
  Add-Paragraph $selection 'O teste atual usa aparelho físico por USB, API local na porta 5055 e adb reverse tcp:5055 tcp:5055. Após desconectar/reconectar o celular, reiniciar ADB ou trocar o aparelho, o reverse pode precisar ser restabelecido.'
  Add-Bullet $selection 'Tornar detecção do aparelho, adb reverse e inicialização do App automáticos/confiáveis.'
  Add-Bullet $selection 'Melhorar diagnóstico de falha de comunicação local.'
  Add-Bullet $selection 'Melhorar a janela da API para exibir método, rota, tempo e status HTTP, por exemplo sessões 200, viagens 200, leituras 200/409 e erro interno 500.'
  Add-Bullet $selection 'Nunca exibir senhas, tokens, hashes ou informações sensíveis.'
  Add-Paragraph $selection 'Esta pendência deve ser tratada depois da homologação final da leitura e antes de grandes refinamentos visuais. Não foi implementada nesta atualização documental.'

  Add-Heading $selection '11. PRÓXIMOS PASSOS OFICIAIS' 2
  Add-Paragraph $selection '1. Criar nova Carga/Pedido de teste pelo fluxo normal.'
  Add-Paragraph $selection '2. Homologar fisicamente a última correção: Pendentes primeiro, Entregues amarelos no final, retorno automático, bloqueio de concluídos e conclusão total voltando para Minhas viagens.'
  Add-Paragraph $selection '3. Homologar a câmera, caso ainda não tenha sido testada fisicamente.'
  Add-Paragraph $selection '4. Melhorar/fechar comunicação local e diagnóstico da API: ADB reverse, inicialização e logs HTTP/status.'
  Add-Paragraph $selection '5. Somente depois iniciar refinamento do layout das telas do App.'
  Add-Paragraph $selection '6. Após uso operacional, reavaliar se a tela intermediária Parada continua necessária, pode ser simplificada ou pode ganhar nova função. Não remover a tela agora.'

  Add-Heading $selection '12. DIRETRIZ DE CONTINUIDADE' 2
  Add-Paragraph $selection 'O próximo agente deve começar pela seção mais recente de STATUS_APP_MOTORISTA_CARGA.md. Não deve refazer autenticação, Manifesto, vínculo Transportador → Motorista App, backend C/R ou scanner; não deve alterar API sem incompatibilidade comprovada; não deve reconstruir o histórico por busca ampla nem ler _HISTORICO_NAO_LER.'
  Add-Paragraph $selection 'Este fechamento alterou somente STATUS_APP_MOTORISTA_CARGA.md e este manual. Nenhum fonte Delphi, Flutter ou API foi alterado; nenhum banco, carga, pedido, Manifesto ou leitura real foi modificado.'

  $document.Save()
}
finally {
  if ($null -ne $document) {
    $document.Close($false)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
  }
  if ($null -ne $word) {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
