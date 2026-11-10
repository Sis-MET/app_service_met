# ServiceMET en iOS con Codemagic

El proyecto conserva Flutter. La compilación de iOS se ejecuta en una Mac de
Codemagic; puedes seguir trabajando desde Windows.

## Configuración del proyecto

- Flutter: **3.44.2**, la misma versión usada para preparar estos cambios.
- Xcode en Codemagic: **26.4**, máquina **Mac mini M2**.
- iOS mínimo: **15.5**, requerido por el OCR de ML Kit.
- Bundle ID: **bo.metrica.smet**.
- Dependencias nativas integradas mediante `ios/Podfile` y CocoaPods.
- Credenciales en Keychain; permisos de cámara, fotos, ubicación, Face ID y red local.
- Ciclo de vida UIScene y notificaciones locales configurados.
- Las carpetas de exportación se eligen en **Archivos**. iOS conserva un bookmark
  para volver a escribir en la carpeta. Las bases de datos de la app no se exponen
  mediante la función de compartir archivos de iTunes/Finder.
- El canal nativo permite abrir los documentos exportados y mantener la pantalla
  encendida durante las mediciones programadas.
- Firebase fue retirado: no tenía uso en la aplicación. La autenticación y la
  sincronización siguen utilizando la API propia de ServiceMET. No necesitas
  crear un proyecto Firebase ni aportar `GoogleService-Info.plist`.

## Primera compilación, sin membresía de Apple

Este es el flujo que puedes ejecutar ahora. Comprueba que el código Dart y los
complementos nativos compilen para un iPhone, **sin firmar la aplicación**.

1. Revisa y sube al repositorio estos cambios, incluido `codemagic.yaml`,
   `pubspec.lock`, los archivos de `ios/`, las adaptaciones de `lib/` y las pruebas.
   Codemagic descarga el código de GitHub, no los archivos que solo estén en tu PC.
   El remoto de este proyecto es `https://github.com/lenash-dev/ServiceMET`.
2. Entra en [Codemagic](https://codemagic.io/) y crea una **cuenta personal**.
   El plan personal incluye minutos gratuitos en M2; las cuentas Team tienen una
   facturación diferente. No necesitas crear un Team para esta comprobación.
3. Conecta GitHub y añade el repositorio **ServiceMET** con **Add application**.
4. Selecciona la rama que contenga estos cambios. Usa la configuración
   **codemagic.yaml**, situada en la raíz del repositorio.
5. Pulsa **Start new build** y selecciona el workflow:
   **iOS - comprobar compilacion sin firma** (`ios-check`).
6. Ejecuta el build. Se obtienen las dependencias bloqueadas, se validan los
   archivos nativos, se analiza el código, se ejecutan las pruebas y se compila
   la aplicación en modo release para dispositivo.
7. Al finalizar, en **Artifacts** aparecerán
   `ServiceMET-ios-sin-firma.app.zip`, los registros disponibles de Xcode y
   `Podfile.lock`.

Después de la primera compilación correcta, descarga ese `Podfile.lock` y
guárdalo en `ios/Podfile.lock` dentro del repositorio para fijar también las
versiones de las dependencias nativas resueltas en macOS.

El `.app.zip` de este flujo **no se instala directamente en un iPhone, no es un
build de simulador y no sirve para TestFlight**. Es el resultado de una
compilación para dispositivo sin firma. Para instalarlo necesita un proceso de
firma y aprovisionamiento válido.

Los workflows se ejecutan manualmente. No hay disparadores por cada push ni
publicación automática. El límite de cada ejecución es de 60 minutos.

Los avisos e informaciones existentes del analizador se muestran en el log;
los errores de análisis y las pruebas fallidas detienen el flujo. No se ignoran
los fallos de compilación.

La preparación se comprobó en Windows con la suite de **592 pruebas Flutter**,
seguida de **29 pruebas de regresión** después de sustituir el selector de
respaldos. El análisis de los archivos Dart modificados terminó sin incidencias.
La configuración YAML se validó con el esquema de Codemagic y se comprobaron la
estructura del proyecto Xcode, los plist y los tamaños y opacidad de los iconos.
Esto no sustituye la compilación ni la ejecución nativa en iOS.

## Prueba personal desde Windows con una cuenta Apple gratuita

La compilación nativa de `ios-check` ya terminó correctamente en Codemagic.
Se importó su `Podfile.lock` al proyecto, verificando que el checksum coincidiera
con el `Podfile` utilizado.

Para una prueba personal puedes firmar e instalar la app mediante
[Sideloadly](https://sideloadly.io/) en Windows. Con una cuenta Apple gratuita la
firma dura siete días; se debe renovar para seguir usando esa instalación.
Esto permite probar la app antes de configurar los workflows de distribución
del Apple Developer Program.

El ZIP de la aplicación contiene `Runner.app`. Un IPA para esta ruta contiene
esa misma aplicación dentro de `Payload/Runner.app/`, conservando sus archivos
y permisos. Empaquetarlo como IPA no lo firma: Sideloadly realiza la firma y el
aprovisionamiento al instalarlo.

1. Instala Sideloadly desde su web oficial. Sigue sus instrucciones para los
   componentes de Apple que necesite Windows para reconocer el dispositivo.
2. Conecta el iPhone por USB, desbloquéalo y acepta **Confiar en este ordenador**.
3. Abre en Sideloadly el IPA sin firma preparado a partir del build de Codemagic.
4. Selecciona el dispositivo, inicia sesión con tu cuenta Apple en Sideloadly y
   pulsa **Start**.
5. En el iPhone, si aparece **Desarrollador no fiable**, ve a **Ajustes > General >
   VPN y gestión de dispositivos** y confía en la cuenta usada para la firma.
6. En iOS 16 o posterior activa **Ajustes > Privacidad y seguridad > Modo de
   desarrollador** y completa el reinicio y la confirmación que indique iOS.
7. Abre ServiceMET y realiza la prueba física descrita más abajo, con acceso a
   la red interna o a la VPN de la empresa.

Al renovar o actualizar, utiliza la misma cuenta y el mismo Bundle ID para
actualizar la instalación existente. Consulta los detalles y límites en las
[preguntas frecuentes de Sideloadly](https://sideloadly.io/faq).

## Generar un IPA instalable con Apple Developer

Los dos workflows firmados preparados utilizan certificados y perfiles del
Apple Developer Program. Puedes configurar esos recursos desde Windows mediante
el portal de Apple y Codemagic.

### Para instalar en iPhones concretos: `ios-adhoc`

1. Activa una membresía de [Apple Developer](https://developer.apple.com/programs/enroll/).
2. Registra el identificador de aplicación **bo.metrica.smet** en
   **Certificates, Identifiers & Profiles > Identifiers** del portal de Apple.
   El identificador debe coincidir con el proyecto y con `codemagic.yaml`.
3. Registra el **UDID de cada iPhone o iPad** en **Devices**. En una cuenta
   personal de Codemagic este registro se realiza manualmente en Apple.
4. Crea una API key en **App Store Connect > Users and Access > Integrations >
   App Store Connect API**, con el rol apropiado, por ejemplo **App Manager**.
   Conserva el archivo `.p8`, su **Key ID** y el **Issuer ID**.
5. Añade esa integración en la configuración de tu cuenta de Codemagic. En
   **Code signing identities > iOS certificates** puedes generar un certificado
   **Apple Distribution** con esa API key. Guarda y registra en Codemagic el
   certificado y su clave privada según indique su interfaz.
6. En el portal de Apple crea un perfil **Ad Hoc** para `bo.metrica.smet`,
   seleccionando el certificado anterior y los dispositivos registrados.
7. Sube el perfil `.mobileprovision` a **Code signing identities > iOS
   provisioning profiles** en Codemagic. Debe aparecer un certificado compatible.
   Los archivos de firma se configuran en Codemagic, no en el repositorio.
8. Ejecuta **iOS - IPA para iPhones registrados** (`ios-adhoc`). El workflow
   obtiene las identidades correspondientes al Bundle ID, aplica los perfiles y
   genera `build/ios/ipa/*.ipa`.
9. Abre el resultado de ese build en Safari desde un dispositivo incluido en el
   perfil. Utiliza la opción o QR de instalación del artefacto firmado que
   ofrece Codemagic. El IPA Ad Hoc solo funciona en los dispositivos del perfil.
   Para añadir otro dispositivo, regístralo y vuelve a generar y cargar el perfil.

### Para TestFlight: `ios-app-store`

1. Crea la aplicación en **App Store Connect**, con el mismo Bundle ID.
2. Prepara un perfil de distribución **App Store**, asociado al certificado
   Apple Distribution, y añádelo a **Code signing identities**.
3. Ejecuta **iOS - IPA para TestFlight o App Store** (`ios-app-store`). Este
   workflow genera el IPA para ese canal; **no lo sube ni lo publica**.
4. Para subirlo desde Codemagic, configura una integración de App Store Connect
   llamada `servicemet_apple` y añade estos dos bloques **dentro del workflow
   `ios-app-store`**, al mismo nivel que `environment`, `scripts` y `artifacts`:

   ```yaml
   integrations:
     app_store_connect: servicemet_apple
   publishing:
     app_store_connect:
       auth: integration
       submit_to_testflight: true
       submit_to_app_store: false
   ```

   Ejecuta de nuevo ese workflow cuando quieras enviar el build a TestFlight.
   Completa en App Store Connect los datos solicitados por Apple, incluida la
   declaración de cifrado y los datos de prueba que correspondan.
5. Cuando Apple procese el build, habilítalo para el grupo de pruebas y acepta
   la invitación desde la aplicación **TestFlight** del iPhone.

El IPA destinado a App Store/TestFlight no se instala directamente desde Safari.
Los builds firmados usan `PROJECT_BUILD_NUMBER + 21` como número incremental;
la versión comercial se toma de `pubspec.yaml`.

## Primera prueba en el iPhone

La primera compilación en macOS y esta prueba física son necesarias para
confirmar la compatibilidad completa. Desde Windows se pueden ejecutar el
análisis y las pruebas Flutter, pero no el compilador ni las API nativas de iOS.

1. Usa un dispositivo con **iOS/iPadOS 15.5 o posterior**.
2. Conecta el dispositivo a la Wi-Fi de la empresa o configura la VPN de iOS
   para alcanzar `192.168.1.5:3100` o `10.50.8.1:3100`. La VPN de Windows no se
   transfiere al teléfono. El certificado HTTPS debe coincidir con la huella
   fijada en `ServiceMetHttpClient`; no se desactiva esa verificación.
3. Acepta el permiso de **red local** cuando iOS lo solicite. Si se rechazó,
   habilítalo en **Ajustes > Apps > ServiceMET > Red local** o en
   **Privacidad y seguridad > Red local**, según la versión de iOS.
4. Completa la configuración y el login; descarga los catálogos. Activa la
   biometría y comprueba Face ID o Touch ID en los dispositivos compatibles.
5. Prueba crear, guardar y volver a abrir registros sin conexión; luego
   sincronízalos con el servidor.
6. Prueba fotografías, QR y el lector OCR en un equipo real. Verifica que la
   lectura mostrada coincida con el indicador antes de usarla en un registro.
7. Exporta un servicio con sus fotos. En el selector **Archivos**, crea o elige
   una carpeta local en **En mi iPhone / En mi iPad** para trabajar sin conexión.
   Debe aparecer `ServiceMET/<código>/` con el documento y las fotos.
   Prueba también **Abrir**, compartir, imprimir, respaldar e importar.
8. Verifica ubicación y notificaciones. Haz una medición programada y comprueba
   que la pantalla siga encendida; al salir debe recuperarse el bloqueo normal.

Una carpeta elegida en iCloud Drive puede necesitar conexión para sincronizarse.
Si se mueve o se revoca su permiso, vuelve a seleccionarla. La ubicación y la
cámara se usan en primer plano; una medición se pausa si se cambia de app.

## Si un build falla

- **No encuentra codemagic.yaml:** confirma que esté subido a la rama elegida y
  en la raíz del repositorio.
- **No encuentra un certificado o perfil:** usa `ios-check` mientras no tengas
  firma. Para los otros workflows verifica Bundle ID, tipo de distribución,
  vigencia del perfil y coincidencia del certificado.
- **No se puede instalar el IPA Ad Hoc:** comprueba que el UDID esté incluido
  en el perfil usado para ese build, no solo registrado en el portal.
- **Fallo de CocoaPods o Xcode:** conserva el log de la etapa que falló. No se
  debe cambiar el iOS mínimo a una versión inferior a 15.5.
- **No conecta con la API:** comprueba Wi-Fi/VPN, permiso de red local, hora del
  teléfono, disponibilidad del servidor y vigencia de su certificado HTTPS.

## Referencias

- [Configuración YAML de Codemagic](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
- [Flutter en Codemagic](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/)
- [Certificados y perfiles para iOS](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Registro de dispositivos iOS](https://docs.codemagic.io/yaml-testing/ios-provisioning/)
- [Precios y minutos gratuitos](https://codemagic.io/pricing/)
- [Distribución de Flutter para iOS](https://docs.flutter.dev/deployment/ios)
