import 'stage_activity.dart';
import 'stage_crew_recruitment.dart';
import 'stage_event.dart';
import 'stage_my_crew.dart';
import 'stage_studio.dart';
import 'stage_user_profile.dart';

class StageDashboardSection<T> {
  const StageDashboardSection.data(this.data) : error = null;
  const StageDashboardSection.error(this.error) : data = null;

  final T? data;
  final Object? error;

  bool get hasError => error != null;
}

class StageHomeDashboard {
  const StageHomeDashboard({
    required this.profile,
    required this.myCrew,
    required this.activity,
    required this.recruitments,
    required this.events,
    required this.studios,
  });

  final StageDashboardSection<StageUserProfile> profile;
  final StageDashboardSection<StageMyCrewOverview> myCrew;
  final StageDashboardSection<List<StageActivity>> activity;
  final StageDashboardSection<List<StageCrewRecruitment>> recruitments;
  final StageDashboardSection<List<StageEvent>> events;
  final StageDashboardSection<List<StageStudio>> studios;

  bool get allSectionsFailed =>
      profile.hasError &&
      myCrew.hasError &&
      activity.hasError &&
      recruitments.hasError &&
      events.hasError &&
      studios.hasError;
}
