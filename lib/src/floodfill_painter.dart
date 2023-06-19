import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'queuelinear_floodfiller.dart';

class FloodFillPainter extends CustomPainter {
  QueueLinearFloodFiller? _filler;
  double? _width;
  double? _height;
  bool? _isFillActive;
  List<Color>? _avoidColor;

  ValueNotifier<String>? notifier;
  ui.Image image;
  Color fillColor;
  Function(Offset, ui.Image)? onFloodFillStart;
  Function(ui.Image)? onFloodFillEnd;
  Function? onInitialize;
  Function? onRepainted;

  FloodFillPainter(
      {required this.image,
      required this.fillColor,
      this.notifier,
      this.onFloodFillStart,
      this.onFloodFillEnd,
      this.onInitialize})
      : super(repaint: notifier) {
    _initFloodFiller();
  }

  int colorToHex(Color color) => Color.fromARGB(color.alpha, color.red, color.green, color.blue).value;

  void _initFloodFiller() async {
    ByteData byteData = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    var bytes = byteData.buffer.asUint8List();
    img.Image decoded = img.decodeImage(bytes)!;
    _filler = QueueLinearFloodFiller(decoded, colorToHex(fillColor));
    onInitialize!();
  }

  void setSize(Size size) {
    _width = size.width;
    _height = size.height;
    _filler?.resize(size);
  }

  void setFillColor(Color color) {
    _filler?.setFillColor(colorToHex(color));
  }

  void setIsFillActive(bool isActive) {
    _isFillActive = isActive;
  }

  void setAvoidColor(List<Color>? color) {
    if (color != null) _avoidColor = color;
  }

  void setTolerance(int? tolerance) {
    if (tolerance != null) _filler?.setTolerance(tolerance);
  }

  bool _checkAvoidColor(Color touchColor) {
    if (_avoidColor == null) return false;

    return _avoidColor!.any((element) => _isAvoidColor(element, touchColor));
  }

  bool _isAvoidColor(Color avoidColor, Color touchColor) {
    int touchR = touchColor.red;
    int touchG = touchColor.green;
    int touchB = touchColor.blue;
    int touchA = touchColor.alpha;

    int red = avoidColor.red;
    int green = avoidColor.green;
    int blue = avoidColor.blue;
    int alpha = avoidColor.alpha;

    return red >= (touchR - 100) &&
        red <= (touchR + 100) &&
        green >= (touchG - 100) &&
        green <= (touchG + 100) &&
        blue >= (touchB - 100) &&
        blue <= (touchB + 100) &&
        alpha >= (touchA - 100) &&
        alpha <= (touchA + 100);
  }

  void fill(Offset position) async {
    int pX = position.dx.toInt();
    int pY = position.dy.toInt();

    if (_filler == null) return;

    if (pX < 0 || pY < 0) return;

    var pixelColor = _filler!.image!.getPixelCubic(pX, pY);
    Color touchColor = Color.fromARGB(
      pixelColor.a.toInt(),
      pixelColor.r.toInt(),
      pixelColor.g.toInt(),
      pixelColor.b.toInt(),
    );

    if (_checkAvoidColor(touchColor)) return;
    if (onFloodFillStart != null) onFloodFillStart!(position, image);

    _filler?.setTargetColor(touchColor);
    await _filler!.floodFill(pX, pY);

    ui.decodeImageFromPixels(
      _filler!.image!.getBytes(),
      _filler!.image!.width,
      _filler!.image!.height,
      ui.PixelFormat.rgba8888,
      (output) async {
        image = output;
        notifier!.value = position.toString() + touchColor.toString();
        if (onFloodFillEnd != null) onFloodFillEnd!(output);
      },
    );
  }

  @override
  bool? hitTest(Offset position) {
    if (_isFillActive!) fill(position);
    return super.hitTest(position);
  }

  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawImage(image, Offset(0,0), Paint());
    double w = _width ?? image.width.toDouble();
    double h = _height ?? image.height.toDouble();
    paintImage(
        image, Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w, height: h), canvas, Paint(), BoxFit.fill);
  }

  void paintImage(ui.Image image, Rect outputRect, Canvas canvas, Paint paint, BoxFit fit) {
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final FittedSizes sizes = applyBoxFit(fit, imageSize, outputRect.size);
    final Rect inputSubrect = Alignment.center.inscribe(sizes.source, Offset.zero & imageSize);
    final Rect outputSubrect = Alignment.center.inscribe(sizes.destination, outputRect);
    canvas.drawImageRect(image, inputSubrect, outputSubrect, paint);
  }

  @override
  bool shouldRepaint(FloodFillPainter oldDelegate) {
    return true;
  }
}
