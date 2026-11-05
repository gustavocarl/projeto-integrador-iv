# Projeto Integrador IV - Univesp

Projeto desenvolvido para o Projeto Integrador IV (PJI410) do curso de Engenharia da Computação da Univesp.

É um sistema de **gestão e análise de vendas para lojas de varejo** (o protótipo foi pensado para a loja *Marcelo Eletrônicos*). Ele junta, num só lugar, o cadastro de produtos, a venda pelo caixa, a importação de planilhas de vendas (loja física e virtual, por marketplace) e análises que ajudam a decidir o que comprar e o que vender. Entre essas análises estão a **previsão de vendas dos próximos meses** e o **agrupamento de produtos**, feitos com aprendizado de máquina (ML.NET).

O sistema tem duas partes:

| Parte | Tecnologia | Pasta | Documentação |
|---|---|---|---|
| **Backend** (API) | C# / ASP.NET Core (.NET 10), EF Core, PostgreSQL 17, JWT, ClosedXML, ML.NET | [`src/backend`](src/backend) | [README do backend](src/backend/README.md) |
| **Frontend** (app) | Flutter (Android e Web), Riverpod, Dio | [`src/frontend`](src/frontend) | [README do frontend](src/frontend/README.md) |

## Sumário

- [Visão geral](#visão-geral)
- [Início rápido](#início-rápido)
- [Funcionalidades](#funcionalidades)
- [Como funciona](#como-funciona)
  - [Fluxo de dados](#fluxo-de-dados)
- [Aprendizado de máquina](#aprendizado-de-máquina)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Requisitos](#requisitos)
- [Como executar](#como-executar)
- [Testes](#testes)
- [Dados de exemplo](#dados-de-exemplo)
- [Convenções do projeto](#convenções-do-projeto)
- [Licença](#licença)

## Visão geral

O repositório é um monorepo com o backend de análise de dados (C# / ASP.NET Core) e o frontend (Flutter). No app, a loja:

- cadastra produtos com preço, custo, estoque e foto por link. O custo nunca pode ser maior que o preço, para não vender com prejuízo. A foto é obrigatória ou não, conforme as preferências de cada usuário;
- vende pelo caixa;
- importa planilhas Excel de vendas (loja física x virtual, por marketplace) ou digita as vendas. Se o usuário ligar essa opção nas preferências, os SKUs que ainda não existem viram produtos cadastrados;
- acompanha os resultados e compara meses (ex.: janeiro/2025 x janeiro/2026);
- vê a **previsão de vendas dos próximos meses** e os **grupos de produtos** que vendem de forma parecida, feitos com aprendizado de máquina (ML.NET).

Cada usuário escolhe o tema do app nas preferências: escuro (o padrão) ou claro. Ali também liga ou desliga o **aviso de reposição de estoque**, que vem ligado: aparece um selo no menu Produtos e um aviso depois da venda no caixa.

Na tela de login dá para **criar conta** e **recuperar a senha** de forma simples, sem confirmação por e-mail (só para demonstração).

Cada usuário pertence a uma **loja**. Ao criar a conta, a pessoa informa o nome da loja:

- se a loja não existe, ela é criada e a pessoa vira o admin;
- se já existe, a pessoa faz um pedido de acesso e o admin recebe uma **notificação** no sino do app para aprovar.

O **admin** aprova, remove, promove e escolhe quais partes do sistema cada usuário usa. Os dados de cada loja ficam separados. Tudo trafega em HTTPS.

| Projeto | Tecnologia | Documentação |
|---|---|---|
| `src/backend/` | .NET 10, EF Core, PostgreSQL, JWT, ClosedXML, ML.NET | [src/backend/README.md](src/backend/README.md) |
| `src/frontend/` | Flutter (Android + Web), Riverpod, Dio | [src/frontend/README.md](src/frontend/README.md) |

## Início rápido

```bash
# Banco + backend (https://localhost:7077)
cd src/backend
podman compose up -d                     # ou: docker compose up -d
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)" --project src/UnivespProject.Api   # 1ª vez
dotnet dev-certs https --trust           # 1ª vez: confia no certificado HTTPS de desenvolvimento
dotnet run --project src/UnivespProject.Api

# Frontend (em outro terminal, a partir da raiz do repositório)
cd src/frontend
flutter run -d chrome          # Web (usa https://localhost:7077)
flutter run                    # Android/emulador (usa https://10.0.2.2:7077)
```

Os detalhes estão em [Requisitos](#requisitos) e [Como executar](#como-executar).

## Funcionalidades

O app tem um menu com até seis telas. Cada usuário vê só as que o admin da loja liberou.

| Menu | O que faz |
|---|---|
| **Produtos** | Cadastro com nome, SKU, categoria, preço de venda, custo, estoque, estoque mínimo, foto (link ou arquivo enviado) e ativo/inativo. O custo nunca pode ser maior que o preço, para não vender com prejuízo. |
| **Vender** | Caixa: vende produtos do cadastro, dá baixa no estoque e registra o custo para calcular o lucro. O desconto máximo é de 15% e o preço nunca fica abaixo do custo. As vendas entram num lote mensal automático ("Vendas - outubro/2026"). |
| **Importar** | Envio de planilhas Excel (`.xlsx`) de vendas, com um modelo pronto para baixar. A validação é tudo ou nada, com o erro apontado na linha. Também dá para digitar vendas à mão. Cada envio vira um **lote**, com análises: vendas por canal (Presencial/Online) e por marketplace, evolução diária, produtos mais e menos vendidos, **curva ABC**, sugestão de estoque e lucro. |
| **Exportar** | Gera uma planilha com todas as vendas de um dia, uma semana, um mês ou um período, e a guarda para baixar de novo. |
| **Comparar** | Compara um mês com outro somando todos os lotes (ex.: janeiro/2025 x janeiro/2026): faturamento, itens, ticket médio, plataformas, produtos que mais subiram e caíram e o acumulado dia a dia. |
| **Prever** | Previsão de vendas dos próximos 1 a 6 meses, por produto, com sugestão de compra, e **grupos de produtos** que vendem de forma parecida. |

Além disso:

- **Contas e login**: criar conta, entrar (token JWT), alterar senha e recuperar senha. A recuperação é simples, sem confirmação por e-mail, e serve só para demonstração.
- **Lojas e permissões**: ao criar a conta, a pessoa informa o nome da loja. Se a loja não existe, ela é criada e a pessoa vira **admin**. Se já existe, a pessoa faz um **pedido de acesso** e o admin recebe uma notificação (sino do app). O admin aprova, recusa, remove e promove usuários e escolhe quais partes do sistema cada um usa. **Os dados de cada loja ficam separados.**
- **Preferências de cada usuário**: tema escuro (o padrão) ou claro, exigir foto nos produtos, cadastrar produtos novos ao importar planilhas e aviso de reposição de estoque (ligado por padrão).
- **Só HTTPS**, também no ambiente de desenvolvimento.

## Como funciona

```
                         ┌───────────────────────── App Flutter (Android / Web) ──────────────────────────┐
                         │  Produtos · Vender · Importar · Exportar · Comparar · Prever · Notificações   │
                         └───────────────────────────────────────┬───────────────────────────────────────┘
                                                                 │ HTTPS + JWT (Dio)
                                                                 ▼
┌──────────────────────────────────────── API ASP.NET Core (https://localhost:7077) ────────────────────────────────────────┐
│  /api/auth · /api/store · /api/notifications · /api/settings · /api/products · /api/sales · /api/analytics             │
│                                                                                                                        │
│  planilha .xlsx ──► leitura e validação (ClosedXML) ──┐                                                                │
│  caixa do app ────► baixa de estoque + custo ─────────┼──► lotes de vendas ──► resumos, curva ABC, comparativo, lucro  │
│  venda digitada ──────────────────────────────────────┘          │                                                     │
│                                                                  └──► ML.NET: previsão (Poisson) e grupos (k-means)    │
└──────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────┘
                                                           ▼
                                             PostgreSQL 17 (container)
```

### Fluxo de dados

```
planilha .xlsx (app) ─► backend: lê e valida (ClosedXML) ─┐
caixa do app (produtos do cadastro) ─► baixa de estoque ────┼─► PostgreSQL (lotes de vendas) ─► /api/sales ─► app Flutter (gráficos: plataformas, evolução diária, produtos/curva ABC, lucro, comparativo de meses)
                                                            │                 └─► /api/analytics (ML.NET: previsão dos próximos meses, grupos de produtos) ─► app Flutter (menu Prever)
venda digitada no app ──────────────────────────────────────┘
```

- O **backend** segue a Clean Architecture (`Domain` ← `Application` ← `Infrastructure` / `Api`). Os erros de validação são devolvidos como notificações num formato único (ProblemDetails + lista `errors` com `key` e `message`), que o app mostra embaixo do campo certo.
- O **isolamento por loja** é garantido no banco: um filtro global do EF Core só mostra os dados da loja do usuário, e cada rota confere se ele tem acesso àquela parte do sistema.
- O **banco é criado sozinho**: na inicialização, a API aplica as migrations pendentes.
- O **frontend** é organizado por funcionalidade (`features/<feature>/{data,domain,presentation}`). Os gráficos foram feitos à mão, sem pacote de gráficos, e funcionam nos dois temas.

Os detalhes de cad
a rota, das regras de negócio e das tabelas estão no [README do backend](src/backend/README.md). As telas estão descritas no [README do frontend](src/frontend/README.md).

## Aprendizado de máquina

As análises usam o histórico de **todos os lotes** (planilhas, vendas digitadas e caixa). Só entram meses completos e bem registrados: o mês atual fica de fora, assim como os meses com vendas em menos da metade dos dias.

| Análise | Rota | Modelo | Resultado |
|---|---|---|---|
| Previsão de vendas | `GET /api/analytics/forecast?months=3` | Regressão de Poisson (`LbfgsPoissonRegression`). Atributos: produto, tendência e época do ano (seno e cosseno do mês) | Unidades e faturamento previstos por produto e sugestão de compra (previsto + estoque mínimo − estoque atual). Inclui uma validação: o modelo é retreinado sem o último mês e o erro é comparado com o de uma média simples |
| Grupos de produtos | `GET /api/analytics/product-groups` | k-means (k-means++). Atributos: itens por mês, preço médio (em escala log) e regularidade | Grupos como *Carros-chefe*, *Alto giro*, *Alto valor, baixo giro* e *Baixo giro*. Quando o número de grupos não é informado, ele é escolhido pela maior **silhueta** |

A previsão precisa de pelo menos 3 meses completos de vendas. Com menos que isso, a API responde 404 e explica o motivo.

## Estrutura do repositório

```
projeto-integrador-iv/
├── README.md                 # este arquivo
├── LICENSE                   # MIT
└── src/
    ├── README.md             # visão geral técnica do monorepo
    ├── backend/
    │   ├── UnivespProject.slnx
    │   ├── compose.yaml      # PostgreSQL 17 local (container univesp-postgres)
    │   ├── samples/          # planilhas de exemplo (válidas e com erros) e o script que as gera
    │   ├── postman/          # coleção (142 requisições, 269 verificações) e ambiente
    │   ├── src/
    │   │   ├── UnivespProject.Domain/          # entidades e regras de negócio
    │   │   ├── UnivespProject.Application/     # serviços (casos de uso), DTOs, interfaces
    │   │   ├── UnivespProject.Infrastructure/  # EF Core, segurança, planilhas, ML.NET
    │   │   └── UnivespProject.Api/             # Minimal APIs, autenticação, erros
    │   └── tests/UnivespProject.Tests/         # xUnit
    └── frontend/
        ├── pubspec.yaml
        ├── lib/              # app/, core/, shared/, features/
        ├── test/             # espelha lib/
        ├── android/
        └── web/
```

## Requisitos

| Ferramenta | Uso |
|---|---|
| [.NET SDK 10](https://dotnet.microsoft.com/download) | Backend |
| [Podman](https://podman.io/) ou [Docker](https://www.docker.com/) (com `compose`) | Banco PostgreSQL |
| [Flutter](https://flutter.dev/) (Dart ^3.13) | Frontend |
| Chrome | Rodar o app Web |
| Android SDK + emulador (opcional) | Rodar o app Android. Para `flutter build apk` é preciso um JDK completo |
| OpenSSL | Gerar a chave do JWT |

## Como executar

### 1. Banco e API

```bash
cd src/backend

podman compose up -d                     # ou: docker compose up -d

# Só na primeira vez em cada máquina:
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)" --project src/UnivespProject.Api
dotnet dev-certs https --trust           # confia no certificado HTTPS de desenvolvimento

dotnet run --project src/UnivespProject.Api   # https://localhost:7077
```

A API não inicia sem a chave do JWT nem sem o banco. Se ela falhar com `Connection refused` na porta 5432, ligue o container com `podman start univesp-postgres`. Em desenvolvimento, o documento OpenAPI fica em `https://localhost:7077/openapi/v1.json`.

### 2. App

Com a API rodando:

```bash
cd src/frontend
flutter pub get

flutter run -d chrome        # Web (usa https://localhost:7077)
flutter run                  # Android/emulador (usa https://10.0.2.2:7077)

# Outra URL de API:
flutter run --dart-define=API_BASE_URL=https://192.168.0.10:7077
```

Na primeira vez, crie uma conta pela tela de login (**Criar conta**) e informe um nome de loja novo: você será o admin dela.

> **Certificado HTTPS**: na Web, quem valida o certificado é o navegador. Por isso é preciso rodar `dotnet dev-certs https --trust` (no Linux, às vezes também reabrir o navegador). No emulador Android, as builds *debug* aceitam o certificado de desenvolvimento só para `localhost`/`10.0.2.2`.

## Testes

```bash
# Backend (xUnit)
cd src/backend && dotnet test

# Frontend
cd src/frontend && flutter analyze && flutter test
```

Para testar só a API, sem o app, importe no Postman os dois arquivos de [`src/backend/postman`](src/backend/postman) e rode a coleção com o ambiente **Univesp - Local**. Cada execução cria um usuário e uma loja próprios, então não mexe nos dados da sua loja. O passo a passo, inclusive pelo Postman CLI, está no [README do backend](src/backend/README.md#testando-no-postman).

## Dados de exemplo

A pasta [`src/backend/samples`](src/backend/samples) tem planilhas prontas para importar pelo app:

| Arquivo | Conteúdo |
|---|---|
| `vendas-exemplo.xlsx` | 112 vendas variadas |
| `vendas-com-erros.xlsx` | Planilha com erros, para ver a validação por linha |
| `vendas-tecnologia.xlsx` | 151 vendas de tecnologia em setembro/2026 |
| `vendas-tecnologia-2025-01.xlsx`, `-2025-07`, `-2026-01`, `-2026-09` | Meses diferentes, para o **comparativo** e para a **previsão** (que precisa de 3 meses ou mais) |
| `vendas-produtos-novos.xlsx` | SKU novo, para testar o cadastro de produtos pela importação |
| `gerar_vendas_tecnologia.py` | Script (openpyxl) que gera as planilhas `vendas-tecnologia-AAAA-MM.xlsx` |

Atenção: `vendas-tecnologia.xlsx` e `vendas-tecnologia-2026-09.xlsx` são do mesmo mês. Se você importar os dois, setembro/2026 fica com as vendas em dobro.

## Convenções do projeto

- Textos para o usuário e documentação em português. Código, nomes e comentários em inglês.
- Interfaces sempre que possível e classes base abstratas para o comportamento comum (`BaseEntity`, `BaseService`, `BaseState`).
- Os erros seguem um único formato do backend até a tela. Veja "Formato de erro da API" no [README do backend](src/backend/README.md#formato-de-erro-da-api) e "Tratamento de erros" no [README do frontend](src/frontend/README.md#tratamento-de-erros).
- Telas que funcionam nos dois temas (escuro e claro) e em celular de 360 px.

## Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE).
