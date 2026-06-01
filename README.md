# Kurone-ko Alarm

Kurone-ko Alarm es una aplicación Flutter/Android para importar horarios desde Excel o imágenes, revisar alarmas y programar avisos exactos de descanso, almuerzo e inicio/término de turno.

Este repositorio público es una **base preliminar de trabajo**: lo subimos para compartir avances y para que Rodrigo, colega y amigo en proceso de aprendizaje, pueda clonar el proyecto, practicar corrección de bugs, mejorar interfaces y acostumbrarse a trabajar con una base real.

## Ruta rápida en Windows 11

1. Instalá Flutter, Android Studio y Git.
2. Cloná el repositorio.
3. Ejecutá `flutter pub get`.
4. Corré los tests con `flutter test`.
5. Abrí un emulador o conectá un dispositivo Android.
6. Ejecutá la app con `flutter run`.

Si todo está bien, la aplicación abre una pantalla para importar Excel o imagen y revisar las alarmas activas.

## Requisitos

| Herramienta | Versión recomendada | Notas |
|---|---:|---|
| Windows | 11 | El proyecto fue trabajado y probado en Windows. |
| Flutter | SDK compatible con Dart `^3.11.5` | Verificá con `flutter doctor`. |
| Android Studio | Reciente | Incluye Android SDK, emulador y herramientas ADB. |
| Android SDK | compileSdk 36 | El proyecto usa Android nativo para alarmas exactas. |
| Git | Reciente | Para clonar, crear ramas y subir cambios. |

## Clonar y preparar el proyecto

```powershell
git clone <URL_DEL_REPOSITORIO>
cd kurone-ko-alarm
flutter doctor
flutter pub get
```

> Si `flutter doctor` muestra problemas con Android, abrí Android Studio y revisá **SDK Manager** y **Device Manager**.

## Ejecutar tests y análisis

```powershell
flutter test
flutter analyze
```

Para compilar APK debug:

```powershell
flutter build apk --debug
```

El APK queda en:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Ejecutar en Android

Con un emulador abierto o un celular conectado:

```powershell
flutter devices
flutter run
```

La app necesita permisos Android para funcionar correctamente:

- Notificaciones.
- Alarmas exactas.
- Full-screen intent para mostrar la alarma sobre la pantalla cuando corresponde.

En pruebas manuales, si el popup de alarma no aparece, revisá en Android:

```text
Settings → Apps → kurone_ko_alarm → Special app access
```

La ruta exacta puede cambiar según versión de Android u OEM.

## Caches opcionales en disco E:

Durante el desarrollo original se usaron caches fuera del disco C para evitar llenar el sistema.

Si querés replicarlo, podés revisar:

```text
tools/use-e-drive-caches.ps1
docs/android-studio-cache-setup.md
```

No es obligatorio para correr el proyecto, pero ayuda si tu disco C tiene poco espacio.

## Estructura importante

```text
lib/
  domain/          Entidades, value objects y servicios puros.
  application/     Casos de uso: importar, revisar, confirmar y mapear alarmas.
  infrastructure/  Adaptadores: Excel, OCR, Drift, MethodChannel Android.
  presentation/    Riverpod, pantallas y widgets.

android/
  app/src/main/kotlin/...  Scheduler nativo, receiver, servicio y Activity de alarma.

test/
  domain/          Tests de reglas puras.
  application/     Tests de casos de uso.
  infrastructure/  Tests de adaptadores y persistencia.
  presentation/    Tests de controller y widgets.

openspec/
  changes/         Artefactos SDD usados para especificar cambios grandes.
```

## Flujo recomendado para Rodrigo

1. Crear una rama para cada bug o mejora.

```powershell
git checkout -b fix/nombre-del-bug
```

2. Reproducir el problema antes de tocar código.
3. Escribir o ajustar un test que falle.
4. Implementar el cambio mínimo para que pase.
5. Ejecutar:

```powershell
flutter test
flutter analyze
```

6. Documentar qué cambió y por qué.

La idea no es “parchar rápido”. La idea es aprender a razonar: entender causa raíz, proteger con tests y recién después refactorizar.

## Buenas prácticas del proyecto

- Mantener arquitectura limpia: dominio no debe depender de Flutter ni Android.
- Evitar duplicar reglas: si una regla define qué alarmas son editables, debe existir una fuente de verdad clara.
- Probar primero cuando se corrigen bugs críticos.
- Usar textos de app en español neutro.
- No subir builds, caches, APKs ni archivos locales del IDE.
- No subir credenciales, keystores ni configuraciones privadas.

## Estado actual

Este código base ya incluye:

- Importación desde Excel.
- Flujo de revisión y edición de alarmas.
- Programación nativa Android con alarmas exactas.
- Popup/servicio de alarma con botón para detener.
- Historial de alarmas recientes.
- Agrupación de alarmas por día.
- Tests automatizados para dominio, aplicación, infraestructura y presentación.

También puede contener bugs pendientes. Eso es intencional: el objetivo es que Rodrigo pueda practicar con casos reales.

## Próximo paso sugerido

Cloná el repo, corré los tests y elegí un bug pequeño. Primero entendé el comportamiento esperado, después escribí el test, y recién ahí tocá código.
