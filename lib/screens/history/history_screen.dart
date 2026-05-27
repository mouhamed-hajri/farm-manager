import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/history_entry.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_field.dart';

const _monthsFr = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];
const _monthsShortFr = [
  'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
  'juil', 'aoû', 'sep', 'oct', 'nov', 'déc',
];

// ─── Filter constants ────────────────────────────────────────────────────────

enum _Period { today, week, month, year, all, custom }

const _periodLabels = {
  _Period.today: "Aujourd'hui",
  _Period.week: '7 jours',
  _Period.month: 'Mois',
  _Period.year: 'Année',
  _Period.all: 'Tout',
};

enum _Type { all, born, sold, dead, sale, expense }

const _typeLabels = {
  _Type.all: 'Tout',
  _Type.born: '🐑 Nés',
  _Type.sold: '💰 Vendus',
  _Type.dead: '✝ Décès',
  _Type.sale: '🌾 Ventes',
  _Type.expense: '💸 Dépenses',
};

bool _matchesType(HistoryEntry e, _Type t) {
  switch (t) {
    case _Type.born:
      return e.actionType == 'animal_added';
    case _Type.sold:
      return e.actionType == 'animal_sold';
    case _Type.dead:
      return e.actionType == 'animal_died';
    case _Type.sale:
      return const {'crop_sold', 'product_sold', 'sale_added'}
          .contains(e.actionType);
    case _Type.expense:
      return e.actionType == 'expense_added';
    case _Type.all:
      return true;
  }
}

Color _typeColor(_Type t) {
  switch (t) {
    case _Type.born:
      return AppColors.green;
    case _Type.sold:
      return AppColors.blue;
    case _Type.dead:
      return AppColors.red;
    case _Type.sale:
      return Colors.teal;
    case _Type.expense:
      return Colors.orange;
    case _Type.all:
      return Colors.blueGrey;
  }
}

Color _entryColor(String actionType) {
  switch (actionType) {
    case 'animal_added':
      return AppColors.green;
    case 'animal_sold':
      return AppColors.blue;
    case 'animal_died':
      return AppColors.red;
    case 'crop_sold':
    case 'product_sold':
    case 'sale_added':
      return Colors.teal;
    case 'expense_added':
      return Colors.orange;
    case 'backup_completed':
    case 'restore_completed':
      return Colors.deepPurple;
    default:
      return Colors.grey;
  }
}

IconData _entryIcon(String actionType) {
  switch (actionType) {
    case 'animal_added':
      return Icons.add_circle_outline;
    case 'animal_sold':
      return Icons.sell_outlined;
    case 'animal_died':
      return Icons.cancel_outlined;
    case 'crop_sold':
    case 'product_sold':
    case 'sale_added':
      return Icons.eco_outlined;
    case 'expense_added':
      return Icons.money_off_outlined;
    case 'backup_completed':
      return Icons.cloud_done_outlined;
    case 'restore_completed':
      return Icons.restore;
    default:
      return Icons.info_outline;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _search = '';
  _Period _period = _Period.all;
  _Type _type = _Type.all;
  DateTimeRange? _customRange;
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 300;
      if (show != _showFab) setState(() => _showFab = show);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ───────────────────────────────────────────────────────────────

  bool _inPeriod(HistoryEntry e) {
    if (_period == _Period.all) return true;
    final d = DateTime.tryParse(e.date);
    if (d == null) return false;
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case _Period.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        return d.isAfter(weekAgo);
      case _Period.month:
        return d.year == now.year && d.month == now.month;
      case _Period.year:
        return d.year == now.year;
      case _Period.custom:
        if (_customRange == null) return true;
        return !d.isBefore(_customRange!.start) &&
            !d.isAfter(_customRange!.end.add(const Duration(days: 1)));
      case _Period.all:
        return true;
    }
  }

  List<HistoryEntry> _filter(List<HistoryEntry> all) {
    var list = all.where(_inPeriod).toList();
    if (_type != _Type.all) {
      list = list.where((e) => _matchesType(e, _type)).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              (e.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String, int> _typeCounts(List<HistoryEntry> filteredByPeriod) {
    return {
      for (final t in _Type.values)
        t.name: t == _Type.all
            ? filteredByPeriod.length
            : filteredByPeriod.where((e) => _matchesType(e, t)).length,
    };
  }

  Map<String, List<HistoryEntry>> _groupByMonth(List<HistoryEntry> entries) {
    final groups = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      final key = e.date.length >= 7 ? e.date.substring(0, 7) : e.date;
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return key;
    return '${_monthsFr[m - 1]} ${parts[0]}';
  }

  String _periodSubtitle() {
    switch (_period) {
      case _Period.today:
        return "Aujourd'hui";
      case _Period.week:
        return '7 derniers jours';
      case _Period.month:
        return 'Ce mois-ci';
      case _Period.year:
        return 'Cette année';
      case _Period.all:
        return "Depuis le début";
      case _Period.custom:
        if (_customRange == null) return 'Personnalisé';
        return '${_fmtShortDate(_customRange!.start)} → ${_fmtShortDate(_customRange!.end)}';
    }
  }

  static String _fmtShortDate(DateTime d) {
    return '${d.day} ${_monthsShortFr[d.month - 1]}';
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _pickCustomRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _CustomRangeDialog(initial: _customRange),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = _Period.custom;
      });
    }
  }

  Future<void> _showEntrySheet(HistoryEntry entry) async {
    final canNavigate =
        entry.relatedType == 'animal' && entry.relatedId != null;
    final color = _entryColor(entry.actionType);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_entryIcon(entry.actionType), color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                entry.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (entry.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  entry.description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _fmtFullDate(entry.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            if (canNavigate)
              ListTile(
                leading: const Icon(Icons.open_in_new, color: AppColors.blue),
                title: const Text('Voir la fiche'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/animals/animal/${entry.relatedId}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(ctx);
                _copyEntry(entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.red),
              title: Text('Supprimer',
                  style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(entry);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copyEntry(HistoryEntry entry) {
    final buf = StringBuffer();
    buf.writeln(entry.title);
    if (entry.description?.isNotEmpty ?? false) buf.writeln(entry.description);
    buf.writeln(_fmtFullDate(entry.date));
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _toast('Copié', icon: Icons.copy, color: AppColors.green);
  }

  Future<void> _confirmDelete(HistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: Text(
          '"${entry.title}"\n\nCette action est irréversible et supprime aussi la copie en ligne.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repo = ref.read(historyRepositoryProvider);
      await repo.deleteEntry(entry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Entrée supprimée'),
            ]),
            action: SnackBarAction(
              textColor: Colors.white,
              label: 'Annuler',
              onPressed: () async {
                await repo.insertHistoryDirect(entry);
              },
            ),
          ),
        );
      }
    }
  }

  void _exportFiltered(List<HistoryEntry> filtered) {
    final now = DateTime.now();
    final nowStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final buf = StringBuffer();
    buf.writeln('=== HISTORIQUE — ${_periodSubtitle()} ===');
    buf.writeln('Type : ${_typeLabels[_type]}');
    buf.writeln('Exporté le $nowStr');
    buf.writeln();
    final groups = _groupByMonth(filtered);
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in keys) {
      buf.writeln();
      buf.writeln('[${_monthLabel(key)}]');
      for (final e in groups[key]!) {
        buf.writeln('  - ${e.date} : ${e.title}');
        if (e.description?.isNotEmpty ?? false) {
          buf.writeln('    ${e.description}');
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _toast('Historique copié (${filtered.length} entrées)',
        icon: Icons.copy, color: AppColors.green);
  }

  void _toast(String msg, {required IconData icon, required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
    ));
  }

  String _fmtFullDate(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return iso;
    return '${parts[2]} ${_monthsFr[m - 1].toLowerCase()} ${parts[0]}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(historyListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Historique'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
              onPressed: () => _scrollCtrl.animateTo(0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic),
              backgroundColor: AppColors.green,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
      body: histAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (all) {
          // First pass: filter by period only (so type counts reflect period scope)
          final byPeriod = all.where(_inPeriod).toList();
          final counts = _typeCounts(byPeriod);

          final filtered = _filter(all);
          final groups = _groupByMonth(filtered);
          final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(historyListProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            color: AppColors.green,
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Filter chips header ──
                SliverToBoxAdapter(
                  child: _FilterHeader(
                    period: _period,
                    onPeriodChanged: (p) => setState(() => _period = p),
                    onPickCustom: _pickCustomRange,
                    customRange: _customRange,
                    type: _type,
                    onTypeChanged: (t) => setState(() => _type = t),
                    typeCounts: counts,
                    search: _search,
                    searchCtrl: _searchCtrl,
                    onSearch: (v) => setState(() => _search = v.trim()),
                    totalCount: filtered.length,
                    periodSubtitle: _periodSubtitle(),
                    onExport: () => _exportFiltered(filtered),
                  ),
                ),

                // ── Empty state ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      hasSearch: _search.isNotEmpty,
                      hasFilters: _type != _Type.all || _period != _Period.all,
                      search: _search,
                      onClearFilters: () {
                        setState(() {
                          _type = _Type.all;
                          _period = _Period.all;
                          _customRange = null;
                          _search = '';
                          _searchCtrl.clear();
                        });
                      },
                    ),
                  )
                else ...[
                  // ── Timeline grouped by month ──
                  for (final key in keys) ...[
                    SliverToBoxAdapter(
                      child: _MonthHeader(
                        label: _monthLabel(key),
                        count: groups[key]!.length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      sliver: SliverList.separated(
                        itemCount: groups[key]!.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final entry = groups[key]![i];
                          return _EntryCard(
                            entry: entry,
                            onTap: () {
                              if (entry.relatedType == 'animal' &&
                                  entry.relatedId != null) {
                                context.push(
                                    '/animals/animal/${entry.relatedId}');
                              } else {
                                _showEntrySheet(entry);
                              }
                            },
                            onLongPress: () => _showEntrySheet(entry),
                          );
                        },
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Filter Header ───────────────────────────────────────────────────────────

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.period,
    required this.onPeriodChanged,
    required this.onPickCustom,
    required this.customRange,
    required this.type,
    required this.onTypeChanged,
    required this.typeCounts,
    required this.search,
    required this.searchCtrl,
    required this.onSearch,
    required this.totalCount,
    required this.periodSubtitle,
    required this.onExport,
  });

  final _Period period;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onPickCustom;
  final DateTimeRange? customRange;
  final _Type type;
  final ValueChanged<_Type> onTypeChanged;
  final Map<String, int> typeCounts;
  final String search;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final int totalCount;
  final String periodSubtitle;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (ID, nom, description)…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: onSearch,
            ),
          ),

          // Period chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in _Period.values.where((p) => p != _Period.custom))
                  _PeriodChip(
                    label: _periodLabels[p]!,
                    selected: period == p,
                    onTap: () => onPeriodChanged(p),
                  ),
                _PeriodChip(
                  label: customRange == null
                      ? '📅 Personnalisé'
                      : '📅 ${_HistoryScreenState._fmtShortDate(customRange!.start)} → ${_HistoryScreenState._fmtShortDate(customRange!.end)}',
                  selected: period == _Period.custom,
                  onTap: onPickCustom,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Type chips with counts
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in _Type.values)
                  _TypeChip(
                    label: _typeLabels[t]!,
                    count: typeCounts[t.name] ?? 0,
                    color: _typeColor(t),
                    selected: type == t,
                    onTap: () => onTypeChanged(t),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Result count strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      children: [
                        TextSpan(
                          text: '$totalCount entrée${totalCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        TextSpan(text: ' · $periodSubtitle'),
                      ],
                    ),
                  ),
                ),
                if (totalCount > 0)
                  InkWell(
                    onTap: onExport,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.copy_all_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('Exporter',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chips ───────────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.green : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3),
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month Header ────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.green,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Divider(color: Colors.grey.shade300, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entry Card ──────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = _entryColor(entry.actionType);
    final icon = _entryIcon(entry.actionType);
    final canNavigate =
        entry.relatedType == 'animal' && entry.relatedId != null;
    final dayLabel = _dayLabel(entry.date);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vertical accent stripe
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                // Day badge
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel.day,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayLabel.month,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Icon
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.description?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 3),
                          Text(
                            entry.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Chevron / more
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: canNavigate
                      ? Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey[400])
                      : Icon(Icons.more_vert,
                          size: 16, color: Colors.grey[300]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static ({String day, String month}) _dayLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return (day: '?', month: '');
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return (day: parts[2], month: '');
    return (day: parts[2], month: _monthsShortFr[m - 1].toUpperCase());
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearch,
    required this.hasFilters,
    required this.search,
    required this.onClearFilters,
  });
  final bool hasSearch;
  final bool hasFilters;
  final String search;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch
                ? 'Aucun résultat pour "$search"'
                : hasFilters
                    ? 'Aucune entrée pour ce filtre'
                    : 'Pas encore d\'historique',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch || hasFilters
                ? 'Essayez d\'élargir vos filtres.'
                : 'Les actions sur la ferme s\'afficheront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          if (hasSearch || hasFilters) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réinitialiser les filtres'),
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Custom date-range dialog (typeable) ─────────────────────────────────────

class _CustomRangeDialog extends StatefulWidget {
  const _CustomRangeDialog({this.initial});
  final DateTimeRange? initial;

  @override
  State<_CustomRangeDialog> createState() => _CustomRangeDialogState();
}

class _CustomRangeDialogState extends State<_CustomRangeDialog> {
  DateTime? _start;
  DateTime? _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end = widget.initial?.end;
  }

  void _confirm() {
    if (_start == null || _end == null) {
      setState(() => _error = 'Renseignez les deux dates');
      return;
    }
    if (_end!.isBefore(_start!)) {
      setState(() => _error = 'La fin doit être après le début');
      return;
    }
    Navigator.pop(context, DateTimeRange(start: _start!, end: _end!));
  }

  Widget _quickShortcut(String label, DateTime start, DateTime end) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => setState(() {
        _start = start;
        _end = end;
        _error = null;
      }),
      backgroundColor: AppColors.green.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.green.withValues(alpha: 0.3)),
      labelStyle: const TextStyle(color: AppColors.green),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.date_range, color: AppColors.green),
        const SizedBox(width: 8),
        const Text('Période personnalisée'),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(
              label: 'Du',
              initialDate: _start,
              lastDate: now,
              required: true,
              onChanged: (d) => setState(() {
                _start = d;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Au',
              initialDate: _end,
              lastDate: now,
              required: true,
              onChanged: (d) => setState(() {
                _end = d;
                _error = null;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: AppColors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: AppColors.red, fontSize: 12)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            const Text('Raccourcis',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _quickShortcut('30 derniers jours',
                    now.subtract(const Duration(days: 30)), now),
                _quickShortcut('Trimestre',
                    DateTime(now.year, now.month - 3, now.day), now),
                _quickShortcut('6 mois',
                    DateTime(now.year, now.month - 6, now.day), now),
                _quickShortcut('Année en cours',
                    DateTime(now.year, 1, 1), now),
                _quickShortcut("Année dernière",
                    DateTime(now.year - 1, 1, 1),
                    DateTime(now.year - 1, 12, 31)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _confirm,
          child: const Text('OK', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
