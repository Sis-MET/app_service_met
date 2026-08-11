import 'servicio_model.dart';

class PendingUploadGroup {
  final String seca;
  final int count;

  const PendingUploadGroup({required this.seca, required this.count});
}

class HomeDashboardData {
  final int calibratedScales;
  final int supportServices;
  final int servicesInProgress;
  final int pendingUploads;
  final String lastPreload;
  final List<PendingUploadGroup> pendingUploadGroups;
  final List<ServicioResumen> calibrationServices;
  final List<ServicioResumen> supportServiceGroups;

  const HomeDashboardData({
    required this.calibratedScales,
    required this.supportServices,
    required this.servicesInProgress,
    required this.pendingUploads,
    required this.lastPreload,
    required this.pendingUploadGroups,
    required this.calibrationServices,
    required this.supportServiceGroups,
  });
}
