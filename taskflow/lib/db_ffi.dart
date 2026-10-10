// Inicialización de sqflite FFI (escritorio). En web es no-op:
// sqflite_common_ffi no compila en navegador (usa dart:ffi).
export 'db_ffi_stub.dart' if (dart.library.io) 'db_ffi_io.dart';
