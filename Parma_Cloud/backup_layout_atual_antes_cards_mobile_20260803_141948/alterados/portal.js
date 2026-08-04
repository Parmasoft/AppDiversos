"use strict";

const painelLogin = document.getElementById("painelLogin");
const painelConsulta = document.getElementById("painelConsulta");
const painelResultado = document.getElementById("painelResultado");

const formLogin = document.getElementById("formLogin");
const campoUsuario = document.getElementById("usuario");
const campoSenha = document.getElementById("senha");
const botaoEntrar = document.getElementById("btnEntrar");
const mensagemLogin = document.getElementById("mensagemLogin");

const campoBusca = document.getElementById("busca");
const botaoPesquisar = document.getElementById("btnPesquisar");
const listaProdutos = document.getElementById("listaProdutos");
const quantidade = document.getElementById("quantidade");

const nomeCliente = document.getElementById("nomeCliente");
const nomeUsuario = document.getElementById("nomeUsuario");
const situacao = document.getElementById("situacao");
const botaoSair = document.getElementById("btnSair");

const chaveUsuarioLogado = "parmasoft.portal.usuarioLogado";


function obterIdentificadorCliente() {
    const parametros = new URLSearchParams(window.location.search);
    const clienteQuery = (parametros.get("cliente") || "")
        .trim()
        .toLowerCase();

    if (clienteQuery) {
        return clienteQuery;
    }

    const partes = window.location.pathname
        .split("/")
        .filter(Boolean);

    const indicePortal = partes.indexOf("portal");

    if (
        indicePortal >= 0
        && partes.length > indicePortal + 1
        && partes[indicePortal + 1] !== "index.html"
    ) {
        return partes[indicePortal + 1]
            .trim()
            .toLowerCase();
    }

    return "";
}


const identificador = obterIdentificadorCliente();


function obterUsuarioDoLogin(dadosLogin = null) {
    if (dadosLogin?.nome_usuario) {
        return dadosLogin.nome_usuario;
    }

    if (dadosLogin?.usuario) {
        return dadosLogin.usuario;
    }

    return "";
}


function guardarUsuarioLogado(usuario) {
    if (!usuario) {
        return;
    }

    try {
        window.sessionStorage.setItem(chaveUsuarioLogado, usuario);
    } catch {
        // O portal continua funcionando mesmo se o navegador bloquear storage.
    }
}


function recuperarUsuarioLogado() {
    try {
        return window.sessionStorage.getItem(chaveUsuarioLogado) || "";
    } catch {
        return "";
    }
}


function limparUsuarioLogado() {
    try {
        window.sessionStorage.removeItem(chaveUsuarioLogado);
    } catch {
        // O portal continua funcionando mesmo se o navegador bloquear storage.
    }
}


function escaparHtml(valor) {
    return String(valor ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


function formatarQuantidade(valor) {
    return Number(valor || 0).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 4
    });
}


function formatarPreco(valor) {
    return Number(valor || 0).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}


function formatarCusto(valor) {
    if (valor === null || valor === undefined || valor === "") {
        return "—";
    }

    return Number(valor).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}


function formatarDataUltimaCompra(valor) {
    if (!valor) {
        return null;
    }

    const texto = String(valor).trim();

    if (!texto) {
        return null;
    }

    const partes = texto.slice(0, 10).split("-");

    if (partes.length === 3) {
        return `${partes[2]}/${partes[1]}/${partes[0]}`;
    }

    const data = new Date(texto);

    if (Number.isNaN(data.getTime())) {
        return null;
    }

    return data.toLocaleDateString("pt-BR");
}


function textoUltimaCompra(produto) {
    const data = formatarDataUltimaCompra(produto.data_ultima_compra);

    if (!data) {
        return "Última compra: não localizada";
    }

    const partes = [`Última compra: ${data}`];

    if (produto.nota_ultima_compra) {
        partes.push(`NF ${produto.nota_ultima_compra}`);
    }

    if (produto.serie_ultima_compra) {
        partes.push(`Série ${produto.serie_ultima_compra}`);
    }

    return partes.join(" · ");
}


function textoUltimaCompraMobile(produto) {
    const data = formatarDataUltimaCompra(produto.data_ultima_compra);

    if (!data) {
        return "ÚLTIMA COMPRA: NÃO LOCALIZADA";
    }

    const partes = [`ÚLTIMA COMPRA: ${data}`];

    if (produto.nota_ultima_compra) {
        partes.push(`NF: ${produto.nota_ultima_compra}`);
    }

    if (produto.serie_ultima_compra) {
        partes.push(`SÉRIE: ${produto.serie_ultima_compra}`);
    }

    return partes.join("   ");
}


function htmlPainelProdutoMobile(produto) {
    const unidade = produto.unidade
        ? `<span>UN: ${escaparHtml(produto.unidade)}</span>`
        : "";

    return `
        <div class="produto-mobile-linha produto-mobile-linha-principal">
            <strong>${escaparHtml(produto.produto)}</strong>
            <span class="produto-mobile-descricao">
                ${escaparHtml(produto.descricao)}
            </span>
            ${unidade}
        </div>
        <div class="produto-mobile-linha produto-mobile-linha-valores">
            <span>ESTOQUE: ${formatarQuantidade(produto.estoque)}</span>
            <span>CUSTO: ${formatarCusto(produto.custo)}</span>
            <span>PREÇO: ${formatarPreco(produto.preco)}</span>
        </div>
        <div class="produto-mobile-linha produto-mobile-linha-compra">
            ${escaparHtml(textoUltimaCompraMobile(produto))}
        </div>
    `;
}


function definirSituacao(texto, tipo = "") {
    situacao.textContent = texto;
    situacao.className = "situacao";

    if (tipo) {
        situacao.classList.add(`situacao-${tipo}`);
    }
}


function mostrarLogin(mensagem = "") {
    painelLogin.classList.remove("oculto");
    painelConsulta.classList.add("oculto");
    painelResultado.classList.add("oculto");

    mensagemLogin.textContent = mensagem;
    nomeUsuario.textContent = "—";
    limparUsuarioLogado();

    definirSituacao("Aguardando login");

    campoSenha.value = "";
    campoBusca.value = "";
    exibirMensagem("Digite um produto para iniciar a consulta.");
    campoUsuario.focus();
}


function mostrarConsulta(dadosLogin = null) {
    painelLogin.classList.add("oculto");
    painelConsulta.classList.remove("oculto");
    painelResultado.classList.remove("oculto");

    mensagemLogin.textContent = "";

    const usuarioLogin = obterUsuarioDoLogin(dadosLogin);

    if (usuarioLogin) {
        guardarUsuarioLogado(usuarioLogin);
        nomeUsuario.textContent = usuarioLogin;
    } else {
        nomeUsuario.textContent = recuperarUsuarioLogado() || "—";
    }

    definirSituacao("Conectado", "sucesso");
    campoBusca.focus();
}


function exibirMensagem(texto) {
    listaProdutos.innerHTML = `
        <tr>
            <td colspan="6" class="mensagem">
                ${escaparHtml(texto)}
            </td>
        </tr>
    `;

    quantidade.textContent = "0 produtos";
}


function exibirProdutos(produtos) {
    if (!Array.isArray(produtos) || produtos.length === 0) {
        exibirMensagem("Nenhum produto encontrado.");
        return;
    }

    listaProdutos.innerHTML = produtos.map((produto) => `
        <tr>
            <td class="codigo">
                ${escaparHtml(produto.produto)}
            </td>

            <td class="produto-info">
                <div class="produto-descricao-principal">
                    ${escaparHtml(produto.descricao)}
                </div>
                <div class="produto-ultima-compra produto-ultima-compra-desktop">
                    ${escaparHtml(textoUltimaCompra(produto))}
                </div>
                <div class="produto-ultima-compra produto-ultima-compra-mobile">
                    ${escaparHtml(textoUltimaCompraMobile(produto))}
                </div>
            </td>

            <td class="unidade" data-label="UN:">
                ${escaparHtml(produto.unidade || "")}
            </td>

            <td class="numero estoque" data-label="ESTOQUE:">
                ${formatarQuantidade(produto.estoque)}
            </td>

            <td class="numero custo" data-label="CUSTO:">
                ${formatarCusto(produto.custo)}
            </td>

            <td class="numero preco" data-label="PREÇO:">
                ${formatarPreco(produto.preco)}
            </td>

            <td class="produto-mobile-painel" colspan="6">
                ${htmlPainelProdutoMobile(produto)}
            </td>
        </tr>
    `).join("");

    quantidade.textContent =
        `${produtos.length} produto${produtos.length === 1 ? "" : "s"}`;
}


async function lerRespostaJson(resposta) {
    try {
        return await resposta.json();
    } catch {
        return {
            ok: false,
            message: "Resposta inválida recebida do servidor."
        };
    }
}


async function realizarLogin(evento) {
    evento.preventDefault();

    const usuario = campoUsuario.value.trim();
    const senha = campoSenha.value;

    if (!identificador) {
        mensagemLogin.textContent =
            "O cliente não foi informado no endereço do portal.";

        definirSituacao("Cliente não informado", "erro");
        return;
    }

    if (!usuario || !senha) {
        mensagemLogin.textContent =
            "Informe o usuário e a senha.";

        return;
    }

    botaoEntrar.disabled = true;
    mensagemLogin.textContent = "";
    definirSituacao("Entrando...");

    try {
        const resposta = await fetch(
            `/portal/${encodeURIComponent(identificador)}/login`,
            {
                method: "POST",
                credentials: "same-origin",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    usuario,
                    senha
                })
            }
        );

        const dados = await lerRespostaJson(resposta);

        if (!resposta.ok || !dados.ok) {
            mostrarLogin(
                dados.message || "Não foi possível realizar o login."
            );

            definirSituacao("Login inválido", "erro");
            return;
        }

        if (dados.nome_fantasia) {
            nomeCliente.textContent = dados.nome_fantasia;
            document.title =
                `${dados.nome_fantasia} - Consulta de Produtos`;
        }

        mostrarConsulta(dados);
        exibirMensagem("Digite um produto para iniciar a consulta.");
    } catch (erro) {
        console.error(erro);

        mostrarLogin(
            "Não foi possível comunicar com o servidor."
        );

        definirSituacao("Erro de conexão", "erro");
    } finally {
        botaoEntrar.disabled = false;
    }
}


async function pesquisar() {
    const busca = campoBusca.value.trim();

    if (!busca) {
        exibirMensagem("Digite um produto para pesquisar.");
        campoBusca.focus();
        return;
    }

    botaoPesquisar.disabled = true;
    definirSituacao("Consultando...");
    exibirMensagem("Consultando produtos...");

    try {
        const parametros = new URLSearchParams({
            busca,
            limite: "100"
        });

        const resposta = await fetch(
            `/portal/${encodeURIComponent(identificador)}/produtos`
            + `?${parametros.toString()}`,
            {
                method: "GET",
                credentials: "same-origin",
                headers: {
                    "Accept": "application/json"
                }
            }
        );

        const dados = await lerRespostaJson(resposta);

        if (resposta.status === 401) {
            mostrarLogin(
                "Sua sessão expirou. Entre novamente."
            );

            definirSituacao("Sessão expirada", "erro");
            return;
        }

        if (!resposta.ok || !dados.ok) {
            throw new Error(
                dados.message || "Erro ao consultar produtos."
            );
        }

        if (dados.nome_fantasia) {
            nomeCliente.textContent = dados.nome_fantasia;
        }

        exibirProdutos(dados.produtos);
        definirSituacao("Consulta concluída", "sucesso");
    } catch (erro) {
        console.error(erro);

        exibirMensagem(
            erro.message || "Não foi possível realizar a consulta."
        );

        definirSituacao("Erro", "erro");
    } finally {
        botaoPesquisar.disabled = false;
    }
}


async function realizarLogout() {
    if (!identificador) {
        mostrarLogin();
        return;
    }

    if (botaoSair) {
        botaoSair.disabled = true;
    }

    definirSituacao("Saindo...");

    try {
        await fetch(
            `/portal/${encodeURIComponent(identificador)}/logout`,
            {
                method: "POST",
                credentials: "same-origin",
                headers: {
                    "Accept": "application/json"
                }
            }
        );
    } catch (erro) {
        console.error(erro);
    } finally {
        if (botaoSair) {
            botaoSair.disabled = false;
        }

        mostrarLogin();
    }
}


async function verificarSessaoExistente() {
    if (!identificador) {
        mostrarLogin(
            "O endereço do portal não contém o identificador do cliente."
        );

        definirSituacao("Cliente não informado", "erro");
        return;
    }

    definirSituacao("Verificando sessão...");

    try {
        const resposta = await fetch(
            `/portal/${encodeURIComponent(identificador)}/produtos`
            + "?limite=1",
            {
                method: "GET",
                credentials: "same-origin",
                headers: {
                    "Accept": "application/json"
                }
            }
        );

        const dados = await lerRespostaJson(resposta);

        if (resposta.status === 401) {
            mostrarLogin();
            return;
        }

        if (!resposta.ok || !dados.ok) {
            throw new Error(
                dados.message || "Não foi possível validar a sessão."
            );
        }

        if (dados.nome_fantasia) {
            nomeCliente.textContent = dados.nome_fantasia;
            document.title =
                `${dados.nome_fantasia} - Consulta de Produtos`;
        }

        mostrarConsulta();
        exibirMensagem("Digite um produto para iniciar a consulta.");
    } catch (erro) {
        console.error(erro);

        mostrarLogin(
            "Não foi possível comunicar com o servidor."
        );

        definirSituacao("Erro de conexão", "erro");
    }
}


formLogin.addEventListener("submit", realizarLogin);

botaoPesquisar.addEventListener("click", pesquisar);

if (botaoSair) {
    botaoSair.addEventListener("click", realizarLogout);
}

campoBusca.addEventListener("keydown", (evento) => {
    if (evento.key === "Enter") {
        pesquisar();
    }
});

verificarSessaoExistente();
