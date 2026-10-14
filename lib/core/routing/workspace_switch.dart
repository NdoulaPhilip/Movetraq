import 'package:flutter/material.dart';
import '../../widgets/movetraq_brand.dart';
import '../widgets/components.dart';

class WorkspaceSwitch {
  static final _active = Expando<bool>();
  static Future<bool> open(BuildContext context,
      {required bool deliverer,
      required Future<bool> Function() changeRole}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (_active[navigator] == true) return false;
    _active[navigator] = true;
    try {
      return await showGeneralDialog<bool>(
              context: context,
              barrierDismissible: false,
              transitionDuration: Duration.zero,
              pageBuilder: (context, _, __) => WorkspaceSwitchOverlay(
                  deliverer: deliverer,
                  reducedMotion: MediaQuery.disableAnimationsOf(context),
                  changeRole: changeRole)) ??
          false;
    } finally {
      _active[navigator] = false;
    }
  }
}

class WorkspaceSwitchOverlay extends StatefulWidget {
  const WorkspaceSwitchOverlay(
      {super.key,
      required this.deliverer,
      required this.reducedMotion,
      required this.changeRole});
  final bool deliverer, reducedMotion;
  final Future<bool> Function() changeRole;
  @override
  State<WorkspaceSwitchOverlay> createState() => _WorkspaceSwitchOverlayState();
}

class _WorkspaceSwitchOverlayState extends State<WorkspaceSwitchOverlay> {
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _change());
  }

  Future<void> _change() async {
    try {
      final changed = await widget.changeRole();
      if (!mounted) return;
      if (changed) {
        Navigator.pop(context, true);
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _failed,
      child: Material(
          color: Colors.white,
          child: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const MoveTraqMark(size: 100),
                        const SizedBox(height: 22),
                        Text(
                            widget.deliverer
                                ? 'Getting you ready to deliver'
                                : 'Getting you ready to send',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        if (_failed)
                          ErrorState(
                              message:
                                  'Unable to change workspace. Please try again.',
                              retry: () => Navigator.pop(context, false))
                        else if (widget.reducedMotion)
                          const Text('Connecting...')
                        else
                          const SizedBox(
                              width: 72, child: LinearProgressIndicator()),
                      ]))))));
}
