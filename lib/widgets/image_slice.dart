import 'package:flutter/material.dart';

class ImageSlice extends StatelessWidget {
  const ImageSlice({
    super.key,
    required this.asset,
    required this.source,
    required this.rect,
  });

  final String asset;
  final Size source;
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: rect.width,
        height: rect.height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: source.width,
            maxWidth: source.width,
            minHeight: source.height,
            maxHeight: source.height,
            child: Transform.translate(
              offset: Offset(-rect.left, -rect.top),
              child: Image.asset(
                asset,
                width: source.width,
                height: source.height,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
