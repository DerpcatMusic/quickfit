import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/utils/platform.dart';

Future<T?> showAdaptiveDialog<T>(
  BuildContext context, {
  required Widget title,
  required Widget content,
  required List<Widget> actions,
}) {
  if (isCupertinoPlatform(context)) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: title,
      content: content,
      actions: actions,
    ),
  );
}

