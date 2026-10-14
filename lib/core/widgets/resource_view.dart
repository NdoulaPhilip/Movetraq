import 'package:flutter/material.dart';
import 'components.dart';

class ResourceView<T> extends StatefulWidget {
  const ResourceView(
      {super.key, required this.load, required this.builder, this.resourceKey});
  final Future<T> Function() load;
  final Widget Function(T data) builder;
  final Object? resourceKey;
  @override
  State<ResourceView<T>> createState() => _ResourceViewState<T>();
}

class _ResourceViewState<T> extends State<ResourceView<T>> {
  late Future<T> _result;
  @override
  void initState() {
    super.initState();
    _result = widget.load();
  }

  @override
  void didUpdateWidget(ResourceView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceKey != widget.resourceKey) _result = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorState(
              message: 'Unable to load this information.',
              retry: () {
                final result = widget.load();
                setState(() {
                  _result = result;
                });
              });
        }
        return widget.builder(snapshot.data as T);
      });
}
