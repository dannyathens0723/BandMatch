import 'package:flutter/material.dart';

import '../models/member_profile.dart';
import '../services/member_search_service.dart';
import '../widgets/member_card.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final _memberSearchService = MemberSearchService();
  late Future<List<MemberProfile>> _members;

  @override
  void initState() {
    super.initState();
    _members = _memberSearchService.fetchMembers();
  }

  void _reload() =>
      setState(() => _members = _memberSearchService.fetchMembers());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバーを探す'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MemberProfile>>(
          future: _members,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MemberListError(error: snapshot.error!, onRetry: _reload);
            }

            final members = snapshot.requireData;
            if (members.isEmpty) return const _EmptyMemberList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 640
                        ? 2
                        : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 380,
                      ),
                      itemCount: members.length,
                      itemBuilder: (context, index) =>
                          MemberCard(member: members[index]),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyMemberList extends StatelessWidget {
  const _EmptyMemberList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 44),
              const SizedBox(height: 16),
              Text(
                '表示できるメンバーはまだいません',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('ほかのメンバーが登録されると、ここに表示されます。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberListError extends StatelessWidget {
  const _MemberListError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 16),
              const Text('メンバー一覧を読み込めませんでした'),
              const SizedBox(height: 8),
              Text('詳細: $error', maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}
