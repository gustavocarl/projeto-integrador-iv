import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/store.dart';
import '../controllers/store_providers.dart';
import '../widgets/store_area_view.dart';

/// Admin: approves a request, or changes a user's role and the parts of the app they use,
/// or removes them. Pops with the message for the list's snack bar.
class StoreMemberPage extends ConsumerStatefulWidget {
  const StoreMemberPage({super.key, required this.member});

  final StoreMember member;

  @override
  ConsumerState<StoreMemberPage> createState() => _StoreMemberPageState();
}

class _StoreMemberPageState extends BaseState<StoreMemberPage> {
  late StoreRole _role = widget.member.isPending
      ? StoreRole.member
      : widget.member.role;

  /// A request starts with everything ticked; the admin unticks what the person won't use.
  late final Set<StoreArea> _areas = widget.member.isPending
      ? {...StoreArea.values}
      : {...widget.member.areas};

  StoreMember get _member => widget.member;

  bool get _isMe => _member.id == ref.read(authControllerProvider).value?.id;

  Future<void> _save() async {
    final controller = ref.read(storeMembersProvider.notifier);
    final saved = await runSafely(
      () => _member.isPending
          ? controller.approve(_member.id, _areas)
          : controller.save(_member, role: _role, areas: _areas),
    );
    if (saved == null || !mounted) return;

    // An admin who stepped down can't manage users anymore.
    if (_isMe && saved.role != StoreRole.admin) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pop(
      _member.isPending
          ? 'Acesso de ${_member.name} aprovado.'
          : 'Alterações de ${_member.name} salvas.',
    );
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isMe ? 'Sair da loja?' : 'Remover ${_member.name}?'),
        content: Text(
          _isMe
              ? 'Você perde o acesso aos dados da loja.'
              : '${_member.name} perde o acesso aos dados da loja. Para voltar, '
                    'precisa pedir acesso de novo com o código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isMe ? 'Sair' : 'Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await runSafely(() async {
      await ref.read(storeMembersProvider.notifier).remove(_member.id);
      return true;
    });
    if (removed != true || !mounted) return;
    if (_isMe) {
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pop('${_member.name} foi removido da loja.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isAdmin = _role == StoreRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(_member.name)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_member.email, style: muted),
                const SizedBox(height: 16),
                if (_member.isPending)
                  Text(
                    'Pediu acesso à loja. Escolha o que ${_member.name} poderá usar:',
                    style: theme.textTheme.bodyLarge,
                  )
                else ...[
                  Text('Papel', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<StoreRole>(
                    segments: const [
                      ButtonSegment(
                        value: StoreRole.member,
                        icon: Icon(Icons.person_outline),
                        label: Text('Usuário'),
                      ),
                      ButtonSegment(
                        value: StoreRole.admin,
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        label: Text('Admin'),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: isLoading
                        ? null
                        : (selection) => setState(() {
                            clearFailure();
                            _role = selection.first;
                          }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Admin usa todas as partes e gerencia a loja e os usuários.'
                        : 'Usuário usa só as partes marcadas abaixo.',
                    style: muted,
                  ),
                  const SizedBox(height: 24),
                  Text('Partes do sistema', style: theme.textTheme.titleSmall),
                ],
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final area in StoreArea.values)
                        CheckboxListTile(
                          key: Key('area_${area.name}'),
                          secondary: Icon(area.icon),
                          title: Text(area.label),
                          subtitle: Text(area.description),
                          value: isAdmin || _areas.contains(area),
                          onChanged: isAdmin || isLoading
                              ? null
                              : (checked) => setState(() {
                                  clearFailure();
                                  checked == true
                                      ? _areas.add(area)
                                      : _areas.remove(area);
                                }),
                        ),
                    ],
                  ),
                ),
                if (fieldError('areas') case final error?) ...[
                  const SizedBox(height: 8),
                  Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ],
                if (!isAdmin && _areas.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sem nenhuma parte marcada, a pessoa entra no app mas não vê nada.',
                    style: muted,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('saveMember'),
                  onPressed: isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: Icon(
                    _member.isPending ? Icons.how_to_reg : Icons.save_outlined,
                  ),
                  label: Text(
                    _member.isPending ? 'Aprovar acesso' : 'Salvar alterações',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('removeMember'),
                  onPressed: isLoading ? null : _remove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: Icon(
                    _member.isPending
                        ? Icons.block
                        : _isMe
                        ? Icons.logout
                        : Icons.person_remove_outlined,
                  ),
                  label: Text(
                    _member.isPending
                        ? 'Recusar pedido'
                        : _isMe
                        ? 'Sair da loja'
                        : 'Remover da loja',
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
