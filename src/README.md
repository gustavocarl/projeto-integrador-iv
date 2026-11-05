# Univesp Project

Monorepo com o backend de análise de dados (C# / ASP.NET Core) e o frontend (Flutter). No app, a loja cadastra produtos (preço, custo — nunca maior que o preço, para não vender com prejuízo —, estoque e foto por link — obrigatória ou não, conforme as preferências de cada usuário), vende pelo caixa, importa planilhas Excel de vendas (loja física x virtual, por marketplace; se o usuário ligar nas preferências, os SKUs que ainda não existem viram produtos cadastrados) ou digita vendas, acompanha os resultados, compara meses (ex.: janeiro/2025 x janeiro/2026) e vê a **previsão de vendas dos próximos meses** e os **grupos de produtos** que vendem de forma parecida, feitos com aprendizado de máquina (ML.NET). Cada usuário escolhe o tema do app (escuro, o padrão, ou claro) nas preferências, onde também liga ou desliga o **aviso de reposição de estoque** (ligado por padrão: selo no menu Produtos e aviso depois da venda no caixa). Na tela de login dá para **criar conta** e **recuperar a senha** de forma simples (sem confirmação por e-mail; só para demonstração). Cada usuário pertence a uma **loja**: ao criar a conta, informa o nome da loja: se ela não existe, é criada (e a pessoa vira o admin); se já existe, vira um pedido de acesso e o admin recebe uma **notificação** no sino do app para aprovar; o **admin** aprova, remove, promove e escolhe quais partes do sistema cada usuário usa. Os dados de cada loja ficam separados. Tudo trafega em HTTPS.

| Projeto | Tecnologia | Documentação |
|---|---|---|
| `backend/` | .NET 10, EF Core, PostgreSQL, JWT, ClosedXML, ML.NET | [backend/README.md](backend/README.md) |
| `frontend/` | Flutter (Android + Web), Riverpod, Dio | [frontend/README.md](frontend/README.md) |

## Fluxo de dados

```
planilha .xlsx (app) ─► backend: lê e valida (ClosedXML) ─┐
caixa do app (produtos do cadastro) ─► baixa de estoque ────┼─► PostgreSQL (lotes de vendas) ─► /api/sales ─► app Flutter (gráficos: plataformas, evolução diária, produtos/curva ABC, lucro, comparativo de meses)
                                                                               └─► /api/analytics (ML.NET: previsão dos próximos meses, grupos de produtos) ─► app Flutter (menu Prever)
venda digitada no app ───────────────────────────────────────┘
```

## Início rápido

```bash
# Banco + backend (https://localhost:7077)
cd backend
podman compose up -d                     # ou: docker compose up -d
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)" --project src/UnivespProject.Api   # 1ª vez
dotnet dev-certs https --trust           # 1ª vez: confia no certificado HTTPS de desenvolvimento
dotnet run --project src/UnivespProject.Api

# Frontend
cd frontend
flutter run -d chrome          # Web (usa https://localhost:7077)
flutter run                    # Android/emulador (usa https://10.0.2.2:7077)
```

## Convenções gerais

- Erros seguem um único formato do backend até a tela — veja "Formato de erro da API" (backend) e "Tratamento de erros" (frontend).
- Interfaces sempre que possível; classes base abstratas para comportamento comum (`BaseEntity`, `BaseService`, `BaseState`).
- Mensagens para o usuário em português; código e nomes em inglês.
