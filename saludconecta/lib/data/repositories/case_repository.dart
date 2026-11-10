import '../../domain/models/telemedicine_case.dart';

/// Almacén de casos de telemedicina.
abstract class CaseRepository {
  /// Todos los casos, en orden de inserción.
  List<TelemedicineCase> getAll();

  TelemedicineCase? getById(String id);

  /// Inserta un caso o reemplaza el que tenga el mismo `id`.
  void save(TelemedicineCase telemedicineCase);

  /// Siguiente ID libre: "TM-<año>-<secuencia de 4 dígitos>".
  String nextId(DateTime at);
}

/// Implementación en memoria: al reiniciar la app se vuelve a los datos semilla.
class InMemoryCaseRepository implements CaseRepository {
  InMemoryCaseRepository([Iterable<TelemedicineCase> initial = const []]) {
    for (final c in initial) {
      _cases[c.id] = c;
    }
  }

  // El mapa conserva el orden de inserción.
  final _cases = <String, TelemedicineCase>{};

  @override
  List<TelemedicineCase> getAll() => List.unmodifiable(_cases.values);

  @override
  TelemedicineCase? getById(String id) => _cases[id];

  @override
  void save(TelemedicineCase telemedicineCase) {
    _cases[telemedicineCase.id] = telemedicineCase;
  }

  @override
  String nextId(DateTime at) {
    var lastSequence = 0;
    for (final id in _cases.keys) {
      final sequence = int.tryParse(id.split('-').last) ?? 0;
      if (sequence > lastSequence) lastSequence = sequence;
    }
    return 'TM-${at.year}-${(lastSequence + 1).toString().padLeft(4, '0')}';
  }
}
