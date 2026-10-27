import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shape_map/shape_map.dart';

import 'layouts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Garante que nenhum getter decodifique um mapa durante o primeiro build.
  await ShapeMaps.preload();
  runApp(const ShapeMapExampleApp());
}

class ShapeMapExampleApp extends StatelessWidget {
  const ShapeMapExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'shape_map example',
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
    home: const MapGallery(),
  );
}

class MapGallery extends StatefulWidget {
  const MapGallery({super.key});

  @override
  State<MapGallery> createState() => _MapGalleryState();
}

class _MapGalleryState extends State<MapGallery>
    with SingleTickerProviderStateMixin {
  static const _municipalityColors = [
    Color(0xFFE8F5E9),
    Color(0xFFA5D6A7),
    Color(0xFF66BB6A),
    Color(0xFF2E7D32),
    Color(0xFF0D4D21),
  ];

  final _random = Random();
  final _controller = ShapeMapController();
  final _camera = ShapeMapCameraController();
  late final AnimationController _entrance;
  int _tab = 2;
  ShapeMapEntranceStyle _style = ShapeMapEntranceStyle.fade;
  ShapeMapStaggerOrder _order = ShapeMapStaggerOrder.topToBottom;
  Duration _entranceDuration = const Duration(milliseconds: 1200);
  Map<String, MapRegionData> _data = ReferenceLayouts.southAmericaData;
  List<MapMarkerData> _markers = ReferenceLayouts.southAmericaMarkers;
  MapDefinition? _municipalityMap;
  Map<String, MapRegionData> _municipalityData = const {};
  List<MapMarkerData> _municipalityMarkers = const [];
  Object? _municipalityError;
  bool _municipalityLoading = false;

  MapDefinition get _map => switch (_tab) {
    0 => ShapeMaps.world,
    1 => ShapeMaps.latinAmerica,
    2 => ShapeMaps.southAmerica,
    3 => ShapeMaps.brazilStates,
    _ => _municipalityMap ?? ShapeMaps.brazilStates,
  };

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: 0,
    )..forward();
  }

  Future<void> _loadMunicipalities() async {
    if (_municipalityLoading) return;
    setState(() {
      _municipalityLoading = true;
      _municipalityError = null;
    });
    try {
      final bytes = await rootBundle.load(
        'assets/maps/brazil_municipalities.smap',
      );
      final map = await ShapeMapData.decode(bytes, id: 'brazilMunicipalities');
      await map.warmUp();
      final data = <String, MapRegionData>{};
      for (final region in map.regions) {
        final code = region.id.substring(3);
        var hash = 17;
        for (final character in code.codeUnits) {
          hash = (hash * 31 + character) & 0x7fffffff;
        }
        final value = hash % 1000;
        final band = value * _municipalityColors.length ~/ 1000;
        data[region.id] = MapRegionData(
          value: value,
          fill:
              _municipalityColors[band.clamp(
                0,
                _municipalityColors.length - 1,
              )],
        );
      }
      const capitalCodes = <String>[
        '1200401',
        '2704302',
        '1600303',
        '1302603',
        '2927408',
        '2304400',
        '5300108',
        '3205309',
        '5208707',
        '2111300',
        '5103403',
        '5002704',
        '3106200',
        '1501402',
        '2507507',
        '4106902',
        '2611606',
        '2211001',
        '3304557',
        '2408102',
        '4314902',
        '1100205',
        '1400100',
        '4205407',
        '3550308',
        '2800308',
        '1721000',
      ];
      final markers = [
        for (final code in capitalCodes)
          if (map.regionById('BR-$code') case final region?)
            MapMarkerData(
              regionId: region.id,
              value: data[region.id]?.value ?? 0,
              position: region.markerAnchor,
              diameter: 8,
              showLabel: false,
            ),
      ];
      if (!mounted) return;
      setState(() {
        _municipalityMap = map;
        _municipalityData = data;
        _municipalityMarkers = markers;
        _municipalityLoading = false;
      });
      _entrance.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _municipalityError = error;
        _municipalityLoading = false;
      });
    }
  }

  void _randomize() {
    setState(() {
      _data = {
        for (final region in _map.regions)
          region.id: MapRegionData(
            value: _random.nextInt(10000),
            label: region.id == 'BR-BA' ? 'Bahia' : null,
          ),
      };
      _markers = [
        for (final marker in _markers)
          MapMarkerData(
            regionId: marker.regionId,
            value: _random.nextInt(10000),
            label: marker.label,
            diameter: 20 + _random.nextDouble() * 45,
            position: marker.position,
            showLabel: marker.showLabel,
          ),
      ];
    });
  }

  void _changeTab(int tab) {
    setState(() {
      _tab = tab;
      switch (tab) {
        case 2:
          _data = ReferenceLayouts.southAmericaData;
          _markers = ReferenceLayouts.southAmericaMarkers;
          _controller.clearSelection();
          break;
        case 3:
          _data = ReferenceLayouts.brazilData();
          _markers = ReferenceLayouts.brazilMarkers;
          _controller.select('BR-BA');
          break;
        case 4:
          _data = _municipalityData;
          _markers = _municipalityMarkers;
          _controller.clearSelection();
          break;
        case 0:
          _data = ReferenceLayouts.worldData;
          _markers = ReferenceLayouts.worldMarkers;
          _controller.clearSelection();
        case 1:
          _data = ReferenceLayouts.latinAmericaData;
          _markers = ReferenceLayouts.latinAmericaMarkers;
          _controller.clearSelection();
      }
      _replay();
    });
    if (tab == 4 && _municipalityMap == null) unawaited(_loadMunicipalities());
  }

  void _replay() {
    _entrance.forward(from: 0);
  }

  void _setDuration(Duration duration) {
    setState(() {
      _entranceDuration = duration;
      _entrance.duration = duration;
    });
  }

  void _setStyle(ShapeMapEntranceStyle style) {
    setState(() => _style = style);
  }

  void _setOrder(ShapeMapStaggerOrder order) {
    setState(() => _order = order);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _controller.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('shape_map'),
      actions: [
        IconButton(
          tooltip: 'Randomizar valores',
          onPressed: _randomize,
          icon: const Icon(Icons.shuffle),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Mundo')),
                ButtonSegment(value: 1, label: Text('América Latina')),
                ButtonSegment(value: 2, label: Text('América do Sul')),
                ButtonSegment(value: 3, label: Text('Brasil')),
                ButtonSegment(value: 4, label: Text('Municípios (BR)')),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) => _changeTab(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_tab == 4 && _municipalityMap == null) {
                  return _MunicipalityStatus(
                    loading: _municipalityLoading,
                    error: _municipalityError,
                    onRetry: _loadMunicipalities,
                  );
                }
                final mapData = _tab == 4 ? _municipalityData : _data;
                final mapMarkers = _tab == 4 ? _municipalityMarkers : _markers;
                final map = Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: ShapeMap(
                        map: _map,
                        data: mapData,
                        markers: mapMarkers,
                        controller: _controller,
                        cameraController: _camera,
                        zoomEnabled: true,
                        maxScale: _tab == 4 ? 40 : 10,
                        entrance: ShapeMapEntrance(
                          style: _tab == 4
                              ? ShapeMapEntranceStyle.fade
                              : _style,
                          duration: _entranceDuration,
                          staggerOrder: _order,
                        ),
                        entranceAnimation: _entrance,
                        animationDuration: const Duration(milliseconds: 300),
                        onRegionTap: (_) {},
                        style: ShapeMapStyle(
                          selectedColor: const Color(0xFFFF9A76),
                          // 5.570 municípios: borda fina para não cobrir os
                          // municípios pequenos (unidades do viewBox).
                          borderWidth: _tab == 4 ? 0.5 : 2,
                          marker: MarkerStyle(
                            borderWidth: _tab == 3 ? 1.5 : 2,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: ListenableBuilder(
                        listenable: _controller,
                        builder: (context, child) {
                          final selected = _controller.selectedRegionId;
                          final region = selected == null
                              ? null
                              : _map.regionById(selected);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (region != null)
                                Material(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    child: Text(region.name),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Ampliar',
                                      onPressed: () => _camera.zoomBy(1.5),
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: 'Reduzir',
                                      onPressed: () => _camera.zoomBy(1 / 1.5),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    IconButton(
                                      tooltip: 'Redefinir zoom',
                                      onPressed: _camera.resetZoom,
                                      icon: const Icon(Icons.refresh),
                                    ),
                                    IconButton(
                                      tooltip: 'Ampliar seleção',
                                      onPressed: region == null
                                          ? null
                                          : () =>
                                                _camera.zoomToRegion(region.id),
                                      icon: const Icon(
                                        Icons.center_focus_strong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
                final controls = _EntranceControls(
                  animation: _entrance,
                  style: _style,
                  order: _order,
                  duration: _entranceDuration,
                  onPlay: () => _entrance.forward(),
                  onReverse: () => _entrance.reverse(),
                  onPause: () => _entrance.stop(),
                  onResume: () => _resumeEntrance(),
                  onReset: () => _entrance.value = 0,
                  onReplay: _replay,
                  onStyleChanged: _setStyle,
                  onOrderChanged: _setOrder,
                  onDurationChanged: _setDuration,
                );
                if (constraints.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: map),
                      const SizedBox(width: 20),
                      SizedBox(width: 300, child: controls),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 2, child: map),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(child: controls),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  void _resumeEntrance() {
    if (_entrance.status == AnimationStatus.reverse) {
      _entrance.reverse();
    } else {
      _entrance.forward();
    }
  }
}

class _EntranceControls extends StatelessWidget {
  const _EntranceControls({
    required this.animation,
    required this.style,
    required this.order,
    required this.duration,
    required this.onPlay,
    required this.onReverse,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onReplay,
    required this.onStyleChanged,
    required this.onOrderChanged,
    required this.onDurationChanged,
  });

  final AnimationController animation;
  final ShapeMapEntranceStyle style;
  final ShapeMapStaggerOrder order;
  final Duration duration;
  final VoidCallback onPlay;
  final VoidCallback onReverse;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;
  final VoidCallback onReplay;
  final ValueChanged<ShapeMapEntranceStyle> onStyleChanged;
  final ValueChanged<ShapeMapStaggerOrder> onOrderChanged;
  final ValueChanged<Duration> onDurationChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only this part depends on the animation value and rebuilds per
          // tick; the dropdowns below rebuild only when their config changes.
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final progress = animation.value;
              final running = animation.isAnimating;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Entrada do mapa'),
                      Text('${(progress * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    label: '${(progress * 100).round()}%',
                    value: progress,
                    onChanged: (value) {
                      animation.stop();
                      animation.value = value;
                    },
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _actionButton(
                        tooltip: 'Reproduzir para frente',
                        label: 'Play',
                        icon: Icons.play_arrow,
                        onPressed: onPlay,
                      ),
                      _actionButton(
                        tooltip: 'Reproduzir ao contrário',
                        label: 'Reverse',
                        icon: Icons.fast_rewind,
                        onPressed: onReverse,
                      ),
                      _actionButton(
                        tooltip: running ? 'Pausar' : 'Continuar',
                        label: running ? 'Pause' : 'Resume',
                        icon: running ? Icons.pause : Icons.play_circle,
                        onPressed: running ? onPause : onResume,
                      ),
                      _actionButton(
                        tooltip: 'Voltar ao início',
                        label: 'Reset',
                        icon: Icons.restart_alt,
                        onPressed: onReset,
                      ),
                      _actionButton(
                        tooltip: 'Repetir animação',
                        label: 'Replay',
                        icon: Icons.replay,
                        onPressed: onReplay,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ShapeMapEntranceStyle>(
            decoration: const InputDecoration(labelText: 'Estilo'),
            isExpanded: true,
            initialValue: style,
            items: const [
              DropdownMenuItem(
                value: ShapeMapEntranceStyle.fade,
                child: Text('Fade'),
              ),
              DropdownMenuItem(
                value: ShapeMapEntranceStyle.grow,
                child: Text('Grow'),
              ),
              DropdownMenuItem(
                value: ShapeMapEntranceStyle.stagger,
                child: Text('Stagger'),
              ),
              DropdownMenuItem(
                value: ShapeMapEntranceStyle.draw,
                child: Text('Draw'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onStyleChanged(value);
            },
          ),
          DropdownButtonFormField<Duration>(
            decoration: const InputDecoration(labelText: 'Duração'),
            isExpanded: true,
            initialValue: duration,
            items: const [
              DropdownMenuItem(
                value: Duration(milliseconds: 600),
                child: Text('600 ms'),
              ),
              DropdownMenuItem(
                value: Duration(milliseconds: 1200),
                child: Text('1200 ms'),
              ),
              DropdownMenuItem(
                value: Duration(milliseconds: 2500),
                child: Text('2500 ms'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onDurationChanged(value);
            },
          ),
          DropdownButtonFormField<ShapeMapStaggerOrder>(
            decoration: const InputDecoration(labelText: 'Ordem'),
            isExpanded: true,
            initialValue: order,
            items: const [
              DropdownMenuItem(
                value: ShapeMapStaggerOrder.mapOrder,
                child: Text('Ordem do mapa'),
              ),
              DropdownMenuItem(
                value: ShapeMapStaggerOrder.topToBottom,
                child: Text('De cima para baixo'),
              ),
              DropdownMenuItem(
                value: ShapeMapStaggerOrder.bottomToTop,
                child: Text('De baixo para cima'),
              ),
              DropdownMenuItem(
                value: ShapeMapStaggerOrder.leftToRight,
                child: Text('Da esquerda para direita'),
              ),
              DropdownMenuItem(
                value: ShapeMapStaggerOrder.rightToLeft,
                child: Text('Da direita para esquerda'),
              ),
            ],
            onChanged: style == ShapeMapEntranceStyle.stagger
                ? (value) {
                    if (value != null) onOrderChanged(value);
                  }
                : null,
          ),
        ],
      ),
    ),
  );

  Widget _actionButton({
    required String tooltip,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class _MunicipalityStatus extends StatelessWidget {
  const _MunicipalityStatus({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar a malha municipal.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
