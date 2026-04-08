import 'dart:typed_data';

enum VerticalPosition {
  top,
  middle,
  bottom,
}

class Graphic {
  final Uint8List imageBytes;
  final String caption;
  final int columnSpan; // 1, 2, or 3
  final VerticalPosition verticalPosition;

  Graphic({
    required this.imageBytes,
    required this.caption,
    required this.columnSpan,
    required this.verticalPosition,
  }) : assert(columnSpan >= 1 && columnSpan <= 3);
}

class Article {
  final String heading;
  final String body;
  final List<Graphic> graphics;

  Article({
    required this.heading,
    required this.body,
    required this.graphics,
  });
}
