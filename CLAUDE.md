# CLAUDE.md — Receitas MKT

> Este arquivo orienta o Claude Code a entender o projeto, suas convenções e regras antes de qualquer intervenção no código.

---

## Visão Geral do Projeto

Aplicativo Flutter multiplataforma (**Android + Windows**) para gerenciamento de fluxo de caixa fixo do setor de marketing. Permite registrar entradas e saídas, fotografar notas fiscais, exportar relatórios em PDF e sincronizar os dados com uma planilha do Google Sheets via Service Account.

---

## Stack e Dependências Principais

| Pacote                | Papel                                              |
|-----------------------|----------------------------------------------------|
| `flutter_riverpod`    | Gerência de estado (MVVM)                          |
| `sqflite`             | Banco de dados local (SQLite) — fonte da verdade   |
| `path_provider`       | Caminhos de sistema de arquivos                    |
| `pdf` + `printing`    | Geração e compartilhamento de relatório PDF        |
| `image_picker`        | Captura/seleção de fotos de NF                     |
| `shared_preferences`  | Preferências globais (link da planilha, saldo, tema)|
| `gsheets`             | Integração com a API do Google Sheets              |
| `connectivity_plus`   | Checagem de rede antes do sync                     |
| `uuid`                | Geração de IDs únicos para `CashLog`               |
| `intl`                | Formatação de moeda (BRL) e datas                  |

---

## Arquitetura — MVVM + Riverpod

```
lib/
├── ui/            → Telas e widgets reutilizáveis
│   ├── home_view.dart
│   ├── form_view.dart
│   ├── logs_view.dart
│   └── widgets/
├── logic/         → Notifiers, Providers, Controllers
│   ├── cash_logic_provider.dart
│   └── sync_controller.dart
└── data/          → Modelos, SQLite, Sheets service
    ├── cash_log_model.dart
    ├── local_database.dart
    └── sheets_service.dart
```

### Regra de Dependência (NUNCA violar)
```
ui  →  logic  →  data
```
- `ui/` importa apenas arquivos de `logic/` e, excepcionalmente, os **Models** de `data/`.
- `ui/` **nunca** importa `local_database.dart` ou `sheets_service.dart` diretamente.
- `logic/` não importa nada de `ui/`.

---

## Modelo Central — `CashLog`

```dart
enum CashType { ingress, egress }

class CashLog {
  final String       id;           // UUID v4
  final CashType     type;         // ingress = receita | egress = gasto
  final String?      photoPath;    // Caminho local da foto da NF (nullable)
  final double       amount;       // Valor em BRL
  final List<String> products;     // Produtos envolvidos (pode ser vazia)
  final String       employeeName; // Funcionário responsável
  final DateTime     date;         // Timestamp do registro
  final bool         isSynced;     // false = pendente de sync com Sheets
}
```

---

## Regras de Negócio Críticas

### Saldo
```
saldo_atual = initial_balance + Σ(ingressos) − Σ(egresos)
```
- Calculado **exclusivamente** no `cash_logic_provider.dart`.
- Recalculado a cada mutação da lista de logs.

### Fluxo de Escrita (Offline-First)
```
1. Salva no SQLite com isSynced: false
2. Tenta enviar para Google Sheets
   ├── Sucesso → atualiza isSynced: true no SQLite
   └── Falha   → mantém isSynced: false (entra na fila)
```

### Sync Queue
- `syncPendingLogs()` em `sync_controller.dart` busca todos os registros com `isSynced == false`.
- Chamada no `initState` da `HomeView` e por botão manual.
- **Sempre** verificar conectividade com `connectivity_plus` antes de tentar o sync.

---

## Configurações Globais

### `shared_preferences` — apenas preferências locais de UI
| Chave               | Tipo    | Descrição                                    |
|---------------------|---------|----------------------------------------------|
| `sheets_link`       | String  | URL completa da planilha Google Sheets        |
| `theme_mode`        | String  | `"light"` ou `"dark"`                        |

### SQLite — cache offline
| Chave                    | Tipo   | Descrição                                                    |
|--------------------------|--------|--------------------------------------------------------------|
| `cached_initial_balance` | double | Último `saldo_inicial` lido do Sheets; fallback sem internet |

> ⚠️ **Fonte da verdade do `saldo_inicial`: Google Sheets** (aba `Config`, célula `B1`).
> O SQLite guarda apenas o cache para funcionamento offline. Nunca inverter essa hierarquia.

### Fluxo de leitura do saldo inicial
```
App inicia
     ↓
Há conectividade?
     ├── Sim → lê Config!B1 no Sheets → atualiza cache no SQLite
     └── Não → usa cached_initial_balance do SQLite
```

### Edição do saldo inicial (dialog na HomeView)
```
Usuário confirma novo valor
     ↓
Salva em Config!B1 no Sheets
     ↓
Atualiza cache no SQLite
```

---

## Convenções de Código

### Nomenclatura
- Arquivos: `snake_case.dart`
- Classes: `PascalCase`
- Variáveis e métodos: `camelCase`
- Constantes: `kCamelCase` (ex: `kDbName`, `kSheetName`)
- Providers Riverpod: sufixo `Provider` (ex: `cashLogicProvider`, `themeProvider`)

### Qualidade
- **Proibido** `print()` em produção → use `debugPrint()`.
- Todo método `async` deve ter `try/catch` e **expor o erro via estado do Riverpod** (jamais silenciar falhas).
- Widgets com mais de ~80 linhas devem ser decompostos em subwidgets no diretório `widgets/`.
- **Zero** lógica de negócio dentro de métodos `build()`.
- Todos os widgets devem suportar **tema claro e escuro**.

### Tratamento de Erros
- Estados de erro devem ser tipados (ex: `AsyncError`, `AppException`).
- A UI deve exibir feedback visual para erros (SnackBar, dialog) — nunca engolir silenciosamente.

---

## Google Sheets — Contrato de Integração

### Aba `Config` — metadados da planilha
| Célula | Campo           | Descrição                              |
|--------|-----------------|----------------------------------------|
| A1     | Label           | Texto fixo: `"saldo_inicial"`          |
| B1     | `saldo_inicial` | **Fonte da verdade** do saldo inicial  |

### Aba `Logs` — registros de caixa (colunas fixas)
| Coluna | Campo         |
|--------|---------------|
| A      | id            |
| B      | type          |
| C      | amount        |
| D      | employeeName  |
| E      | date          |
| F      | products      |
| G      | photoPath     |

### Credenciais
- Autenticação via **Service Account JSON** fornecida pelo usuário nas configurações.
- Nunca commitar credenciais no repositório.
- Armazenar o JSON de credenciais em caminho seguro retornado por `path_provider`.

---

## Estrutura da HomeView

```
┌─────────────────────────────────────┐
│ [Saldo Atual ▼]        [☀/🌙 tema] │  ← AppBar / Header
├─────────────────────────────────────┤
│                                     │
│        [ + Novo Registro ]          │
│        [ 📋 Gerenciar Logs ]        │  ← Centro
│        [ 📄 Exportar PDF  ]         │
│                                     │
├─────────────────────────────────────┤
│  v1.0.0  •  3 registros pendentes  │  ← Rodapé (status sync)
└──────────────────────── [⚙️ FAB] ──┘
```

---

## Ordem de Implementação Recomendada

Ao criar ou refatorar arquivos, seguir esta sequência:

1. `pubspec.yaml`
2. `data/cash_log_model.dart`
3. `data/local_database.dart`
4. `data/sheets_service.dart`
5. `logic/cash_logic_provider.dart`
6. `logic/sync_controller.dart`
7. `ui/home_view.dart`
8. `ui/form_view.dart`
9. `ui/logs_view.dart`
10. `ui/widgets/` (componentes extraídos)

---

## O que NÃO Fazer

- ❌ Não armazenar `saldo_inicial` como fonte primária em `shared_preferences` ou SQLite — a fonte da verdade é sempre o Sheets (`Config!B1`); o restante é cache.
- ❌ Não colocar lógica de cálculo de saldo em qualquer arquivo de `ui/`.
- ❌ Não fazer chamadas ao SQLite ou Sheets dentro de widgets.
- ❌ Não armazenar imagens no Google Sheets (apenas o `photoPath` local).
- ❌ Não bloquear a UI durante operações de sync — use `async`/`await` com indicadores de loading.
- ❌ Não criar dependências circulares entre camadas.
- ❌ Não hardcodar o `spreadsheetId` — sempre extrair do link configurado.
- ❌ Não commitar arquivos de credenciais GCP no repositório.

---

## Checklist antes de qualquer PR / commit

- [ ] `saldo_inicial` lido do Sheets na inicialização (não de shared_preferences)
- [ ] Cache do saldo inicial atualizado no SQLite após leitura/edição
- [ ] Nenhuma regra de negócio em `ui/`
- [ ] Todos os `async` têm `try/catch`
- [ ] Erros expostos via estado Riverpod, não silenciados
- [ ] Widgets decompostos (< 80 linhas)
- [ ] Suporte a tema claro e escuro verificado
- [ ] Nenhum `print()` em código de produção
- [ ] `isSynced` gerenciado corretamente no fluxo CRUD