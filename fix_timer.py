import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/splash_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

target = """class _SplashScreenState extends State<SplashScreen> {
  AudioPlayer? _player;"""

replacement = """class _SplashScreenState extends State<SplashScreen> {
  AudioPlayer? _player;
  bool _hasRedirected = false;"""

content = content.replace(target, replacement)

target2 = """      if (kIsWeb) {
        final String hash = getWebHash();
        if (hash.startsWith('#/')) {
          final path = hash.substring(1); // Quitamos el '#'
          if (path.isNotEmpty && path != '/') {
            context.go(path);
            return; // Detenemos la ejecución del splash y saltamos directo
          }
        }
      }"""

replacement2 = """      if (kIsWeb) {
        final String hash = getWebHash();
        if (hash.startsWith('#/')) {
          final path = hash.substring(1); // Quitamos el '#'
          if (path.isNotEmpty && path != '/') {
            _hasRedirected = true;
            context.go(path);
            return; // Detenemos la ejecución del splash y saltamos directo
          }
        }
      }"""

content = content.replace(target2, replacement2)

target3 = """    // Auto-navegación automática después de 4.8s tanto en Web como en App Móvil
    Timer(const Duration(milliseconds: 4800), () {
      // Verificar de nuevo si se debe navegar al home o si ya redirigimos
      if (mounted) {
        if (kIsWeb && getWebHash().startsWith('#/')) {
          return;
        }
        context.go('/home');
      }
    });"""

replacement3 = """    // Auto-navegación automática después de 4.8s tanto en Web como en App Móvil
    Timer(const Duration(milliseconds: 4800), () {
      // Verificar de nuevo si se debe navegar al home o si ya redirigimos
      if (mounted && !_hasRedirected) {
        context.go('/home');
      }
    });"""

content = content.replace(target3, replacement3)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated splash screen timer logic")
