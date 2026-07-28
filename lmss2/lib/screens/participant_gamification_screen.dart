import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';
import '../widgets/badge_icon.dart';

class ParticipantGamificationScreen extends StatefulWidget {
  final int initialTab;
  const ParticipantGamificationScreen({super.key, this.initialTab = 0});
  @override
  State<ParticipantGamificationScreen> createState() => _State();
}

class _State extends State<ParticipantGamificationScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  bool loading = true;
  String? error;
  int balance = 0;
  List<Map<String, dynamic>> rewards = [],
      redemptions = [],
      badges = [],
      leaders = [],
      certificates = [];
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    var successCount = 0;
    await Future.wait<void>([
      _api
          .getRewards()
          .then((store) {
            balance = (store['balance'] as num?)?.toInt() ?? 0;
            rewards = List<Map<String, dynamic>>.from(
              store['rewards'] ?? const [],
            );
            redemptions = List<Map<String, dynamic>>.from(
              store['redemptions'] ?? const [],
            );
            successCount++;
          })
          .catchError((_) {}),
      _api
          .getMyBadges()
          .then((value) {
            badges = value;
            successCount++;
          })
          .catchError((_) {}),
      _api
          .getLeaderboard()
          .then((value) {
            leaders = List<Map<String, dynamic>>.from(
              value['leaderboard'] ?? const [],
            );
            successCount++;
          })
          .catchError((_) {}),
      _api
          .getCertificates()
          .then((value) {
            certificates = value;
            successCount++;
          })
          .catchError((_) {}),
    ]);
    error = successCount == 0
        ? 'Achievements are temporarily unavailable.'
        : null;
    if (mounted) setState(() => loading = false);
  }

  Widget _rewards() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: ListTile(
          leading: const Icon(Icons.bolt),
          title: Text('$balance XP'),
          subtitle: const Text('Available balance'),
        ),
      ),
      ...rewards.map(
        (r) => Card(
          child: ListTile(
            title: Text(r['title']?.toString() ?? ''),
            subtitle: Text(
              '${r['description'] ?? ''}\n${r['xp_cost']} XP • ${r['stock'] == -1 ? 'Unlimited' : '${r['stock']} left'}',
            ),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: balance >= (r['xp_cost'] as num).toInt()
                  ? () async {
                      await _api.redeemReward(r['id'] as int);
                      await _load();
                    }
                  : null,
              child: const Text('Redeem'),
            ),
          ),
        ),
      ),
      if (redemptions.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 18),
          child: Text(
            'My redemptions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ...redemptions.map(
        (r) => ListTile(
          title: Text(r['title']?.toString() ?? ''),
          subtitle: Text(r['redeemed_at']?.toString() ?? ''),
          trailing: Chip(label: Text(r['status']?.toString() ?? '')),
        ),
      ),
    ],
  );
  Widget _badges() => badges.isEmpty
      ? const Center(child: Text('No badges earned yet.'))
      : GridView.extent(
          padding: const EdgeInsets.all(20),
          maxCrossAxisExtent: 260,
          children: badges
              .map(
                (b) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BadgeIcon(value: b['icon_path']?.toString()),
                        Text(
                          b['name']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          b['description']?.toString() ?? '',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
  Widget _leaderboard() => ListView.builder(
    padding: const EdgeInsets.all(20),
    itemCount: leaders.length,
    itemBuilder: (c, i) {
      final e = leaders[i];
      return Card(
        color: e['is_me'] == true
            ? Theme.of(c).colorScheme.primaryContainer
            : null,
        child: ListTile(
          leading: CircleAvatar(child: Text('${e['rank']}')),
          title: Text(e['display_name']?.toString() ?? ''),
          subtitle: Text(
            '${e['store_code'] ?? ''} • ${e['chapters_completed'] ?? 0} chapters • ${e['quizzes_taken'] ?? 0} quizzes',
          ),
          trailing: Text(
            '${e['total_xp'] ?? 0} XP',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    },
  );
  Widget _certificates() => certificates.isEmpty
      ? const Center(child: Text('Complete a course to earn a certificate.'))
      : ListView(
          padding: const EdgeInsets.all(20),
          children: certificates
              .map(
                (c) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.workspace_premium),
                    ),
                    title: Text(c['course_title']?.toString() ?? ''),
                    subtitle: Text('Completed ${c['completed_at'] ?? ''}'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => context.go(
                      '/participant/certificates/${c['course_id']}',
                    ),
                  ),
                ),
              )
              .toList(),
        );
  @override
  Widget build(BuildContext context) => LmsShell(
    title: 'Rewards & Achievements',
    rootPage: true,
    actions: [
      IconButton(
        tooltip: 'Refresh achievements',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Rewards'),
            Tab(text: 'Badges'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Certificates'),
          ],
        ),
        Expanded(
          child: loading
              ? const LmsLoadingState(label: 'Loading achievements')
              : error != null
              ? LmsErrorState(
                  message: 'We could not load your achievements.',
                  onRetry: _load,
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _rewards(),
                    _badges(),
                    _leaderboard(),
                    _certificates(),
                  ],
                ),
        ),
      ],
    ),
  );
}
