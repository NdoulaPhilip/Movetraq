import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';

enum FieldKind { text, multiline, email, phone, money, number, password, code }

class FormFieldSpec {
  const FormFieldSpec(this.key, this.label,
      {this.kind = FieldKind.text,
      this.required = true,
      this.options = const [],
      this.hint,
      this.minLength = 1});
  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final String? hint;
  final int minLength;
}

class FeatureFormScreen extends StatefulWidget {
  const FeatureFormScreen(
      {super.key,
      required this.title,
      required this.fields,
      required this.action,
      this.subtitle,
      this.path,
      this.method = 'POST',
      this.fixedValues = const {},
      this.initialValues = const {},
      this.review = false,
      this.reviewTitle = 'Review your details',
      this.reviewAction,
      this.onSubmit,
      this.dangerous = false});
  final String title;
  final String? subtitle;
  final List<FormFieldSpec> fields;
  final String action;
  final String? path;
  final String method;
  final Map<String, dynamic> fixedValues;
  final Map<String, dynamic> initialValues;
  final bool review;
  final String reviewTitle;
  final String? reviewAction;
  final bool dangerous;
  final Future<void> Function(BuildContext, Map<String, dynamic>)? onSubmit;

  @override
  State<FeatureFormScreen> createState() => _FeatureFormScreenState();
}

class _FeatureFormScreenState extends State<FeatureFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String>{};
  bool _busy = false;
  bool _reviewing = false;
  Object? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initialValues[field.key]?.toString() ?? '';
      _controllers[field.key] = TextEditingController(text: initial);
      if (field.options.isNotEmpty && field.options.contains(initial)) {
        _choices[field.key] = initial;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _values() => {
        ...widget.fixedValues,
        for (final field in widget.fields)
          if ((_choices[field.key] ?? _controllers[field.key]!.text)
              .trim()
              .isNotEmpty)
            field.key: switch (field.kind) {
              FieldKind.money => parseMinorUnits(_controllers[field.key]!.text),
              FieldKind.number => int.tryParse(_controllers[field.key]!.text),
              _ => _choices[field.key] ?? _controllers[field.key]!.text.trim(),
            },
      };

  Future<void> _submit() async {
    if (_busy) return;
    if (!_reviewing && !_form.currentState!.validate()) return;
    if (widget.review && !_reviewing) {
      setState(() => _reviewing = true);
      return;
    }
    if (widget.dangerous &&
        !await confirmAction(context, widget.action,
            'Review your details before confirming this action.')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(context, _values());
      } else {
        await FeatureGateway(context.read<LocalDataService>()).request(
            widget.title, widget.method, widget.path!,
            body: _values());
      }
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate(FormFieldSpec field, String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) {
      return field.required ? 'Enter ${field.label.toLowerCase()}' : null;
    }
    if (value.length < field.minLength) {
      return 'At least ${field.minLength} characters';
    }
    if (field.kind == FieldKind.email &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    if (field.kind == FieldKind.phone &&
        !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    if (field.kind == FieldKind.money &&
        (parseMinorUnits(value) == null || parseMinorUnits(value)! <= 0)) {
      return 'Enter an amount greater than zero';
    }
    if (field.kind == FieldKind.number && int.tryParse(value) == null) {
      return 'Enter a whole number';
    }
    if (field.kind == FieldKind.code && !RegExp(r'^\d{4,8}$').hasMatch(value)) {
      return 'Enter a valid verification code';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: _done
            ? 'Request received'
            : _reviewing
                ? widget.reviewTitle
                : widget.title,
        subtitle: _done ? null : widget.subtitle,
        children: [
          if (_done) ...[
            const InfoBand(
                title: 'Submitted successfully',
                icon: Icons.check_circle_outline),
            SecondaryButton(
                label: 'Back', onPressed: () => Navigator.maybePop(context)),
          ] else ...[
            if (_reviewing) ...[
              for (final field in widget.fields)
                if (_values().containsKey(field.key))
                  DetailRow(
                      field.label,
                      field.kind == FieldKind.password ||
                              field.kind == FieldKind.code
                          ? 'Hidden'
                          : field.kind == FieldKind.money
                              ? 'NGN ${_controllers[field.key]!.text}'
                              : _values()[field.key].toString()),
              TextButton.icon(
                  onPressed:
                      _busy ? null : () => setState(() => _reviewing = false),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit details')),
            ] else
              Form(
                  key: _form,
                  child: Column(children: [
                    for (final field in widget.fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              if (field.options.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  initialValue: _choices[field.key],
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      hintText: field.hint ?? 'Select'),
                                  items: field.options
                                      .map((option) => DropdownMenuItem(
                                          value: option,
                                          child: Text(
                                              option.replaceAll('_', ' '),
                                              style: const TextStyle(
                                                  fontSize: 13))))
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    if (value != null) {
                                      _choices[field.key] = value;
                                    }
                                  }),
                                  validator: (value) =>
                                      field.required && value == null
                                          ? 'Choose an option'
                                          : null,
                                )
                              else
                                TextFormField(
                                  controller: _controllers[field.key],
                                  obscureText: field.kind == FieldKind.password,
                                  maxLines:
                                      field.kind == FieldKind.multiline ? 4 : 1,
                                  keyboardType: switch (field.kind) {
                                    FieldKind.email =>
                                      TextInputType.emailAddress,
                                    FieldKind.phone => TextInputType.phone,
                                    FieldKind.money =>
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                    FieldKind.number ||
                                    FieldKind.code =>
                                      TextInputType.number,
                                    _ => TextInputType.text,
                                  },
                                  decoration:
                                      InputDecoration(hintText: field.hint),
                                  validator: (value) => _validate(field, value),
                                ),
                            ]),
                      ),
                  ])),
            if (_error != null) LoadError(error: _error!),
            PrimaryButton(
                label: widget.review && !_reviewing
                    ? 'Review details'
                    : _reviewing
                        ? widget.reviewAction ?? widget.action
                        : widget.action,
                loading: _busy,
                background: widget.dangerous ? AppColors.danger : AppColors.ink,
                onPressed: _submit),
          ],
        ],
      );
}

class FeatureListScreen extends StatefulWidget {
  const FeatureListScreen(
      {super.key,
      required this.title,
      required this.path,
      this.subtitle,
      this.itemKey = 'items',
      this.createRoute,
      this.emptyTitle = 'Nothing here yet',
      this.fields = const ['status'],
      this.embedded = false,
      this.createArguments});
  final String title;
  final String? subtitle;
  final String path;
  final String itemKey;
  final String? createRoute;
  final String emptyTitle;
  final List<String> fields;
  final bool embedded;
  final Object? createArguments;
  @override
  State<FeatureListScreen> createState() => _FeatureListScreenState();
}

class _FeatureListScreenState extends State<FeatureListScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = FeatureGateway(context.read<LocalDataService>())
      .request(widget.title, 'GET', widget.path);
  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.title,
        subtitle: widget.subtitle,
        embedded: widget.embedded,
        actions: [
          if (widget.createRoute != null)
            IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.pushNamed(
                    context, widget.createRoute!,
                    arguments: widget.createArguments))
        ],
        children: [
          FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LoadError(
                      error: snapshot.error!, onRetry: () => setState(_load));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw = snapshot.data![widget.itemKey];
                final records = raw is List
                    ? raw.whereType<Map<String, dynamic>>().toList()
                    : <Map<String, dynamic>>[];
                if (records.isEmpty) {
                  return PremiumEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: widget.emptyTitle,
                      body: '');
                }
                return Column(
                    children: records
                        .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PremiumSurface(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      (item['title'] ??
                                              item['name'] ??
                                              item['id'] ??
                                              '')
                                          .toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  for (final field in widget.fields)
                                    if (item[field] != null)
                                      DetailRow(field.replaceAll('_', ' '),
                                          item[field].toString()),
                                ]))))
                        .toList());
              })
        ],
      );
}
