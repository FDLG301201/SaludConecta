import '../process/process_step.dart';
import 'enums.dart';

/// Un hecho de la línea de tiempo del caso.
class ProcessEvent {
  const ProcessEvent({
    required this.step,
    required this.actor,
    required this.actorName,
    required this.at,
    required this.title,
    this.detail = '',
    this.kind = EventKind.completed,
  });

  final ProcessStep step;
  final Actor actor;
  final String actorName;
  final DateTime at;
  final String title;
  final String detail;
  final EventKind kind;

  /// Solo los eventos `completed` completan el paso; los demás son auxiliares
  /// (p. ej. el inicio de la consulta o una llamada de seguimiento).
  bool get completesStep => kind == EventKind.completed;
}
