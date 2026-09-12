# CI/CD de jocaagura_ia

El proyecto es un paquete Dart. `0.0.0` identifica el bootstrap local;
no se publica mediante el workflow. La versión mínima de Dart es 3.13.2.

## Integración continua

`Dart CI` se ejecuta en pushes a cualquier rama, PR hacia `develop` o `master`,
ejecución manual y llamadas desde preparación/publicación de versiones.
Los jobs no omiten actores bot ni títulos de PR con `[skip ci]`.
GitHub todavía reconoce sus propias instrucciones de omisión en mensajes de
commit: el check obligatorio `CI result` debe estar configurado para impedir
integrar cambios sin validación. No uses instrucciones de omisión de CI.

Los controles incluyen firmas verificadas por GitHub, ausencia de overrides
versionados, formato, análisis estricto, pruebas de los scripts de release,
validación de workflows con actionlint, pruebas Dart y cobertura LCOV.
La consulta de commits usa paginación; el primer push valida toda su historia.
En una ejecución manual se verifica la firma del commit seleccionado.

La cobertura mínima es **95 %**, con objetivo del **100 %**. La variable de
Actions `COVERAGE_MIN` es opcional y solo permite elevar el umbral hasta 100.
Se compara la proporción real sin redondearla. La ausencia de pruebas o líneas
ejecutables hace fallar CI. Los informes se conservan durante 14 días.
La cobertura mide las líneas de `lib` reportadas por la VM durante las pruebas;
no garantiza que archivos nunca cargados estén incluidos. El scaffold inicial
solo tiene una línea ejecutable, por lo que su 100 % no mide funcionalidad futura.

CodeQL analiza el lenguaje `actions`, es decir, los propios workflows. No
analiza Dart. Se ejecuta en PR/push de las ramas principales y semanalmente.

### Comprobación local

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings .
dart test --coverage=coverage/raw
dart run coverage:format_coverage --lcov --in=coverage/raw --out=coverage/lcov.info --report-on=lib
python -m pip install -r .github/scripts/requirements.txt
python -m unittest discover -s .github/scripts/tests -v
```

Las pruebas de scripts requieren Bash; está incluido en Git for Windows.
Si cambia la versión mínima del SDK, actualiza los pasos `setup-dart` de CI y
publicación. Los paquetes anidados con pruebas también deben declarar `coverage`
como dependencia de desarrollo.

## Preparación de versiones

1. Agrega las contribuciones bajo `## Unreleased` en `CHANGELOG.md`.
2. Ejecuta `Prepare version` seleccionando la rama `develop`.
3. Indica una versión estable `X.Y.Z` superior a la actual, por ejemplo `0.0.1`,
   y notas Markdown UTF-8 codificadas en Base64. Deben contener secciones `###`
   como `### Added` o `### Fixed`, sin encabezados `##`.
4. El workflow valida CI, mueve las notas a `## [X.Y.Z] - YYYY-MM-DD`, conserva
   `Unreleased` vacío y crea un commit firmado por GitHub en `develop`.
5. Integra `develop` en `master` mediante PR y CI aprobado.

Solo se admiten releases estables en este flujo; no se aceptan sufijos `+build`
ni prereleases. Repetir la misma versión con las mismas notas no crea otro
commit; cambiar notas de una versión preparada produce un error.
La actualización verifica el HEAD esperado para evitar sobrescribir cambios
concurrentes. Si el HEAD cambia, vuelve a ejecutar el workflow.

El commit de preparación usa `GITHUB_TOKEN`, cuyo push no dispara otro CI;
por eso se ejecuta CI antes de modificar los dos archivos de versión, y se
repite para el PR de integración y para el tag de publicación.
Si las reglas de `develop` impiden commits directos del workflow, la operación
fallará: en ese caso prepara esos dos archivos mediante un PR normal, sin
desactivar las protecciones de la rama.

## Publicación

El workflow `Publish package` se activa con un tag `vX.Y.Z`. Comprueba que el
commit pertenezca al historial de `master`, que coincida con `pubspec.yaml`,
que la versión sea distinta de `0.0.0` y tenga una única entrada de changelog
con fecha y contenido. Ejecuta `dart pub publish --dry-run`, CI completo y
el workflow oficial de Dart para publicar mediante OIDC, sin tokens duraderos.
Después crea la GitHub Release con las notas de esa versión.
Si solo falla la creación de la GitHub Release, reejecuta los jobs fallidos
para evitar repetir la publicación que ya se realizó.

## Configuración al crear el repositorio oficial

- Crea un repositorio vacío y conecta su URL como `origin`; sube `master` y
  `develop`. Añade esa URL al campo `repository` de `pubspec.yaml`.
- Registra en GitHub la clave pública que firma los commits locales para que
  aparezcan como `Verified`. CI exige esa verificación desde el primer push.
- Configura `CI result` como check obligatorio y los PR de integración a
  `master`. Configura CodeQL según la disponibilidad de code scanning del repo.
- `COVERAGE_MIN` puede omitirse (95 %) o configurarse entre 95 y 100.
- Completa la descripción, README y funcionalidad del paquete antes de la
  primera publicación. Mantén notas reales para la versión que se publique.
- La primera publicación de un paquete nuevo debe realizarla un mantenedor;
  después, habilita Automated publishing en pub.dev para el repositorio oficial
  y el patrón `v{{version}}`. Para esa primera versión, publica manualmente
  desde el commit validado y después crea su tag/release; el job OIDC no podrá
  publicar de nuevo la misma versión. Los siguientes tags usarán el flujo completo.
- Restringe la creación/modificación de tags `v*` a los responsables de releases.

El dry-run del bootstrap todavía advertirá que `0.0.0` no tiene entrada de
release. Es una condición deliberada de esta fase inicial; el workflow bloquea
su publicación. La URL oficial ya está declarada en `pubspec.yaml`.

Referencias: [publicación automatizada de Dart](https://dart.dev/tools/pub/automated-publishing),
[eventos y GITHUB_TOKEN](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[lenguajes de CodeQL](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/).
