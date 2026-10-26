import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/presupuesto_provider.dart';
import 'theme/varflo_theme.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VfCostApp());
}

class VfCostApp extends StatelessWidget {
  const VfCostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PresupuestoProvider(),
      child: MaterialApp(
        title: 'VFCOST - S10 Presupuestos',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light, // Modo estándar corporativo Varflo
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'PE'),
          Locale('es', ''),
          Locale('en', ''),
        ],
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: VarfloTheme.grisFondo,
          colorScheme: ColorScheme.fromSeed(
            seedColor: VarfloTheme.azulPrincipal,
            primary: VarfloTheme.azulPrincipal,
            secondary: VarfloTheme.naranjaPrincipal,
            surface: VarfloTheme.grisSuperficie,
            outline: VarfloTheme.grisBorde,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: VarfloTheme.azulPrincipal,
            foregroundColor: Colors.white,
            elevation: 2,
            centerTitle: false,
            shadowColor: Color(0x33000000),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: VarfloTheme.naranjaPrincipal,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            color: VarfloTheme.grisSuperficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: VarfloTheme.naranjaPrincipal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VarfloTheme.grisBordeSuave),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VarfloTheme.grisBordeSuave),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VarfloTheme.azulPrincipal, width: 1.5),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
