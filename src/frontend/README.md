# Univesp Project — Frontend

App Flutter (**Android e Web**, tema **escuro** por padrão e **claro** como opção de cada usuário) para a loja: cadastro de produtos, venda pelo caixa e importação de planilhas de vendas, com os resultados em gráficos. Conversa com o [backend](../backend/README.md) por **HTTPS**.

## Sumário

- [Stack](#stack)
- [Estrutura](#estrutura)
- [Login e sessão](#login-e-sessão)
- [Menu principal](#menu-principal)
- [Produtos](#produtos)
- [Venda de produtos (caixa)](#venda-de-produtos-caixa)
- [Importação de vendas](#importação-de-vendas)
- [Exportação de vendas](#exportação-de-vendas)
- [Comparativo de meses](#comparativo-de-meses)
- [Previsão e grupos de produtos (aprendizado de máquina)](#previsão-e-grupos-de-produtos-aprendizado-de-máquina)
- [Tratamento de erros](#tratamento-de-erros)
- [Configuração](#configuração)
- [Como executar](#como-executar)
- [Testes](#testes)

## Stack

| Pacote | Uso |
|---|---|
| `flutter_riverpod` | Injeção de dependência (providers) e estado (sessão do usuário) |
| `dio` | Cliente HTTP, com interceptor que envia o token JWT |
| `flutter_secure_storage` | Guarda o token criptografado (Android Keystore / WebCrypto no navegador) |
| `file_picker` | Escolher a planilha e salvar o modelo (Android e Web) |
| `intl` | Formatos brasileiros (R$, datas, porcentagem) |
| `flutter_localizations` | Textos do Material em português (calendário, botões) |

## Estrutura

Organização *feature-first*: cada funcionalidade tem suas próprias camadas.

```
lib/
├── main.dart                     # ProviderScope + App
├── app/
│   ├── app.dart                  # MaterialApp (tema do usuário: escuro por padrão, ou claro)
│   ├── auth_gate.dart            # escolhe Login, o menu principal ou (sem loja aprovada) a tela da loja
│   └── theme.dart                # AppTheme.dark (azul-marinho, verde-água) e AppTheme.light (fundo claro, verde-água mais escuro)
├── core/                         # comum a todas as features (não importa features)
│   ├── config/env.dart           # URL da API
│   ├── errors/                   # Failure, ErrorNotifier (SnackBar/Dialog), BaseState
│   ├── files/file_service.dart   # FileService: escolher/salvar arquivos
│   ├── network/                  # dioProvider, AuthInterceptor, guardRequest, certificado de dev (Android debug)
│   ├── session/                  # sinais de sessão expirada (401) e de acesso à loja alterado (403)
│   ├── storage/token_storage.dart
│   └── utils/                    # formatters (R$, datas, %), parsers (números digitados)
├── shared/widgets/               # widgets reutilizáveis (gráficos, SuggestionField, brand.dart: logo, cores da marca, TintedIcon, EmptyState)
└── features/
    ├── analytics/
    │   ├── domain/               # SalesForecast, ProductGroups, AnalyticsRepository (interface)
    │   ├── data/                 # AnalyticsModel, AnalyticsRepositoryImpl (+ provider)
    │   └── presentation/         # analytics_providers, AnalyticsPage, ForecastTab, ProductGroupsTab
    ├── auth/
    │   ├── domain/               # User, AuthRepository (interface)
    │   ├── data/                 # UserModel, AuthRepositoryImpl (+ provider)
    │   └── presentation/         # AuthController, LoginPage, RegisterPage, ForgotPasswordPage, ChangePasswordPage, widgets/auth_form_parts
    ├── home/
    │   └── presentation/         # HomeShell (menu principal), AccountMenuButton
    ├── products/
    │   ├── domain/               # Product, ProductInput, ProductFilter, ProductRepository (interface)
    │   ├── data/                 # ProductModel, ProductRepositoryImpl (+ provider)
    │   └── presentation/         # ProductsController, ProductsPage, ProductFormPage, StockBadge
    ├── store/
    │   ├── domain/               # StoreMembership, StoreMember, StoreArea, StoreRole, StoreRepository (interface)
    │   ├── data/                 # StoreModel, StoreRepositoryImpl (+ provider)
    │   └── presentation/         # storeAreasProvider, storeMembersProvider, StoreAccessPage, StoreUsersPage, StoreMemberPage, StoreNameField
    ├── notifications/
    │   ├── domain/               # AppNotification, NotificationKind, NotificationInbox, NotificationRepository (interface)
    │   ├── data/                 # NotificationModel, NotificationRepositoryImpl (+ provider)
    │   └── presentation/         # NotificationsController (notificationsProvider), NotificationsButton (sino), NotificationsPage
    ├── settings/
    │   ├── domain/               # UserSettings, SettingsRepository (interface)
    │   ├── data/                 # UserSettingsModel, SettingsRepositoryImpl (+ provider)
    │   └── presentation/         # UserSettingsController (userSettingsProvider), UserSettingsPage (Preferências)
    └── sales/
        ├── domain/               # entidades (lotes, vendas, caixa, ProfitSummary, MonthComparison), SalesRepository, services/ (sales_analysis, month_comparison_analysis)
        ├── data/                 # SalesImportModel, MonthComparisonModel, SalesRepositoryImpl (+ provider)
        └── presentation/         # controllers, SalesMetric, CheckoutPage, MonthComparisonPage, páginas e widgets das abas
test/                             # espelha lib/; helpers/fakes.dart tem os fakes das interfaces
```

Regras:

- `presentation` depende de `domain`; `data` implementa os contratos de `domain`.
- `core` não importa nada de `features`. Uma feature só usa outra através de `domain`/providers.
- Dependa de interfaces (`abstract interface class`), registradas em providers do Riverpod; nos testes, troque por fakes com `overrideWithValue`.

## Login e sessão

```
LoginPage ─► AuthController.login ─► AuthRepository ─► POST /api/auth/login
                    │                                    └─ salva o token (TokenStorage)
                    └─ estado = usuário ─► AuthGate mostra o menu principal
```

- **Criar conta**: no login, **Ainda não tem conta? → Criar conta** (`RegisterPage`). Campos nome, e-mail (já vem com o que foi digitado no login), senha (com as regras no texto de ajuda), confirmação e **Nome da loja** (um campo só): se a loja ainda não existe, ela é criada e a pessoa vira admin; se já existe (sem diferenciar acentos e maiúsculas), vira um pedido de acesso e o admin da loja recebe uma notificação. Sem nenhuma confirmação de dados por e-mail: ao criar, a conta já entra (`POST /api/auth/register`); quem criou a loja vê o app, quem pediu acesso vê a tela de espera. Erros do backend aparecem embaixo de cada campo (ex.: e-mail já cadastrado).
- **Esqueci minha senha**: no login, abaixo da senha (`ForgotPasswordPage`). Campos e-mail, nova senha e confirmação; versão simples do protótipo, **sem confirmação por e-mail** (a tela avisa). Ao salvar (`POST /api/auth/reset-password`), volta ao login com o e-mail preenchido e "Senha alterada. Entre com a nova senha.". E-mail sem conta aparece embaixo do campo.
- **Ao abrir o app**: `AuthController` chama `restoreSession()`. Se houver token salvo, valida com `GET /api/auth/me`; token inválido/expirado é apagado e o login aparece.
- **Em toda requisição**: `AuthInterceptor` envia `Authorization: Bearer <token>`.
- **Token expirado no meio do uso** (401 em requisição autenticada): o token é apagado, `SessionExpiredSignal` é disparado e o app volta ao login.
- **Sair**: menu da conta (inicial do nome, no canto da barra superior) → `AuthController.logout()`.
- **Alterar senha**: menu da conta → **Configurações do usuário** (abre as opções logo abaixo, no mesmo menu) → **Alterar senha** (`ChangePasswordPage`, em `features/auth`). Campos senha atual, nova senha (com as regras no texto de ajuda) e confirmação; um botão de olho mostra/oculta as três. Só a confirmação é conferida no app ("As senhas não conferem."); o resto vem do backend, embaixo de cada campo (`currentPassword`, `newPassword`). Ao salvar, volta para a tela anterior com "Senha alterada." e a sessão continua.
- **Preferências**: menu da conta → **Configurações do usuário** → **Preferências** (`UserSettingsPage`, feature `settings`). O **Tema** (Escuro / Claro) muda o app na hora e vem escuro. As chaves **Exigir imagem nos produtos** e **Cadastrar produtos ao importar** começam desligadas; **Avisar sobre reposição de estoque** começa **ligada**: o menu **Produtos** ganha um selo com quantos produtos ativos chegaram ao estoque mínimo, e a mensagem de venda do caixa diz quais produtos vendidos precisam de reposição ("Repor estoque: Mouse sem fio (restam 1)."). Desligada, nada disso aparece (a lista de produtos continua mostrando o estado do estoque). Tudo é salvo na hora (`PUT /api/settings`, só o que mudou) e valem só para o usuário logado. Elas são carregadas de `GET /api/settings` ao entrar e voltam ao padrão ao sair.
- **Backend fora do ar ao abrir**: mostra o login (o token é mantido para a próxima vez).

Tela de login: validação local (campos obrigatórios e formato do e-mail), mostrar/ocultar senha, *autofill*, Enter envia, botão com indicador de carregamento. Erros do backend aparecem via `BaseState`.

## Loja, usuários e permissões

Cada usuário é de **uma loja** e só vê os dados dela (o backend separa tudo).

- **Esperando aprovação / sem loja** (`StoreAccessPage`, mostrada pelo `AuthGate` no lugar do app): quem pediu acesso vê "Aguardando aprovação" com o nome da loja (o admin recebeu uma notificação) e **Verificar agora** (o app também confere sozinho a cada 30 s). Quem foi removido da loja vê o aviso. Nos dois casos dá para informar **outro nome de loja** (nova = vira admin; existente = novo pedido, o anterior é cancelado) e **Sair**.
- **Admin** — menu da conta → **Loja e usuários** (`StoreUsersPage`; o item ganha um selo com o número de pedidos pendentes):
  - nome da loja (lápis para renomear; o nome é único — o de outra loja é recusado). Não há código de convite: quem vai trabalhar na loja cria a conta com o **nome** dela;
  - **Pedidos de acesso** primeiro; tocar abre o pedido com as **partes do sistema** todas marcadas — o admin desmarca o que a pessoa não vai usar e toca **Aprovar acesso**, ou **Recusar pedido**;
  - **Usuários**: papel e partes liberadas; tocar abre `StoreMemberPage`: **Usuário / Admin** (admin usa tudo), as partes (Produtos, Vender, Importar, Exportar, Comparar, Prever) e **Remover da loja**. Só o que mudou é enviado. A loja nunca fica sem admin (o backend recusa e a mensagem aparece).
- **Menu filtrado**: o `HomeShell` mostra só as partes liberadas (`User.can(area)`). Com uma parte só, ela abre sem barra de menu; sem nenhuma, aparece "Nenhuma parte do sistema liberada". O selo de reposição só aparece para quem tem Produtos, e o atalho **Gerar planilha** (venda lançada) só para quem tem Exportar. O caixa não chama a lista de lotes (`salesBatchSaved` só atualiza a lista se ela já foi aberta).
- **Mudanças do admin no meio do uso**: se o backend responde 403 nas chaves `store` ou `area`, o `AuthInterceptor` dispara `AccessChangedSignal` e o `AuthController.refreshProfile()` recarrega `GET /api/auth/me` sem tela de carregamento: o menu se ajusta, ou o app volta para a tela da loja se o acesso foi retirado.
- O menu da conta mostra a loja e o papel ("Marcelo Eletrônicos · Admin").

## Notificações

Pedido do usuário: ao informar o nome de uma loja existente, o admin recebe uma notificação no sistema para aprovar.

- **Sino** na barra do app (`NotificationsButton`, ao lado do avatar): selo com o número de não lidas (tooltip "Notificações (N não lidas)"). Enquanto o sino está na tela, o app consulta `GET /api/notifications` **a cada 30 s**; chegou notificação nova → SnackBar com a mensagem e **Ver** (e a lista de pedidos do admin é recarregada).
- **Notificações** (`NotificationsPage`): as 30 mais recentes, não lidas destacadas (fundo e ponto). Tocar marca como lida; um **pedido de acesso** abre o pedido (`StoreMemberPage`) para **aprovar ou recusar** — se já foi respondido, avisa "Este pedido já foi respondido.". Ícone ✓✓ = **Marcar todas como lidas**. Puxar para baixo atualiza.
- Aprovar ou recusar resolve a notificação no backend (o sino atualiza na hora); quem pediu recebe "Seu acesso à loja X foi aprovado.".

## Menu principal

`HomeShell` (`features/home`) tem até seis telas (cada usuário vê só as que o admin liberou; o admin vê todas):

| Menu | Tela | O que faz |
|---|---|---|
| **Produtos** | Produtos | Cadastro de produtos |
| **Vender** | Venda de produtos | Caixa: vende produtos do cadastro |
| **Importar** | Importações de vendas | Planilhas, lotes de vendas e análises |
| **Exportar** | Exportações de vendas | Planilhas geradas com as vendas de um período |
| **Comparar** | Comparativo de meses | Um mês contra outro, de todos os lotes |
| **Prever** | Previsão e grupos de produtos | Previsão de vendas dos próximos meses e grupos de produtos (aprendizado de máquina) |

- Os nomes do menu são curtos (**Importar**, **Exportar**, **Prever**) para os seis caberem num celular de 360 px; a barra de cima mostra o título completo.
- No celular (menos de 600 px) o menu fica numa barra embaixo; em telas maiores, numa coluna à esquerda (`NavigationRail`).
- Cada tela é criada na primeira vez que é aberta e depois mantida (`IndexedStack`): trocar de tela não perde a busca nem o carrinho.
- A barra superior mostra o título da tela e o **menu da conta**: nome, e-mail, loja e papel, **Loja e usuários** (só admin), **Configurações do usuário** (expande e mostra **Preferências** e **Alterar senha**) e **Sair**.
- Telas de detalhe (produto, lote, lançar venda) abrem por cima do menu, com botão de voltar.

## Produtos

- **Imagem**: no formulário, o campo **Imagem** aceita o link de uma foto (`https://...`) ou o botão **Enviar arquivo** (PNG, JPEG, WebP ou GIF até 5 MB), que manda a foto para a pasta do backend e preenche o campo com o caminho dela (`/uploads/products/...`). Uma prévia aparece ao lado. É opcional, ou obrigatório quando a preferência **Exigir imagem nos produtos** está ligada (o rótulo muda e o backend recusa sem imagem). A foto aparece na lista, na busca do caixa e no carrinho; sem foto, ou se o link não carregar, aparece um ícone conforme o tipo do produto (notebook, celular, fone, mouse...).
- **Lista** em ordem de nome, com busca por nome/SKU, filtro por **categoria** e **Mostrar inativos**. Cada produto mostra SKU, categoria, preço, margem e o **estoque**: normal, *Estoque baixo* (no mínimo ou abaixo) ou *Sem estoque*. O topo resume quantos precisam de reposição.
- **Novo produto** / tocar num produto: formulário com nome, SKU (único), categoria (com sugestões), preço de venda, custo (opcional), estoque e estoque mínimo, e a chave **Ativo**. Enquanto digita, mostra a margem e o lucro por unidade. O custo **não pode ser maior que o preço de venda** (cada venda daria prejuízo): o aviso fica vermelho com o valor do prejuízo e, ao salvar, o erro do backend aparece no campo de custo. Custo igual ao preço é aceito ("Sem lucro").
- **Excluir produto**: só para produtos sem vendas — nem no caixa, nem digitadas ou importadas com o mesmo SKU; para os outros, o backend recusa e a tela mostra a mensagem. Nesse caso, desligue **Ativo**: o produto some do caixa, mas continua no cadastro e nas vendas antigas.
- Erros (SKU repetido, preço negativo...) vêm do backend e aparecem embaixo de cada campo.

## Venda de produtos (caixa)

- **Adicionar produto**: busca entre os produtos ativos pelo nome ou SKU; cada sugestão mostra preço e estoque. Produtos sem estoque aparecem desabilitados.
- **Carrinho**: cada linha tem quantidade com − / + (o + para no estoque disponível) e **preço unitário** já preenchido com o preço do produto, mas editável (desconto). O preço **não pode ficar abaixo do custo** do produto: enquanto você digita, o campo mostra "O preço não pode ser menor que o custo (R$ 40,00): a venda daria prejuízo.", e o backend recusa a venda com o mesmo erro na linha. Igual ao custo é aceito. O **desconto máximo é de 15%** do preço do produto (R$ 100,00 → mínimo R$ 85,00): abaixo disso o campo avisa "O desconto não pode passar de 15% do preço do produto: o mínimo é R$ 85,00." e o backend recusa. Com desconto válido, o campo mostra "Desconto de 10,0% (máximo 15,0%)". Escolher o mesmo produto de novo soma 1.
- **Venda**: data (até hoje), canal **Presencial/Online** e, se online, marketplace (com sugestões; vazio = loja virtual própria). A tela avisa em qual lote a venda vai entrar (`Vendas - outubro/2026`).
- A barra de baixo mostra itens, total e **lucro estimado** (dos produtos com custo) e o botão **Finalizar venda**.
- Ao finalizar, o backend grava tudo ou nada: se faltar estoque, por exemplo, o erro aparece na linha do produto e o carrinho continua. Com sucesso, o carrinho é limpo, a lista de produtos é recarregada (estoque novo) e o lote do mês aparece atualizado em Importações.

## Importação de vendas

Menu **Importar** (tela Importações de vendas):

- **Baixar modelo**: baixa `modelo-vendas.xlsx` do backend e salva (Web: download do navegador; Android: tela "salvar como"). O app informa o sistema operacional e a planilha vem na fonte padrão das planilhas dele (Calibri no Windows, Helvetica Neue no Mac/iPhone, Liberation Sans no Linux, Roboto no Android; na Web, o sistema do navegador). O mesmo vale para as planilhas geradas em Exportações.
- **Selecionar planilha**: escolhe um `.xlsx` e envia (`multipart/form-data`). Se alguma linha for inválida, **nada é salvo** e os erros aparecem num diálogo, um por linha ("Linha 5: ..."). A tela usa `DialogErrorNotifier` em vez do SnackBar.
- **Produtos novos da planilha**: com a preferência **Cadastrar produtos ao importar** ligada (vem desligada), os SKUs da planilha que ainda não estão no catálogo viram produtos, com o nome e o último preço vendido; estoque, categoria, custo e imagem ficam para completar em **Produtos**. O card de importação mostra se ela está ligada ("SKUs novos viram produtos." / "SKUs novos não viram produtos.") e tem um atalho **Preferências**. A mensagem de sucesso diz quantos foram cadastrados ("...; 3 produtos cadastrados."), e a lista de produtos é recarregada. Linhas sem SKU não viram produto.
- **Lista** dos lotes importados (arquivo, vendas, faturamento, período, quem importou). Puxar para baixo atualiza.
- **Lançar venda** (botão flutuante): formulário para digitar uma venda — lote (um existente ou **novo lote manual**, com nome sugerido "Vendas manuais - mês/ano"), data (calendário em português, até hoje), produto, SKU, quantidade, preço (aceita `49,90` e `1.234,56`), canal e, se online, marketplace (com sugestões dos já cadastrados; vazio = loja virtual própria). Mostra o total. **Salvar e lançar outra** mantém lote, data e canal e limpa o produto. Os erros vêm do backend e aparecem embaixo de cada campo. Depois de salvar, o aviso tem o atalho **Gerar planilha** (período em volta da data da venda; veja [Exportação de vendas](#exportação-de-vendas)); o mesmo está no ícone de planilha da barra do formulário.
- **Excluir** um lote inteiro: antes, a confirmação mostra o que vai acontecer — quantas vendas e quanto faturamento saem dos relatórios, a quantos produtos cadastrados elas estão ligadas (os produtos continuam no catálogo, sem essas vendas no histórico) e quantas unidades do caixa voltam ao estoque.
- Lotes manuais e os lotes do caixa (`Vendas - mês/ano`) aparecem na lista com ícones próprios.
- **Detalhe** do lote, em 3 abas. O seletor **Faturamento / Vendas / Itens** vale para todos os gráficos e é mantido ao trocar de aba:
  - **Resumo**: cards (faturamento, vendas, itens, período e, se houver vendas do caixa com custo, **lucro** com a margem); barra de participação **Presencial x Online**; **ranking de plataformas** (loja física, cada marketplace e loja virtual própria) — onde a loja mais fatura.
  - **Evolução**: **gráfico por dia** (barras cinzas = cada dia; linha azul = média móvel de 7 dias, que mostra a tendência sem o sobe-e-desce diário) e o bloco **Aumento ou queda**: média por dia da 1ª x 2ª metade do período (Alta/Queda/Estável, com ±5% de tolerância), melhor e pior dia.
  - **Produtos**: **mais vendidos** e **menos vendidos** (5 de cada; com até 10 produtos, um ranking só), **curva ABC** (quantos produtos e quanto do faturamento em A, B e C) e **sugestão de estoque**: *Avaliar saída* (aberta primeiro), *Priorizar* e *Manter*, com curva, SKU, itens, faturamento e última venda de cada produto.
  - **Vendas**: as vendas do lote (mais recentes primeiro, 50 por vez com "Carregar mais"), busca por produto/SKU, origem de cada uma ("Linha 14 da planilha", "Lançada por ..." ou "Vendida no caixa por ..."), **Lançar venda** neste lote e **excluir uma venda** (com confirmação; os totais e os gráficos do lote são recalculados; venda do caixa devolve o estoque).
  - Passe o mouse / pressione e segure num gráfico para ver todas as métricas (tooltip).

A curva ABC e a sugestão vêm prontas do backend (regras no [README do backend](../backend/README.md#análise-de-produtos-curva-abc-e-sugestão-de-estoque)). Como a planilha não tem custo, a análise de produtos usa **faturamento**; o lucro só aparece para as vendas do caixa.

## Visual

- **Dois temas**, escolhidos por cada usuário em **Preferências** e salvos no backend: **escuro** (padrão), com fundo **azul-marinho** (não preto) e destaque **verde-água**, e **claro**, com fundo cinza-azulado bem claro, cartões brancos e um verde-água mais escuro. A tela de login é sempre escura (ainda não se sabe quem é o usuário); depois do login, o app troca para o tema salvo.
- Os ícones coloridos usam tons mais vivos no escuro e mais fortes no claro (`BrandColors.tintsOf(context)`), sempre com contraste de pelo menos 3:1.
- A marca (logo com chip, gradiente verde-água → índigo) aparece no login, na barra superior (celular) e no topo do menu lateral.
- Ícones coloridos em quadrados suaves (`TintedIcon`): produtos ganham um ícone pelo tipo (notebook, celular, fone, mouse, SSD...) com a cor da categoria, ou a foto do produto; lotes têm cor por origem (planilha, caixa, manual).
- Produtos tem um resumo no topo (ativos, para repor, valor em estoque); os cartões de números das análises e do comparativo têm ícones, e o principal tem o gradiente da marca.
- Listas vazias mostram ícone, título e explicação (`EmptyState`).
- As cores da marca são só de interface: **os gráficos continuam com a `ChartPalette`** (cor de série nunca vem da marca).

Os gráficos são widgets próprios em `lib/shared/widgets/charts/` (`ShareBarChart`, `HorizontalBarChart`, `TimeSeriesChart`, `ComparisonLineChart`, `ScatterChart`, `ChartPalette` com cores validadas para daltonismo, as mesmas nos dois temas).

Regras da planilha: veja o [README do backend](../backend/README.md#importação-de-vendas-planilha-excel). Planilhas de exemplo em `backend/samples/`.

## Exportação de vendas

Menu **Exportar** (tela Exportações de vendas, `SalesExportsPage`), separado das importações:

- **Gerar planilha** (botão flutuante): o diálogo escolhe **Dia**, **Semana** (segunda a domingo), **Mês** (o padrão) ou **Período** (calendário de intervalo) e mostra o período antes de baixar. A planilha traz **todas as vendas** do período — planilhas importadas, lançamentos manuais e caixa — com as colunas do modelo mais Total, Origem e Lote, e uma aba Resumo.
- Cada planilha gerada entra na lista (período, faturamento, vendas, quando e por quem foi gerada) e pode ser **baixada de novo** (o arquivo como foi gerado) ou **excluída** (com confirmação; as vendas continuam no sistema).
- Também dá para gerar logo depois de **lançar uma venda** (atalho **Gerar planilha** no aviso, ou o ícone na barra do formulário): o período começa na data da venda.
- Período sem vendas: o aviso do backend aparece ("Não há vendas em …") e nada é guardado.
- A planilha gerada não vira lote: importá-la duplicaria as vendas.

## Comparativo de meses

Menu **Comparar** (`MonthComparisonPage`). Compara dois meses com vendas, somando todos os lotes (planilhas, lançamentos e caixa):

- **Mês base** e **Comparar com**: listas só com os meses que têm vendas (com o faturamento de cada um); o mês escolhido de um lado fica desabilitado do outro. O botão **Inverter meses** troca os lados.
- Atalhos para o mês de **Comparar com**: **Mês anterior** e **Mesmo mês do ano anterior** (ex.: janeiro/2026 x janeiro/2025). Ficam desabilitados quando aquele mês não tem vendas.
- Ao abrir: o mês mais recente contra o mesmo mês do ano anterior; se esse não tiver vendas, contra o mês anterior com vendas. Com menos de dois meses, a tela explica que é preciso ter vendas em pelo menos dois meses.
- Cartões: faturamento, vendas, itens, ticket médio e lucro (se houver vendas com custo), cada um com a variação e o valor do mês base ("+25,1% sobre setembro/2026 (239)"). Mês em andamento ganha um aviso com os dias já passados.
- Seletor Faturamento / Vendas / Itens para as seções abaixo:
  - **Acumulado no mês**: duas linhas (mês base laranja, mês comparado azul), somando dia a dia desde o dia 1; dica com o valor do dia e o acumulado de cada mês. O mês em andamento para no dia de hoje.
  - **Por canal** e **por plataforma** (loja física, cada marketplace, loja virtual própria): tabela com os dois meses e a variação (seta + porcentagem; "novo" quando não vendeu no mês base). No celular, cada linha mostra "de R$ X para R$ Y".
  - **Produtos que mais cresceram / caíram** (5 de cada, pela diferença absoluta) e **Todos os produtos** (expansível, com quantos foram vendidos só no mês comparado e quantos ficaram sem vendas).
- Puxar a tela para baixo recarrega. Os meses e a comparação também são recarregados sozinhos quando vendas mudam no app (importar, lançar, vender no caixa, excluir).
- Código: `salesMonthsProvider` e `monthComparisonProvider` (`presentation/controllers/month_comparison_providers.dart`), `MonthComparisonAnalysis` (puro e testado: crescimento, mês anterior/ano anterior, par inicial, acumulado, maiores altas/quedas), `ComparisonTable` e o gráfico `ComparisonLineChart` (`shared/widgets/charts`).

## Previsão e grupos de produtos (aprendizado de máquina)

Menu **Prever** (tela "Previsão e grupos de produtos", `AnalyticsPage`), com duas abas. Os modelos rodam no backend com ML.NET ([detalhes](../backend/README.md#análises-com-aprendizado-de-máquina-mlnet)); o app só mostra.

**Aba Próximos meses** (`ForecastTab`):

- Horizonte: **Próximo mês**, **Próximos 3 meses** (padrão) ou **Próximos 6 meses**, sempre a partir do mês seguinte ao atual.
- Cartões: faturamento previsto, itens previstos, produtos para comprar (e quantas unidades) e o **erro no teste** do modelo, ao lado do erro da média simples.
- Gráfico **Vendido x previsto** (faturamento ou itens): os meses usados pelo modelo em cinza e os previstos em azul (`TimeSeriesChart` com `highlightFrom`).
- Cartão com os meses usados e os deixados de fora, com o motivo (mês em andamento, mês com vendas em menos da metade dos dias).
- **Previsão por produto**: unidades por mês, total e faturamento previsto; para produtos do cadastro, estoque, mínimo e **Comprar N** (previsto + mínimo − estoque) ou **Estoque cobre**. Filtro **Só os que precisam de compra**.
- **Como a previsão é feita** (expansível): o método em palavras simples e o resultado do teste.

**Aba Grupos de produtos** (`ProductGroupsTab`):

- **Automático** (o backend escolhe o número de grupos pela silhueta) ou 2 a 6 grupos.
- Cartões: número de grupos e a silhueta (o quanto os grupos ficaram separados).
- Gráfico **Preço x vendas por mês** (`ScatterChart`, escalas logarítmicas): cada ponto é um produto; o grupo escolhido nos chips fica em azul e os outros em cinza — com até 6 grupos, cores diferentes para cada um não seriam distinguíveis num gráfico de dispersão. Tocar num ponto mostra o produto.
- Um cartão por grupo (nome, descrição, participação no faturamento, itens por mês, preço médio), que abre a lista de produtos.
- **Como os grupos são formados** (expansível): o método e a silhueta de cada tentativa.

Sem histórico suficiente (404), cada aba mostra a explicação do backend como estado vazio, não como erro. Puxar para baixo recarrega; previsão e grupos também recarregam sozinhos quando as vendas mudam no app.

Código: feature `analytics` — `SalesForecast`/`ProductGroups` (entidades), `AnalyticsRepository` (interface) → `AnalyticsRepositoryImpl` + `analyticsRepositoryProvider`, `AnalyticsModel` (JSON), `salesForecastProvider(meses)` e `productGroupsProvider(grupos)` (`presentation/controllers/analytics_providers.dart`).

## Tratamento de erros

As telas **não criam mensagens de erro**. O fluxo é sempre:

```
backend (JSON de erro) ─► guardRequest converte em Failure ─► BaseState captura ─► ErrorNotifier mostra
```

| Arquivo | Papel |
|---|---|
| `core/errors/failure.dart` | `Failure`: o único tipo de erro do app. `Failure.fromResponse` lê o JSON de erro do backend |
| `core/errors/error_notifier.dart` | `ErrorNotifier`: interface de "como mostrar um erro" |
| `core/errors/snackbar_error_notifier.dart` | Implementação padrão: SnackBar com os erros gerais |
| `core/errors/dialog_error_notifier.dart` | Alternativa: diálogo com a lista de todos os erros (usado na importação) |
| `core/errors/base_state.dart` | `BaseState`: classe base que **toda tela com estado herda** (estende `ConsumerState`) |
| `core/network/request_guard.dart` | `guardRequest`: envolve as chamadas HTTP e converte `DioException` em `Failure` |

### Usando em uma tela

```dart
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends BaseState<LoginPage> {
  Future<void> _submit() async {
    // Erros já são exibidos automaticamente; null = falhou.
    final user = await runSafely(
      () => ref.read(authControllerProvider.notifier).login(email, password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: 'E-mail',
        errorText: fieldError('email'), // mensagem do backend para este campo
      ),
    );
  }
}
```

`BaseState` oferece:

- `runSafely(acao)` — executa, controla `isLoading`, captura `Failure` (ou qualquer exceção, que vira erro genérico) e mostra o erro;
- `fieldError('campo')` — mensagem para `errorText` do campo;
- `showFailure(failure)` / `clearFailure()`;
- `errorNotifier` — sobrescreva para mudar a forma de exibição em uma tela específica.

### Nos repositórios

Todo método que chama o backend fica dentro de `guardRequest(() async { ... })`, que gera:

- resposta de erro do backend → `Failure.fromResponse(statusCode, json)`;
- sem conexão / *timeout* → `Failure.connection()`;
- qualquer outro problema → `Failure.unexpected()`.

As chaves dos erros (`"email"`, `"password"`, ...) são as mesmas do JSON enviado ao backend; chave vazia é erro geral (vai para o SnackBar).

## Configuração

| Variável | Padrão | Descrição |
|---|---|---|
| `API_BASE_URL` | Web: `https://localhost:7077`<br>Android: `https://10.0.2.2:7077` | URL do backend. `10.0.2.2` é o computador visto pelo emulador Android |

Plataformas:

- **HTTPS em todas as plataformas**; HTTP sem TLS não é mais liberado (nem no debug).
- **Web**: o navegador valida o certificado. Rode uma vez `dotnet dev-certs https --trust` na máquina (veja o README do backend). Se o navegador ainda recusar, abra `https://localhost:7077/api/auth/me` uma vez e aceite o certificado. O backend precisa permitir CORS (hoje liberado para qualquer origem em desenvolvimento).
- **Android**: o emulador acessa o computador por `10.0.2.2`, e o certificado de desenvolvimento é emitido para `localhost`, então a validação normal falharia. Em **builds debug**, e só para `localhost`/`127.0.0.1`/`10.0.2.2`, o Dio aceita esse certificado (`core/network/dev_certificate_io.dart`, carregado por *conditional import*; na web é um *stub* vazio). Builds release validam o certificado normalmente.

## Como executar

Com o backend rodando (veja o [README do backend](../backend/README.md)):

```bash
cd frontend
flutter pub get

flutter run -d chrome            # Web
flutter run -d <emulador>        # Android (flutter devices lista os disponíveis)

# Outra URL de API:
flutter run --dart-define=API_BASE_URL=https://192.168.0.10:7077
```

Builds:

```bash
flutter build web                # saída em build/web
flutter build apk                # requer um JDK completo (com javac), ex.: java-25-openjdk-devel
```

## Testes

```bash
flutter analyze
flutter test
```

Os testes não acessam a rede: os repositórios são testados com `FakeHttpAdapter` (respostas falsas do Dio) e as telas com fakes das interfaces (`FakeAuthRepository`, `FakeSalesRepository`, `FakeSalesExportRepository`, `FakeAnalyticsRepository`, `FakeProductRepository`, `FakeFileService`) via `ProviderScope(overrides: ...)`. Os fakes ficam em `test/helpers/fakes.dart`.

Os testes de tela usam largura de celular (400–500 px lógicos) — eles já pegaram um texto estourando a tela. O menu principal é testado nas duas larguras (barra embaixo e coluna lateral). Valores em reais nos testes usam `brl('80,00')`, porque o `intl` põe um espaço não separável depois de `R$`.
