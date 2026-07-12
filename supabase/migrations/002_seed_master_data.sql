-- BandMatch Phase 1 master data
-- Run after 001_initial_schema.sql.

begin;

insert into public.parts (code, name, sort_order) values
  ('vocal', 'ボーカル', 1),
  ('guitar', 'ギター', 2),
  ('bass', 'ベース', 3),
  ('piano_keyboard', 'ピアノ・キーボード', 4),
  ('drums', 'ドラム', 5),
  ('percussion', 'パーカッション', 6),
  ('wind_instruments', '管楽器', 7),
  ('string_instruments', '弦楽器', 8),
  ('songwriter_arranger', '作詞作曲・アレンジャー', 9),
  ('dj', 'DJ', 10),
  ('dancer', 'ダンサー', 11),
  ('other', 'その他', 12)
on conflict (code) do update
set name = excluded.name,
    sort_order = excluded.sort_order,
    is_active = true;

insert into public.genres (code, name, sort_order) values
  ('pops', 'ポップス', 1),
  ('rock', 'ロック', 2),
  ('hard_rock_heavy_metal', 'ハードロック・ヘビーメタル', 3),
  ('punk_melocore', 'パンク・メロコア', 4),
  ('hardcore', 'ハードコア', 5),
  ('thrash_death_metal', 'スラッシュメタル・デスメタル', 6),
  ('visual_kei', 'ビジュアル系', 7),
  ('funk_blues', 'ファンク・ブルース', 8),
  ('jazz_fusion', 'ジャズ・フュージョン', 9),
  ('country_folk', 'カントリー・フォーク', 10),
  ('ska_rockabilly', 'スカ・ロカビリー', 11),
  ('soul_rnb', 'ソウル・R&B', 12),
  ('gospel_a_cappella', 'ゴスペル・アカペラ', 13),
  ('bossa_nova_latin', 'ボサノバ・ラテン', 14),
  ('classical', 'クラシック', 15),
  ('hiphop_reggae', 'ヒップホップ・レゲエ', 16),
  ('house_techno', 'ハウス・テクノ', 17),
  ('anison_vocaloid', 'アニソン・ボカロ', 18)
on conflict (code) do update
set name = excluded.name,
    sort_order = excluded.sort_order,
    is_active = true;

-- Areas are intentionally not seeded here. Import the approved Kanto prefecture/city/station
-- hierarchy as a separate operational migration after deciding the station source of truth.

commit;
