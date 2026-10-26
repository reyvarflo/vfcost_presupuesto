import 'package:flutter/material.dart';

/// Paleta Oficial de Colores y Estilos Dinámicos VARFLO (Azul, Naranja y Gris)
class VarfloTheme {
  // --- COLORES PRINCIPALES VARFLO ---
  static const Color azulPrincipal = Color(0xFF0F2B48);     // Azul Marino Corporativo
  static const Color azulMedio = Color(0xFF1A4470);          // Azul Varflo Elevado
  static const Color azulClaro = Color(0xFFE3EDF8);          // Azul Suave para Fondos y Badges
  static const Color azulAcento = Color(0xFF0284C7);         // Azul Cielo Técnico

  static const Color naranjaPrincipal = Color(0xFFFF6D00);  // Naranja Construcción Varflo
  static const Color naranjaOscuro = Color(0xFFE65100);     // Naranja Profundo
  static const Color naranjaClaro = Color(0xFFFFF3E0);      // Naranja Suave para Badges y Chips
  static const Color naranjaBrillante = Color(0xFFFF851B);  // Naranja Dinámico

  static const Color grisFondo = Color(0xFFF1F5F9);         // Gris Pizarra 100 (Fondo General)
  static const Color grisSuperficie = Colors.white;         // Blanco Puro para Tarjetas
  static const Color grisBorde = Color(0xFFCBD5E1);         // Gris Borde Sutil (Slate 300)
  static const Color grisBordeSuave = Color(0xFFE2E8F0);    // Gris Borde Claro (Slate 200)
  static const Color grisTextoOscuro = Color(0xFF1E293B);   // Texto Principal (Slate 800)
  static const Color grisTextoSecundario = Color(0xFF64748B);// Texto Secundario (Slate 500)
  static const Color grisDesactivado = Color(0xFF94A3B8);   // Iconos y Etiquetas Claras

  // --- DEGRADADOS MODERNOS ---
  static const LinearGradient gradienteAzul = LinearGradient(
    colors: [azulPrincipal, azulMedio],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradienteNaranja = LinearGradient(
    colors: [naranjaBrillante, naranjaOscuro],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradienteGris = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- SOMBRAS MODERNAS ---
  static List<BoxShadow> get sombraTarjeta => [
        BoxShadow(
          color: const Color(0xFF0F2B48).withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get sombraBotonNaranja => [
        BoxShadow(
          color: naranjaPrincipal.withOpacity(0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get sombraBotonAzul => [
        BoxShadow(
          color: azulPrincipal.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
}
