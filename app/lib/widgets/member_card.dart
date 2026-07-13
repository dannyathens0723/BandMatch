import 'package:flutter/material.dart';

import '../models/member_profile.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.member, this.onTap});

  final MemberProfile member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (member.age != null) '${member.age}歳',
      if (member.gender != null) _genderLabel(member.gender!),
      if (member.experienceLevel != null)
        _experienceLevelLabel(member.experienceLevel!),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(
                    avatarUrl: member.avatarUrl,
                    displayName: member.displayName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle.join(' ・ '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (member.purposes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TagGroup(
                  icon: Icons.flag_outlined,
                  labels: member.purposes.map(_purposeLabel).toList(),
                ),
              ],
              if (member.partNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TagGroup(
                  icon: Icons.music_note_outlined,
                  labels: member.partNames,
                ),
              ],
              if (member.genreNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TagGroup(
                  icon: Icons.queue_music_outlined,
                  labels: member.genreNames,
                ),
              ],
              if (member.areaNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TagGroup(
                  icon: Icons.location_on_outlined,
                  labels: member.areaNames,
                ),
              ],
              if (member.bio case final bio? when bio.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(bio, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _purposeLabel(String value) {
    return switch (value) {
      'recruit' => 'メンバー募集',
      'join' => '参加希望',
      'practice' => '練習仲間探し',
      _ => value,
    };
  }

  String _experienceLevelLabel(String value) {
    return switch (value) {
      'beginner_new' => '未経験・始めたばかり',
      'beginner' => '初心者',
      'experienced' => '経験者',
      'pro_oriented' => 'プロ志向',
      _ => value,
    };
  }

  String _genderLabel(String value) {
    return switch (value) {
      'male' => '男性',
      'female' => '女性',
      'non_binary' => 'ノンバイナリー',
      'no_answer' => '回答しない',
      _ => value,
    };
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 25,
        child: Text(displayName.characters.first),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 25, child: Text(displayName.characters.first)),
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.icon, required this.labels});

  final IconData icon;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: labels.map((label) => Chip(label: Text(label))).toList(),
          ),
        ),
      ],
    );
  }
}
