# Instalar Agendaservi en tu iPhone

Cada push a `main` dispara el workflow **Build iOS IPA** (pestaña *Actions*
del repo), que compila la app en un Mac de GitHub y publica
`Agendaservi-unsigned.ipa` en dos sitios:

- **Releases** del repo (lo más cómodo de descargar)
- Artefactos del workflow (30 días)

## Por qué "unsigned"

Apple exige que toda app instalada en un iPhone esté **firmada**. Como el repo
no tiene una cuenta de Apple Developer (99 USD/año), el IPA sale sin firma y
la firma se hace en el momento de instalar, con tu Apple ID gratuito.

Con Apple ID gratuito la app **caduca a los 7 días** y hay que reinstalarla
(mismo procedimiento, 2 minutos). Con cuenta de pago dura 1 año.

## Opción A — Sideloadly (recomendada)

1. Descarga [Sideloadly](https://sideloadly.io/) en tu PC (Windows sirve).
2. Descarga `Agendaservi-unsigned.ipa` desde Releases.
3. Conecta el iPhone por USB y ábrelo desbloqueado.
4. Arrastra el IPA a Sideloadly, escribe tu Apple ID y pulsa *Start*.
5. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** →
   confía en tu certificado de desarrollador.
6. Abre Agendaservi. Listo: la app consume directamente el backend de
   producción en `https://dibeltran05.alwaysdata.net`.

## Opción B — AltStore

Igual de válida: instala AltServer en el PC, AltStore en el iPhone, y desde
AltStore abre el IPA descargado. AltStore además **renueva la firma sola**
cada 7 días si el iPhone está en la misma red que el PC.

## Si algún día tienes cuenta de Apple Developer

Se añade el certificado y el provisioning profile como *secrets* del repo y
el workflow puede firmar y hasta subir a TestFlight. Pídelo y se configura.
