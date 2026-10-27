# shape_map

`shape_map` é um package Flutter nativo para renderizar mapas vetoriais interativos e animados. A geometria vem de dados geográficos públicos compilados offline no formato binário SMAP v2, sem dependências de runtime além do Flutter.

## Mapas incluídos

| Mapa | Regiões | IDs |
|---|---|---|
| `ShapeMaps.world` | 234 países e territórios (Natural Earth 50m, sem Antártida) | ISO 3166-1 alpha-2 (`BR`, `US`, `FR`…) |
| `ShapeMaps.latinAmerica` | 33 países soberanos da América Latina e Caribe + `GF` | ISO alpha-2 |
| `ShapeMaps.southAmerica` | `AR BO BR CL CO EC GF GY PE PY SR UY VE` | ISO alpha-2 |
| `ShapeMaps.brazilStates` | 27 UFs (IBGE), incluindo `BR-DF` | `BR-XX` |

Opcional, fora do core: os 5.570 municípios brasileiros (IBGE), IDs `BR-<código IBGE de 7 dígitos>` (ex.: `BR-3550308` = São Paulo). Veja [Municípios brasileiros](#municípios-brasileiros-opcionais).

Cada região tem ID estável, nome em português e âncora de marcador calculada por polylabel (ponto mais interno do maior polígono). A geometria é simplificada topologicamente (tolerância de 0,6 unidade do viewBox, sem gaps entre vizinhos) e quantizada numa grade de 0,25 unidade.

## Uso

```dart
import 'package:shape_map/shape_map.dart';

ShapeMap(
  map: ShapeMaps.southAmerica,
  data: const {
    'BR': MapRegionData(value: 9800, label: 'Brasil'),
    'AR': MapRegionData(value: 820),
  },
  markers: const [MapMarkerData(regionId: 'BR', value: 9800)],
  onRegionTap: (region) => print(region.id),
)
```

Os marcadores usam `MapRegion.markerAnchor` por padrão; `MapMarkerData.position` serve para layouts customizados. `MapMarkerData(showLabel: false)` cria um marcador sem texto. `ShapeMaps.southAmericaCountries` continua disponível como alias deprecated de `southAmerica`.

## Preload e primeiro frame

Os getters de `ShapeMaps` são síncronos e decodificam o mapa no primeiro acesso. Para não fazer esse trabalho durante o primeiro build, prepare os mapas antes:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShapeMaps.preload(); // ou preload([ShapeMapId.brazilStates])
  runApp(const App());
}
```

`preload` decodifica em isolates; depois dele os getters retornam a mesma instância já pronta. Para mapas carregados sob demanda com `ShapeMapData.decode`, chame `await map.warmUp()` enquanto a tela de loading é exibida: ele materializa paths, bordas e o índice de hit-test em fatias cooperativas.

## Animação de entrada

`ShapeMapEntrance` oferece `fade`, `grow`, `stagger` e `draw`, com controller interno (toca ao montar) ou externo (`entranceAnimation`, você controla play/reverse/scrub). Durante a entrada, hit-test, destaque e tooltip ficam desabilitados até 100%. Com animações desabilitadas no sistema, o mapa aparece completo.

## Mapas grandes (mais de 1.000 regiões)

- Pintura com uma transformação de canvas por camada; preenchimento e borda são particionados em uma grade espacial 8×8 de Pictures no espaço do viewBox. Cada frame de zoom/pan desenha somente os tiles que intersectam o retângulo visível, em vez de reprocessar o mapa inteiro.
- Mudar `data` reconstrói os batches e Pictures uma vez, em O(regiões), no frame da mudança, seguido de um crossfade barato por tile. Prefira mudanças discretas, não uma atualização por frame.
- A largura da borda usa buckets geométricos de escala (passos de 2^(1/4)); escalas próximas não regravam as Pictures, enquanto cruzar um bucket regrava apenas as bordas.
- Entrada: `grow` e `draw` caem para `fade`; `stagger` usa até 48 bandas, agrupadas por banda e cor.
- Use `borderWidth` menor (ex.: `0.5`) para não cobrir regiões pequenas.

## Municípios brasileiros opcionais

A malha municipal não faz parte de `lib/`, para manter o package leve. O app de exemplo distribui `example/assets/maps/brazil_municipalities.smap` (5.570 regiões, 94.740 vértices, ~660 KB) e carrega sob demanda:

```dart
final bytes = await rootBundle.load('assets/maps/brazil_municipalities.smap');
final map = await ShapeMapData.decode(bytes, id: 'brazilMunicipalities');
await map.warmUp();
```

Usa a mesma projeção e viewBox de `ShapeMaps.brazilStates`, então as âncoras municipais caem dentro das UFs correspondentes.

## Decodificação customizada

`ShapeMapData.decodeSync(Uint8List)` ou `await ShapeMapData.decode(ByteData)` carregam qualquer arquivo SMAP v2 (parsing em isolate no método assíncrono, `Path` lazy). O formato está em [tool/FORMAT.md](tool/FORMAT.md).

## Fontes, licenças e geração

- Países: [Natural Earth](https://www.naturalearthdata.com/) 50m admin-0, domínio público.
- Brasil (UFs e municípios): malhas territoriais do [IBGE](https://servicodados.ibge.gov.br/api/docs/malhas?versao=3).

URLs, hashes SHA-256 e qualidade ficam em `tool/maps/sources.json`; a atribuição completa está em [ATTRIBUTION.md](ATTRIBUTION.md). `mapshaper` e `polylabel` são dependências apenas de build, em `tool/`, e não vão para o app.

```sh
dart run tool/generate_maps.dart   # baixa (com cache), valida hashes e gera os mapas
dart format .
dart analyze
flutter test
python3 tool/verify_goldens.py
```

O gerador é determinístico: projeta, inverte o eixo Y para coordenadas de tela, simplifica preservando a topologia, quantiza e falha se contagens, IDs, anéis ou orçamentos de vértices forem inválidos.

## Escala mundial

Todos os países simplificados cabem no core (o mapa mundial tem ~48 KB e só é decodificado quando usado). Municípios e cidades do mundo inteiro não devem ir embutidos no package: o tamanho e o número de paths pesam no download, na memória e no primeiro frame. Para outros países, gere datasets regionais com o mesmo pipeline e carregue sob demanda com `ShapeMapData.decode`.

## Zoom, pan e seleção

O zoom e os gestos são opt-in com `zoomEnabled: true`; o comportamento padrão não captura gestos de rolagem de pais. Use `ShapeMapCameraController` para `zoomTo`, `zoomBy`, `panBy`, `zoomToRegion` e `resetZoom`, inclusive quando os gestos estão desabilitados. `minScale` e `maxScale` limitam a ampliação; a câmera preserva o ponto focal em pinch, roda do mouse e duplo toque. O duplo toque faz o toque simples aguardar o timeout padrão do Flutter.

Uma região selecionada por vez é destacada sem zoom automático. `onRegionSelected` acompanha também mudanças feitas por `ShapeMapController`. `ShapeMapStyle.selectedBorderColor`, `selectedBorderWidth` e `selectedOpacity` personalizam o destaque. Em mapas grandes a borda é regravada após o movimento para conservar sua espessura visual em pixels.
