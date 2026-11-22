import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Barra de herramientas táctil para insertar etiquetas de estructura
/// (CORO, CORO 1..10, SOLISTA, PUENTE, FINAL, etc.) con 1 solo toque.
class HymnStructureToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;

  const HymnStructureToolbar({
    super.key,
    required this.controller,
    this.onChanged,
  });

  void _insertTag(BuildContext context, String tag) {
    HapticFeedback.lightImpact();

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    // Si es un número de estrofa (ej: '1.', '2.') no lleva dos puntos al final.
    final bool isVerseNumber = RegExp(r'^\d+\.?$').hasMatch(tag);
    final String formattedTag = isVerseNumber 
        ? (tag.endsWith('.') ? tag : '$tag.')
        : (tag.endsWith(':') ? tag : '$tag:');

    if (start < 0) {
      // Sin selección: insertar al final del texto
      final prefix = (text.isEmpty || text.endsWith('\n\n'))
          ? ''
          : (text.endsWith('\n') ? '\n' : '\n\n');
      controller.text = '$text$prefix$formattedTag\n';
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    } else {
      // Insertar en la posición del cursor con saltos de línea limpios
      final before = text.substring(0, start);
      final after = text.substring(end);

      final bool needBlankLineBefore = before.isNotEmpty && !before.endsWith('\n\n');
      final bool needNewlineBefore = needBlankLineBefore && !before.endsWith('\n');

      final String prefix = needNewlineBefore
          ? '\n\n'
          : (before.isNotEmpty && !before.endsWith('\n') ? '\n' : '');
      final String suffix = after.startsWith('\n') ? '' : '\n';

      final insertion = '$prefix$formattedTag\n$suffix';
      final newText = '$before$insertion$after';
      controller.text = newText;

      // Colocar el cursor en la línea siguiente a la etiqueta
      final cursorOffset = (before + prefix + formattedTag + '\n').length;
      controller.selection = TextSelection.collapsed(
        offset: cursorOffset.clamp(0, controller.text.length),
      );
    }

    onChanged?.call();
  }

  void _showAllTagsModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.style_rounded, color: Color(0xFF6366F1), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Insertar Etiqueta de Estructura',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toca cualquier etiqueta para pegarla en la letra en la posición del cursor:',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _buildCategorySection(
                    ctx,
                    title: 'Coros y Estribillos',
                    icon: Icons.music_note_rounded,
                    color: const Color(0xFF6366F1),
                    tags: [
                      'CORO', 'CORO 1', 'CORO 2', 'CORO 3', 'CORO 4', 
                      'CORO 5', 'CORO 6', 'CORO 7', 'CORO 8', 'CORO 9', 'CORO 10', 
                      'CORO FINAL', 'PRE-CORO', 'ESTRIBILLO'
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildCategorySection(
                    ctx,
                    title: 'Solistas, Partes Vocales y Recitados',
                    icon: Icons.mic_rounded,
                    color: const Color(0xFFEC4899),
                    tags: [
                      'SOLISTA', 'SOLISTA 1', 'SOLISTA 2', 'SOLISTA 3', 
                      'SOLISTA 4', 'SOLISTA 5', 'SOLO',
                      'HOMBRES', 'MUJERES', 'TODOS',
                      'RECITADO', 'RECITADO 1', 'RECITADO 2',
                      'HABLADO', 'DECLAMACIÓN', 'NARRACIÓN'
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildCategorySection(
                    ctx,
                    title: 'Puentes, Interludios y Cierre',
                    icon: Icons.alt_route_rounded,
                    color: const Color(0xFF0EA5E9),
                    tags: [
                      'PUENTE', 'PUENTE 1', 'PUENTE 2', 'PUENTE 3',
                      'INTERLUDIO', 'INTRO', 'INTRODUCCIÓN',
                      'FINAL', 'OUTRO', 'CODA'
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildCategorySection(
                    ctx,
                    title: 'Estrofas Numeradas',
                    icon: Icons.format_list_numbered_rounded,
                    color: const Color(0xFF10B981),
                    tags: ['1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.', '10.'],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> tags,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags.map((t) {
            return ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              label: Text(
                t,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _insertTag(context, t);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;

    final List<Map<String, dynamic>> quickTags = [
      {'tag': 'CORO', 'color': const Color(0xFF6366F1)},
      {'tag': 'PRE-CORO', 'color': const Color(0xFF8B5CF6)},
      {'tag': 'SOLISTA', 'color': const Color(0xFFEC4899)},
      {'tag': 'RECITADO', 'color': const Color(0xFFF59E0B)},
      {'tag': 'PUENTE', 'color': const Color(0xFF0EA5E9)},
      {'tag': 'FINAL', 'color': const Color(0xFFEF4444)},
      {'tag': '1.', 'color': const Color(0xFF10B981)},
      {'tag': '2.', 'color': const Color(0xFF10B981)},
      {'tag': 'CORO 1', 'color': const Color(0xFF6366F1)},
      {'tag': 'CORO 2', 'color': const Color(0xFF6366F1)},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.style_outlined, size: 14, color: isDark ? Colors.white60 : Colors.black54),
              const SizedBox(width: 4),
              Text(
                'Estructura rápida (1-tap):',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final item in quickTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _insertTag(context, item['tag'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withValues(alpha: isDark ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (item['color'] as Color).withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          item['tag'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: item['color'] as Color,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Botón "Más etiquetas"
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showAllTagsModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: primaryColor),
                        const SizedBox(width: 2),
                        Text(
                          'Más...',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

