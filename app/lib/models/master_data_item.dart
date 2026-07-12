class MasterDataItem {
  const MasterDataItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final int sortOrder;

  factory MasterDataItem.fromJson(Map<String, dynamic> json) {
    return MasterDataItem(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class MasterData {
  const MasterData({required this.parts, required this.genres});

  final List<MasterDataItem> parts;
  final List<MasterDataItem> genres;
}
