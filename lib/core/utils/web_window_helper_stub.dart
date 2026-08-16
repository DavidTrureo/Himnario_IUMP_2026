/// Stub implementation for non-web platforms
class WebWindowHelper {
  static void openProjectorWindow(String url) {
    // No-op en móvil
  }
  
  static void broadcastProjectorState(int slideIndex, String theme, double fontSize, {bool isBlank = false, String? hymnId, String? collection}) {
    // No-op en móvil
  }

  static void listenToProjectorState(Function(int slideIndex, String theme, double fontSize, bool isBlank, String? hymnId, String? collection) onStateChanged) {
    // No-op en móvil
  }
  
  static void dispose() {
    // No-op en móvil
  }
}
