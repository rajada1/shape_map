## 0.6.0

* `ShapeMaps.world` passa a usar Mercator (recorte -60..84°, viewBox 1200×790) para que os países mantenham a forma familiar durante o zoom.
* As camadas de `ShapeMaps.loadCountryFocus(iso)` são geradas no mesmo quadro do mundo, com detalhe relativo ao tamanho do país e tratamento do antimeridiano. Novo `ShapeMaps.loadWorldWithCountry(iso)`, `ShapeMaps.worldWithCountryIfLoaded(iso)` e `MapDefinition.withDetail(...)` para compor a camada sobre o mundo.
* `ShapeMap` mantém a câmera ao trocar `map` entre definições com o mesmo viewBox; só reinicia quando o viewBox muda.
* `ShapeMapCameraController` ganha `viewBoxPointAt`, `visibleViewBox` e `viewportSize`.
* `MapDefinition.mercatorLatitudes` e `primaryFocusBounds` com peso de área corrigido para Mercator, clustering relativo ao país e recorte do antimeridiano.
* Novo `GeoCatalog` (asset `assets/catalog/geo_names.json`) com nomes en/pt/es de países e subdivisões, incluindo Guiana Francesa.
* Pipeline: regiões que colapsam em área zero na quantização recebem um footprint 2×2 visível e clicável.

## 0.5.1

* Adiciona `MapDefinition.contentBounds`, união memoizada da geometria das regiões.
* Adiciona `ShapeMapCameraController.zoomToBounds` e insets assimétricos em `zoomToRegion`, permitindo enquadrar conteúdo em áreas visíveis sob overlays.
* Ajusta o clamp de pan para respeitar a área visível durante enquadramentos com insets, sem alterar o comportamento existente quando não há insets.

## 0.5.0

* Adiciona `ShapeMaps.southAmericaFocus(String)` e `ShapeMaps.preloadFocus(String)` para os 12 países sul-americanos, com estados/províncias admin-1 e vizinhos em contexto no mesmo viewBox de `southAmerica`.
* Expõe `MapDefinition.focusBounds` para enquadrar o país inteiro, além de `ShapeMapId` para preload individual. Os mapas não contêm cidades nem municípios.
* Adiciona `MarkerDiameterUnit.screenPixels`, `MarkerShadow` e `MapMarkerData.diameterUnit`; o diâmetro e a borda em pixels permanecem constantes durante zoom e a sombra é pintada antes do marcador.
* Amplia o pipeline Natural Earth 10m admin-1, IDs ISO 3166-2, contagens esperadas, âncoras internas e relatório de topologia.

## 0.4.0

* Adiciona zoom, pan e seleção controlados por `ShapeMapCameraController`, com gestos opcionais e zoom por região.
* Novos parâmetros em `ShapeMap`: `cameraController`, `zoomEnabled` (padrão `false`, sem mudança para quem já usa o package), `minScale`, `maxScale`, `cameraAnimationDuration`, `cameraAnimationCurve` e `onRegionSelected` (`ShapeMapSelectionCallback`). Novos campos em `ShapeMapStyle`: `selectedBorderColor`, `selectedBorderWidth` e `selectedOpacity`.
* Melhora o caminho de mapas grandes: grade espacial 8×8 com culling de fills e bordas durante zoom/pan, crossfade por tile e bucket de escala para evitar regravações desnecessárias de bordas; marcadores fora da viewport são ignorados.
* Documenta `warmUp()` como preparação recomendada para o índice de hit-test de mapas grandes.

## 0.3.0

Breaking: a geometria passa a vir de dados geográficos reais em vez dos SVGs de referência de design.

* Substitui as referências SVG por geometrias Natural Earth 50m (países, domínio público) e IBGE (UFs), projetadas, simplificadas topologicamente (tolerância de 0,6 unidade do viewBox) e quantizadas (grade de 0,25). Os SVGs foram movidos para `design/` apenas como referência.
* Adiciona `ShapeMaps.world`, `ShapeMaps.latinAmerica` e `ShapeMaps.southAmerica`; `ShapeMaps.southAmericaCountries` passa a ser alias deprecated.
* Adiciona o formato binário SMAP v2 (varints, deltas zigzag, bordas compartilhadas encadeadas), `ShapeMapData.decodeSync`/`decode` (parsing em isolate) e geometria com `Path` lazy sobre buffers tipados planos.
* Adiciona `ShapeMaps.preload` e `ShapeMapId` (decodificação assíncrona dos mapas embutidos) e `MapDefinition.warmUp` (materializa paths e hit-test em fatias cooperativas).
* Adiciona índice espacial 64×64 para hit-test (`MapDefinition.hitTest`).
* Mapas com mais de 1.000 regiões: transformação única de canvas, fill e borda em `ui.Picture` no viewBox (custo de pintura independente do número de cores), crossfade de dados entre Pictures, entrada `fade` em lote e `stagger` em até 48 bandas agrupadas por banda e cor; `grow` e `draw` caem para `fade`.
* Malha opcional dos 5.570 municípios brasileiros (`BR-<código IBGE>`), fora do core, distribuída como asset do app de exemplo e carregada sob demanda.
* Pipeline offline determinístico (`dart run tool/generate_maps.dart`) com mapshaper e polylabel pinados (somente em tempo de build), fontes com SHA-256 em `tool/maps/sources.json` e atribuição em `ATTRIBUTION.md`.
* Correções: orientação vertical cartográfica, polylines de borda com 2 pontos, largura da borda em mapas grandes e invalidação da borda no resize de mapas pequenos.

## 0.2.0

* Adiciona animação de entrada configurável para regiões e marcadores (`fade`, `grow`, `stagger` e `draw`), com controller interno ou externo.
* `draw` traça o contorno com `drawColor`/`drawWidth` configuráveis e faz a transição para a borda final.
* Adiciona controles de reprodução, reversão, pausa, reset, replay, duração, estilo e ordem ao app de exemplo.

## 0.1.1

* Separa animações de dados, marcadores e highlight, preservando o estado interpolado ao interromper uma transição.
* Evita rebuild da árvore do mapa em hover/seleção; somente o tooltip é reconstruído.
* Adiciona `MapDefinition.regionById`/`indexOf`, igualdade por conteúdo nos modelos e igualdade nos estilos.
* Adiciona `MapMarkerData.showLabel` e suporte a marcador sem texto; `MapRegionData.label` passa a ser usado no tooltip.
* Faz cache de bordas em `ui.Picture`, caminhos transformados e layouts de texto dos marcadores.
* Corrige seleção fora das regiões, posição de tooltip com override de marcador e largura de borda sem hacks por mapa.
* Atualiza o exemplo para reproduzir os dois SVGs de referência e adiciona regressões e goldens.

## 0.1.0

* Adiciona mapas embutidos da América do Sul e das 27 UFs brasileiras.
* Adiciona widget interativo com cores por região, hit-test, seleção, hover e tooltip.
* Adiciona marcadores com escala linear, overrides e animações nativas.
* Adiciona gerador offline determinístico e testes de parser, geometria, layout e widgets.
