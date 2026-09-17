import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/app_icons.dart';

import '../../core/forms.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(AppIcons.link, size: size * 0.54, color: Colors.white),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _email = TextEditingController(text: Session.instance.lastEmail);
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите email и пароль');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.login(email, password);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final controller = TextEditingController(text: _email.text.trim());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => _ForgotSheet(controller: controller),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: AutofillGroup(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 48),
                ),
                const SizedBox(height: 36),
                const Text('Link', style: AppText.display),
                const SizedBox(height: 10),
                Text(
                  'Войдите с рабочим email и паролем',
                  style: AppText.body.copyWith(color: AppColors.ink2),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  hint: 'name@company.kz',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                ),
                const FormGap(),
                AppTextField(
                  label: 'Пароль',
                  controller: _password,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                    icon: Icon(
                      _obscure ? AppIcons.eye : AppIcons.eyeSlash,
                      size: 20,
                      color: AppColors.ink3,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (_error != null) InlineError(_error!),
                const SizedBox(height: 28),
                PrimaryButton(label: 'Войти', loading: _busy, onTap: _submit),
                const SizedBox(height: 12),
                Center(
                  child: CupertinoButton(
                    onPressed: _forgot,
                    child: const Text(
                      'Забыли пароль?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.violet,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet({required this.controller});

  final TextEditingController controller;

  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    final email = widget.controller.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Введите email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Hr.resetPassword(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Сброс пароля', style: AppText.title),
            const SizedBox(height: 8),
            Text(
              _sent
                  ? 'Инструкции отправлены на ${widget.controller.text.trim()}. Проверьте почту.'
                  : 'Отправим ссылку для создания нового пароля.',
              style: AppText.body.copyWith(color: AppColors.ink2),
            ),
            const SizedBox(height: 20),
            if (!_sent) ...[
              AppTextField(
                label: 'Email',
                controller: widget.controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _send(),
              ),
              if (_error != null) InlineError(_error!),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Отправить ссылку',
                loading: _busy,
                onTap: _send,
              ),
            ] else
              PrimaryButton(
                label: 'Готово',
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 64),
            SizedBox(height: 24),
            CupertinoActivityIndicator(),
          ],
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = LocalAuthentication();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Разблокировать Link',
      );
      if (ok) Session.instance.markUnlocked();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Не удалось проверить Face ID. Попробуйте ещё раз.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              AppAvatar(name: s.fullName, imageUrl: s.image, size: 88),
              const SizedBox(height: 18),
              Text(
                s.fullName,
                textAlign: TextAlign.center,
                style: AppText.title,
              ),
              const SizedBox(height: 6),
              Text(
                'Link заблокирован',
                style: AppText.body.copyWith(color: AppColors.ink2),
              ),
              if (_error != null) InlineError(_error!),
              const Spacer(),
              PrimaryButton(
                label: 'Разблокировать',
                icon: AppIcons.lockOpen,
                loading: _busy,
                onTap: _unlock,
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => s.logout(),
                child: const Text(
                  'Выйти из аккаунта',
                  style: TextStyle(color: AppColors.ink2, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoEmployeeScreen extends StatefulWidget {
  const NoEmployeeScreen({super.key});

  @override
  State<NoEmployeeScreen> createState() => _NoEmployeeScreenState();
}

class _NoEmployeeScreenState extends State<NoEmployeeScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyState(
                icon: AppIcons.personCropCircleBadgeExclam,
                title: 'Профиль сотрудника не найден',
                message:
                    'Учётная запись ${s.userId} не привязана к активному сотруднику. Обратитесь в отдел кадров.',
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Проверить снова',
                loading: _busy,
                onTap: () async {
                  setState(() => _busy = true);
                  try {
                    await s.refresh();
                  } catch (e) {
                    if (context.mounted)
                      showToast(context, errorText(e), error: true);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
              CupertinoButton(
                onPressed: () => s.logout(),
                child: const Text('Выйти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
