import 'package:app/models/stage_profile_taxonomy_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('genre selection', () {
    test('selects one and multiple genres', () {
      final one = StageProfileTaxonomySelection().toggleGenre('genre-a');
      final multiple = one.toggleGenre('genre-b');

      expect(one.selectedGenreIds, {'genre-a'});
      expect(multiple.selectedGenreIds, {'genre-a', 'genre-b'});
    });

    test('deselects a selected genre', () {
      final selection = StageProfileTaxonomySelection(
        selectedGenreIds: {'genre-a', 'genre-b'},
      ).toggleGenre('genre-a');

      expect(selection.selectedGenreIds, {'genre-b'});
    });
  });

  group('role and primary-role selection', () {
    const order = ['role-a', 'role-b', 'role-c'];

    test('first selected role automatically becomes primary', () {
      final selection = StageProfileTaxonomySelection().toggleRole(
        'role-b',
        order,
      );

      expect(selection.selectedRoleIds, {'role-b'});
      expect(selection.primaryRoleId, 'role-b');
    });

    test('supports multiple roles and changes the primary role', () {
      final selection = StageProfileTaxonomySelection()
          .toggleRole('role-a', order)
          .toggleRole('role-c', order)
          .choosePrimaryRole('role-c');

      expect(selection.selectedRoleIds, {'role-a', 'role-c'});
      expect(selection.primaryRoleId, 'role-c');
    });

    test(
      'deselecting primary chooses first remaining service-ordered role',
      () {
        final selection = StageProfileTaxonomySelection(
          selectedRoleIds: {'role-b', 'role-c'},
          primaryRoleId: 'role-c',
        ).toggleRole('role-c', order);

        expect(selection.selectedRoleIds, {'role-b'});
        expect(selection.primaryRoleId, 'role-b');
      },
    );

    test('cannot choose an unselected role as primary', () {
      final original = StageProfileTaxonomySelection(
        selectedRoleIds: {'role-a'},
        primaryRoleId: 'role-a',
      );

      final result = original.choosePrimaryRole('role-b');

      expect(identical(result, original), isTrue);
      expect(result.primaryRoleId, 'role-a');
    });
  });

  group('validation and draft', () {
    test('requires at least one genre', () {
      final validation = StageProfileTaxonomySelection(
        selectedRoleIds: {'role-a'},
        primaryRoleId: 'role-a',
      ).validate();

      expect(validation.genreMessage, 'ダンスジャンルを1つ以上選択してください');
      expect(validation.isValid, isFalse);
    });

    test('requires at least one role', () {
      final validation = StageProfileTaxonomySelection(
        selectedGenreIds: {'genre-a'},
      ).validate();

      expect(validation.roleMessage, '役割を1つ以上選択してください');
      expect(validation.isValid, isFalse);
    });

    test('requires a primary role when roles are selected', () {
      final validation = StageProfileTaxonomySelection(
        selectedGenreIds: {'genre-a'},
        selectedRoleIds: {'role-a'},
      ).validate();

      expect(validation.primaryRoleMessage, 'メインの役割を選択してください');
      expect(validation.isValid, isFalse);
    });

    test('creates an ordered immutable ID-only draft', () {
      final selection = StageProfileTaxonomySelection(
        selectedGenreIds: {'genre-c', 'genre-a'},
        selectedRoleIds: {'role-c', 'role-a'},
        primaryRoleId: 'role-c',
      );

      final draft = selection.toDraft(
        orderedGenreIds: const ['genre-a', 'genre-b', 'genre-c'],
        orderedRoleIds: const ['role-a', 'role-b', 'role-c'],
      );

      expect(draft.selectedGenreIds, ['genre-a', 'genre-c']);
      expect(draft.selectedRoleIds, ['role-a', 'role-c']);
      expect(draft.primaryRoleId, 'role-c');
      expect(
        () => draft.selectedGenreIds.add('genre-d'),
        throwsUnsupportedError,
      );
    });
  });
}
