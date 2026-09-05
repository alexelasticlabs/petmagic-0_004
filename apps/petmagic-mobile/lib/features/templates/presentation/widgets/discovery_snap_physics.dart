import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Keeps free multi-card flings, then settles on a card edge (or the rail end).
class DiscoverySnapPhysics extends ScrollPhysics {
  const DiscoverySnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  DiscoverySnapPhysics applyTo(ScrollPhysics? ancestor) => DiscoverySnapPhysics(
    itemExtent: itemExtent,
    parent: buildParent(ancestor),
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange ||
        (position.pixels <= position.minScrollExtent && velocity <= 0) ||
        (position.pixels >= position.maxScrollExtent && velocity >= 0)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final projected = FrictionSimulation(
      0.135,
      position.pixels,
      velocity,
    ).finalX;
    final target =
        (position.minScrollExtent +
                ((projected - position.minScrollExtent) / itemExtent).round() *
                    itemExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
