# Univesp Project — Backend

API em ASP.NET Core (.NET 10), servida em **HTTPS**, que recebe planilhas Excel de vendas enviadas pelo app Flutter, salva os dados no PostgreSQL e expõe os resumos para análise e comparação. Também mantém o cadastro de produtos (com estoque e custo), registra as vendas feitas pelo caixa do app e cuida do cadastro e login de usuários (JWT).

## Sumário

- [Arquitetura](#arquitetura)
- [Padrões do projeto](#padrões-do-projeto)
- [Autenticação](#autenticação)
- [Lojas, usuários e permissões](#lojas-usuários-e-permissões)
- [Importação de vendas (planilha Excel)](#importação-de-vendas-planilha-excel)
- [Vendas manuais e remoção de vendas](#vendas-manuais-e-remoção-de-vendas)
- [Produtos e caixa](#produtos-e-caixa)
- [Comparativo de meses](#comparativo-de-meses)
- [Exportação de vendas (planilha por período)](#exportação-de-vendas-planilha-por-período)
  - [Fonte das planilhas geradas](#fonte-das-planilhas-geradas)
- [Análises com aprendizado de máquina (ML.NET)](#análises-com-aprendizado-de-máquina-mlnet)
- [Formato de erro da API](#formato-de-erro-da-api)
- [Banco de dados](#banco-de-dados)
- [Configuração](#configuração)
- [Como executar](#como-executar)
- [Testes](#testes)
- [Testando no Postman](#testando-no-postman)

## Arquitetura

Clean Architecture, com as dependências sempre apontando para dentro:

```
Api ──► Application ──► Domain
 │           ▲
 └──► Infrastructure
```

```
backend/
├── UnivespProject.slnx
├── compose.yaml                     # PostgreSQL local
├── dotnet-tools.json                # dotnet-ef (dotnet tool restore)
├── samples/                         # planilhas de exemplo (válidas e com erros)
├── postman/                         # coleção e ambiente do Postman
├── src/
│   ├── UnivespProject.Domain/
│   │   ├── Common/BaseEntity.cs           # Id, auditoria, notificações
│   │   ├── Common/TextNormalizer.cs       # normalização de nomes (acentos, espaços)
│   │   ├── Notifications/                 # Notification, INotifiable, Notifiable
│   │   ├── Enums/                         # SalesChannel (Presencial/Online), ImportSource
│   │   └── Entities/                      # User, UserSettings, Product, Marketplace, SalesImport, Sale
│   ├── UnivespProject.Application/
│   │   ├── Abstractions/                  # interfaces implementadas na Infrastructure/Api
│   │   ├── Notifications/                 # INotifier (erros da requisição)
│   │   ├── Common/BaseService.cs          # base de todos os serviços
│   │   ├── Auth/                          # AuthService, PasswordPolicy
│   │   ├── Products/                      # ProductService (cadastro de produtos)
│   │   ├── Sales/                         # importação, venda manual, caixa (CheckoutService), análises
│   │   ├── Settings/                      # SettingsService, ICurrentUserSettings (configurações do usuário logado)
│   │   ├── Analytics/                     # previsão de vendas e grupos de produtos (aprendizado de máquina)
│   │   └── DTOs/
│   ├── UnivespProject.Infrastructure/
│   │   ├── Persistence/                   # AppDbContext, mapeamentos, repositórios, migrations
│   │   ├── Security/                      # hash de senha, geração de JWT
│   │   ├── Spreadsheets/                  # leitura/geração de .xlsx (ClosedXML)
│   │   ├── MachineLearning/               # modelos do ML.NET (regressão de Poisson, k-means)
│   │   └── ExternalApi/                   # cliente de API externa (reservado, ainda vazio)
│   └── UnivespProject.Api/
│       ├── Endpoints/                     # Minimal APIs
│       ├── Errors/                        # formato de erro e tratamento global de exceções
│       ├── Extensions/                    # configuração do JWT
│       └── Services/CurrentUser.cs        # usuário logado (a partir do token)
└── tests/UnivespProject.Tests/            # xUnit, espelha as pastas de src
```

| Camada | Responsabilidade | Não pode |
|---|---|---|
| **Domain** | Entidades e regras de negócio | Depender de qualquer outra camada ou pacote |
| **Application** | Casos de uso (serviços), DTOs, interfaces | Conhecer EF, HTTP ou PostgreSQL |
| **Infrastructure** | Banco, segurança, planilhas (ClosedXML), modelos de aprendizado de máquina (ML.NET), APIs externas | Conter regra de negócio |
| **Api** | Endpoints, autenticação, formato das respostas | Conter regra de negócio |

## Padrões do projeto

### Entidades herdam `BaseEntity`

Toda entidade herda `BaseEntity` (classe abstrata), que fornece:

| Campo | Tipo | Preenchimento |
|---|---|---|
| `Id` | `Guid` | Gerado na criação do objeto |
| `CreatedAt` / `CreatedBy` | `DateTime` (UTC) / `string` | Automático ao inserir (`AuditInterceptor`) |
| `UpdatedAt` / `UpdatedBy` | `DateTime?` / `string?` | Automático ao alterar (`AuditInterceptor`) |

O autor é o e-mail do usuário logado ou `system` quando não há usuário autenticado.

Para mapear uma nova entidade no EF, crie uma configuração herdando `BaseEntityConfiguration<T>` e chame `base.Configure(builder)`.

### Notificações em vez de exceções

Erros de validação e de regra de negócio **não** lançam exceção: eles são registrados como notificações.

- **Entidades** (via `BaseEntity : Notifiable`) chamam `AddNotification(chave, mensagem)` e expõem `IsValid`/`Notifications`.
- **Serviços** herdam `BaseService` e usam:
  - `Validate(entidade)` — copia as notificações da entidade para a requisição;
  - `Notify(chave, mensagem, tipo)` — registra um erro;
  - `HasNotifications` — indica se algo falhou.
- **`INotifier`** (scoped, um por requisição) junta todos os erros.
- **Endpoints** terminam sempre com `notifier.ToResult(resposta, sucesso)`, que devolve o erro no [formato padrão](#formato-de-erro-da-api) quando há notificações.

A chave da notificação é o nome do campo no JSON (`"email"`, `"password"`), para o app mostrar a mensagem embaixo do campo certo. Chave vazia = erro geral.

O tipo da notificação define o status HTTP; com tipos misturados, vale o mais restritivo:

| `NotificationType` | Status |
|---|---|
| `Unauthorized` | 401 |
| `NotFound` | 404 |
| `Conflict` | 409 |
| `Validation` | 400 |

Exemplo de serviço novo:

```csharp
internal sealed class ExemploService(INotifier notifier, IExemploRepository repo)
    : BaseService(notifier), IExemploService
{
    public async Task<ExemploResponse?> CriarAsync(CriarExemploRequest request, CancellationToken ct)
    {
        var entidade = new Exemplo(request.Nome);
        if (!Validate(entidade))
            return null;

        if (await repo.ExisteAsync(entidade.Nome, ct))
        {
            Notify("nome", "Já existe um registro com este nome.", NotificationType.Conflict);
            return null;
        }

        // ... salvar e retornar
    }
}
```

## Autenticação

| Método | Rota | Autenticação | Resposta |
|---|---|---|---|
| POST | `/api/auth/register` | — | 201 + token (com `storeName`) |
| POST | `/api/auth/login` | — | 200 + token |
| GET | `/api/auth/me` | `Authorization: Bearer <token>` | 200 + dados do usuário |
| POST | `/api/auth/change-password` | `Authorization: Bearer <token>` | 204 (senha alterada) |
| POST | `/api/auth/reset-password` | — | 204 (senha recuperada) |

Resposta de cadastro/login:

```json
{
  "accessToken": "eyJhbGciOi...",
  "expiresAt": "2026-10-30T00:20:14Z",
  "user": {
    "id": "a5b6...", "name": "Maria Silva", "email": "maria@exemplo.com", "createdAt": "...",
    "store": {
      "id": "c1d2...", "name": "Loja da Maria", "role": "Admin",
      "areas": ["Products", "Checkout", "Imports", "Exports", "Comparison", "Analytics"]
    }
  }
}
```

O cadastro pede **o nome da loja** (`storeName`): um nome novo abre a loja (o usuário vira admin); o nome de uma loja que já existe faz um pedido de acesso (fica `Pending` até o admin aprovar, e os admins recebem uma notificação). Veja [Lojas, usuários e permissões](#lojas-usuários-e-permissões).

Regras:

- **E-mail**: obrigatório, válido, único; salvo em minúsculas.
- **Nome**: obrigatório, até 150 caracteres.
- **Senha**: 8 a 128 caracteres, com maiúscula, minúscula e número. Todas as regras quebradas são retornadas de uma vez.
- **Senha no banco**: apenas o *hash* (PBKDF2-HMAC-SHA512, salt aleatório, via `PasswordHasher` do ASP.NET Identity). A senha original não pode ser recuperada.
- **Login inválido**: a mesma mensagem para e-mail inexistente e senha errada, para não revelar quais e-mails existem.
- **Loja**: `storeName` obrigatório, até 100 caracteres; comparado com as lojas existentes sem diferenciar acentos, maiúsculas e espaços sobrando.
- **Token**: JWT HMAC-SHA256, validade de 60 minutos (`Jwt:ExpirationMinutes`), claims `sub` (id), `email`, `name`.

### Alterar senha

`POST /api/auth/change-password` com `{ "currentPassword": "Senha123", "newPassword": "NovaSenha456" }` troca a senha do usuário logado.

- Erros (400), cada um na chave do seu campo e todos de uma vez: `currentPassword` vazia ("Informe a senha atual."), `newPassword` fora das regras de senha, senha atual errada ("A senha atual está incorreta.") e nova igual à atual ("A nova senha deve ser diferente da atual.").
- Senha atual errada é **400, não 401**: o usuário está logado, só o campo está errado (o app encerra a sessão em qualquer 401 de requisição autenticada).
- O token em uso continua valendo até expirar (JWT sem estado; não há lista de tokens revogados).

### Recuperar senha (versão simples)

`POST /api/auth/reset-password` com `{ "email": "maria@exemplo.com", "newPassword": "NovaSenha456" }` troca a senha da conta desse e-mail. **Não pede token nem confirmação** (sem código por e-mail): é a versão simples escolhida para o protótipo.

- Erros: `email` vazio (400, "Informe o e-mail."), `newPassword` fora das regras de senha (400, todas de uma vez) e e-mail sem conta (**404** na chave `email`, "Nenhum usuário cadastrado com este e-mail.").
- O e-mail é comparado sem diferenciar maiúsculas e sem espaços nas pontas, como no login.
- ⚠️ **Só para demonstração**: quem souber o e-mail de alguém consegue trocar a senha dessa pessoa, e o 404 revela quais e-mails têm conta. Antes de usar com dados reais, troque por um fluxo com código enviado por e-mail (o serviço fica atrás de `IAuthService.ResetPasswordAsync`).

### Configurações do usuário

As configurações ficam na tabela **`user_settings`**, uma linha por usuário, e valem só para o usuário do token:

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/settings` | 200 + `{ "requireProductImage": false, "createProductsOnImport": false, "theme": "Dark", "notifyRestock": true }` |
| PUT | `/api/settings` | 200 + todas as configurações já salvas |

| Configuração | Padrão | O que faz |
|---|---|---|
| `requireProductImage` | desligada | Os produtos que **este usuário** cadastra ou edita precisam ter `imageUrl`. É conferido ao salvar; produtos que já existem sem imagem só são cobrados quando forem editados |
| `theme` | `Dark` | Tema do app: `Dark` (escuro) ou `Light` (claro), sem diferenciar maiúsculas. Outro valor → 400 na chave `theme` |
| `createProductsOnImport` | desligada | Ao importar uma planilha, os SKUs que ainda não estão no catálogo viram produtos (veja [Produtos cadastrados pela importação](#produtos-cadastrados-pela-importação)) |
| `notifyRestock` | **ligada** | O app avisa quando produtos ativos chegam ao estoque mínimo e precisam ser repostos: um selo com a quantidade no menu **Produtos** e, depois de uma venda no caixa, a lista dos produtos vendidos que ficaram no mínimo ou abaixo. O backend só guarda a escolha; o estado do estoque vem de `isLowStock` em cada produto |

- Usuário que nunca mudou nada não tem linha: `GET` devolve os padrões (tudo desligado, menos `notifyRestock`). A linha é criada na primeira alteração.
- O `PUT` muda **só os campos enviados**. Por exemplo, `{ "createProductsOnImport": true }` não mexe em `requireProductImage`. Sem nenhum campo → 400 ("Informe ao menos uma configuração para alterar.").
- Os serviços leem as configurações de quem está logado por `ICurrentUserSettings` (Application/Settings).

Para proteger um endpoint: `.RequireAuthorization()`. O usuário logado vem de `ICurrentUser`.

## Lojas, usuários e permissões

Pedido do usuário: "cada usuário deve ter sua própria loja ou pertencer a uma loja já criada", com uma tabela de lojas e um **admin** que dá acesso aos outros usuários — e escolhe **quais partes do sistema** cada um usa.

- **Tabela `stores`** (nome **único**, comparado sem acentos/maiúsculas/espaços extras pela coluna `NormalizedName`). Produtos, marketplaces, lotes, vendas e exportações têm `StoreId`: **cada loja só vê os próprios dados**. O SKU e o nome do marketplace são únicos **por loja**.
- **Entrar em uma loja** (escolha do usuário: "um campo só: nome da loja"): no cadastro (ou depois, sem loja), o usuário informa o nome. **Nome novo** → a loja é aberta e o usuário vira **Admin**. **Nome de uma loja existente** (ex.: "loja da maria" = "Loja da Maria") → **pedido de acesso**: o usuário fica `Pending`, sem ver nada, e **cada admin da loja recebe uma notificação** ("João (joao@…) pediu acesso à loja X."). Não existe mais código de convite.
- **Central de notificações** (escolha do usuário): tabela `notifications`, rotas `/api/notifications` (abaixo). Aprovar ou recusar o pedido marca como lidas as notificações dos admins sobre ele; aprovar avisa quem pediu ("Seu acesso à loja X foi aprovado."). Um pedido trocado por outro (o pendente informou outra loja) também resolve as notificações antigas. O app consulta a cada 30 s.
- **Admin** (escolha do usuário: "aprovar, remover e promover"): aprova ou recusa pedidos, remove usuários, torna outro usuário admin (ou volta a usuário comum) e renomeia a loja. **A loja nunca fica sem admin** (rebaixar ou remover o último = 409).
- **Partes do sistema** (pedido do usuário): o admin escolhe o que cada usuário comum usa. Admin usa tudo.

| Parte (`areas`) | No app | Rotas |
|---|---|---|
| `Products` | Produtos | `/api/products/*` (listar e ver um produto também com `Checkout`) |
| `Checkout` | Vender | `POST /api/sales/checkout`; lê produtos e marketplaces |
| `Imports` | Importar | lotes, planilhas, vendas digitadas, modelo, `/api/sales/marketplaces` |
| `Exports` | Exportar | `/api/sales/exports/*` |
| `Comparison` | Comparar | `/api/sales/months`, `/api/sales/comparison` |
| `Analytics` | Prever | `/api/analytics/*` |

Cada rota de dados tem `.RequireStoreAccess(StoreArea...)` (filtro de endpoint em `Api/Extensions/StoreAccessExtensions.cs`), que chama `IStoreAccessService.EnterAsync`:

- sem loja, ou pedido pendente → **403** na chave `store` ("Seu pedido de acesso à loja X ainda não foi aprovado pelo admin." / "Você não faz parte de nenhuma loja...");
- parte não liberada → **403** na chave `area`;
- liberado → `ICurrentStore.Enter(lojaId)`: a partir daí o **filtro global do EF** (`HasQueryFilter(e => e.StoreId == loja atual)`, também em `ExecuteUpdate`/`ExecuteDelete`) mostra só a loja, e o `StoreOwnershipInterceptor` grava `StoreId` nos registros novos. Sem passar pelo filtro, nenhum dado de loja aparece.

A checagem lê o usuário do banco a cada requisição (não do token): aprovar, remover ou mudar as partes vale na hora, sem novo login.

| Método | Rota | Quem | Resposta |
|---|---|---|---|
| POST | `/api/store` | sem loja ou pendente | `{ "name": "..." }`: nome novo → 201 + usuário admin; nome existente → 200 + usuário pendente (admins notificados) |
| PUT | `/api/store` | admin | 200 + usuário (renomeia; `{ "name": "..." }`; nome de outra loja → 409 em `name`) |
| GET | `/api/store/members` | admin | 200 + usuários da loja (pendentes primeiro) |
| POST | `/api/store/members/{id}/approve` | admin | 200 (`{ "areas": [...] }`; sem `areas` = todas) |
| PUT | `/api/store/members/{id}/role` | admin | 200 (`{ "role": "Admin" \| "Member" }`; admin novo ganha todas as partes) |
| PUT | `/api/store/members/{id}/areas` | admin | 200 (`{ "areas": [...] }`; só para usuário comum; lista vazia vale) |
| DELETE | `/api/store/members/{id}` | admin | 204 (remove ou recusa o pedido) |

Notificações (qualquer usuário logado, mesmo sem acesso à loja):

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/notifications` | 200 + `{ "unread": 1, "items": [{ "id", "kind", "message", "relatedUserId", "read", "createdAt" }] }` (as 30 mais recentes; `kind` = `AccessRequested` ou `AccessApproved`; `relatedUserId` = quem pediu) |
| POST | `/api/notifications/{id}/read` | 200 + notificação lida (404 se for de outra pessoa) |
| POST | `/api/notifications/read-all` | 200 + `{ "marked": N }` |

Ações de admin feitas por outro usuário → 403 na chave `admin`. Usuário de outra loja → 404. Quem já tem acesso não abre nem pede outra loja (409). Usuário removido fica com `store: null` e pode abrir a própria loja ou pedir acesso a outra.

**Dados que já existiam** (migration `AddStores`): tudo foi para uma loja "Minha loja" (o admin pode renomear) e **todos os usuários que já existiam viraram admins dela**. A migration `StoreNamesAndNotifications` trocou o código de convite pelo nome único (`NormalizedName`; nomes repetidos ganhariam " (2)") e criou a tabela `notifications`.

Código: `Domain/Entities/Store.cs`, `Domain/Common/StoreOwnedEntity.cs` (+ `IStoreOwned`), `Domain/Enums/StoreRole.cs` e `StoreArea.cs` (flags), `User` (`StoreId`, `Role`, `Areas`, `OpenStore`, `RequestAccess`, `Approve`, `ChangeRole`, `SetAreas`, `LeaveStore`, `EffectiveAreas`); `Application/Stores` (`IStoreEnrollment` — compartilhado pelo cadastro e pela tela de loja —, `IStoreService`, `IStoreAccessService`, `StoreAreas`, `UserMapper`); `Domain/Entities/UserNotification.cs` + `Domain/Enums/NotificationKind.cs`; `Application/Notifications/Center` (`IAccessRequestNotices`, `IUserNotificationService`) e `IUserNotificationRepository`; `Api/Endpoints/NotificationEndpoints.cs`; `Infrastructure/Persistence` (`CurrentStore`, `StoreOwnershipInterceptor`, `StoreOwnedEntityConfiguration`, filtros no `AppDbContext`).

## Importação de vendas (planilha Excel)

O usuário envia uma planilha `.xlsx` pelo app; o backend lê, valida e salva as vendas para análise e comparação.

### Modelo da planilha

`GET /api/sales/template` devolve `modelo-vendas.xlsx` com a aba **Vendas** (cabeçalho pronto, lista Presencial/Online na coluna Canal) e a aba **Instruções** (regras e exemplos, que não são importados).

| Coluna | Obrigatória | Regra |
|---|---|---|
| Data | sim | Data da venda (`dd/mm/aaaa` ou célula de data). Não pode estar no futuro |
| Produto | sim | Até 200 caracteres |
| SKU | não | Até 60 caracteres. Liga a venda ao produto de mesmo SKU; se o produto não existe, ele é cadastrado (veja abaixo) |
| Quantidade | sim | Inteiro maior que zero |
| Preço Unitário | sim | Número ≥ 0 (aceita `49,90`, `R$ 1.234,56` ou célula numérica) |
| Canal | sim | `Presencial` (loja física) ou `Online` (loja virtual). Aceita também "Loja física"/"Loja virtual" |
| Marketplace | não | Onde a venda online foi feita. Vazio = fora de marketplace. **Venda presencial não pode ter marketplace** |

- Os cabeçalhos são comparados sem acento/maiúsculas e aceitam variações (`Qtd`, `Preco`, `Valor unitário`...). SKU e Marketplace podem não existir na planilha.
- A aba lida é a **Vendas** (ou a primeira, se não houver). Linhas totalmente vazias são ignoradas.
- Limites: 10 MB por arquivo, 50.000 linhas.

### Regras da importação

- **Tudo ou nada**: se qualquer linha for inválida, nada é salvo e a resposta lista os erros com o número da linha (`"Linha 5: A quantidade deve ser maior que zero."`). No máximo 100 mensagens; acima disso vem "... e mais N erro(s)".
- **Cada envio é uma importação (lote)** separada, com nome do arquivo, data e usuário — os lotes ficam lado a lado para comparação. Totais (vendas, itens, faturamento, período) ficam gravados no lote.
- **Marketplaces** são cadastrados automaticamente na primeira vez que aparecem. Nomes iguais sem considerar acento/maiúsculas/espaços são o mesmo marketplace (`mercado  livre` = `Mercado Livre`).
- `Total` de cada venda = `Quantidade × Preço Unitário` (arredondado em 2 casas).

### Produtos cadastrados pela importação

Com a configuração **`createProductsOnImport`** do usuário ligada ([Configurações do usuário](#configurações-do-usuário); vem **desligada**), cada **SKU da planilha que ainda não está no catálogo vira um produto**, e as vendas dele já ficam ligadas a esse produto. Desligada, as vendas só se ligam aos produtos que já existem.

| Campo do produto | Valor |
|---|---|
| Nome | O nome mais usado nas vendas daquele SKU (empate: o da venda mais recente) |
| SKU | O da planilha (salvo em maiúsculas, como no cadastro) |
| Preço de venda | O preço unitário da venda mais recente |
| Categoria, custo, imagem | Vazios, para completar depois |
| Estoque e estoque mínimo | 0 (vendas passadas não dizem quantas unidades restam) |

- **Produto já cadastrado não é cadastrado de novo.** Antes de criar, a importação procura o SKU entre **todos** os produtos, inclusive os inativos, sem diferenciar maiúsculas (`mou-280` = `MOU-280`). Se o produto existe, as vendas só se ligam a ele, e nada nele muda (nome, preço, estoque e situação continuam como estão). O mesmo SKU repetido em várias linhas vira um produto só, e uma segunda importação com o mesmo SKU não cria outro. O índice único de `products.Sku` garante isso também no banco.
- A comparação é **só pelo SKU**: um produto cadastrado com o mesmo nome e outro SKU não é reconhecido. Nomes variam muito entre planilhas, e juntar por nome poderia ligar vendas ao produto errado.
- **Linhas sem SKU não viram produto**: o SKU é obrigatório no cadastro e nunca é inventado. Essas vendas continuam nas análises pelo nome.
- Um SKU com acento ou espaços (ex.: `CÂM-01`) não é cadastrado, porque seria salvo de outro jeito (`CAM-01`) e não ficaria ligado às vendas.
- A preferência "exigir imagem" não bloqueia a importação: o produto só precisa de imagem quando for editado.
- Tudo ou nada também vale aqui: com qualquer erro na planilha, nenhum produto é cadastrado.
- Vendas de lotes anteriores com o mesmo SKU também passam a apontar para o produto novo.
- Excluir o lote **não** apaga os produtos que ele cadastrou (enquanto tiverem vendas, só podem ser desativados).
- A resposta da importação traz `createdProducts` (quantos foram cadastrados). Na lista de lotes, esse campo vem `null`.

### Endpoints (todos exigem token)

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/sales/template?platform=windows` | Arquivo `modelo-vendas.xlsx`, na fonte padrão das planilhas do sistema ([veja](#fonte-das-planilhas-geradas)) |
| POST | `/api/sales/imports` | `multipart/form-data`, campo `file` → 201 + resumo do lote com `createdProducts` |
| GET | `/api/sales/imports` | Lotes, do mais recente ao mais antigo |
| GET | `/api/sales/imports/{id}` | Resumo + totais por canal, marketplace, dia e produto (com curva ABC) |
| DELETE | `/api/sales/imports/{id}` | 204 (remove o lote e suas vendas; marketplaces continuam; vendas do caixa devolvem o estoque) |
| GET | `/api/sales/imports/{id}/deletion-impact` | O que a exclusão do lote vai causar (não altera nada) |
| POST | `/api/sales/manual` | Venda digitada (JSON) → 201 + venda e lote atualizado. Veja [Vendas manuais](#vendas-manuais-e-remoção-de-vendas) |
| GET | `/api/sales/imports/{id}/sales` | Vendas do lote, paginadas (`?search=&page=1&pageSize=50`) |
| DELETE | `/api/sales/imports/{id}/sales/{saleId}` | 204 (remove uma venda e recalcula os totais do lote) |
| GET | `/api/sales/marketplaces` | Nomes dos marketplaces cadastrados (para sugerir ao digitar) |
| POST | `/api/sales/checkout` | Venda de produtos do cadastro → 201. Veja [Produtos e caixa](#produtos-e-caixa) |

Detalhe de um lote:

```json
{
  "import": { "id": "...", "fileName": "vendas-outubro.xlsx", "importedAt": "...", "importedBy": "maria@exemplo.com",
              "salesCount": 112, "totalQuantity": 284, "totalRevenue": 38015.6,
              "periodStart": "2026-10-01", "periodEnd": "2026-10-28" },
  "byChannel": [
    { "key": "InPerson", "name": "Presencial", "sales": 39, "quantity": 101, "revenue": 11950.4 },
    { "key": "Online",   "name": "Online",     "sales": 73, "quantity": 183, "revenue": 26065.2 }
  ],
  "byMarketplace": [
    { "key": "<id>", "name": "Mercado Livre",       "sales": 20, "quantity": 45, "revenue": 6132.8 },
    { "key": "none", "name": "Fora de marketplace", "sales": 16, "quantity": 43, "revenue": 5207.1 }
  ],
  "byDay": [
    { "date": "2026-10-01", "sales": 4, "quantity": 7, "revenue": 1252.5 },
    { "date": "2026-10-02", "sales": 0, "quantity": 0, "revenue": 0 }
  ],
  "products": [
    { "key": "TEN-010", "name": "Tênis Corrida", "sku": "TEN-010", "sales": 15, "quantity": 40, "revenue": 11960,
      "revenueShare": 0.3146, "abcClass": "A", "recommendation": "Prioritize", "lastSaleDate": "2026-10-26" }
  ],
  "profit": { "salesWithCost": 0, "revenue": 0, "cost": 0, "profit": 0, "margin": null }
}
```

- `byMarketplace` considera só as vendas **online**; "Fora de marketplace" é a loja virtual própria.
- `byDay` traz **todos os dias** do período (do primeiro ao último dia com venda), com zeros nos dias sem venda — para o gráfico de aumento/queda.
- `products` vem ordenado por faturamento. O mesmo produto escrito de formas diferentes é somado junto: mesmo **SKU** (sem acento/maiúsculas), ou mesmo **nome** quando não há SKU.
- `profit` soma só as vendas **com custo conhecido** (vendas do caixa de produtos com preço de custo): `salesWithCost` diz quantas são; `revenue` é o faturamento delas; `margin` = lucro / faturamento. Lotes de planilha têm `salesWithCost: 0`.

### Análise de produtos (curva ABC e sugestão de estoque)

**Curva ABC** pelo faturamento (`AbcCurve`): os produtos, do maior para o menor faturamento, são classificados pela participação acumulada **antes** deles:

| Classe | Faixa | Significado |
|---|---|---|
| A | primeiros 80% do faturamento | produtos principais (o mais vendido é sempre A) |
| B | próximos 15% | importância intermediária |
| C | últimos 5% | pouco faturamento |

**Sugestão de estoque** (`StockRecommendation`, campo `recommendation`):

| Valor | Quando |
|---|---|
| `Prioritize` | curva A |
| `Keep` | curva B, ou curva C que vendeu **pelo menos a mediana** de unidades (produto barato que vende muito, ex.: cabos) |
| `ReviewRemoval` | curva C **e** menos unidades vendidas que a mediana dos produtos do lote |

O critério de unidades evita sugerir a saída de produtos baratos de alto giro só porque faturam pouco.

> A planilha não tem custo, então a curva ABC usa **faturamento** (quantidade × preço). O lucro só existe para as vendas feitas pelo caixa (campo `profit`).

## Vendas manuais e remoção de vendas

Além da planilha, o usuário pode **digitar uma venda** e **remover vendas uma a uma**.

### Lotes manuais

Toda venda pertence a um lote (as análises são por lote). Ao digitar uma venda, o usuário escolhe:

- um **lote existente** (`importId`) — inclusive um lote de planilha; ou
- um **novo lote manual** (`importName`), criado junto com a venda.

Informar os dois, ou nenhum, é erro (chave `importId`). O lote tem `source`: `Spreadsheet` ou `Manual`.

```json
POST /api/sales/manual
{
  "importId": null,
  "importName": "Balcão outubro",
  "date": "2026-10-20",
  "productName": "Mouse sem fio",
  "sku": "MOU-280",
  "quantity": 2,
  "unitPrice": 79.90,
  "channel": "Online",
  "marketplace": "Mercado Livre"
}
```

- Mesmas regras da planilha (`Sale`): data obrigatória e não futura, produto até 200, SKU até 60, quantidade > 0, preço ≥ 0, venda presencial sem marketplace.
- `channel`: `InPerson`/`Online` (aceita também `Presencial`, `Loja física`, `Loja virtual`).
- `marketplace`: reaproveita o existente ignorando acento/maiúsculas; um nome novo é cadastrado.
- As chaves dos erros são os nomes dos campos do JSON (`date`, `productName`, `sku`, `quantity`, `unitPrice`, `channel`, `marketplace`, `importId`, `importName`), para o app mostrar cada erro embaixo do campo.
- Resposta 201: `{ "import": <lote com totais atualizados>, "sale": <venda> }`. A venda manual tem `rowNumber: null` (as da planilha trazem a linha de origem).

### O que a exclusão de um lote causa

`GET /api/sales/imports/{id}/deletion-impact` só **consulta**; o app mostra o resultado na confirmação antes de excluir:

```json
{
  "importId": "…",
  "fileName": "vendas-tecnologia-2026-01.xlsx",
  "salesCount": 112,
  "totalRevenue": 48210.50,
  "linkedProducts": 19,
  "stockReturned": 0
}
```

- `linkedProducts`: quantos produtos cadastrados têm vendas nesse lote. Os produtos **continuam** no catálogo (inclusive os que a importação cadastrou), só perdem essas vendas do histórico.
- `stockReturned`: unidades vendidas pelo caixa que voltam ao estoque.
- Lote inexistente → 404.

A exclusão não é bloqueada quando há produtos ligados: o usuário decide, vendo o impacto (decisão do projeto).

### Remover uma venda

`DELETE /api/sales/imports/{id}/sales/{saleId}` remove a venda e **recalcula** vendas, itens, faturamento e período do lote. O lote continua existindo mesmo se ficar vazio (para excluí-lo, use `DELETE /api/sales/imports/{id}`). Uma venda de outro lote dá 404.

`GET /api/sales/imports/{id}/sales` lista as vendas do dia mais recente ao mais antigo; `search` procura no produto e no SKU (sem diferenciar maiúsculas); `pageSize` vai até 100.

## Produtos e caixa

### Cadastro de produtos

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/products?search=&category=&includeInactive=false` | Produtos por nome; `search` procura no nome e no SKU; inativos só com `includeInactive=true` |
| GET | `/api/products/categories` | Categorias em uso (para sugerir e filtrar) |
| GET | `/api/products/{id}` | Um produto |
| POST | `/api/products` | 201 + produto (409 se o SKU já existe) |
| PUT | `/api/products/{id}` | 200 + produto |
| POST | `/api/products/images` | 201 + `{ "url": "/uploads/products/….png" }` (multipart, campo `file`) |
| DELETE | `/api/products/{id}` | 204; **409 se o produto tem vendas** — do caixa, digitadas ou da planilha com o mesmo SKU (desative-o: `isActive: false`) |

```json
POST /api/products
{
  "name": "Notebook Pro 14",
  "sku": "nb-pro-14",
  "category": "Notebooks",
  "salePrice": 6499.90,
  "costPrice": 4800,
  "stockQuantity": 10,
  "minimumStock": 2,
  "isActive": true,
  "imageUrl": "https://exemplo.com/imagens/notebook-pro-14.png"
}
```

- Obrigatórios: `name` (até 200), `sku` (até 60, **único**; salvo em maiúsculas e sem acento: `nb-pro-14` → `NB-PRO-14`), `salePrice` (≥ 0), `stockQuantity` (≥ 0).
- Opcionais: `category` (até 60), `costPrice` (≥ 0 e **nunca maior que `salePrice`**; sem ele não há lucro), `minimumStock` (padrão 0), `isActive` (padrão `true` ao criar; mantido ao editar).
- **Regra de negócio: produto não é vendido com prejuízo.** Custo maior que o preço de venda → 400 com o erro na chave `costPrice` ("O preço de custo não pode ser maior que o preço de venda: cada venda daria prejuízo."). Custo **igual** ao preço é aceito (margem 0%). Vale ao criar e ao editar; produtos já salvos só são conferidos quando forem editados.
- A resposta traz também `margin` ((venda − custo) / venda) e `isLowStock` (estoque ≤ mínimo).
- Produto **inativo** continua no cadastro e nas vendas antigas, mas não pode ser vendido no caixa.

### Venda pelo caixa

```json
POST /api/sales/checkout
{
  "date": "2026-10-30",
  "channel": "Online",
  "marketplace": "Mercado Livre",
  "items": [
    { "productId": "<id>", "quantity": 2 },
    { "productId": "<id>", "quantity": 1, "unitPrice": 5999.00 }
  ]
}
```

- Só vende **produtos cadastrados e ativos**. `unitPrice` é opcional: vazio usa o preço de venda do produto (pode-se dar desconto).
- **Desconto máximo de 15%** (regra de negócio): `unitPrice` abaixo de 85% do preço de venda do produto → 400 na chave `items[i].unitPrice` ("O desconto não pode passar de 15% do preço do produto: o mínimo é R$ 85,00." para um produto de R$ 100,00). Exatamente 15% é aceito; preço acima do preço de venda não é desconto. O mínimo é arredondado para centavos (`Product.MinimumCheckoutPrice`, `Product.MaxDiscount`). Se o preço também ficar abaixo do custo, o erro mostrado é o do custo.
- **Nunca abaixo do custo** (regra de negócio, a mesma do cadastro): `unitPrice` menor que o custo do produto → 400 na chave `items[i].unitPrice` ("O preço não pode ser menor que o custo (R$ 50,00): a venda daria prejuízo.") e nada é vendido. Igual ao custo é aceito (lucro zero); produto sem custo aceita qualquer preço. Comparação em centavos (`Product.SellsAtLoss`). Vendas digitadas e da planilha não passam por essa regra (não têm custo).
- `date` vazio = hoje. As vendas entram no **lote do mês** da data — `Vendas - outubro/2026`, `source: "Store"` —, criado automaticamente na primeira venda do mês.
- **Tudo ou nada**: se um item falhar, nada é salvo. Erros de cada item usam a chave `items[i].campo` (`items[1].quantity`, `items[0].productId`); data, canal e marketplace aparecem uma vez só (`date`, `channel`, `marketplace`); carrinho vazio usa `items`.
- **Estoque**: cada venda tira as unidades do produto; o mesmo produto em duas linhas soma as quantidades. Sem estoque suficiente → erro na quantidade do item.
- **Custo**: cada venda guarda uma cópia do custo do produto naquele momento (`UnitCost`, `TotalCost`), para o lucro não mudar se o custo for editado depois.
- Resposta 201: `{ "import": <lote do mês>, "sales": [...], "total": 240, "cost": 100, "profit": 140 }` (`cost`/`profit` nulos se nenhum produto tiver custo).
- Excluir uma venda do caixa (ou o lote inteiro) **devolve as unidades ao estoque**.

### Imagem do produto

`imageUrl` guarda **onde está a foto** do produto, de um destes dois jeitos:

1. **Link externo**: endereço `http://` ou `https://` completo (o app carrega a imagem direto do link).
2. **Arquivo enviado**: `POST /api/products/images` (multipart, campo `file`) salva a foto numa pasta do backend e devolve `{ "url": "/uploads/products/3f2a….png" }`; esse caminho vai no `imageUrl` do produto.

Envio de arquivo:

- Aceita **PNG, JPEG, WebP e GIF** de até **5 MB**. O formato é conferido pelos primeiros bytes do arquivo, não pelo nome (um arquivo renomeado para `.png` é recusado). Erros na chave `file`.
- O arquivo é salvo com um nome novo (GUID + extensão do formato detectado); o nome original não chega ao disco.
- Pasta: `ProductImages:Directory` (padrão `uploads/products`, relativo à pasta do projeto `UnivespProject.Api`, ou seja `backend/src/UnivespProject.Api/uploads/products/`). Ela está no `.gitignore`.
- A API serve a pasta em `ProductImages:RequestPath` (padrão `/uploads/products`), **sem login** (uma `<img>` não envia token), com cache longo (o nome nunca muda) e `nosniff`.
- Quando o produto troca de imagem ou é excluído, o arquivo antigo é apagado — a não ser que outro produto use a mesma imagem. Links externos nunca são tocados.
- Um caminho `/…` que não seja de uma imagem enviada que exista → 400 em `imageUrl` ("A imagem enviada não foi encontrada. Envie o arquivo novamente.").
- Fotos enviadas mas nunca salvas num produto (o usuário desistiu do cadastro) ficam na pasta.

Regras de `imageUrl`:

- Opcional, a não ser que o usuário logado tenha ligado `requireProductImage` nas configurações: aí, sem imagem → 400 em `imageUrl` ("A imagem do produto é obrigatória (definido nas suas configurações).").
- Até 2048 caracteres; espaços nas pontas são removidos e vazio vira `null`.

### Vendas ligadas ao produto pelo SKU

Um produto com vendas **não pode ser excluído** (409 na API e FK `restrict` no banco). Além das vendas do caixa, também ficam ligadas ao produto as vendas **digitadas e da planilha cujo SKU é o do produto** (sem diferenciar maiúsculas; acentos e espaços contam):

- ao lançar ou importar a venda, se já existe produto com aquele SKU;
- ao cadastrar o produto, ou trocar o SKU dele — as vendas antigas com o SKU novo passam a apontar para ele, e as do SKU antigo (fora do caixa) são desligadas;
- a migration `LinkSalesToProductsBySku` ligou as vendas que já existiam.

Essa ligação **não mexe em estoque nem em custo**: só as vendas do caixa (`isCheckout: true` na resposta) tiram e devolvem estoque. Para tirar o produto do catálogo sem perder o histórico, desative-o.

### Planilhas de exemplo

`samples/vendas-exemplo.xlsx` (112 vendas válidas, outubro/2026) e `samples/vendas-com-erros.xlsx` (7 erros em 5 linhas) — usadas também pela coleção do Postman, assim como `samples/produto-exemplo.png` (foto de exemplo para o envio de imagem) e `samples/vendas-produtos-novos.xlsx` (4 vendas: 3 do SKU `POSTMAN-NOVO-01`, que não existe no catálogo, e 1 sem SKU — testa o cadastro de produtos pela importação).

`samples/vendas-tecnologia.xlsx`: 151 vendas válidas de produtos de tecnologia (smartphones, notebooks, periféricos etc.) em setembro/2026, faturamento de R$ 142.400,90. Inclui os marketplaces KaBuM! e Casas Bahia (criados automaticamente na importação). Útil para comparar com o lote de outubro.

Planilhas de tecnologia por mês, para o **comparativo de meses** (mesmo catálogo de 19 produtos, sazonalidade e preços de 2025 cerca de 8% menores):

| Arquivo | Mês | Vendas | Itens | Faturamento |
|---|---|---|---|---|
| `samples/vendas-tecnologia-2025-01.xlsx` | janeiro/2025 (volta às aulas: notebooks, tablets) | 118 | 206 | R$ 110.595,04 |
| `samples/vendas-tecnologia-2025-07.xlsx` | julho/2025 (férias: consoles, TVs) | 126 | 238 | R$ 110.818,86 |
| `samples/vendas-tecnologia-2026-01.xlsx` | janeiro/2026 (+20% sobre janeiro/2025) | 142 | 265 | R$ 133.023,05 |
| `samples/vendas-tecnologia-2026-09.xlsx` | setembro/2026 | 150 | 277 | R$ 143.942,75 |

`vendas-tecnologia-2026-09.xlsx` é **outro** setembro/2026, diferente de `vendas-tecnologia.xlsx`: importar os dois soma as vendas no mesmo mês (o comparativo junta todos os lotes). Use um ou outro.

Os quatro arquivos são gerados por `samples/gerar_vendas_tecnologia.py` (Python + `openpyxl`, semente fixa por mês: rodar de novo gera os mesmos arquivos). Para outro mês, acrescente uma linha em `MONTHS`.

## Comparativo de meses

Compara dois meses somando **todas as vendas de todos os lotes** (planilhas, lançamentos manuais e caixa) pela data da venda. Serve tanto para meses do mesmo ano (janeiro/2026 x março/2026) quanto para o mesmo mês em anos diferentes (janeiro/2025 x janeiro/2026).

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/sales/months` | Meses com pelo menos uma venda, do mais recente ao mais antigo: `[{ "month": "2026-10", "label": "outubro/2026", "sales", "quantity", "revenue" }]` |
| GET | `/api/sales/comparison?base=2025-01&target=2026-01` | Os dois meses lado a lado (abaixo) |

- `base` é o mês de referência e `target` o mês comparado a ele: crescimento = (target − base) / base (o app calcula as variações).
- Resposta: `base` e `target` (`month`, `label`, `days`, `elapsedDays` — menor que `days` no mês em andamento —, `sales`, `quantity`, `revenue`, `profit`), `byChannel`, `byMarketplace` (só online, com "Fora de marketplace"), `products` (todos os vendidos em qualquer um dos meses, maior faturamento do `target` primeiro) e `byDay` (dia 1 até o fim do mês mais longo). Cada item de grupo tem `key`, `name`, `sku` (produtos) e os totais `base`/`target` (zeros onde não vendeu); em `byDay`, o lado do mês mais curto vem `null` (não existe 30 de fevereiro).
- Produtos são agrupados pela mesma chave do detalhe do lote (SKU normalizado, ou nome sem SKU); o nome mostrado é o do mês `target`.
- Lucro: só das vendas com custo (caixa), como no detalhe do lote.
- Erros (400) nas chaves `base`/`target`: mês vazio ("Escolha o mês base."), formato inválido ("Use o formato AAAA-MM"), meses iguais ("Escolha um mês diferente do mês base.") e mês sem vendas ("Não há vendas em abril/2026.").
- Código: `ISalesComparisonService`/`SalesComparisonService` (Application) e `ISalesReportRepository`/`SalesReportRepository` (totais por período). As consultas de totais (canal, marketplace, dia, produto, custo) ficam em `SaleAggregates` e são as mesmas do detalhe do lote. `SalesMonth` faz a leitura de `"2026-01"`; nomes dos meses em `Domain/Common/MonthNames`.
- Índice `IX_sales_SaleDate` (migration `AddSaleDateIndex`) para filtrar por data em todos os lotes.

## Exportação de vendas (planilha por período)

Gera um `.xlsx` com **todas as vendas de um período**, de todos os lotes (planilhas importadas, lançamentos manuais e caixa). O período pode ser um dia, uma semana, um mês ou qualquer intervalo de até 366 dias (o app oferece Dia, Semana — segunda a domingo —, Mês e Período). Cada planilha gerada fica guardada (tabela `sales_exports`) para ser baixada de novo; no app ela aparece na tela **Exportações**, separada de **Importações**.

| Método | Rota | Resposta |
|---|---|---|
| POST | `/api/sales/exports` | 201 com o resumo da planilha gerada. Corpo: `{ "start": "2026-11-02", "end": "2026-11-08", "platform": "linux" }` (`platform` opcional: [fonte](#fonte-das-planilhas-geradas)) |
| GET | `/api/sales/exports` | Planilhas geradas, da mais recente à mais antiga (sem o arquivo) |
| GET | `/api/sales/exports/{id}/file` | O `.xlsx` como foi gerado |
| DELETE | `/api/sales/exports/{id}` | 204 (remove só o arquivo gerado; nenhuma venda muda) |

```json
{
  "id": "…",
  "fileName": "vendas-2026-11-02-a-2026-11-08.xlsx",
  "periodStart": "2026-11-02",
  "periodEnd": "2026-11-08",
  "periodLabel": "02/11/2026 a 08/11/2026",
  "salesCount": 37,
  "totalRevenue": 18250.40,
  "createdAt": "2026-11-01T16:39:10Z",
  "createdBy": "maria@exemplo.com"
}
```

- Nome e rótulo: um dia → `vendas-2026-11-05.xlsx` / "05/11/2026"; um mês inteiro → `vendas-2026-11.xlsx` / "novembro/2026"; outro intervalo → `vendas-2026-11-02-a-2026-11-08.xlsx` / "02/11/2026 a 08/11/2026".
- Aba **Vendas**: as colunas do modelo de importação (Data, Produto, SKU, Quantidade, Preço Unitário, Canal, Marketplace) e mais **Total**, **Origem** (Planilha, Manual ou Caixa) e **Lote**, com filtro no cabeçalho; ordem: data, lote, linha da planilha. Aba **Resumo**: vendas, itens e faturamento do período, e totais por origem e por canal.
- A aba Vendas segue o modelo, então o arquivo pode ser lido de volta — mas **importá-lo no sistema duplica as vendas** (o Resumo avisa). Por isso a planilha gerada nunca vira lote.
- Erros (400) nas chaves `start`/`end`: data vazia ("Informe a data inicial."), formato diferente de `aaaa-mm-dd`, data final antes da inicial e período maior que 366 dias. Período sem vendas: 404 "Não há vendas em 01/01/1990 a 07/01/1990." (nada é guardado). Planilha gerada inexistente: 404.
- Código: `ISalesExportService`/`SalesExportService` (Application), `ISalesExportRepository`/`SalesExportRepository` (lista sem ler o arquivo; exclusão com `ExecuteDelete`), `ISalesReportRepository.ListSalesAsync` (vendas do período com marketplace e lote) e `ISalesSpreadsheet.CreatePeriodSheet` (ClosedXML). Migration `AddSalesExports`.

### Fonte das planilhas geradas

O modelo (`GET /api/sales/template?platform=...`) e as exportações (`"platform"` no corpo do `POST /api/sales/exports`) saem na **fonte padrão das planilhas do sistema operacional de quem pediu** — a do programa de planilhas mais usado nele (`SpreadsheetFont`):

| `platform` | Fonte | Programa |
|---|---|---|
| `windows` (ou vazio) | Calibri 11 | Excel |
| `macos`, `ios` | Helvetica Neue 10 | Numbers |
| `linux` | Liberation Sans 10 | LibreOffice Calc |
| `android` | Roboto 10 | fonte do sistema |

- O app manda o nome do sistema como o Flutter o chama (`windows`, `macOS`, `linux`, `android`, `iOS`, `fuchsia` = android; maiúsculas não importam). Na Web é o sistema do navegador.
- Valor desconhecido: 400 na chave `platform` ("Sistema operacional inválido. Use windows, macos, linux, android ou ios.") e nada é gerado.
- A fonte vale para todas as células (cabeçalho, dados, resumo, instruções) e para as colunas das abas, que o Excel e o LibreOffice usam nas células vazias. O título do Resumo continua maior (14). Só o estilo "Normal" do arquivo fica em Calibri (o ClosedXML não o troca): ele só aparece numa aba que a pessoa criar à mão.
- Uma exportação guarda o arquivo como foi gerado: baixada de novo em outro sistema, mantém a fonte de quando foi gerada.

## Análises com aprendizado de máquina (ML.NET)

Duas análises sobre o histórico de vendas de **todos os lotes** (planilhas, lançamentos e caixa), feitas com [ML.NET](https://dotnet.microsoft.com/apps/ai/ml-dotnet) (`Microsoft.ML` 5.0.1, só na Infrastructure):

| Método | Rota | O que faz |
|---|---|---|
| GET | `/api/analytics/forecast?months=3` | Previsão de vendas dos próximos meses (1 a 6; padrão 3), por produto, com sugestão de compra |
| GET | `/api/analytics/product-groups?groups=3` | Grupos de produtos que vendem de forma parecida (2 a 6 grupos; sem `groups`, o número é escolhido automaticamente) |

### Histórico usado

As duas análises aprendem com o total de cada produto em cada mês. Para não ensinar errado ao modelo, só contam **meses completos e registrados de verdade**:

- o mês atual fica de fora (ainda não terminou);
- um mês com vendas em **menos da metade dos dias** fica de fora: parece um mês registrado pela metade (algumas vendas digitadas, uma planilha parcial) e seria lido como um mês de vendas fracas;
- um mês sem nenhuma venda é **desconhecido, não zero**: a loja pode só não ter importado aquele mês.

Os meses deixados de fora voltam na resposta (`ignoredMonths`, com o motivo). Produtos são identificados pelo SKU normalizado (ou pelo nome, sem SKU), como no resto da API. Histórico insuficiente → **404** com a explicação (ex.: "A previsão precisa de pelo menos 3 meses completos de vendas e há só 2. ...").

### Previsão dos próximos meses

- **Modelo:** regressão de Poisson (`LbfgsPoissonRegression`), própria para contagens como unidades vendidas: log(unidades esperadas) = efeito do produto + tendência + época do ano. Um único modelo para todos os produtos (cada um tem poucos meses, mas a tendência e a época são aprendidas com todos juntos).
- **Atributos:** produto (one-hot), meses desde o início do histórico (tendência) e o mês do ano num círculo (seno e cosseno: dezembro fica ao lado de janeiro). Os atributos de tempo são padronizados (média 0, desvio 1); um atributo que não variou no treino (ex.: só janeiros e julhos, seno sempre 0) vira 0 em vez de dividir por zero.
- **Precisa de** pelo menos 3 meses completos. Previsão a partir do **mês seguinte ao atual**; unidades arredondadas (meio notebook não é vendido).
- **Faturamento previsto** = unidades × preço médio do último mês em que o produto vendeu.
- **Sugestão de compra** (só produtos do cadastro) = previsto no período + estoque mínimo − estoque atual, nunca abaixo de 0. Produtos desativados ensinam o modelo, mas não são previstos.
- **Validação** (`validation`): o modelo é treinado de novo **sem o último mês** do histórico, prevê esse mês e compara com o que foi vendido. Erro = soma de |previsto − vendido| / unidades vendidas. Ao lado, o erro do palpite simples (média dos meses anteriores de cada produto), para mostrar se o modelo acrescenta algo. No banco local: erro de 39% do modelo contra 54% da média simples, testando setembro/2026.
- Semente fixa: o mesmo histórico dá sempre a mesma previsão.

### Grupos de produtos

- **Modelo:** k-means (`KMeansTrainer`, início k-means++, semente fixa e uma thread: os mesmos produtos formam sempre os mesmos grupos).
- **Atributos:** itens por mês e preço médio, em escala logarítmica (um cabo de R$ 30 e um notebook de R$ 5.000 diferem em proporção, não em reais), e regularidade (fração dos meses com vendas). Todos padronizados (*z-score*) antes do k-means; coluna constante vira 0.
- **Número de grupos:** testa de 2 a 6 (no máximo produtos − 1) e fica o de maior **silhueta** (−1 a 1; empate = menos grupos). A silhueta de cada tentativa volta em `candidates`. Com `groups`, usa o número pedido.
- **Nome do grupo:** o centro do grupo comparado com o produto mediano em itens por mês e preço — **Carros-chefe** (vendem muito, preço alto), **Alto giro** (muito, barato), **Alto valor, baixo giro** (pouco, caro) e **Baixo giro** (pouco, barato) —, com uma descrição e um aviso de vendas irregulares quando a regularidade média fica abaixo de 50%. Nomes repetidos ganham número ("Alto giro 2"). Grupos numerados do maior para o menor faturamento.
- Precisa de pelo menos 1 mês completo e 3 produtos com vendas.

### Código

- Application: `Analytics/` — `SalesHistory` (meses usados e ignorados, histórico por produto), `SalesAnalyticsService` (base abstrata: carrega o histórico e avisa quando não basta), `SalesForecastService`, `ProductGroupsService`, `FeatureScaling`, `Silhouette`, `ProductGroupNames`. DTOs em `DTOs/Analytics`.
- Interfaces `ISalesForecaster` e `IProductClusterer` (Abstractions); implementações `MlNetSalesForecaster` e `MlNetProductClusterer` em `Infrastructure/MachineLearning`. Os serviços não conhecem o ML.NET (testados com *fakes*); os modelos reais têm testes próprios com dados de resposta óbvia.
- `ISalesReportRepository.GetTotalsByProductAndMonthAsync` e `GetDaysWithSalesByMonthAsync` (SQL agrupado; sem migration).
- Endpoints em `Api/Endpoints/AnalyticsEndpoints.cs`.

## Formato de erro da API

Todo erro — validação, regra de negócio, JSON inválido ou exceção inesperada — tem o mesmo formato (RFC 7807 + lista `errors`):

```json
{
  "title": "Dados inválidos.",
  "status": 400,
  "errors": [
    { "key": "email", "message": "O e-mail informado é inválido." },
    { "key": "password", "message": "A senha deve ter no mínimo 8 caracteres." }
  ],
  "traceId": "00-..."
}
```

Status: 400 (validação), 401 (sem login), **403** (sem acesso à loja, parte não liberada ou ação só de admin), 404, 409. Exceções não tratadas viram 500 com mensagem genérica (o detalhe vai só para o log), via `GlobalExceptionHandler`.

## Banco de dados

- PostgreSQL com Entity Framework Core (Npgsql).
- Na inicialização, a API chama `Database.MigrateAsync()`: **cria o banco se não existir** e aplica as migrations pendentes.
- Na primeira execução aparece no log `An error occurred using the connection to database` — é o EF verificando que o banco ainda não existe, antes de criá-lo. É esperado.

### Tabela `users`

| Coluna | Tipo |
|---|---|
| `Id` | `uuid` (PK) |
| `Name` | `varchar(150)` |
| `Email` | `varchar(254)`, índice único |
| `PasswordHash` | `text` |
| `LastLoginAt` | `timestamptz?` |
| `StoreId` | `uuid?`, FK `stores` (null = sem loja) |
| `Role` | `varchar(10)?`: `Admin`, `Member` ou `Pending` |
| `Areas` | `integer`: soma das partes liberadas (`StoreArea`, flags; admin usa todas) |
| `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy` | auditoria |

### Tabela `stores`

| Coluna | Tipo |
|---|---|
| `Id` | `uuid` (PK) |
| `Name` | `varchar(100)` |
| `NormalizedName` | `varchar(100)`, índice único (nome sem acentos, em maiúsculas, espaços simples) |
| `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy` | auditoria |

`products`, `marketplaces`, `sales_imports`, `sales` e `sales_exports` têm `StoreId` (`uuid`, FK `stores`, Restrict). Índices únicos por loja: `products (StoreId, Sku)` e `marketplaces (StoreId, NormalizedName)`.

### Tabela `notifications`

Central de notificações (não confundir com as notificações de validação das requisições).

| Coluna | Tipo |
|---|---|
| `Id` | `uuid` (PK) |
| `UserId` | `uuid`, FK `users` (cascade: some junto com o usuário); índice `(UserId, CreatedAt)` |
| `Kind` | `varchar(30)`: `AccessRequested` ou `AccessApproved` |
| `Message` | `varchar(500)` |
| `RelatedUserId` | `uuid?`, indexado (quem pediu acesso; sem FK) |
| `ReadAt` | `timestamptz?` (null = não lida) |
| `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy` | auditoria |

### Tabela `user_settings`

| Coluna | Tipo |
|---|---|
| `Id` | `uuid` (PK) |
| `UserId` | `uuid`, índice único, FK `users` (cascade: some junto com o usuário) |
| `RequireProductImage` | `boolean`, padrão `false` |
| `CreateProductsOnImport` | `boolean`, padrão `false` |
| `NotifyRestock` | `boolean`, padrão `true` (migration `AddNotifyRestockSetting`; usuários que já existiam ficaram com o aviso ligado) |
| `Theme` | `varchar(10)`: `Dark` (padrão) ou `Light` (migration `AddUserThemeSetting`) |
| `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy` | auditoria |

A migration `AddUserSettings` criou a tabela, copiou a configuração "exigir imagem" de quem já tinha ligado (antes ela era a coluna `users.RequireProductImage`) e removeu essa coluna.

### Tabelas de vendas

| Tabela | Conteúdo | Chaves |
|---|---|---|
| `marketplaces` | `Name`, `NormalizedName` | `NormalizedName` único |
| `products` | `Name`, `Sku`, `Category?`, `SalePrice`, `CostPrice?`, `StockQuantity`, `MinimumStock`, `IsActive`, `ImageUrl?` (link da foto, até 2048) | `Sku` único |
| `sales_imports` | Lote: `FileName` (nome do arquivo, do lote manual ou `Vendas - mês/ano`), `Source` (`Spreadsheet`/`Manual`/`Store`), `SalesCount`, `TotalQuantity`, `TotalRevenue`, `PeriodStart`, `PeriodEnd` | — |
| `sales_exports` | Planilha gerada: `FileName`, `PeriodStart`, `PeriodEnd`, `PeriodLabel`, `SalesCount`, `TotalRevenue`, `Content` (`bytea`, o `.xlsx`) | índice `CreatedAt` |
| `sales` | `RowNumber?` (linha da planilha; vazio = digitada ou do caixa), `SaleDate`, `ProductName`, `Sku`, `Quantity`, `UnitPrice`, `TotalPrice`, `Channel` (`InPerson`/`Online`), `MarketplaceId?`, `ProductId?` (produto do caixa ou de mesmo SKU), `IsCheckout` (vendida no caixa: só essas mexem no estoque), `UnitCost?`, `TotalCost?` | FK lote (cascade), FK marketplace (restrict), FK produto (restrict: produto vendido não pode ser excluído) |

Todas têm os campos de auditoria de `BaseEntity`.

### Nova migration

```bash
dotnet tool restore
dotnet ef migrations add NomeDaMigration \
  --project src/UnivespProject.Infrastructure \
  --startup-project src/UnivespProject.Api \
  --output-dir Persistence/Migrations
```

## Configuração

| Chave | Onde | Descrição |
|---|---|---|
| `ConnectionStrings:DefaultConnection` | `appsettings.Development.json` (dev) / variável de ambiente (prod) | Conexão com o PostgreSQL |
| `Jwt:Key` | **user-secrets** (dev) / variável de ambiente (prod) | Chave de assinatura, mínimo 32 caracteres. Nunca no repositório |
| `Jwt:Issuer`, `Jwt:Audience`, `Jwt:ExpirationMinutes` | `appsettings.json` | Parâmetros do token |
| `ExternalApi:BaseUrl`, `ExternalApi:TimeoutSeconds` | `appsettings.json` | API externa (reservada; ainda não usada) |

Em produção, as variáveis de ambiente usam `__` no lugar de `:` (ex.: `Jwt__Key`).

A API não inicia se `Jwt` estiver inválido ou se a connection string estiver vazia.

## Como executar

```bash
cd backend

# 1. PostgreSQL
podman compose up -d          # ou: docker compose up -d

# 2. Chave do JWT (uma vez por máquina)
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)" --project src/UnivespProject.Api

# 3. Certificado HTTPS de desenvolvimento (uma vez por máquina)
dotnet dev-certs https --trust

# 4. API em https://localhost:7077
dotnet run --project src/UnivespProject.Api
```

### HTTPS

A API roda só em **HTTPS** (`https://localhost:7077`, perfil único em `Properties/launchSettings.json`). `UseHttpsRedirection` redireciona qualquer acesso HTTP e, fora de Development, `UseHsts` manda o navegador usar sempre HTTPS.

- Em desenvolvimento o certificado é o do ASP.NET (`dotnet dev-certs https`), emitido para `localhost`. O `--trust` o adiciona às autoridades confiáveis do sistema e do navegador. No Linux pode ser preciso fechar e abrir o navegador depois.
- O app Flutter no **Android** (emulador, `https://10.0.2.2:7077`) não consegue validar esse certificado, porque o nome não bate com o host. Por isso, **só em builds debug** e só para `localhost`/`10.0.2.2`, ele aceita o certificado de desenvolvimento (`dev_certificate_io.dart` no frontend). Builds release validam normalmente.
- `curl` precisa de `-k` (ou do certificado confiável) para chamar a API local.

Exemplos de requisições: `src/UnivespProject.Api/UnivespProject.Api.http`. Documento OpenAPI (em desenvolvimento): `/openapi/v1.json`.

## Testes

```bash
dotnet test
```

Os testes ficam em `tests/UnivespProject.Tests`, nas mesmas pastas da camada testada (`Domain/`, `Application/`, `Infrastructure/`, `Api/`). Serviços são testados com repositórios em memória e *fakes* das interfaces.

## Testando no Postman

A pasta `postman/` tem uma coleção pronta, que testa só a API (sem o app Flutter):

| Arquivo | Conteúdo |
|---|---|
| `postman/UnivespProject.postman_collection.json` | 142 requisições (pastas **Auth**, **Loja**, **Vendas**, **Produtos e caixa** e **Análises**) com 269 verificações automáticas |
| `postman/Local.postman_environment.json` | Ambiente **Univesp - Local** (`baseUrl = https://localhost:7077`) |

**No aplicativo Postman**

1. Com o banco e a API rodando, clique em **Import** e arraste os dois arquivos. Se o certificado de desenvolvimento não for aceito, desligue *Settings → General → SSL certificate verification* (só para a API local).
2. No canto superior direito, selecione o ambiente **Univesp - Local**.
3. Rode tudo: clique com o botão direito na coleção → **Run collection** → **Run**. Ou envie uma requisição por vez, na ordem.

Na pasta **Auth**, as requisições **Alterar senha** trocam a senha do usuário de teste (nova senha gerada a cada execução, na variável `newPassword`) e conferem que a antiga deixa de entrar e a nova entra. As **Recuperar senha** conferem os erros (dados inválidos, e-mail sem conta = 404), trocam a senha só pelo e-mail (nova senha gerada em `recoveredPassword`) e conferem o login com a senha anterior (recusado) e com a recuperada. As requisições **Configurações** conferem que um usuário novo tem tudo desligado (menos o aviso de reposição, ligado), que `/api/settings` exige token e recusa corpo vazio e tema inválido, trocam o tema para claro e de volta para escuro, desligam e religam o aviso de reposição, e ligam "exigir imagem" para esse usuário de teste; na pasta **Produtos e caixa**, um produto sem imagem e outro com link inválido são recusados, e a preferência é desligada antes de cadastrar o produto (com imagem) usado no resto da pasta. As requisições **Imagem** enviam `samples/produto-exemplo.png` (e uma planilha, recusada), baixam o arquivo, usam-no no produto e conferem que ele some (404) quando o produto é excluído.

O cadastro gera um e-mail novo a cada execução, **abre uma loja nova** (então a coleção só vê os dados dela, nunca os da sua loja) e o token é salvo sozinho na variável `token`; as requisições protegidas já usam `Bearer {{token}}`. As verificações aparecem na aba **Test Results** de cada resposta.

A pasta **Loja** confere um nome de loja longo demais (400) e cadastra um segundo usuário com o **nome da loja** do primeiro, em maiúsculas e com espaços sobrando (token em `memberToken`, gerado por script); confere a notificação do pedido na central do admin e a central vazia de quem pediu, pendente sem acesso (403 `store`), pendente não gerencia usuários (403 `admin`), aprovar com parte inválida (400) e só com o caixa (a notificação do admin fica lida; quem pediu recebe "Seu acesso à loja X foi aprovado.", marca como lida, ninguém marca a notificação de outra pessoa — 404 — e "marcar todas"), caixa lê produtos mas não cadastra (403 `area`), sem importações (403) e depois liberadas, tornar admin e voltar, papel inválido, renomear a loja, remover o último admin (409), remover o usuário (perde o acesso, perfil sem loja), o removido abre a própria loja e não pode entrar em outra (409), renomear para o nome de outra loja (409) e notificações sem token (401).

**Pelo terminal (Postman CLI)**

```bash
postman collection run postman/UnivespProject.postman_collection.json \
  -e postman/Local.postman_environment.json --working-dir . --report-events=false --insecure
```

`--insecure` aceita o certificado de desenvolvimento.

Na pasta **Vendas**, **Importar - sucesso** confere que, com a configuração desligada (padrão), nenhum SKU de `vendas-exemplo.xlsx` vira produto. Depois, **Configurações - cadastrar produtos ao importar** liga a configuração só para o usuário de teste, e as requisições seguintes importam `vendas-produtos-novos.xlsx` duas vezes (1 produto cadastrado na primeira, nenhum na segunda), conferem o produto `POSTMAN-NOVO-01`, que ele não pode ser excluído enquanto tem vendas, e depois excluem os dois lotes e o produto. **Meses com vendas** guarda os dois meses mais recentes e **Comparar meses** os compara (é pulada se o banco só tiver vendas em um mês); duas requisições conferem os erros (mesmo mês, formato inválido). As requisições **Exportação** conferem os erros de datas e o período sem vendas (404), geram a planilha da semana de 05 a 11/10/2026 (com `platform: linux`), listam, baixam, excluem (e conferem o 404 depois) e testam a rota sem token — a coleção não deixa planilha gerada no banco.

A pasta **Análises** pede a previsão de 3 e de 6 meses (meses seguidos a partir do próximo, quantidades de cada produto somando o total, total do mês = soma dos produtos, sugestão de compra = previsto + mínimo − estoque, validação no último mês do histórico) e os grupos de produtos automáticos e com 2 grupos (número escolhido pela melhor silhueta, grupos ordenados por faturamento, cada produto num só grupo, participações somando 100%), além dos erros de limite (`months=7`, `groups=1`) e das rotas sem token. Num banco sem histórico suficiente, previsão e grupos aceitam o 404 e conferem a explicação.

A pasta **Produtos e caixa** cadastra um produto de teste (SKU `PM-<timestamp>`), vende, confere estoque e lucro, exclui a venda (o estoque volta) e exclui o produto. O lote do mês só é excluído no fim se tiver sido criado pela própria execução (ele pode ter vendas reais).

Os uploads usam os arquivos de `samples/`. No app Postman, se o campo `file` (aba **Body**) aparecer em vermelho, selecione o arquivo de novo ou ajuste *Settings → General → Working directory* para a pasta `backend`.

O que é verificado: status de cada cenário (201, 200, 204, 400, 401, 404, 409), formato padrão de erro, mensagens, normalização do e-mail e do SKU, token JWT válido, que a senha/hash nunca aparece nas respostas, que rotas protegidas recusam requisições sem token ou com token inválido, baixa e devolução de estoque e cálculo do lucro.

Ao criar um endpoint novo, adicione as requisições e os testes nesta coleção.

