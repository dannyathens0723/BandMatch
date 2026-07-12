class MasterDataItem {
  const MasterDataItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    this.level,
  });

  final String id;
  final String code;
  final String name;
  final int sortOrder;
  final String? level;

  factory MasterDataItem.fromJson(Map<String, dynamic> json) {
    return MasterDataItem(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      level: json['level'] as String?,
    );
  }
}

class MasterData {
  const MasterData({
    required this.parts,
    required this.genres,
    required this.areas,
  });

  final List<MasterDataItem> parts;
  final List<MasterDataItem> genres;
  final List<MasterDataItem> areas;
}
