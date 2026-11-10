# shape_map

`shape_map` é um package Flutter nativo para renderizar mapas vetoriais interativos e animados. A geometria vem de dados geográficos públicos compilados offline no formato binário SMAP v2, sem dependências de runtime além do Flutter.

## Mapas incluídos

| Mapa | Regiões | IDs |
|---|---|---|
| `ShapeMaps.world` | 234 países e territórios (Natural Earth 50m, sem Antártida) | ISO 3166-1 alpha-2 (`BR`, `US`, `FR`…) |
| `ShapeMaps.latinAmerica` | 33 países soberanos da América Latina e Caribe + `GF` | ISO alpha-2 |
| `ShapeMaps.southAmerica` | `AR BO BR CL CO EC GF GY PE PY SR UY VE` | ISO alpha-2 |
| `ShapeMaps.brazilStates` | 27 UFs (IBGE), incluindo `BR-DF` | `BR-XX` |
| `ShapeMaps.southAmericaFocus(iso)` | Admin-1 do país selecionado + os demais países como contexto, no viewBox continental | ISO 3166-2 no país selecionado e ISO alpha-2 no contexto |
| `ShapeMaps.loadCountryFocus(iso)` | Admin-1 country-only sob demanda para países com foco no catálogo | `<ISO>-...` |

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

### Focos por país

O pacote distribui sob demanda um asset SMAP country-only para cada país com admin-1 confiável no Natural Earth 10m. `ShapeMaps.focusCountries` é o conjunto canônico gerado pelo pipeline, e `ShapeMaps.hasFocus(iso)` verifica a disponibilidade sem decodificar geometria.

```dart
if (ShapeMaps.hasFocus(countryIso)) {
  final map = await ShapeMaps.loadCountryFocus(countryIso);
  await map.warmUp();
  camera.zoomToBounds(map.focusBounds!);
}

// Pré-carrega em isolate e reutiliza a mesma instância em chamadas futuras.
await ShapeMaps.preloadCountryFocus('JP');
```

`loadCountryFocus` normaliza o ISO alpha-2, carrega `assets/maps/country_focus/<ISO>.smap`, decodifica em isolate e mantém cache por país. O mapa retornado contém somente regiões com prefixo `<ISO>-`; um país sem foco lança `ArgumentError` claro. `focusBounds` sempre é calculado a partir dessas regiões.

O catálogo canônico gerado está em `catalog/geo_catalog.json`. Ele contém países, subdivisões, nomes em inglês/português/espanhol, tipo, códigos de origem e aliases para integração com GeoNames. `source_codes` preserva os valores brutos; `aliases` contém somente formas canônicas não ambíguas, e o relatório registra colisões que não podem ser usadas para resolução automática. `code` é único no catálogo e em cada mapa de foco. Quando a fonte fornece o mesmo ISO 3166-2 para feições diferentes, o pipeline preserva cada geometria e usa um sufixo curto de código de origem quando ele é único; caso contrário, usa os três primeiros dígitos base36 de um hash SHA-256 de país, código base e identificador estável da fonte. O código antigo não vira alias quando é ambíguo. Feições multipartes reais permanecem uma única região porque já chegam como uma geometria `MultiPolygon`.

### Mapas de foco

`ShapeMaps.southAmericaFocus('BR')` (ou qualquer um dos 12 países `AR BO BR CL CO EC GY PE PY SR UY VE`) mantém exatamente o viewBox e a projeção de `ShapeMaps.southAmerica`. O país selecionado é dividido em estados, províncias, departamentos ou distritos admin-1; os vizinhos continuam visíveis como regiões de contexto com IDs ISO alpha-2. O package não inclui cidades nem municípios nesses mapas.

O campo `MapDefinition.focusBounds` reúne as subdivisões do país selecionado para enquadramento, enquanto `MapDefinition.contentBounds` reúne a geometria visível de todas as regiões. Use `ShapeMapCameraController.zoomToBounds` quando overlays ocuparem parte do viewport. O parâmetro `insets` é aplicado à área disponível antes do `padding` simétrico:

```dart
final map = ShapeMaps.southAmericaFocus('AR');
final camera = ShapeMapCameraController();
final data = {
  for (final region in map.regions)
    region.id: MapRegionData(
      fill: region.id.startsWith('AR-')
          ? const Color(0xFFFFDBC9)
          : const Color(0xFFE2E9ED),
    ),
};
ShapeMap(map: map, cameraController: camera, data: data);

// Enquadra o país inteiro acima de um painel inferior.
camera.zoomToBounds(
  map.focusBounds!,
  insets: const EdgeInsets.only(top: 72, bottom: 280),
  padding: 16,
);
// Para focar uma província: camera.zoomToRegion('AR-B');
```

`zoomToRegion` mantém o `padding` simétrico anterior e também aceita `insets`.

### Marcadores em pixels

`MarkerScale` e `MapMarkerData` usam viewBox por padrão, preservando o comportamento anterior. Para um diâmetro constante em pixels de tela durante zoom da câmera, use `MarkerDiameterUnit.screenPixels`; `MarkerStyle.shadow` pinta uma sombra antes do círculo:

```dart
const style = MarkerStyle(
  scale: MarkerScale(
    minDiameter: 32,
    maxDiameter: 64,
    unit: MarkerDiameterUnit.screenPixels,
  ),
  shadow: MarkerShadow(
    color: Color(0x24000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
);
ShapeMap(
  map: ShapeMaps.southAmerica,
  style: style,
  markers: const [MapMarkerData(regionId: 'BR', value: 9800)],
);
```

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
- Países: [Natural Earth](https://www.naturalearthdata.com/) 10m admin-1 states/provinces, domínio público, usado nos focos country-only e nos mapas de foco sul-americanos. Não há cidades ou municípios nesses mapas.
- Catálogo canônico: `catalog/geo_catalog.json`, gerado no mesmo passo que os assets e contendo os aliases de origem/GeoNames.
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
