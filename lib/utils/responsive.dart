import 'package:flutter/material.dart';

class Responsive {
  Responsive(BuildContext context)
      : _mq = MediaQuery.of(context),
        _width = MediaQuery.sizeOf(context).width,
        _height = MediaQuery.sizeOf(context).height;

  final MediaQueryData _mq;
  final double _width;
  final double _height;

  static const double _baseWidth = 393;
  static const double _baseHeight = 852;

  double get _sw => (_width / _baseWidth).clamp(0.75, 1.6);

  double get _sh => (_height / _baseHeight).clamp(0.75, 1.6);

  double s(double value) => value * _sw;

  double fs(double value) => value * ((_sw + 1) / 2); // half-way between 1× and _sw

  double icon(double value) => value * _sw;

  double h(double value) => value * _sh;

  double get maxFormWidth => _width > 600 ? 520 : double.infinity;

  bool get isCompact => _width < 360;

  bool get isWide => _width >= 600;

  double get textScale => _mq.textScaler.scale(1.0);
}
