# GU-WOW

**Русский** · [English](#english)

Графическое улучшение World of Warcraft, созданное для сообщества Brothers of Turtle. Проверено на Tauri (Legion 7.3.5).

Добавляет в игру туман и низовую дымку, солнечные и лунные лучи, настоящую ночь, в которой светят огни, тени в щелях, мокрую землю в дождь, цветовые стили и фоторежим. Всё настраивается прямо в игре: Интерфейс > Модификации > GU-WOW, или кнопка у миникарты.

## Установка

1. Скачайте архив последней версии на странице [Releases](https://github.com/iievan/GU-wow/releases) и распакуйте его.
2. Закройте игру и запустите `GU-WOW.exe`. Если Windows покажет «Система Windows защитила ваш компьютер», нажмите «Подробнее» и «Выполнить в любом случае».
3. Проверьте папку игры в верхней строке и нажмите «Установить». Нужен интернет: ReShade скачивается с [reshade.me](https://reshade.me).
4. Запустите игру. Первый запуск дольше обычного: эффекты собираются 10–20 секунд.

Удаление: `GU-WOW.exe`, кнопка «Удалить».

Что нового в каждой версии: [CHANGELOG.md](CHANGELOG.md). Подробное руководство: [docs/manual-ru.md](docs/manual-ru.md).

## Клиенты

| Клиент | Состояние |
|---|---|
| Legion 7.3.5 (Tauri) | проверено, интерфейс не затрагивается |
| WotLK 3.3.5, Cataclysm 4.3.4, MoP 5.4.8 | ставится, в игре не проверено, туман ложится и на интерфейс |
| Classic 1.12, TBC 2.4.3 | ставится без меню в игре, настройки в окне ReShade |

## Лицензия

GPL-3.0. Туман и лучи основаны на [comfyatmosphere](https://github.com/aloofbit/comfyatmosphere) автора aloofbit. В установщик входит [ReshadeEffectShaderToggler](https://github.com/4lex4nder/ReshadeEffectShaderToggler) (MIT). ReShade не входит в пакет: установщик скачивает его с официального сайта. Проект не связан с компанией Blizzard Entertainment.

---

## English

A graphics upgrade for World of Warcraft, made for the Brothers of Turtle community. Tested on Tauri (Legion 7.3.5).

It adds fog and ground mist, sun and moon rays, a real night where the lights keep glowing, contact shadows, wet ground in the rain, colour styles and a photo mode. Everything is set up right in the game: Interface > AddOns > GU-WOW, or the minimap button.

## Installation

1. Download the latest archive from [Releases](https://github.com/iievan/GU-wow/releases) and unpack it.
2. Close the game and run `GU-WOW.exe`. If Windows says "Windows protected your PC", click "More info" and "Run anyway".
3. Check the game folder in the top line and press "Установить" (Install). An internet connection is needed: ReShade is downloaded from [reshade.me](https://reshade.me).
4. Start the game. The first start takes longer: the effects compile for 10 to 20 seconds.

To remove: `GU-WOW.exe`, the "Удалить" (Remove) button.

What is new in each version: [CHANGELOG.md](CHANGELOG.md).

## Clients

| Client | Status |
|---|---|
| Legion 7.3.5 (Tauri) | tested, the interface is left alone |
| WotLK 3.3.5, Cataclysm 4.3.4, MoP 5.4.8 | installs, not tested in game, the fog also covers the interface |
| Classic 1.12, TBC 2.4.3 | installs without the in-game menu, settings in the ReShade window |

## License

GPL-3.0. The fog and rays are based on [comfyatmosphere](https://github.com/aloofbit/comfyatmosphere) by aloofbit. The installer includes [ReshadeEffectShaderToggler](https://github.com/4lex4nder/ReshadeEffectShaderToggler) (MIT). ReShade is not part of the package: the installer downloads it from the official site. This project is not affiliated with Blizzard Entertainment.
