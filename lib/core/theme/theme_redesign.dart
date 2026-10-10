import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// PRGS Redesign Design System — extracted from Figma "PRGS App" (QFjLqMK4YbjJYCZvZZu9Te)
// Section: Recursos 2:217
// Extraction date: 2026-10-08
// ---------------------------------------------------------------------------
//
// FONT NOTE:
// Figma specifies two families:
//   - Headings: "Neue Haas Grotesk Display Pro" (weights 500/700)
//   - Body/UI:  "Metropolis" (weights 400/500/600)
// Neither is available in the google_fonts package.
// Fallback mapping used below:
//   - Metropolis (body/UI) → self-hosted, assets/fonts/, declared in pubspec. ACTIVE.
//   - Neue Haas Grotesk Display Pro (headings) → GoogleFonts.dmSans fallback (PAID, pending license).
// TODO: When Neue Haas is licensed, add the files to assets/fonts/ + pubspec and
//       switch the three heading getters from GoogleFonts.dmSans to fontFamily: 'NeueHaasGroteskDisplay'.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// COLORS
// ---------------------------------------------------------------------------

/// Extracted verbatim from Figma Colores node 28:581.
/// Each field is named [Palette]/[Step] matching the Figma layer name.
class RedesignColors {
  RedesignColors._();

  // ── Primario (cool navy/dark scale) ─────────────────────────────────────
  static const Color primario950 = Color(0xFF001934); // Primario/950 — darkest bg
  static const Color primario900 = Color(0xFF00203F); // Primario/900 — deep navy
  static const Color primario800 = Color(0xFF10253B); // Primario/800
  static const Color primario700 = Color(0xFF1E2A36); // Primario/700 — dark card / secondary button bg
  static const Color primario600 = Color(0xFF31363B); // Primario/600 — info banner bg
  static const Color primario500 = Color(0xFF61676D); // Primario/500 — muted icon
  static const Color primario400 = Color(0xFF999FA5); // Primario/400
  static const Color primario300 = Color(0xFFD1D1D1); // Primario/300 — placeholder text / unselected nav
  static const Color primario200 = Color(0xFFEAEAEA); // Primario/200 — card subtitle text
  static const Color primario100 = Color(0xFFF6F8F9); // Primario/100
  static const Color primario50  = Color(0xFFFFFFFF); // Primario/50  — white

  // ── Secundario (teal/mint action palette) ───────────────────────────────
  static const Color secundario900 = Color(0xFF002820); // Secundario/900 — deepest teal
  static const Color secundario800 = Color(0xFF005547); // Secundario/800
  static const Color secundario700 = Color(0xFF008C76); // Secundario/700
  static const Color secundario600 = Color(0xFF01B69A); // Secundario/600
  static const Color secundario500 = Color(0xFF01D2B2); // Secundario/500 — PRIMARY ACTION (buttons, focus ring, FAB)
  static const Color secundario400 = Color(0xFF4DD8BB); // Secundario/400 — primary button fill / FAB bubble
  static const Color secundario300 = Color(0xFF81E1CA); // Secundario/300 — day-chip selected fill / unselected border
  static const Color secundario200 = Color(0xFFB5EDDE); // Secundario/200 — highlighted label text
  static const Color secundario100 = Color(0xFFE0F8F1); // Secundario/100

  // ── Neutral (olive/warm grey scale) ─────────────────────────────────────
  static const Color neutral900 = Color(0xFF10110E); // Neutral/900
  static const Color neutral800 = Color(0xFF181915); // Neutral/800
  static const Color neutral700 = Color(0xFF34372F); // Neutral/700
  static const Color neutral600 = Color(0xFF54584B); // Neutral/600 — disabled text
  static const Color neutral500 = Color(0xFF737967); // Neutral/500
  static const Color neutral400 = Color(0xFF929886); // Neutral/400
  static const Color neutral300 = Color(0xFFB0B4A7); // Neutral/300 — disabled button fill
  static const Color neutral200 = Color(0xFFCDD0C8); // Neutral/200
  static const Color neutral100 = Color(0xFFE6E8E3); // Neutral/100 — input placeholder text
  static const Color neutral50  = Color(0xFFF5F6F4); // Neutral/50

  // ── Exito / Success ──────────────────────────────────────────────────────
  static const Color exito900 = Color(0xFF02250C); // Exito/900
  static const Color exito800 = Color(0xFF074F22); // Exito/800
  static const Color exito700 = Color(0xFF13833C); // Exito/700
  static const Color exito600 = Color(0xFF22C55E); // Exito/600 — success default
  static const Color exito500 = Color(0xFF50CD73); // Exito/500
  static const Color exito300 = Color(0xFF80D993); // Exito/300
  static const Color exito200 = Color(0xFFB3E8BC); // Exito/200
  static const Color exito100 = Color(0xFFDFF6E2); // Exito/100

  // ── Advertencia / Warning ────────────────────────────────────────────────
  static const Color advertencia900 = Color(0xFF2D1C05); // Advertencia/900 — cardio icon text
  static const Color advertencia800 = Color(0xFF5F4013); // Advertencia/800 — warning banner bg
  static const Color advertencia700 = Color(0xFF9B6B25); // Advertencia/700
  static const Color advertencia600 = Color(0xFFCA8C34); // Advertencia/600
  static const Color advertencia500 = Color(0xFFAC7E40); // Advertencia/500
  static const Color advertencia400 = Color(0xFFEBAE5B); // Advertencia/400 — cardio banner fill
  static const Color advertencia300 = Color(0xFFF4CD9C); // Advertencia/300 — cardio icon bg
  static const Color advertencia200 = Color(0xFFF7D9B4); // Advertencia/200
  static const Color advertencia100 = Color(0xFFFCEFDF); // Advertencia/100 — warning text

  // ── Peligro / Danger ─────────────────────────────────────────────────────
  static const Color peligro900 = Color(0xFF2C0708); // Peligro/900
  static const Color peligro800 = Color(0xFF5D181A); // Peligro/800
  static const Color peligro700 = Color(0xFF992D30); // Peligro/700 — urgent banner bg
  static const Color peligro600 = Color(0xFFC73D42); // Peligro/600 — cancel/destructive button
  static const Color peligro500 = Color(0xFFAC4545); // Peligro/500
  static const Color peligro400 = Color(0xFFEB6362); // Peligro/400
  static const Color peligro300 = Color(0xFFF9A09C); // Peligro/300
  static const Color peligro200 = Color(0xFFFCB7B3); // Peligro/200 — urgent text / cancel button text
  static const Color peligro100 = Color(0xFFFFE0DE); // Peligro/100

  // ── Semantic aliases (use these in widget code) ──────────────────────────

  /// Primary action: button fill, FAB, focus ring, selected nav icon
  static const Color actionPrimary = secundario400;       // #4DD8BB

  /// Primary action — darker / border variant
  static const Color actionPrimaryDark = secundario500;   // #01D2B2

  /// Dark surface behind primary buttons (text on primary)
  static const Color onActionPrimary = primario950;       // #001934

  /// Secondary button fill (dark slate)
  static const Color actionSecondary = primario700;       // #1E2A36

  /// App / scaffold background
  static const Color background = primario950;            // #001934

  /// Card / list item surface
  static const Color surface = Color(0x80313639);         // rgba(49,54,59,0.5) — Tarjetas bg

  /// Input field fill (frosted)
  static const Color inputFill = Color(0x26FFFFFF);       // rgba(255,255,255,0.15)

  /// Focused input border
  static const Color inputBorderFocused = secundario500;  // #01D2B2

  /// Nav bar background (teal wash)
  static const Color navbarBackground = Color(0x4001B69A); // rgba(1,182,154,0.25)

  /// Selected nav item text/icon
  static const Color navSelected = primario50;            // white

  /// Unselected nav item text
  static const Color navUnselected = primario300;         // #D1D1D1

  /// Nav FAB bubble
  static const Color navFab = secundario400;              // #4DD8BB

  /// Generic icon background on dark (Primario/950)
  static const Color iconBackground = primario950;        // #001934

  /// Success
  static const Color success = exito600;                  // #22C55E

  /// Warning
  static const Color warning = advertencia400;            // #EBAE5B

  /// Danger / destructive
  static const Color danger = peligro600;                 // #C73D42

  /// Disabled fill
  static const Color disabledFill = neutral300;           // #B0B4A7

  /// Disabled text
  static const Color disabledText = neutral600;           // #54584B
}

// ---------------------------------------------------------------------------
// TYPOGRAPHY
// ---------------------------------------------------------------------------

/// Type ramp extracted from Figma Frame 19 (node 2:198).
///
/// Two families in the spec:
///   Headings  → "Neue Haas Grotesk Display Pro"  (fallback: DM Sans — PAID, pending license)
///   Body/UI   → "Metropolis"                     (self-hosted, assets/fonts/, in pubspec)
///
/// Token names match the Figma layer names exactly.
class RedesignType {
  RedesignType._();

  /// Body/UI text uses the real self-hosted Metropolis font.
  static TextStyle _body({
    required double fontSize,
    required FontWeight fontWeight,
    double height = 1.0,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: 'Metropolis',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ── Raw tokens ───────────────────────────────────────────────────────────

  /// Heading XL — 47.78 sp, weight 700, lineHeight 100% (≈ 47.78)
  static TextStyle get headingXl => GoogleFonts.dmSans(
    fontSize: 47.78,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0,
  );

  /// Heading LG — 40 sp, weight 500, lineHeight 100%
  static TextStyle get headingLg => GoogleFonts.dmSans(
    fontSize: 40,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0,
  );

  /// Heading MD — 32 sp, weight 500, lineHeight 100%
  static TextStyle get headingMd => GoogleFonts.dmSans(
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0,
  );

  /// Body MD — 24 sp, weight 500, lineHeight 100%
  static TextStyle get bodyMd => _body(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  /// Body SM — 16 sp, weight 400, lineHeight 20 (1.25)
  static TextStyle get bodySm => _body(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.25, // 20/16
  );

  /// Label — 13 sp, weight 400, lineHeight 16 (≈ 1.23)
  static TextStyle get label => _body(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.231, // 16/13
  );

  // ── Semantic aliases used in button / nav / card text ───────────────────

  /// Button text — Body SM SemiBold (Metropolis Semi_Bold in Figma)
  static TextStyle get buttonLg => _body(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  /// Small button / tag text — Label Medium (Metropolis Medium in Figma)
  static TextStyle get buttonSm => _body(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.231,
  );

  /// Nav label — Label Regular
  static TextStyle get navLabel => label;

  /// Nav label selected — Label SemiBold (trainer navbar "Inicio" uses Semi_Bold)
  static TextStyle get navLabelSelected => _body(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.231,
  );

  /// Card title — Body SM Regular
  static TextStyle get cardTitle => bodySm;

  /// Card subtitle — Label Regular
  static TextStyle get cardSubtitle => label;

  // ── TextTheme for ThemeData ──────────────────────────────────────────────
  static TextTheme get textTheme => TextTheme(
    // Material roles mapped to the PRGS ramp
    displayLarge:   headingXl,
    displayMedium:  headingLg,
    displaySmall:   headingMd,
    headlineLarge:  headingMd,
    headlineMedium: bodyMd,
    headlineSmall:  bodyMd,
    titleLarge:     bodySm.copyWith(fontWeight: FontWeight.w600),
    titleMedium:    bodySm,
    titleSmall:     label.copyWith(fontWeight: FontWeight.w500),
    bodyLarge:      bodySm,
    bodyMedium:     label,
    bodySmall:      label,
    labelLarge:     buttonLg,
    labelMedium:    buttonSm,
    labelSmall:     label,
  );
}

// ---------------------------------------------------------------------------
// SHAPE / SPACING TOKENS
// ---------------------------------------------------------------------------

/// Corner radii extracted from component fills.
/// Buttons: rounded-[30px] (Boton / Boton Md)
/// Small buttons / tags: rounded-[20px] (Boton small / Etiqueta / Días)
/// Inputs / Search: rounded-[40px]
/// Cards (Tarjetas): rounded-[40px]
/// Avisos/banners: rounded-[15px]
/// Icon containers: rounded-[24px] (card icon bg)
/// Nav FAB: rounded-[40px]
/// Navbar top corners: rounded-tl/tr-[20px]
class RedesignRadius {
  RedesignRadius._();

  static const double buttonLg   = 30; // Boton, Boton Md
  static const double buttonSm   = 20; // Boton small, Etiqueta, Días chip
  static const double input      = 40; // Input, Buscador
  static const double card       = 40; // Tarjetas
  static const double banner     = 15; // Avisos
  static const double iconBadge  = 24; // Card icon container
  static const double navFab     = 40; // Navbar central FAB pill
  static const double navBar     = 20; // Navbar top-left/right corner

  static BorderRadius get buttonLgBr  => BorderRadius.circular(buttonLg);
  static BorderRadius get buttonSmBr  => BorderRadius.circular(buttonSm);
  static BorderRadius get inputBr     => BorderRadius.circular(input);
  static BorderRadius get cardBr      => BorderRadius.circular(card);
  static BorderRadius get bannerBr    => BorderRadius.circular(banner);
  static BorderRadius get iconBadgeBr => BorderRadius.circular(iconBadge);
}

/// Standard spacing tokens (derived from component padding values).
class RedesignSpacing {
  RedesignSpacing._();

  // Horizontal/vertical padding seen in components:
  // Boton Lg:    px 20, py 15  → h 54
  // Boton Md:    px 20, py 10
  // Boton Sm:    px 10, py 5
  // Input/Search: px 20-25, py 15  → h 54
  // Card (Tarjetas): px 20, py 15
  // Avisos:      px 15, py 20
  // Navbar:      pb 24, px 30/46

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double xxl = 30;

  static const double buttonPaddingH   = 20;
  static const double buttonPaddingV   = 15;
  static const double buttonMdPaddingV = 10;
  static const double buttonSmPaddingH = 10;
  static const double buttonSmPaddingV = 5;

  static const double inputPaddingH  = 20;
  static const double inputPaddingV  = 15;
  static const double inputHeight    = 54;

  static const double cardPaddingH = 20;
  static const double cardPaddingV = 15;

  static const double bannerPaddingH = 15;
  static const double bannerPaddingV = 20;

  static const double navPaddingBottom = 24;
}

// ---------------------------------------------------------------------------
// THEME
// ---------------------------------------------------------------------------

/// Opt-in ThemeData built entirely from RedesignColors, RedesignType, and
/// RedesignRadius. No existing files are modified.
///
/// Usage in a redesigned screen:
///   Theme(data: RedesignTheme.theme, child: MyRedesignedScreen())
class RedesignTheme {
  RedesignTheme._();

  static ThemeData get theme {
    final tt = RedesignType.textTheme.apply(
      bodyColor: RedesignColors.primario50,
      displayColor: RedesignColors.primario50,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RedesignColors.background,
      primaryColor: RedesignColors.actionPrimary,

      colorScheme: ColorScheme.dark(
        primary:          RedesignColors.actionPrimary,       // #4DD8BB — fills, FAB
        onPrimary:        RedesignColors.onActionPrimary,     // #001934
        primaryContainer: RedesignColors.secundario500,       // #01D2B2 — borders, focus
        secondary:        RedesignColors.actionSecondary,     // #1E2A36 — secondary button
        onSecondary:      RedesignColors.primario50,
        error:            RedesignColors.danger,              // #C73D42
        onError:          RedesignColors.peligro200,          // #FCB7B3
        surface:          RedesignColors.primario700,         // #1E2A36
        onSurface:        RedesignColors.primario50,
        surfaceContainerHighest: RedesignColors.primario600,  // #31363B
      ),

      textTheme: tt,
      primaryTextTheme: tt,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: RedesignColors.background,
        foregroundColor: RedesignColors.primario50,
        centerTitle: true,
        titleTextStyle: RedesignType.bodySm.copyWith(
          fontWeight: FontWeight.w600,
          color: RedesignColors.primario50,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      // Figma Tarjetas: bg rgba(49,54,59,0.5), radius 40, px 20, py 15
      cardTheme: CardThemeData(
        elevation: 0,
        color: RedesignColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: RedesignRadius.cardBr,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: RedesignSpacing.cardPaddingH,
          vertical: RedesignSpacing.cardPaddingV,
        ),
      ),

      // ── Elevated Button (Primario / default large) ───────────────────────
      // Fill: #4DD8BB, text: #001934, radius 30, px 20, py 15, h 54
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, RedesignSpacing.inputHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: RedesignSpacing.buttonPaddingH,
            vertical: RedesignSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(borderRadius: RedesignRadius.buttonLgBr),
          textStyle: RedesignType.buttonLg,
          disabledBackgroundColor: RedesignColors.disabledFill,
          disabledForegroundColor: RedesignColors.disabledText,
        ),
      ),

      // ── Outlined Button (Terciario — teal border, teal text) ────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RedesignColors.actionPrimaryDark,
          side: const BorderSide(color: RedesignColors.actionPrimaryDark, width: 1),
          minimumSize: const Size(double.infinity, RedesignSpacing.inputHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: RedesignSpacing.buttonPaddingH,
            vertical: RedesignSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(borderRadius: RedesignRadius.buttonLgBr),
          textStyle: RedesignType.buttonLg,
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RedesignColors.actionPrimaryDark,
          textStyle: RedesignType.buttonSm,
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RedesignColors.navFab,
        foregroundColor: RedesignColors.onActionPrimary,
        elevation: 0,
        shape: CircleBorder(),
      ),

      // ── Input ───────────────────────────────────────────────────────────
      // Fill: rgba(255,255,255,0.15), radius 40, shadow 0 3 4 rgba(0,0,0,0.1)
      // Focused border: #01D2B2 width 1
      // Placeholder text: #E6E8E3 (Neutral/100), 13sp
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RedesignColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RedesignSpacing.inputPaddingH,
          vertical: RedesignSpacing.inputPaddingV,
        ),
        border: OutlineInputBorder(
          borderRadius: RedesignRadius.inputBr,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RedesignRadius.inputBr,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RedesignRadius.inputBr,
          borderSide: const BorderSide(
            color: RedesignColors.inputBorderFocused,
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RedesignRadius.inputBr,
          borderSide: const BorderSide(color: RedesignColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: RedesignRadius.inputBr,
          borderSide: const BorderSide(color: RedesignColors.danger, width: 1),
        ),
        hintStyle: RedesignType.label.copyWith(color: RedesignColors.neutral100),
        labelStyle: RedesignType.label.copyWith(color: RedesignColors.neutral100),
        floatingLabelStyle: RedesignType.label.copyWith(
          color: RedesignColors.actionPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: RedesignColors.neutral100,
        suffixIconColor: RedesignColors.neutral100,
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      // Bg: rgba(1,182,154,0.25), selected: white, unselected: #D1D1D1
      // Top corners rounded 20, height 92, bottom padding 24
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: RedesignColors.navbarBackground,
        selectedItemColor: RedesignColors.navSelected,
        unselectedItemColor: RedesignColors.navUnselected,
        selectedLabelStyle: TextStyle(
          fontFamily: 'DM Sans', // matches RedesignType
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Chip / Day pills ─────────────────────────────────────────────────
      // Active: bg #81E1CA, text #002820, weight 500
      // Inactive: bg rgba(129,225,202,0.25), border #81E1CA 0.5, text #81E1CA
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x4081E1CA), // rgba(129,225,202,0.25)
        selectedColor: RedesignColors.secundario300,
        labelStyle: RedesignType.bodySm,
        secondaryLabelStyle: RedesignType.bodySm.copyWith(
          fontWeight: FontWeight.w500,
          color: RedesignColors.secundario900,
        ),
        side: const BorderSide(color: RedesignColors.secundario300, width: 0.5),
        padding: const EdgeInsets.symmetric(
          horizontal: RedesignSpacing.buttonPaddingH,
          vertical: RedesignSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: RedesignRadius.buttonSmBr,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: RedesignColors.primario600,
        thickness: 1,
      ),

      // ── Icon ─────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: RedesignColors.primario50,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: RedesignColors.actionPrimary,
        size: 24,
      ),
    );
  }
}
