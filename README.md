# shape_map

`shape_map` é um package Flutter nativo para renderizar mapas vetoriais interativos e animados. A versão inicial inclui os layouts de referência da América do Sul e dos estados brasileiros, com geometria Dart pré-gerada offline.

## Recursos

- 13 países da América do Sul (`BR`, `AR`, `CL`, `PE` etc.) e as 27 UFs (`BR-XX`, incluindo `BR-DF`).
- Cores por região, seleção, hover, marcadores dimensionados por valor e tooltips.
- Hit-test com transformação inversa e `ShapeMapController` baseado em `ChangeNotifier`.
- Animações nativas independentes para cores de regiões, diâmetros dos marcadores e highlight de seleção/hover.
- Cache de `Path`, bordas em `ui.Picture` e layouts de texto dos marcadores fora do caminho de pintura.
- Nenhuma dependência de runtime além do Flutter.

## Uso básico

```dart
import 'package:shape_map/shape_map.dart';

ShapeMap(
  map: ShapeMaps.southAmericaCountries,
  data: const {
    'BR': MapRegionData(value: 620, label: 'Brasil'),
    'AR': MapRegionData(value: 240),
  },
  markers: const [
    MapMarkerData(regionId: 'BR', value: 620, label: '620'),
  ],
  onRegionTap: (region) => print(region.id),
)
```

`MapMarkerData(showLabel: false)` cria um marcador sem texto; um `label: ''` também não pinta texto. Use `position` para sobrescrever a posição visual de um badge sem alterar a âncora interna da região. `MarkerStyle.borderWidth` é a única fonte da largura da borda do marcador.

## Animação de entrada

Use `ShapeMapEntrance` para animar o surgimento das regiões e dos marcadores. Para controlar o progresso externamente, passe um `AnimationController`; o package apenas observa esse controller:

```dart
class MapState extends State<MyMap> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  Widget build(BuildContext context) => ShapeMap(
    map: ShapeMaps.southAmericaCountries,
    entrance: const ShapeMapEntrance(
      style: ShapeMapEntranceStyle.stagger,
      staggerOrder: ShapeMapStaggerOrder.topToBottom,
    ),
    entranceAnimation: controller,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

Os estilos disponíveis são `fade`, `grow`, `stagger` e `draw`. No `draw`, o contorno é traçado progressivamente (cor `ShapeMapEntrance.drawColor`, padrão a cor dos marcadores, e largura `drawWidth`) e depois se dissolve no preenchimento e na borda final. Sem `entrance`, o mapa mantém o comportamento tradicional. Durante a entrada, o hit-test, o destaque e o tooltip são habilitados somente quando o progresso chega a 100%.

`ShapeMaps.brazilStates` usa ids como `BR-SP` e `BR-BA`. Consulte `MapDefinition.regions`, `regionById(id)` e `indexOf(id)` para obter regiões e índices memoizados. `MapRegionData.label` substitui o nome no tooltip quando não está vazio. `Duration.zero` desliga todas as transições. Os valores e listas dos modelos são comparados por conteúdo, permitindo reconstruir o pai sem reiniciar animações desnecessariamente.

## Desenvolvimento

A geometria é gerada a partir dos SVGs de referência sem parsing em runtime:

```sh
dart run tool/generate_maps.dart
dart format .
dart analyze
cd example && flutter analyze
cd .. && flutter test
```

O app em `example/` reproduz os dois layouts (`mapa_view_1.svg` e `mapa_view_2.svg`), incluindo posições e diâmetros dos badges, seleção inicial da Bahia, tooltips e randomização animada de cores e diâmetros.
