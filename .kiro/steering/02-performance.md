# shape_map — Diretrizes de performance

Renderização de mapas é sensível a performance. Toda mudança que toque em layout, paint ou estado deve respeitar estas regras e, quando relevante, ser revisada pelo agente `performance-reviewer`.

## Orçamento de frame
- Alvo: 60fps → ~16ms por frame (120fps → ~8ms). Trabalho pesado não pode acontecer dentro do caminho de render.

## CustomPainter / CustomPaint
- **Sempre** implemente `shouldRepaint` de forma precisa. Nunca retorne `true` incondicionalmente.
- Faça cache de objetos `Path` dos polígonos; não reconstrua a geometria a cada `paint()`.
- Reutilize instâncias de `Paint` em vez de criar novas por frame.
- Isole camadas que repintam com frequência (ex.: hover/seleção) com `RepaintBoundary`, separando-as da geometria estática.
- Evite `canvas.save()/restore()` e clips desnecessários em loop.

## Dados geográficos
- Não faça parsing síncrono de GeoJSON/payloads grandes na thread de UI dentro de `build()`/`paint()`.
- Pré-compute e memoize: parse uma vez, transforme em `Path`/estruturas prontas para desenhar, e reutilize.
- Para payloads grandes, considere `compute()`/isolate.
- Simplifique a geometria (ex.: redução de vértices/Douglas–Peucker) por nível de zoom quando aplicável.

## Estado e rebuilds
- Notifique de forma granular. Prefira `ValueListenableBuilder`/`AnimatedBuilder` em subárvores pequenas em vez de `setState` que reconstrói a tela toda.
- Mantenha `const` em widgets sempre que possível.
- Evite recriar closures/listas/objetos pesados dentro de `build()`.

## Antipadrões a bloquear
- Trabalho de I/O, parsing ou alocação significativa dentro de `build()` ou `paint()`.
- `shouldRepaint` ausente ou sempre `true`.
- Reconstrução de `Path`/`Paint` por frame.
- Loops aninhados sobre todos os vértices no caminho de render sem cache.

## Verificação de performance
- Para mudanças relevantes, o performance-reviewer deve aprovar. Achados de severidade **alta** bloqueiam a conclusão até serem resolvidos.
- Quando possível, valide com DevTools (timeline/rebuild counts) e `flutter test`.
