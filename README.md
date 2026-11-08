<p align="center">
  <img src="app_entreno/assets/branding/rehi_logo.png" alt="REHI" width="160">
</p>

<h1 align="center">REHI</h1>
<p align="center">Registro de entrenamiento de fuerza e hipertrofia: rutinas, series, repeticiones, peso y progreso.</p>

<p align="center">
  <a href="https://github.com/epalzaluisesteban-sys/appREHI/releases/latest/download/REHI.apk"><b>⬇ Descargar REHI para Android (APK)</b></a>
</p>

## Instalar en el celular (Android 7 o superior)

1. Abre el enlace de arriba desde el celular y descarga `REHI.apk`.
2. Ábrelo. Si Android lo pide, permite **instalar apps de origen desconocido** para el navegador o la app de archivos.
3. Si aparece Play Protect, toca **Más detalles → Instalar de todas formas** (la app no está en Play Store, por eso avisa).

Todas las versiones están en [Releases](https://github.com/epalzaluisesteban-sys/appREHI/releases).

## Funciones

- Rutinas con días (p. ej. Torso / Pierna) y ejercicios con series y rango de repeticiones programados.
- Registro por serie de peso, repeticiones y RIR, con la fecha del entrenamiento.
- Temporizador de descanso configurable por ejercicio, con alarma sonora.
- Series de aproximación opcionales por ejercicio: eliges cuántas y el porcentaje de cada una, y durante el entrenamiento se muestra el peso de cada serie según tu peso de trabajo.
- Gráfica de progreso por ejercicio (peso máximo, 1RM estimado y volumen).
- Duración de cada sesión y promedio por día de rutina.
- Unidades en kg o lb y 7 colores de tema.
- Exportación de los registros a Excel y PDF.
- Copia de seguridad en un archivo (por ejemplo en Google Drive) para recuperar los datos al reinstalar o cambiar de celular.

Los datos se guardan en el dispositivo. Al desinstalar la app, Android los borra, así que conviene guardar una copia de seguridad desde **Ajustes → Copia de seguridad**.

## Desarrollo

App hecha con Flutter (`app_entreno/`).

```bash
cd app_entreno
flutter pub get
flutter test
flutter run
```

Para compilar el APK firmado hace falta `android/key.properties` y la clave `.jks`, que no se suben al repositorio.
