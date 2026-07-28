class StageRecruitmentPreview {
  const StageRecruitmentPreview({
    required this.title,
    required this.crewName,
    required this.genre,
    required this.area,
    required this.experience,
    required this.remaining,
    required this.deadline,
    this.badge,
  });

  final String title;
  final String crewName;
  final String genre;
  final String area;
  final String experience;
  final String remaining;
  final String deadline;
  final String? badge;
}

class StageEventPreview {
  const StageEventPreview({
    required this.title,
    required this.category,
    required this.date,
    required this.place,
    required this.source,
    required this.verifiedAt,
    this.badge,
  });

  final String title;
  final String category;
  final String date;
  final String place;
  final String source;
  final String verifiedAt;
  final String? badge;
}

class StageLessonPreview {
  const StageLessonPreview({
    required this.title,
    required this.instructor,
    required this.level,
    required this.schedule,
    required this.trustLabel,
  });

  final String title;
  final String instructor;
  final String level;
  final String schedule;
  final String trustLabel;
}

class StageStudioPreview {
  const StageStudioPreview({
    required this.name,
    required this.station,
    required this.price,
    required this.capacity,
    required this.facilities,
  });

  final String name;
  final String station;
  final String price;
  final String capacity;
  final List<String> facilities;
}

abstract final class StagePreviewData {
  static const recruitments = [
    StageRecruitmentPreview(
      title: '【K-POPカバー】KCDF TOKYO vol.5に一緒に出ませんか',
      crewName: 'Prism Beat',
      genre: 'K-POP',
      area: '新宿・代々木',
      experience: '初心者歓迎',
      remaining: 'あと3名',
      deadline: '締切 8/10',
      badge: '締切間近',
    ),
    StageRecruitmentPreview(
      title: 'HIPHOP大会「SHINJUKU STREET JAM」出場メンバー募集',
      crewName: 'BLAZE UNIT',
      genre: 'HIPHOP',
      area: '新宿',
      experience: '経験1年〜',
      remaining: 'あと2名',
      deadline: '締切 8/24',
      badge: '新着',
    ),
    StageRecruitmentPreview(
      title: '冬のショーケースでNewJeans完コピ・初心者中心クルー',
      crewName: '新規結成',
      genre: 'K-POP',
      area: '池袋',
      experience: '未経験OK',
      remaining: 'あと4名',
      deadline: '締切 9/1',
    ),
  ];

  static const events = [
    StageEventPreview(
      title: 'K-POP COVER DANCE FES TOKYO vol.5',
      category: 'カバーダンス',
      date: '11/22(日)',
      place: '渋谷・Spotify O-EAST',
      source: '公式イベントサイト',
      verifiedAt: '7/28確認',
      badge: '募集中',
    ),
    StageEventPreview(
      title: 'SHINJUKU STREET JAM 2026',
      category: 'HIPHOP',
      date: '10/18(日)',
      place: '新宿中央公園',
      source: '主催者公式SNS',
      verifiedAt: '7/27確認',
      badge: 'エントリー受付中',
    ),
  ];

  static const lessons = [
    StageLessonPreview(
      title: 'K-POPカバー基礎クラス',
      instructor: 'RIHO',
      level: '入門〜初級',
      schedule: '毎週水曜 19:30',
      trustLabel: '運営確認済みプロ',
    ),
    StageLessonPreview(
      title: 'HIPHOP GROOVE 初級',
      instructor: 'TAKUYA',
      level: '初級',
      schedule: '毎週土曜 14:00',
      trustLabel: '本人申告',
    ),
  ];

  static const studios = [
    StageStudioPreview(
      name: 'STUDIO LUZ 新宿',
      station: '新宿駅 徒歩5分',
      price: '¥2,800〜 / 1h',
      capacity: '8〜12名',
      facilities: ['鏡全面', 'Bluetooth', '更衣室'],
    ),
    StageStudioPreview(
      name: 'DANCE BASE 西新宿',
      station: '西新宿駅 徒歩3分',
      price: '¥2,200〜 / 1h',
      capacity: '6〜10名',
      facilities: ['大型鏡', '音響', '深夜利用'],
    ),
    StageStudioPreview(
      name: 'MOVE SPACE 池袋',
      station: '池袋駅 徒歩6分',
      price: '¥1,900〜 / 1h',
      capacity: '5〜8名',
      facilities: ['鏡', '三脚', 'Wi-Fi'],
    ),
  ];
}
