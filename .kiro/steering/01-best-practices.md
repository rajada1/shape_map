# shape_map — Boas práticas de desenvolvimento

Este steering vale para todas as interações no package `shape_map`.

## Sobre o projeto
`shape_map` é um package Flutter de renderização de mapas. Escopo inicial: **mapa da América Latina**. A arquitetura deve permitir estender para outras regiões depois.

## Linguagem e estilo
- Dart/Flutter idiomático. Rode `dart format .` antes de finalizar.
- `dart analyze` deve passar **sem warnings nem erros** antes de considerar qualquer tarefa concluída.
- Respeite as regras de `analysis_options.yaml` (flutter_lints).
- Documente a API pública com dartdoc (`///`). Todo símbolo exportado precisa de doc.
- Nomes em inglês no código (API pública de um package pub.dev); comentários podem ser em português.

## Arquitetura
- Camadas sugeridas: `data` (modelo geográfico + parsing), `rendering` (painters), `state` (notifiers), `widgets` (API pública). Confirme com o architect.
- `lib/shape_map.dart` é o barrel file: exporta apenas a API pública estável. Detalhes internos ficam em `lib/src/`.
- Prefira composição e imutabilidade. Abstrações mínimas — não super-engenheirar.
- Mudanças de API pública são breaking changes: trate com cuidado e registre no CHANGELOG.

## Gerenciamento de estado
- Use elementos **nativos do Flutter**: `ChangeNotifier`, `ValueNotifier`, `Listenable`, `AnimatedBuilder`/`ValueListenableBuilder`, expostos via `InheritedNotifier`/`InheritedWidget`.
- **Não** adicione frameworks de estado externos (Provider, Riverpod, Bloc, GetX etc.) sem justificativa explícita e aprovação do usuário. Um package de UI deve minimizar dependências impostas ao consumidor.

## Dependências
- Minimize dependências. Todo package novo exige justificativa. Prefira versões fixas/pinadas e packages mantidos.
- Pacotes de parsing geográfico (ex.: GeoJSON) são candidatos legítimos — avalie com o architect.

## Testes
- Lógica (projeção, parsing, modelos) coberta por testes unitários (`package:flutter_test`/`test`).
- Widgets cobertos por widget tests (`WidgetTester`).
- Adicione testes ao corrigir bugs (teste de regressão).

## Verificação (definição de pronto)
1. `dart format .` aplicado.
2. `dart analyze` limpo.
3. `flutter test` passando.
4. Mudanças de rendering/estado revisadas pelo performance-reviewer.
