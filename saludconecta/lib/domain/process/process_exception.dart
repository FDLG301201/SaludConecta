/// Error de negocio: la transición pedida no está permitida.
///
/// El mensaje está en español porque la interfaz lo muestra tal cual.
class ProcessException implements Exception {
  const ProcessException(this.message);

  final String message;

  @override
  String toString() => message;
}
