<div align="center">

<img src="assets/images/church_logo_v3.png" alt="Logo IUMP" width="120"/>

# 📖 Himnario Digital IUMP

### Aplicación Móvil Oficial — Iglesia Unida Metodista Pentecostal

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Storage-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/Estado-Riverpod-00B4D8?style=for-the-badge)](https://riverpod.dev)
[![Android](https://img.shields.io/badge/Android-SDK%2036-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![License](https://img.shields.io/badge/Licencia-Privado-red?style=for-the-badge)]()

> Aplicación multiplataforma de apoyo litúrgico para la congregación IUMP. Permite buscar, escuchar, guardar y organizar el catálogo completo de himnos, coritos y cantos especiales de forma rápida, offline y con asistencia de Inteligencia Artificial.

</div>

---

## 📋 Tabla de Contenidos

- [Características Principales](#-características-principales)
- [Capturas de Pantalla](#-capturas-de-pantalla)
- [Arquitectura del Proyecto](#-arquitectura-del-proyecto)
- [Tecnologías Utilizadas](#-tecnologías-utilizadas)
- [Estructura de Carpetas](#-estructura-de-carpetas)
- [Configuración e Instalación](#-configuración-e-instalación)
- [Variables de Entorno](#-variables-de-entorno)
- [Compilación](#-compilación)
- [Desarrollador](#-desarrollador)

---

## ✨ Características Principales

### 🎵 Catálogo de Cantos
- Catálogo completo con **más de 400 himnos oficiales**, coritos y cantos especiales.
- Búsqueda inteligente en tiempo real por título, número y letra.
- Visualización detallada de letra con acordes musicales.
- Modo presentación de pantalla completa para la pantalla del proyector.

### ❤️ Favoritos
- Sistema personal de marcado de cantos favoritos.
- Almacenamiento sincronizado en la nube mediante Firebase Firestore.
- Acceso rápido al listado de cantos favoritos desde el menú principal.

### 📋 Repertorios de Culto
- Creación de **listas de cantos personalizadas** para cada culto.
- Ordenamiento arrastrable y dinámico de los cantos del repertorio.
- Almacenamiento 100% **local y privado** por usuario usando `SharedPreferences` con serialización JSON.
- Cada usuario gestiona sus propios repertorios de forma independiente.

### 🎙️ Grabación de Audio Demostrativo
- Grabación de audio nativa desde el micrófono del dispositivo.
- Codificación comprimida **AAC Mono a 64kbps** para optimizar el almacenamiento.
- Subida y eliminación directa en **Firebase Cloud Storage** con barra de progreso en tiempo real.
- Reproducción de audios demostrativos desde la nube.

### 🤖 Asistente Bíblico con IA
- Asistente temático bíblico integrado con la **API REST de Google Gemini** (producción `v1`).
- Importación automática de cantos desde páginas web mediante OCR asistido por IA.
- Gestión de modelos de respaldo (*fallback*) y esquemas estrictos de respuesta JSON.
- Mensajes de error amigables en español para problemas de cuota o red.

### 🔐 Panel de Administrador
- Acceso a herramientas de administración del catálogo protegido por contraseña.
- Detección y alerta de cantos duplicados entre colecciones (solo visible para administradores).
- Gestión de la base de datos de cantos: agregar, editar y eliminar registros.
- Subida de imágenes y archivos de audio asociados a cantos.

---

## 🏛️ Arquitectura del Proyecto

El proyecto sigue una arquitectura orientada a **features** (características), separando claramente la capa de presentación, dominio e integración con servicios externos.

```
lib/
├── core/                     # Utilidades y configuración global
│   └── theme/                # Tema visual (claro / oscuro)
├── features/
│   ├── home/                 # Pantalla principal y Splash
│   │   └── presentation/
│   ├── hymns/                # Módulo principal de himnos
│   │   ├── data/             # Repositorios y fuentes de datos
│   │   ├── domain/           # Modelos de negocio
│   │   └── presentation/     # Pantallas, widgets y providers
│   ├── favorites/            # Módulo de favoritos
│   │   └── presentation/
│   └── setlists/             # Módulo de repertorios de culto
│       ├── domain/           # Modelo de Setlist
│       └── presentation/     # Pantallas y providers
├── firebase_options.dart     # Configuración Firebase (auto-generado)
└── main.dart                 # Punto de entrada de la aplicación
```

### Gestión de Estado
La gestión de estado se implementa íntegramente con **Riverpod** (`flutter_riverpod ^3.x`), utilizando:
- `AsyncNotifier` para operaciones asíncronas con Firestore.
- `StateNotifier` para estados locales de UI.
- `StreamProvider` para sincronización en tiempo real con la base de datos.

---

## 🛠️ Tecnologías Utilizadas

| Categoría | Tecnología | Uso |
|-----------|-----------|-----|
| **Lenguaje** | Dart 3.x | Lenguaje de programación principal |
| **Framework** | Flutter 3.x | Desarrollo multiplataforma (Android/iOS) |
| **Estado** | Riverpod (flutter_riverpod ^3.3) | Gestión de estado reactivo y asíncrono |
| **Navegación** | Go Router (^17.x) | Navegación declarativa por rutas |
| **Base de datos cloud** | Firebase Firestore | Sincronización en tiempo real del catálogo |
| **Almacenamiento cloud** | Firebase Cloud Storage | Archivos de audio demostrativos |
| **Autenticación** | Firebase Auth | Gestión de sesiones de usuario |
| **Almacenamiento local** | SharedPreferences | Repertorios de culto (JSON privado por dispositivo) |
| **Inteligencia Artificial** | Google Gemini API REST (`v1`) | Asistente bíblico e importación web por IA |
| **Audio** | record ^7.1.1 + just_audio ^0.9.36 | Grabación y reproducción de audio |
| **Fuentes** | Google Fonts + Playfair Display + Nunito | Tipografía personalizada |
| **Animaciones** | flutter_animate ^4.5 | Micro-animaciones de interfaz |
| **HTTP** | http ^1.6.0 | Llamadas a la API REST de Gemini |
| **Imágenes** | image_picker ^1.1 | Selección de imágenes para cantos |

---

## 📁 Estructura de Carpetas

```
Proyecto_Himnario/
├── android/                  # Configuración nativa Android
│   └── app/build.gradle.kts  # Config. Gradle con SDK 36
├── ios/                      # Configuración nativa iOS
├── assets/
│   ├── fonts/                # Fuentes tipográficas (Playfair, Nunito)
│   ├── images/               # Logos de la iglesia y misión
│   └── json/
│       ├── hymns.json            # Catálogo 400+ himnos oficiales
│       ├── special_hymns.json    # Cantos especiales
│       └── coros.json            # Coritos y cánticos
├── lib/                      # Código fuente Dart
├── pubspec.yaml              # Dependencias del proyecto
└── README.md                 # Esta documentación
```

---

## ⚙️ Configuración e Instalación

### Prerrequisitos

Antes de clonar y ejecutar el proyecto, asegúrate de tener instalado lo siguiente:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.12.2`
- [Dart SDK](https://dart.dev/get-dart) `>=3.0.0`
- [Android Studio](https://developer.android.com/studio) con SDK 36 configurado
- [Firebase CLI](https://firebase.google.com/docs/cli) para configurar los servicios
- Una cuenta activa de **Google Firebase** con un proyecto configurado

### Pasos de Instalación

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/DavidTrureo/Himnario_IUMP_2026.git
   cd Himnario_IUMP_2026
   ```

2. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase** (ver sección siguiente).

4. **Ejecutar en modo desarrollo:**
   ```bash
   flutter run
   ```

---

## 🔑 Variables de Entorno

> [!IMPORTANT]
> Este proyecto utiliza Firebase y la API de Google Gemini. Los archivos de configuración sensibles **NO** están incluidos en el repositorio por razones de seguridad.

Deberás configurar los siguientes archivos manualmente:

### Firebase
1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Habilita los servicios: **Firestore**, **Storage** y **Authentication**.
3. Ejecuta `flutterfire configure` para generar el archivo `lib/firebase_options.dart`.
4. Para Android, descarga `google-services.json` y colócalo en `android/app/`.

### Google Gemini API
- La clave de la API de Gemini se gestiona de forma segura dentro de la aplicación.
- Cada usuario configura su propia clave desde la sección de **Búsqueda Bíblica con IA** en la pantalla de búsqueda.
- Obtén tu clave gratuita en [Google AI Studio](https://aistudio.google.com/app/apikey).

---

## 📦 Compilación

### APK de Release (Android)
```bash
flutter build apk --release
```
El archivo generado se encontrará en:
`build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (Google Play Store)
```bash
flutter build appbundle --release
```

### iOS (requiere macOS + Xcode)
```bash
flutter build ios --release
```

---

## 👨‍💻 Desarrollador

<div align="center">

**David Josué Trureo Ahumada**
*Analista Programador — Desarrollador Full-Stack & Mobile*

[![LinkedIn](https://img.shields.io/badge/LinkedIn-david--trureo--ahumada-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/david-trureo-ahumada/)
[![GitHub](https://img.shields.io/badge/GitHub-DavidTrureo-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/DavidTrureo)

*Instituto Profesional Duoc UC — Analista Programador | 2026*

</div>

---

<div align="center">

**© 2026 — Iglesia Unida Metodista Pentecostal (IUMP). Todos los derechos reservados.**
*Aplicación desarrollada con ❤️ para el servicio de la congregación.*

</div>
