# GUÍA: COMPILACIÓN DE VF COST PRO PARA IPHONE (iOS) EN LA NUBE
### Sin necesidad de comprar una Mac física ni pagar cuentas costosas

---

## 1. ¿Cómo funciona la compilación en la Nube?

Apple exige un entorno **macOS** para generar el instalador de iPhone (`.ipa`). Gracias a los archivos que acabamos de configurar en tu proyecto:
* [`.github/workflows/build_ios.yml`](file:///h:/APP%20PRESUPUESTO%20VFCOST/.github/workflows/build_ios.yml)
* [`codemagic.yaml`](file:///h:/APP%20PRESUPUESTO%20VFCOST/codemagic.yaml)

Una **Mac M2 virtual en la nube (servidores de GitHub o Codemagic)** toma tu código fuente, ejecuta las pruebas de presupuesto, compila el motor nativo de iOS y empaqueta el instalador final **`VFCOST_Pro_iOS.ipa`** para que lo descargues con un solo clic.

---

## 2. Paso a Paso: Compilar con GitHub Actions (Gratuito)

### Paso A: Subir el proyecto a GitHub (si aún no lo has subido)
1. Ve a [github.com](https://github.com) y crea un nuevo repositorio (puede ser privado o público) llamado `vfcost_presupuesto`.
2. En tu terminal en Windows (`H:\APP PRESUPUESTO VFCOST`), ejecuta:
   ```bash
   git add .
   git commit -m "Configuración completa de VF COST Pro con soporte iOS"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/vfcost_presupuesto.git
   git push -u origin main
   ```

### Paso B: La compilación arranca automáticamente
1. En tu repositorio de GitHub, entra a la pestaña superior **"Actions"**.
2. Verás el flujo llamado **"Compilar iOS (iPhone) en la Nube - VF COST Pro"** ejecutándose en una Mac M2 virtual.
3. El proceso toma aproximadamente de 3 a 5 minutos.

### Paso C: Descargar el archivo `.ipa`
1. Cuando termine (aparece un check verde ✅), haz clic sobre la ejecución.
2. Al final de la página, en la sección **"Artifacts"**, verás el enlace de descarga:
   👉 **`VFCOST_Pro_iPhone_IPA`** (archivo comprimido conteniendo el `.ipa`).

---

## 3. ¿Cómo instalar el `.ipa` en tu iPhone desde tu PC Windows?

Para instalar un archivo `.ipa` en cualquier iPhone desde Windows de forma **100% gratuita y sin pagar los $99 de Apple Developer**, el método más rápido y estándar es **Sideloadly**:

### Instrucciones con Sideloadly (2 minutos):
1. Descarga e instala **Sideloadly** en tu Windows desde su web oficial: `https://sideloadly.io`
2. Abre Sideloadly y conecta tu iPhone a la PC mediante su cable USB (desbloquea la pantalla y dale "Confiar en esta computadora" si te lo solicita).
3. Arrastra el archivo **`VFCOST_Pro_iOS.ipa`** dentro de la ventana de Sideloadly.
4. En el campo *Apple ID*, escribe tu correo de cuenta Apple normal (el que usas en tu iPhone).
5. Haz clic en el botón **"Start"**.
6. En 1 minuto verás el icono de **VF COST Pro** en la pantalla de inicio de tu iPhone.

> **Nota para el primer inicio en iPhone:**
> La primera vez que toques el icono en tu iPhone, ve a:
> **Ajustes > General > VPN y gestión de dispositivos** > Toca tu Apple ID > **Confiar en esta app**.
> ¡Y listo! La app se abrirá a pantalla completa con todas sus funciones de presupuestos, metrados, análisis unitarios y Delphin Express.

---

## 4. Alternativa 2: Codemagic (Nube especializada en Flutter)

Si prefieres usar Codemagic:
1. Crea una cuenta gratuita en [codemagic.io](https://codemagic.io) con tu cuenta de GitHub.
2. Selecciona tu repositorio `vfcost_presupuesto`.
3. Codemagic detectará automáticamente el archivo [`codemagic.yaml`](file:///h:/APP%20PRESUPUESTO%20VFCOST/codemagic.yaml).
4. Presiona **"Start new build"**.
5. Te enviará el archivo `.ipa` listo para descargar a tu correo electrónico o directo al panel de control.
