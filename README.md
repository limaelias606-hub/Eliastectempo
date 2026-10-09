# Eliastectempo — Flutter starter 0.2

Inclui:
- Condições atuais, sensação térmica, humidade e vento.
- Previsão horária e previsão diária de 7 dias.
- Índice UV máximo diário da Open-Meteo.
- Mensagens sarcásticas condicionais.
- Mascote pixel art com animação flutuante e variações visuais por clima/temperatura.
- Localização de Londrina como fallback e botão para usar GPS.

## Gerar o app Android
Requisitos: Flutter SDK, Android Studio e Android SDK instalados.

Na pasta do projeto:
```bash
flutter create . --platforms=android
flutter pub get
```

Em `android/app/src/main/AndroidManifest.xml`, adicionar antes de `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Depois:
```bash
flutter run
flutter build apk --release
```

APK gerado em `build/app/outputs/flutter-apk/app-release.apk`.

## Observações
- Esta entrega é o código-fonte, não um APK compilado.
- A compilação não foi executada neste ambiente, que não possui toolchain Android/Flutter disponível.
- A primeira abertura usa Londrina como local padrão de demonstração. Toque no ícone de localização para usar GPS.
- Dados meteorológicos vêm da API Open-Meteo. Revise os termos/atribuição e teste no dispositivo antes de publicar.
