import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shape_map/shape_map.dart';

import 'layouts.dart';

void main() => runApp(const ShapeMapExampleApp());

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
  final _random = Random();
  final _controller = ShapeMapController();
  late final AnimationController _entrance;
  int _tab = 0;
  ShapeMapEntranceStyle _style = ShapeMapEntranceStyle.fade;
  ShapeMapStaggerOrder _order = ShapeMapStaggerOrder.topToBottom;
  Duration _entranceDuration = const Duration(milliseconds: 1200);
  Map<String, MapRegionData> _data = ReferenceLayouts.southAmericaData;
  List<MapMarkerData> _markers = ReferenceLayouts.southAmericaMarkers;

  MapDefinition get _map =>
      _tab == 0 ? ShapeMaps.southAmericaCountries : ShapeMaps.brazilStates;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: 0,
    )..forward();
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
      if (tab == 0) {
        _data = ReferenceLayouts.southAmericaData;
        _markers = ReferenceLayouts.southAmericaMarkers;
        _controller.clearSelection();
      } else {
        _data = ReferenceLayouts.brazilData();
        _markers = ReferenceLayouts.brazilMarkers;
        _controller.select('BR-BA');
      }
      _replay();
    });
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
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _tab == 0 ? null : () => _changeTab(0),
                  child: const Text('América do Sul'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _tab == 1 ? null : () => _changeTab(1),
                  child: const Text('Brasil'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final map = RepaintBoundary(
                  child: ShapeMap(
                    map: _map,
                    data: _data,
                    markers: _markers,
                    controller: _controller,
                    entrance: ShapeMapEntrance(
                      style: _style,
                      duration: _entranceDuration,
                      staggerOrder: _order,
                    ),
                    entranceAnimation: _entrance,
                    animationDuration: const Duration(milliseconds: 300),
                    onRegionTap: (region) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Selecionado: ${region.name}'),
                          ),
                        ),
                    style: ShapeMapStyle(
                      selectedColor: const Color(0xFFFF9A76),
                      marker: MarkerStyle(
                        borderWidth: _tab == 1 ? 1.5 : 2,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
