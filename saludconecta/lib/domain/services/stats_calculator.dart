import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/people.dart';
import '../models/telemedicine_case.dart';
import '../process/process_step.dart';

/// Solicitudes y consultas de un mes (gráfica de líneas de Operación).
class MonthlyActivity {
  const MonthlyActivity({required this.month, required this.requests, required this.consultations});

  final DateTime month;
  final int requests;
  final int consultations;
}

/// Lo facturado en un mes: parte del seguro y copago.
class MonthlyBilling {
  const MonthlyBilling({required this.month, required this.insurerAmount, required this.copay});

  final DateTime month;
  final int insurerAmount;
  final int copay;
}

/// Calificación promedio de un mes; `null` si no hubo encuestas.
class MonthlyRating {
  const MonthlyRating({required this.month, this.average});

  final DateTime month;
  final double? average;
}

/// Indicadores clave de la pestaña Operación.
class OperationKpis {
  const OperationKpis({
    required this.requestsThisMonth,
    required this.casesInProcess,
    required this.averageDaysToConsultation,
    required this.rejectionRate,
  });

  final int requestsThisMonth;
  final int casesInProcess;
  final double averageDaysToConsultation;

  /// % de las validaciones que el seguro rechazó.
  final double rejectionRate;
}

/// Cuántos casos tienen cada tipo de resultado.
class ResultsSummary {
  const ResultsSummary({
    required this.prescriptions,
    required this.labOrders,
    required this.imagingOrders,
    required this.referrals,
  });

  final int prescriptions;
  final int labOrders;
  final int imagingOrders;
  final int referrals;
}

/// Lo que cubrió el seguro y lo que pagó el paciente.
class CoverageSplit {
  const CoverageSplit({required this.covered, required this.paid});

  final int covered;
  final int paid;
}

/// Funciones puras que alimentan las gráficas (§7 del spec).
class StatsCalculator {
  const StatsCalculator._();

  static const windowMonths = 12;

  /// Primer día de cada mes de la ventana, del más antiguo al actual.
  static List<DateTime> monthsUpTo(DateTime now) => [
        for (var i = windowMonths - 1; i >= 0; i--) DateTime(now.year, now.month - i),
      ];

  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  /// Casos creados dentro de la ventana de 12 meses.
  static List<TelemedicineCase> inWindow(Iterable<TelemedicineCase> cases, DateTime now) {
    final start = monthsUpTo(now).first;
    return [
      for (final c in cases)
        if (!c.createdAt.isBefore(start)) c,
    ];
  }

  // ----- Operación -----

  static OperationKpis operationKpis(Iterable<TelemedicineCase> cases, DateTime now) {
    final thisMonth = monthOf(now);
    var requestsThisMonth = 0;
    var inProcess = 0;
    var validated = 0;
    var rejected = 0;
    final daysToConsultation = <double>[];
    for (final c in cases) {
      if (monthOf(c.createdAt) == thisMonth) requestsThisMonth++;
      if (c.status.isOpen) inProcess++;
      final insurance = c.insurance;
      if (insurance != null) {
        validated++;
        if (!insurance.approved) rejected++;
      }
      final consulted = c.completedAt(ProcessStep.consultation);
      if (consulted != null) daysToConsultation.add(_hours(c.createdAt, consulted) / 24);
    }
    return OperationKpis(
      requestsThisMonth: requestsThisMonth,
      casesInProcess: inProcess,
      averageDaysToConsultation: _average(daysToConsultation),
      rejectionRate: validated == 0 ? 0 : rejected * 100 / validated,
    );
  }

  static Map<RequestChannel, int> requestsByChannel(Iterable<TelemedicineCase> cases) {
    final counts = {for (final channel in RequestChannel.values) channel: 0};
    for (final c in cases) {
      counts[c.channel] = counts[c.channel]! + 1;
    }
    return counts;
  }

  /// Solicitudes (por mes de creación) y consultas realizadas (por mes de la consulta).
  static List<MonthlyActivity> monthlyActivity(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final requests = {for (final m in months) m: 0};
    final consultations = {for (final m in months) m: 0};
    for (final c in cases) {
      final created = monthOf(c.createdAt);
      if (requests.containsKey(created)) requests[created] = requests[created]! + 1;
      final consulted = c.completedAt(ProcessStep.consultation);
      if (consulted == null) continue;
      final month = monthOf(consulted);
      if (consultations.containsKey(month)) consultations[month] = consultations[month]! + 1;
    }
    return [
      for (final m in months) MonthlyActivity(month: m, requests: requests[m]!, consultations: consultations[m]!),
    ];
  }

  /// Embudo: cuántos casos completaron cada paso.
  static Map<ProcessStep, int> funnel(Iterable<TelemedicineCase> cases) {
    final counts = {for (final step in ProcessStep.values) step: 0};
    for (final c in cases) {
      for (final step in c.completedSteps) {
        counts[step] = counts[step]! + 1;
      }
    }
    return counts;
  }

  /// Horas promedio entre la finalización del paso anterior y la del paso (pasos 2–10).
  static Map<ProcessStep, double> averageHoursPerStage(Iterable<TelemedicineCase> cases) {
    final result = <ProcessStep, double>{};
    for (final step in ProcessStep.values.skip(1)) {
      final hours = <double>[];
      for (final c in cases) {
        final start = c.completedAt(step.previous!);
        final end = c.completedAt(step);
        if (start != null && end != null) hours.add(_hours(start, end));
      }
      result[step] = _average(hours);
    }
    return result;
  }

  // ----- Clínico -----

  static Map<Specialty, int> consultationsBySpecialty(
    Iterable<TelemedicineCase> cases,
    Map<String, MedicalService> servicesById,
  ) {
    final counts = {for (final s in Specialty.values) s: 0};
    for (final c in cases) {
      final specialty = servicesById[c.serviceId]?.specialty;
      if (specialty != null && c.isStepCompleted(ProcessStep.consultation)) {
        counts[specialty] = counts[specialty]! + 1;
      }
    }
    return counts;
  }

  static Map<VideoPlatform, int> platformUsage(Iterable<TelemedicineCase> cases) {
    final counts = {for (final p in VideoPlatform.values) p: 0};
    for (final c in cases) {
      final appointment = c.appointment;
      if (appointment != null && c.isStepCompleted(ProcessStep.consultation)) {
        counts[appointment.platform] = counts[appointment.platform]! + 1;
      }
    }
    return counts;
  }

  static ResultsSummary resultsIssued(Iterable<TelemedicineCase> cases) {
    var prescriptions = 0;
    var lab = 0;
    var imaging = 0;
    var referrals = 0;
    for (final c in cases) {
      final r = c.results;
      if (r == null) continue;
      if (r.prescription != null) prescriptions++;
      if (r.ordersOf(OrderType.lab).isNotEmpty) lab++;
      if (r.ordersOf(OrderType.imaging).isNotEmpty) imaging++;
      if (r.referral != null) referrals++;
    }
    return ResultsSummary(prescriptions: prescriptions, labOrders: lab, imagingOrders: imaging, referrals: referrals);
  }

  // ----- Financiero -----

  /// Facturación por mes de cierre: monto a cargo del seguro y copago.
  static List<MonthlyBilling> monthlyBilling(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final insurer = {for (final m in months) m: 0};
    final copay = {for (final m in months) m: 0};
    for (final c in cases) {
      final billing = c.billing;
      final closedAt = billing?.closedAt;
      if (billing == null || closedAt == null) continue;
      final month = monthOf(closedAt);
      if (!insurer.containsKey(month)) continue;
      insurer[month] = insurer[month]! + billing.invoice.insurerAmount;
      copay[month] = copay[month]! + billing.invoice.copay;
    }
    return [
      for (final m in months) MonthlyBilling(month: m, insurerAmount: insurer[m]!, copay: copay[m]!),
    ];
  }

  /// Reclamaciones por estado (sin las que no aplican).
  static Map<ClaimStatus, int> claimsByStatus(Iterable<TelemedicineCase> cases) {
    final counts = {ClaimStatus.approved: 0, ClaimStatus.pending: 0, ClaimStatus.objected: 0};
    for (final c in cases) {
      final status = c.billing?.claimStatus;
      if (status != null && counts.containsKey(status)) counts[status] = counts[status]! + 1;
    }
    return counts;
  }

  /// Monto a cargo de cada aseguradora en los casos cerrados (clave: id de la aseguradora).
  static Map<String, int> billingByInsurer(Iterable<TelemedicineCase> cases, Map<String, Patient> patientsById) {
    final totals = <String, int>{};
    for (final c in cases) {
      final billing = c.billing;
      final patient = patientsById[c.patientId];
      if (billing == null || billing.closedAt == null || patient == null) continue;
      if (billing.invoice.insurerAmount == 0) continue;
      final insurerId = patient.affiliation.insurerId;
      totals[insurerId] = (totals[insurerId] ?? 0) + billing.invoice.insurerAmount;
    }
    return totals;
  }

  // ----- Satisfacción -----

  static List<Survey> surveysOf(Iterable<TelemedicineCase> cases) => [
        for (final c in cases)
          if (c.followUp?.survey != null) c.followUp!.survey!,
      ];

  static double averageRating(Iterable<TelemedicineCase> cases) =>
      _average([for (final s in surveysOf(cases)) s.rating.toDouble()]);

  /// NPS = % de promotores (9–10) − % de detractores (0–6), redondeado.
  static int nps(Iterable<TelemedicineCase> cases) {
    final surveys = surveysOf(cases);
    if (surveys.isEmpty) return 0;
    final promoters = surveys.where((s) => s.nps >= 9).length;
    final detractors = surveys.where((s) => s.nps <= 6).length;
    return ((promoters - detractors) * 100 / surveys.length).round();
  }

  static Map<int, int> ratingDistribution(Iterable<TelemedicineCase> cases) {
    final counts = {for (var stars = 1; stars <= 5; stars++) stars: 0};
    for (final s in surveysOf(cases)) {
      counts[s.rating] = counts[s.rating]! + 1;
    }
    return counts;
  }

  static List<MonthlyRating> monthlyRating(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final ratings = {for (final m in months) m: <double>[]};
    for (final s in surveysOf(cases)) {
      ratings[monthOf(s.at)]?.add(s.rating.toDouble());
    }
    return [
      for (final m in months) MonthlyRating(month: m, average: ratings[m]!.isEmpty ? null : _average(ratings[m]!)),
    ];
  }

  // ----- Perfil del paciente -----

  /// Suma, en los casos cerrados, lo cubierto por el seguro y lo pagado por el paciente.
  static CoverageSplit coverageSplit(Iterable<TelemedicineCase> patientCases) {
    var covered = 0;
    var paid = 0;
    for (final c in patientCases) {
      final billing = c.billing;
      if (billing == null || billing.closedAt == null) continue;
      covered += billing.invoice.insurerAmount;
      paid += billing.invoice.copay;
    }
    return CoverageSplit(covered: covered, paid: paid);
  }

  static double _hours(DateTime from, DateTime to) => to.difference(from).inMinutes / 60;

  static double _average(List<double> values) => values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
