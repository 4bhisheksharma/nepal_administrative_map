import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/src/rendering/map_camera.dart';

void main() {
  const content = Rect.fromLTWH(0, 0, 1000, 500);
  const size = Size(800, 400);

  test('fit camera reproduces the fitted transform', () {
    final t = MapCamera.fit(content).transform(content, size, EdgeInsets.zero);
    expect(t.scale, 0.8);
    expect(t.toScreen(content.topLeft), Offset.zero);
    expect(t.toScreen(content.bottomRight), const Offset(800, 400));
  });

  test('anchored keeps the plane point under the screen point', () {
    final camera = MapCamera.anchored(
      planePoint: const Offset(250, 100),
      screenPoint: const Offset(50, 60),
      zoom: 3,
      content: content,
      size: size,
      padding: EdgeInsets.zero,
    );
    final t = camera.transform(content, size, EdgeInsets.zero);
    expect(
      t.toScreen(const Offset(250, 100)),
      offsetMoreOrLessEquals(const Offset(50, 60)),
    );
    expect(t.scale, closeTo(2.4, 1e-9));
  });

  test('clamp limits zoom and keeps the centre on the content', () {
    final c = const MapCamera(
      center: Offset(-50, 900),
      zoom: 100,
    ).clamp(content, 1, 40);
    expect(c.zoom, 40);
    expect(c.center, const Offset(0, 500));
    expect(
      const MapCamera(
        center: Offset(10, 10),
        zoom: 0.2,
      ).clamp(content, 1, 40).zoom,
      1,
    );
  });

  test('flight interpolates scale on a log curve', () {
    const flight = CameraFlight((Offset.zero, 1), (Offset(100, 0), 4));
    expect(flight.at(0), (Offset.zero, 1.0));
    final (center, scale) = flight.at(0.5);
    expect(center, const Offset(50, 0));
    expect(scale, closeTo(2, 1e-9)); // geometric midpoint of 1 and 4
    expect(flight.at(1).$2, closeTo(4, 1e-9));
  });
}
