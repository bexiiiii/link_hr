import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'fmt.dart';
import 'theme.dart';
import 'ui.dart';

class SelectOption {
  const SelectOption(this.value, this.label, {this.subtitle});

  final String value;
  final String label;
  final String? subtitle;
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text.rich(TextSpan(
        text: text.toUpperCase(),
        style: AppText.caption.copyWith(letterSpacing: 0.3, color: AppColors.ink3),
        children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.red))],
      )),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child, this.onTap, this.enabled = true, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.99,
      semanticLabel: semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      ),
    );
  }
}

InputDecoration fieldDecoration({String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.body.copyWith(color: AppColors.ink3),
    filled: true,
    fillColor: AppColors.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    disabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.violet, 1.5),
    suffixIcon: suffix,
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.required = false,
    this.enabled = true,
    this.obscure = false,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool required;
  final bool enabled;
  final bool obscure;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label, required: required),
      TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        autofocus: autofocus,
        maxLines: obscure ? 1 : maxLines,
        minLines: 1,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: AppText.body,
        cursorColor: AppColors.violet,
        decoration: fieldDecoration(hint: hint, suffix: suffix),
      ),
    ]);
  }
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? minimum, DateTime? maximum}) {
  final min = minimum == null ? null : Fmt.dateOnly(minimum);
  final max = maximum == null ? null : Fmt.dateOnly(maximum);
  var temp = Fmt.dateOnly(initial ?? DateTime.now());
  if (min != null && temp.isBefore(min)) temp = min;
  if (max != null && temp.isAfter(max)) temp = max;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (c) => Container(
      height: 340,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              CupertinoButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
              const Spacer(),
              CupertinoButton(
                onPressed: () => Navigator.pop(c, temp),
                child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: temp,
              minimumDate: min,
              maximumDate: max,
              dateOrder: DatePickerDateOrder.dmy,
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ]),
      ),
    ),
  );
}

class DateInput extends StatelessWidget {
  const DateInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.minimum,
    this.maximum,
    this.placeholder = 'Выберите дату',
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;
  final bool enabled;
  final DateTime? minimum;
  final DateTime? maximum;
  final String placeholder;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label, required: required),
      _FieldBox(
        enabled: enabled,
        semanticLabel: label,
        onTap: () async {
          FocusScope.of(context).unfocus();
          final d = await pickDate(context, initial: value, minimum: minimum, maximum: maximum);
          if (d != null) onChanged(d);
        },
        child: Row(children: [
          Expanded(
            child: Text(
              value == null ? placeholder : Fmt.long(value),
              style: AppText.body.copyWith(color: value == null ? AppColors.ink3 : AppColors.ink),
            ),
          ),
          if (clearable && value != null && enabled)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: AppColors.ink4),
              ),
            ),
          const Icon(CupertinoIcons.calendar, size: 20, color: AppColors.violet),
        ]),
      ),
    ]);
  }
}

class SelectInput extends StatelessWidget {
  const SelectInput({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.placeholder = 'Выберите',
    this.loading = false,
  });

  final String label;
  final String? value;
  final List<SelectOption> options;
  final ValueChanged<String?> onChanged;
  final bool required;
  final bool enabled;
  final String placeholder;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String? display;
    if (value != null && value!.isNotEmpty) {
      display = options.where((o) => o.value == value).map((o) => o.label).firstOrNull ?? value;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label, required: required),
      _FieldBox(
        enabled: enabled && !loading,
        semanticLabel: label,
        onTap: () async {
          FocusScope.of(context).unfocus();
          final picked = await showSelectSheet(context, title: label, options: options, selected: value);
          if (picked != null) onChanged(picked);
        },
        child: Row(children: [
          Expanded(
            child: Text(
              display ?? (options.isEmpty && !loading ? 'Нет доступных вариантов' : placeholder),
              style: AppText.body.copyWith(color: display == null ? AppColors.ink3 : AppColors.ink),
            ),
          ),
          if (loading)
            const CupertinoActivityIndicator()
          else
            const Icon(CupertinoIcons.chevron_down, size: 18, color: AppColors.ink3),
        ]),
      ),
    ]);
  }
}

Future<String?> showSelectSheet(
  BuildContext context, {
  required String title,
  required List<SelectOption> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _SelectSheet(title: title, options: options, selected: selected),
  );
}

class _SelectSheet extends StatefulWidget {
  const _SelectSheet({required this.title, required this.options, this.selected});

  final String title;
  final List<SelectOption> options;
  final String? selected;

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final items = widget.options
        .where((o) => q.isEmpty || o.label.toLowerCase().contains(q) || (o.subtitle ?? '').toLowerCase().contains(q))
        .toList();
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: AppText.heading)),
            ),
            if (widget.options.length > 7)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: CupertinoSearchTextField(
                  placeholder: 'Поиск',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text('Ничего не найдено', style: AppText.label.copyWith(color: AppColors.ink3)),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = items[i];
                  final isSelected = o.value == widget.selected;
                  return Pressable(
                    onTap: () => Navigator.pop(context, o.value),
                    scale: 0.99,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.label,
                                style: AppText.bodyStrong
                                    .copyWith(color: isSelected ? AppColors.violet : AppColors.ink)),
                            if (o.subtitle != null && o.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(o.subtitle!, style: AppText.caption),
                            ],
                          ]),
                        ),
                        if (isSelected) const Icon(CupertinoIcons.checkmark_alt, color: AppColors.violet, size: 22),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SwitchInput extends StatelessWidget {
  const SwitchInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _FieldBox(
      enabled: enabled,
      onTap: () => onChanged(!value),
      semanticLabel: label,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.bodyStrong),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppText.caption)],
          ]),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: AppColors.violet,
          onChanged: enabled ? onChanged : null,
        ),
      ]),
    );
  }
}

class FormGap extends StatelessWidget {
  const FormGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 18);
}

class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.busy = false,
    this.loading = false,
    this.error,
    this.loadError,
    this.onRetry,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool busy;
  final bool loading;
  final String? error;
  final Object? loadError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = PageScroll(children: [
        for (var i = 0; i < 5; i++) ...[
          const Skeleton(height: 14, width: 120),
          const SizedBox(height: 10),
          const Skeleton(height: 56, radius: AppRadius.field),
          const SizedBox(height: 20),
        ],
      ]);
    } else if (loadError != null) {
      body = PageScroll(children: [ErrorState(error: loadError!, onRetry: onRetry ?? () {})]);
    } else {
      body = GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageScroll(children: [...children, if (error != null) InlineError(error!)]),
      );
    }
    return AppPage(
      header: ScreenHeader(title: title),
      body: body,
      bottom: loading || loadError != null
          ? null
          : PrimaryButton(label: submitLabel, loading: busy, onTap: onSubmit),
    );
  }
}
