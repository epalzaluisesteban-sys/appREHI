import 'package:flutter/material.dart';

/// Combinación de colores de la app: encabezado (tono neutro),
/// fondo, superficie de diálogos y acento claro.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.header,
    required this.background,
    required this.surface,
    required this.accent,
  });

  final String id;
  final String name;
  final Color header;
  final Color background;
  final Color surface;
  final Color accent;
}

/// Siete paletas discretas (tonos apagados) con texto blanco legible.
const appPalettes = <AppPalette>[
  AppPalette(
    id: 'rojo',
    name: 'Rojo',
    header: Color(0xFF8E3B37),
    background: Color(0xFFB3261E),
    surface: Color(0xFF7A201B),
    accent: Color(0xFFFFE3DF),
  ),
  AppPalette(
    id: 'vino',
    name: 'Vino',
    header: Color(0xFF5C2E36),
    background: Color(0xFF7A3542),
    surface: Color(0xFF52222B),
    accent: Color(0xFFF5DDE2),
  ),
  AppPalette(
    id: 'terracota',
    name: 'Terracota',
    header: Color(0xFF6E4A3C),
    background: Color(0xFF8C5A45),
    surface: Color(0xFF5E3D30),
    accent: Color(0xFFF4E3D9),
  ),
  AppPalette(
    id: 'oliva',
    name: 'Oliva',
    header: Color(0xFF4F5238),
    background: Color(0xFF666B45),
    surface: Color(0xFF42452D),
    accent: Color(0xFFEDEED9),
  ),
  AppPalette(
    id: 'salvia',
    name: 'Salvia',
    header: Color(0xFF3E5446),
    background: Color(0xFF4F6B59),
    surface: Color(0xFF34473B),
    accent: Color(0xFFDDEBE1),
  ),
  AppPalette(
    id: 'pizarra',
    name: 'Pizarra',
    header: Color(0xFF34465A),
    background: Color(0xFF435A72),
    surface: Color(0xFF2C3B4C),
    accent: Color(0xFFDDE6F0),
  ),
  AppPalette(
    id: 'grafito',
    name: 'Grafito',
    header: Color(0xFF2E3135),
    background: Color(0xFF45494F),
    surface: Color(0xFF2A2D31),
    accent: Color(0xFFE4E6E9),
  ),
];

AppPalette paletteById(String id) =>
    appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);

/// Colores de la app. Los cuatro principales dependen de la paleta elegida.
class AppColors {
  static AppPalette palette = appPalettes.first;

  /// Tono neutro del encabezado.
  static Color get header => palette.header;

  /// Fondo de las pantallas.
  static Color get background => palette.background;

  /// Superficie de diálogos y hojas inferiores.
  static Color get surface => palette.surface;

  /// Acento claro (barra del logo, detalles).
  static Color get accent => palette.accent;

  /// Tarjetas: velo oscuro sobre el fondo.
  static const card = Color(0x2E000000);

  /// Fila de serie completada.
  static const doneRow = Color(0x33FFFFFF);

  static const onRed = Colors.white;
  static const muted = Color(0xCCFFFFFF);
  static const subtle = Color(0x99FFFFFF);
}

ThemeData buildTheme(AppPalette p) {
  AppColors.palette = p;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.header,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Colors.white,
    onPrimary: p.background,
    secondary: p.accent,
    onSecondary: p.background,
    surface: p.surface,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: p.surface,
    outline: AppColors.subtle,
    outlineVariant: const Color(0x55FFFFFF),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: p.header,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x22FFFFFF),
      isDense: true,
      hintStyle: const TextStyle(color: AppColors.subtle),
      labelStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.card,
      selectedColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: TextStyle(color: p.background),
      side: BorderSide.none,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: TextStyle(color: p.background),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: Color(0x33FFFFFF), space: 1),
  );
}
