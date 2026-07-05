import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/auth_provider.dart';

const _adminEmail = 'kdanalyticsai@gmail.com';

class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _expiring = [];
  List<Map<String, dynamic>> _flagged  = [];
  bool _loading = true;
  String? _error;

  bool get _isAdmin =>
      ref.read(authUserProvider).valueOrNull?.email == _adminEmail;

  @override
  void initState() {
    super.initState();
    if (_isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait([
        db.rpc('admin_stats') as Future,
        db.rpc('admin_expiring_subs') as Future,
        db.from('ai_feedback')
            .select('id, mode, language, question, response, created_at')
            .eq('rating', -1)
            .order('created_at', ascending: false),
      ]);
      setState(() {
        _stats    = (results[0] as Map?)?.cast<String, dynamic>();
        _expiring = List<Map<String, dynamic>>.from(results[1] as Iterable? ?? []);
        _flagged  = List<Map<String, dynamic>>.from(results[2] as Iterable? ?? []);
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(backgroundColor: SacredTheme.deepMeditativeIndigo, foregroundColor: Colors.white),
        body: const Center(child: Text('Access denied.', style: TextStyle(color: SacredTheme.outline))),
      );
    }

    return Scaffold(
      backgroundColor: SacredTheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Profile',
        ),
        title: const Text('Admin Dashboard'),
        backgroundColor: SacredTheme.deepMeditativeIndigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _loading ? null : _load,
        backgroundColor: SacredTheme.deepMeditativeIndigo,
        foregroundColor: Colors.white,
        tooltip: 'Refresh data',
        child: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionLabel('USERS'),
                      _kpiRow([
                        _KpiCard(label: 'Total Users',     value: '${_stats?['total_users'] ?? 0}',    icon: Icons.people_outline,     color: SacredTheme.primary),
                        _KpiCard(label: 'New (30d)',        value: '${_stats?['new_users_30d'] ?? 0}',  icon: Icons.person_add_outlined, color: Colors.green),
                      ]),
                      const SizedBox(height: 16),

                      _sectionLabel('REVENUE & SUBSCRIPTIONS'),
                      _kpiRow([
                        _KpiCard(label: 'Total Revenue', value: '₹${_formatNum(_stats?['revenue_all_inr'] ?? 0)}', icon: Icons.currency_rupee, color: SacredTheme.templeGold),
                        _KpiCard(label: 'Active Subs',   value: '${_stats?['subs_active'] ?? 0}',                  icon: Icons.star_outline,   color: Colors.deepPurple),
                      ]),
                      const SizedBox(height: 8),
                      _kpiRow([
                        _KpiCard(label: 'Sadhaka Plan', value: '${_stats?['subs_sadhaka'] ?? 0}', icon: Icons.spa_outlined,          color: Colors.teal),
                        _KpiCard(label: 'Annual Plan',  value: '${_stats?['subs_annual'] ?? 0}',  icon: Icons.workspace_premium_outlined, color: Colors.orange),
                      ]),
                      const SizedBox(height: 16),

                      _sectionLabel('EXPIRING IN 7 DAYS  •  ${_stats?['expiring_7d'] ?? 0} users'),
                      if (_expiring.isEmpty)
                        _emptyChip('No subscriptions expiring soon')
                      else
                        ..._expiring.map((u) => _ExpiringTile(user: u)),
                      const SizedBox(height: 16),

                      _sectionLabel('AI QUALITY'),
                      _kpiRow([
                        _KpiCard(label: 'Total Queries', value: '${_stats?['ai_total'] ?? 0}',      icon: Icons.chat_bubble_outline, color: SacredTheme.primary),
                        _KpiCard(label: 'Rated',         value: '${_stats?['ai_rated'] ?? 0}',      icon: Icons.thumbs_up_down,      color: Colors.blueGrey),
                      ]),
                      const SizedBox(height: 8),
                      _SatisfactionBar(
                        up:   _stats?['ai_thumbs_up']   as int? ?? 0,
                        down: _stats?['ai_thumbs_down']  as int? ?? 0,
                      ),
                      const SizedBox(height: 8),
                      _kpiRow([
                        _KpiCard(label: 'Scholar Mode', value: '${_stats?['ai_mode_scholar'] ?? 0}', icon: Icons.menu_book_outlined, color: Colors.indigo),
                        _KpiCard(label: 'Guru Mode',    value: '${_stats?['ai_mode_guru'] ?? 0}',    icon: Icons.self_improvement,  color: Colors.deepPurple),
                      ]),
                      const SizedBox(height: 16),

                      _sectionLabel('ENGAGEMENT'),
                      _kpiRow([
                        _KpiCard(label: 'Sadhana (7d)', value: '${_stats?['sadhana_active_7d'] ?? 0}', icon: Icons.local_fire_department_outlined, color: Colors.deepOrange),
                        _KpiCard(label: 'Cache Size',   value: '${_stats?['cache_entries'] ?? 0}',     icon: Icons.bolt_outlined,                  color: Colors.amber),
                      ]),
                      const SizedBox(height: 8),
                      _kpiRow([
                        _KpiCard(label: 'Community Posts', value: '${_stats?['community_posts'] ?? 0}', icon: Icons.forum_outlined, color: Colors.teal),
                        _KpiCard(label: 'Top Language',    value: '${(_stats?['top_language'] as String? ?? '—').toUpperCase()}', icon: Icons.language, color: Colors.green),
                      ]),
                      const SizedBox(height: 16),

                      _sectionLabel('FLAGGED RESPONSES  •  ${_flagged.length}'),
                      if (_flagged.isEmpty)
                        _emptyChip('No thumbs-down responses')
                      else
                        ..._flagged.map((r) => _FlaggedCard(row: r)),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
          color: SacredTheme.outline, letterSpacing: 1.0)),
  );

  Widget _kpiRow(List<Widget> cards) => Row(
    children: cards.expand((c) => [Expanded(child: c), const SizedBox(width: 8)]).toList()
      ..removeLast(),
  );

  Widget _emptyChip(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: const TextStyle(fontSize: 13, color: SacredTheme.outline)),
  );

  String _formatNum(dynamic v) {
    final n = (v is int) ? v : int.tryParse('$v') ?? 0;
    if (n >= 100000) return '${(n / 100).round() / 10}L';
    if (n >= 1000)   return '${(n / 100).round() / 10}k';
    return '$n';
  }
}

// ── KPI card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: SacredTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        border: Border.all(color: SacredTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: SacredTheme.onSurface)),
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: SacredTheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Satisfaction bar ──────────────────────────────────────────────────────────

class _SatisfactionBar extends StatelessWidget {
  final int up;
  final int down;
  const _SatisfactionBar({required this.up, required this.down});

  @override
  Widget build(BuildContext context) {
    final total = up + down;
    final pct   = total == 0 ? 0.0 : up / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SacredTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        border: Border.all(color: SacredTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Satisfaction rate', style: GoogleFonts.inter(fontSize: 12, color: SacredTheme.outline)),
              Text('${(pct * 100).round()}%  ($up 👍  $down 👎)',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SacredTheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.red.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(pct >= 0.7 ? Colors.green : Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expiring subscription tile ────────────────────────────────────────────────

class _ExpiringTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _ExpiringTile({required this.user});

  String _daysLeft(String? iso) {
    if (iso == null) return '';
    final end = DateTime.tryParse(iso);
    if (end == null) return '';
    final diff = end.difference(DateTime.now()).inDays;
    return diff == 0 ? 'today' : 'in $diff day${diff == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final name  = user['full_name']  as String? ?? 'Unknown';
    final email = user['email']      as String? ?? '';
    final tier  = (user['subscription_tier'] as String? ?? '').toUpperCase();
    final end   = user['subscription_end'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SacredTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SacredTheme.onSurface)),
                Text(email, style: GoogleFonts.inter(fontSize: 11, color: SacredTheme.outline)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tier, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: SacredTheme.primary)),
              Text(_daysLeft(end), style: GoogleFonts.inter(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Flagged response card ─────────────────────────────────────────────────────

class _FlaggedCard extends StatefulWidget {
  final Map<String, dynamic> row;
  const _FlaggedCard({required this.row});

  @override
  State<_FlaggedCard> createState() => _FlaggedCardState();
}

class _FlaggedCardState extends State<_FlaggedCard> {
  bool _expanded = false;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final mode     = (widget.row['mode']     as String? ?? '').toUpperCase();
    final lang     = widget.row['language']  as String? ?? '';
    final question = widget.row['question']  as String? ?? '';
    final response = widget.row['response']  as String? ?? '';
    final dateStr  = _formatDate(widget.row['created_at'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: SacredTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        side: BorderSide(color: Colors.red.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Chip(label: mode),
                const SizedBox(width: 6),
                _Chip(label: lang, secondary: true),
                const Spacer(),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: SacredTheme.outline)),
              ],
            ),
            const SizedBox(height: 10),
            const Text('QUESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SacredTheme.outline, letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(question, style: const TextStyle(fontSize: 13, color: SacredTheme.onSurface)),
            const SizedBox(height: 10),
            const Text('AI RESPONSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SacredTheme.outline, letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(
              response,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: SacredTheme.onSurfaceVariant),
            ),
            if (response.length > 200)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_expanded ? 'Show less' : 'Show more',
                      style: const TextStyle(fontSize: 12, color: SacredTheme.primary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool secondary;
  const _Chip({required this.label, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    final color = secondary ? SacredTheme.outlineVariant : SacredTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load dashboard:\n$error', textAlign: TextAlign.center,
                style: const TextStyle(color: SacredTheme.outline)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
