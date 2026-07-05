import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/auth_provider.dart';

const _adminEmail = 'kdanalyticsai@gmail.com';

class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  List<Map<String, dynamic>> _flagged = [];
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('ai_feedback')
          .select('id, mode, language, question, response, created_at')
          .eq('rating', -1)
          .order('created_at', ascending: false);
      setState(() {
        _flagged = List<Map<String, dynamic>>.from(rows as Iterable);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: SacredTheme.deepMeditativeIndigo,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Access denied.',
            style: TextStyle(color: SacredTheme.outline),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SacredTheme.surface,
      appBar: AppBar(
        title: const Text('Flagged Responses'),
        backgroundColor: SacredTheme.deepMeditativeIndigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading data:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SacredTheme.outline),
                    ),
                  ),
                )
              : _flagged.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: SacredTheme.primary),
                          SizedBox(height: 12),
                          Text(
                            'No flagged responses\nAll AI answers rated positively.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SacredTheme.outline, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _flagged.length,
                        itemBuilder: (context, i) => _FlaggedCard(row: _flagged[i]),
                      ),
                    ),
    );
  }
}

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
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode     = (widget.row['mode']     as String? ?? '').toUpperCase();
    final lang     = widget.row['language']  as String? ?? '';
    final question = widget.row['question']  as String? ?? '';
    final response = widget.row['response']  as String? ?? '';
    final dateStr  = _formatDate(widget.row['created_at'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            // Header row
            Row(
              children: [
                _ModeChip(label: mode),
                const SizedBox(width: 6),
                _ModeChip(label: lang, color: SacredTheme.outlineVariant),
                const Spacer(),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: SacredTheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Question
            const Text('QUESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SacredTheme.outline, letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(question, style: const TextStyle(fontSize: 13, color: SacredTheme.onSurface)),

            const SizedBox(height: 10),

            // Response (collapsible)
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
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(fontSize: 12, color: SacredTheme.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _ModeChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? SacredTheme.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color ?? SacredTheme.primary,
        ),
      ),
    );
  }
}
