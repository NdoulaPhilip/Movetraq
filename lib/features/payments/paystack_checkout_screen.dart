import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/networking/api.dart';
import '../../core/widgets/components.dart' show ErrorState;
import '../../widgets/primary_button.dart';
import 'checkout_request.dart';

class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen(
      {super.key, required this.request, required this.api});
  final CheckoutRequest request;
  final ApiClient api;
  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutState();
}

class _PaystackCheckoutState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _verifying = false, _leaving = false, _canExit = false;
  String? _notice, _error;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      }, onWebResourceError: (failure) {
        if (mounted && failure.isForMainFrame == true) {
          setState(() => _error = 'Checkout could not load. Please retry.');
        }
      }, onNavigationRequest: (navigation) {
        final uri = Uri.tryParse(navigation.url);
        if (uri == null) return NavigationDecision.prevent;
        if (widget.request.isCancel(uri)) {
          _leave(confirm: false);
          return NavigationDecision.prevent;
        }
        if (widget.request.isCallback(uri) ||
            widget.request.isAuthenticationClose(uri)) {
          _verify();
          return NavigationDecision.prevent;
        }
        if (widget.request.allowsNavigation(uri)) {
          return NavigationDecision.navigate;
        }
        if (mounted) {
          setState(() => _notice =
              'This payment method is unavailable in mobile checkout.');
        }
        return NavigationDecision.prevent;
      }))
      ..loadRequest(widget.request.url);
  }

  void _finish(bool verified) {
    if (!mounted || _canExit) return;
    setState(() => _canExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, verified);
    });
  }

  Future<bool> _verify() async {
    if (_verifying || !mounted) return false;
    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.api.request(
          '/payments/${widget.request.reference}/verify',
          method: 'POST');
      if (!mounted) return false;
      if (result['status'] == 'verified' &&
          result['reference'] == widget.request.reference) {
        _finish(true);
        return true;
      }
      setState(() => _notice =
          'Payment has not been confirmed. Complete checkout, then check again.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to verify payment. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
    return false;
  }

  Future<void> _leave({bool confirm = true}) async {
    if (_leaving || _verifying || _canExit) return;
    _leaving = true;
    try {
      if (confirm) {
        final exit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Leave payment?'),
                    content: const Text(
                        'Leaving checkout does not confirm or cancel a payment.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep paying')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave checkout'))
                    ]));
        if (exit != true || !mounted) return;
      }
      final verified = await _verify();
      if (mounted && !verified) _finish(false);
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Secure payment'),
            leading: IconButton(
                tooltip: 'Close checkout',
                onPressed: _verifying ? null : _leave,
                icon: const Icon(Icons.close)),
            actions: [
              IconButton(
                  tooltip: 'Reload checkout',
                  onPressed: _verifying
                      ? null
                      : () => _controller.loadRequest(widget.request.url),
                  icon: const Icon(Icons.refresh))
            ]),
        body: Column(children: [
          if (_progress < 100)
            LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100),
          Expanded(
              child: AbsorbPointer(
                  absorbing: _verifying,
                  child: WebViewWidget(controller: _controller))),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorState(message: _error!)),
          if (_notice != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_notice!))
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                    label: 'Check payment status',
                    loading: _verifying,
                    onPressed: _verifying ? null : _verify))),
      ));
}
