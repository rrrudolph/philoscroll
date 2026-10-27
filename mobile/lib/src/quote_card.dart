import 'package:flutter/widgets.dart';

import 'fit.dart';
import 'measure.dart';
import 'quote.dart';

enum CardRole { current, neighbor, leaving, arriving }

class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.quote,
    required this.dy,
    required this.opacity,
    required this.role,
    required this.fontSize,
    required this.frame,
    required this.scaler,
    this.semantics = true,
  });

  final Quote quote;
  final double dy;
  final double opacity;
  final CardRole role;
  final double fontSize;
  final Frame frame;
  final TextScaler scaler;
  final bool semantics;

  bool get showsReadingKeys => role == CardRole.current || role == CardRole.arriving;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          quote.text,
          key: showsReadingKeys ? const Key('quote-text') : null,
          textAlign: TextAlign.center,
          style: quoteStyle(fontSize),
          textScaler: scaler,
        ),
        SizedBox(height: frame.authorGap),
        Text(
          quote.author.toUpperCase(),
          key: showsReadingKeys ? const Key('quote-author') : null,
          textAlign: TextAlign.center,
          style: authorStyle(),
          textScaler: scaler,
        ),
      ],
    );
    final body = Padding(
      padding: EdgeInsets.only(top: frame.padTop, bottom: frame.padBottom),
      child: Center(
        child: SizedBox(width: frame.columnWidth, child: column),
      ),
    );
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: opacity.clamp(0, 1).toDouble(),
        child: semantics
            ? Semantics(container: true, label: '${quote.text}\n${quote.author}', child: ExcludeSemantics(child: body))
            : ExcludeSemantics(child: body),
      ),
    );
  }
}
