import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/utils/platform.dart';

PreferredSizeWidget adaptiveAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
  Widget? leading,
  bool centerTitle = false,
}) {
  if (isCupertinoPlatform(context)) {
    return CupertinoNavigationBar(
      middle: Text(title),
      leading: leading,
      trailing: actions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
      automaticallyImplyLeading: leading == null,
    );
  }

  return AppBar(
    title: Text(title),
    actions: actions,
    leading: leading,
    centerTitle: centerTitle,
  );
}

