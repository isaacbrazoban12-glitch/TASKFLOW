// Detección de plataforma que compila también en web.
// En web `dart:io` no existe, así que se usa import condicional.
export 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart';
