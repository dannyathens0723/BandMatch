import '../models/stage_activity.dart';
import '../models/stage_crew_recruitment.dart';
import '../models/stage_event.dart';
import '../models/stage_home_dashboard.dart';
import '../models/stage_my_crew.dart';
import '../models/stage_studio.dart';
import '../models/stage_user_profile.dart';
import 'stage_activity_service.dart';
import 'stage_crew_discovery_service.dart';
import 'stage_event_discovery_service.dart';
import 'stage_my_crew_service.dart';
import 'stage_profile_service.dart';
import 'stage_studio_discovery_service.dart';

abstract interface class StageHomeDashboardRepository {
  Future<StageHomeDashboard> fetchDashboard();
}

class StageHomeDashboardService implements StageHomeDashboardRepository {
  StageHomeDashboardService({
    this.profileRepository,
    this.myCrewRepository,
    this.activityRepository,
    this.crewRepository,
    this.eventRepository,
    this.studioRepository,
  });

  final StageProfileRepository? profileRepository;
  final StageMyCrewRepository? myCrewRepository;
  final StageActivityRepository? activityRepository;
  final StageCrewDiscoveryRepository? crewRepository;
  final StageEventDiscoveryRepository? eventRepository;
  final StageStudioDiscoveryRepository? studioRepository;

  @override
  Future<StageHomeDashboard> fetchDashboard() async {
    final profile = _capture<StageUserProfile>(
      () => (profileRepository ?? StageProfileService()).fetchMyProfile(),
    );
    final myCrew = _capture<StageMyCrewOverview>(
      () => (myCrewRepository ?? StageMyCrewService()).fetchMyCrewOverview(),
    );
    final activity = _capture<List<StageActivity>>(
      () => (activityRepository ?? StageActivityService()).fetchMyActivity(),
    );
    final recruitments = _capture<List<StageCrewRecruitment>>(
      () => (crewRepository ?? StageCrewDiscoveryService())
          .fetchOpenRecruitments(),
    );
    final events = _capture<List<StageEvent>>(
      () => (eventRepository ?? StageEventDiscoveryService())
          .fetchPublishedEvents(),
    );
    final studios = _capture<List<StageStudio>>(
      () => (studioRepository ?? StageStudioDiscoveryService())
          .fetchPublishedStudios(),
    );

    return StageHomeDashboard(
      profile: await profile,
      myCrew: await myCrew,
      activity: await activity,
      recruitments: await recruitments,
      events: await events,
      studios: await studios,
    );
  }

  Future<StageDashboardSection<T>> _capture<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return StageDashboardSection<T>.data(await operation());
    } on Object catch (error) {
      return StageDashboardSection<T>.error(error);
    }
  }
}
