import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../documents/documents_screen.dart';
import '../finance/salary_slips_screen.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Json? _employee;
  String _reportsTo = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await Hr.employeeDoc();
      var manager = '';
      final reportsTo = doc['reports_to']?.toString();
      if (reportsTo != null && reportsTo.isNotEmpty) {
        manager = await Hr.reportsToName(
          reportsTo,
        ).catchError((_) => reportsTo);
      }
      if (mounted) {
        setState(() {
          _employee = doc;
          _reportsTo = manager;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _showSection(String title, List<(String, String)> rows) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(c).size.height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 16),
                if (rows.every((r) => r.$2.trim().isEmpty))
                  Text(
                    'Данные ещё не заполнены отделом кадров',
                    style: AppText.body.copyWith(color: AppColors.ink3),
                  )
                else
                  FieldRows(rows: rows),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Для входа снова понадобятся email и пароль.',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (!ok) return;
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await Session.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final e = _employee ?? const <String, dynamic>{};
    String v(String f) => (e[f] ?? '').toString();
    final cur = v('salary_currency').isEmpty
        ? s.currency
        : v('salary_currency');
    final subtitle = [
      s.designation,
      s.department,
    ].where((x) => x.isNotEmpty).join(' · ');

    final sections = <(IconData, Tone, String, List<(String, String)>)>[
      (
        CupertinoIcons.person,
        Tone.violet,
        'Сведения о сотруднике',
        [
          ('ФИО', v('employee_name')),
          (
            'Табельный номер',
            v('employee_number').isEmpty ? v('name') : v('employee_number'),
          ),
          ('ИИН', v('custom_iin')),
          (
            'Пол',
            const {'Male': 'Мужской', 'Female': 'Женский'}[v('gender')] ??
                v('gender'),
          ),
          ('Дата рождения', Fmt.long(e['date_of_birth'])),
          ('Дата приёма', Fmt.long(e['date_of_joining'])),
          ('Группа крови', v('blood_group')),
        ],
      ),
      (
        CupertinoIcons.building_2_fill,
        Tone.green,
        'Компания',
        [
          ('Компания', v('company')),
          ('Подразделение', v('department')),
          ('Должность', v('designation')),
          ('Филиал', v('branch')),
          ('Грейд', v('grade')),
          ('Руководитель', _reportsTo),
          ('Тип занятости', v('employment_type')),
        ],
      ),
      (
        CupertinoIcons.phone,
        Tone.amber,
        'Контакты',
        [
          ('Телефон', v('cell_number')),
          ('Личный email', v('personal_email')),
          ('Рабочий email', v('company_email')),
          ('Основной email', v('prefered_email')),
        ],
      ),
      (
        CupertinoIcons.money_dollar_circle,
        Tone.dark,
        'Зарплата и банк',
        [
          (
            'Годовой доход',
            Fmt.number(e['ctc']) == 0 ? '' : Fmt.money(e['ctc'], cur),
          ),
          ('Центр затрат', v('payroll_cost_center')),
          ('Способ выплаты', v('salary_mode')),
          ('Банк', v('bank_name')),
          ('Номер счёта', v('bank_ac_no')),
          ('IBAN', v('iban')),
        ],
      ),
    ];

    return AppPage(
      header: ScreenHeader(
        title: 'Профиль',
        showBack: widget.showBack,
        actions: [
          CircleButton(
            icon: CupertinoIcons.gear,
            label: 'Настройки',
            onTap: () => pushPage(context, const SettingsScreen()),
          ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          const SizedBox(height: 8),
          Center(
            child: AppAvatar(name: s.fullName, imageUrl: s.image, size: 76),
          ),
          const SizedBox(height: 14),
          Text(s.fullName, textAlign: TextAlign.center, style: AppText.title),
          const SizedBox(height: 4),
          Text(
            subtitle.isEmpty ? 'Сотрудник' : subtitle,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: AppColors.ink3),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            ErrorState(error: _error!, onRetry: _load),
            const SizedBox(height: 16),
          ],
          _Group(
            children: [
              for (final (icon, tone, title, rows) in sections)
                _Row(
                  icon: icon,
                  tone: tone,
                  label: title,
                  onTap: _employee == null
                      ? null
                      : () => _showSection(title, rows),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: CupertinoIcons.folder,
                tone: Tone.violet,
                label: 'Кадровые документы',
                onTap: () => pushPage(context, const DocumentsScreen()),
              ),
              _Row(
                icon: CupertinoIcons.doc_plaintext,
                tone: Tone.green,
                label: 'Расчётные листки',
                onTap: () => pushPage(context, const SalarySlipsScreen()),
              ),
              _Row(
                icon: CupertinoIcons.bell,
                tone: Tone.amber,
                label: 'Уведомления',
                onTap: () => pushPage(context, const NotificationsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: CupertinoIcons.lock,
                tone: Tone.dark,
                label: 'Сменить пароль',
                onTap: () => pushPage(context, const ChangePasswordScreen()),
              ),
              _Row(
                icon: CupertinoIcons.gear,
                tone: Tone.dark,
                label: 'Настройки',
                onTap: () => pushPage(context, const SettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Выйти из аккаунта',
            kind: ButtonKind.danger,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divided(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Tone tone;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconBadge(icon: icon, tone: tone, size: 40),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.bodyStrong)),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.ink4,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = LocalAuthentication();
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _auth
        .isDeviceSupported()
        .then((v) {
          if (mounted) setState(() => _supported = v);
        })
        .catchError((_) {});
  }

  Future<void> _toggleLock(bool value) async {
    final s = Session.instance;
    if (value) {
      try {
        final ok = await _auth.authenticate(
          localizedReason: 'Включить вход по Face ID',
        );
        if (!ok) return;
      } catch (_) {
        if (mounted)
          showToast(
            context,
            'Face ID недоступен на этом устройстве',
            error: true,
          );
        return;
      }
    }
    await s.setBiometricLock(value);
    if (value) s.markUnlocked();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return AppPage(
      header: const ScreenHeader(title: 'Настройки'),
      body: PageScroll(
        children: [
          const FieldLabel('Безопасность'),
          SwitchInput(
            label: 'Блокировка Face ID',
            subtitle: _supported
                ? 'Запрашивать Face ID при открытии приложения'
                : 'Биометрия недоступна на этом устройстве',
            value: s.biometricLock,
            enabled: _supported,
            onChanged: _toggleLock,
          ),
          const SizedBox(height: 24),
          const FieldLabel('Аккаунт'),
          FieldRows(
            rows: [
              ('Пользователь', s.userId),
              ('Сотрудник', s.employeeId),
              ('Компания', s.company),
            ],
          ),
          const SizedBox(height: 24),
          const FieldLabel('О приложении'),
          const FieldRows(rows: [('Приложение', 'Link'), ('Версия', '1.0.0')]),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? problem;
    if (_old.text.isEmpty || _new.text.isEmpty) {
      problem = 'Заполните текущий и новый пароль';
    } else if (_new.text.length < 8) {
      problem = 'Новый пароль должен быть не короче 8 символов';
    } else if (_new.text != _confirm.text) {
      problem = 'Пароли не совпадают';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Hr.changePassword(_old.text, _new.text);
      if (mounted) {
        showToast(context, 'Пароль изменён');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Смена пароля',
      submitLabel: 'Сменить пароль',
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        AppTextField(
          label: 'Текущий пароль',
          controller: _old,
          obscure: true,
          required: true,
          autofillHints: const [AutofillHints.password],
        ),
        const FormGap(),
        AppTextField(
          label: 'Новый пароль',
          controller: _new,
          obscure: true,
          required: true,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const FormGap(),
        AppTextField(
          label: 'Повторите новый пароль',
          controller: _confirm,
          obscure: true,
          required: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 10),
        const Text(
          'Используйте не менее 8 символов: буквы разного регистра, цифры и знаки.',
          style: AppText.caption,
        ),
      ],
    );
  }
}
