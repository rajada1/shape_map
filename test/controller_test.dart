import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('controller notifies only when a value changes', () {
    final controller = ShapeMapController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.select('BR');
    controller.select('BR');
    controller.setHovered('BR');
    controller.setHovered('BR');
    controller.clearSelection();
    controller.clearSelection();
    expect(notifications, 3);
  });
}
