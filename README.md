# telegram-join-gif-bot

Бот для Telegram: при **системном сообщении** о том, что в **группу или супергруппу** вошёл новый участник, отправляет **GIF / анимацию** ответом на это сообщение (`[sendAnimation](https://core.telegram.org/bots/api#sendanimation)`).

В обычном личном чате таких «вступлений» нет — бот рассчитан на **группы**.

## Возможности

- Реакция на сервисное сообщение с полем `new_chat_members` (через long polling и `[getUpdates](https://core.telegram.org/bots/api#getupdates)`).
- Настраиваемая гифка: `**file_id`** или **HTTPS URL**.
- Режим **эхо `file_id`** в личке: удобно один раз получить `WELCOME_GIF_FILE_ID`, не подбирая вручную.
- Команды `**/start**` и `**/settings**` в личке — кратко показывают текущую конфигурацию (без токена).
- Скрипт `**[install.sh](install.sh)**` — клонирование репозитория, интерактивная настройка `.env`, виртуальное окружение и опционально **systemd**.

## Требования

- Python **3.10+** (используется синтаксис `str | None`).
- Зависимости: см. `[requirements.txt](requirements.txt)`.
- Для сценария «одна команда»: **bash**, **git**, доступ к **GitHub** по HTTPS.

### Клонирование для разработки

```bash
git clone https://github.com/lyakich/telegram-join-gif-bot.git
cd telegram-join-gif-bot
```

Дальше — раздел [«Установка вручную»](#установка-вручную) или запуск `[install.sh](install.sh)` из уже склонированного каталога.

## Быстрый старт (одна команда)

Репозиторий **[lyakich/telegram-join-gif-bot](https://github.com/lyakich/telegram-join-gif-bot)** на GitHub уже должен быть доступен; в ветке `**main`** лежит `**install.sh**`. Для своего форка замените `**lyakich**` в URL и в аргументе на свой логин или организацию.

```bash
curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich
```

Эквивалентно полному имени репозитория:

```bash
curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich/telegram-join-gif-bot
```

Необязательный **второй аргумент** — каталог установки (по умолчанию `~/telegram-join-gif-bot`):

```bash
curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich /opt/telegram-join-gif-bot
```

На «голой» Ubuntu без пакета `python3-venv` (одной строкой с установкой зависимостей через `apt`):

```bash
TG_JOIN_GIF_APT_INSTALL=1 curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich
```

Если репозиторий уже склонирован:

```bash
cd telegram-join-gif-bot
chmod +x install.sh
./install.sh
```

**Без запросов** (CI, скрипты), опционально с systemd:

```bash
export TG_JOIN_GIF_NONINTERACTIVE=1
export TG_JOIN_GIF_SYSTEMD=1   # при необходимости
export BOT_TOKEN="..."
export WELCOME_GIF_FILE_ID="..."   # или export WELCOME_GIF_URL="..."
# либо только эхо: export ECHO_FILE_ID_MODE=1
bash install.sh
```

Переменная `**GITHUB_REPO**` (`owner/repo`) подставляется по умолчанию в интерактивный вопрос, если первый аргумент не передан (удобно вместе с `curl | bash` без `bash -s --`).

> **Важно:** `curl … | bash` выполняет код с сервера. Используйте только доверенный URL (свой форк или репозиторий, который вы проверили).

## Установка вручную

```bash
cd telegram-join-gif-bot
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Скопируйте пример окружения и отредактируйте:

```bash
cp .env.example .env
```

## Переменные окружения


| Переменная              | Обязательно   | Описание                                                                                                                                                          |
| ----------------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BOT_TOKEN`             | да            | Токен бота от [@BotFather](https://t.me/BotFather).                                                                                                               |
| `WELCOME_GIF_FILE_ID`   | одно из двух* | `file_id` анимации уже загруженной в Telegram.                                                                                                                    |
| `WELCOME_GIF_URL`       | одно из двух* | Прямой HTTPS URL на `.gif` или видео, пригодное для `sendAnimation`.                                                                                              |
| `ECHO_FILE_ID_MODE`     | нет           | `1` / `true` / `yes` / `on` — в **личке** бот отвечает списком `file_id` на подходящие медиа-сообщения.                                                           |
| `ECHO_ALLOWED_USER_IDS` | нет           | Через запятую числовые [user id](https://core.telegram.org/bots/api#user): эхо только для этих пользователей. Если не задано — эхо для любого, кто пишет в личку. |


 Для работы приветствия в группе нужен `**WELCOME_GIF_FILE_ID*`* или `**WELCOME_GIF_URL**`. Если включён только `**ECHO_FILE_ID_MODE**`, бот может стартовать **без** гифки, чтобы сначала получить `file_id`; до появления `WELCOME_GIF_*` ответы на вход в группу отправляться не будут.

Файл `**.env`** в корне проекта подхватывается автоматически ([python-dotenv](https://pypi.org/project/python-dotenv/)).

## Запуск

```bash
source .venv/bin/activate
python bot.py
```

## Настройка в Telegram

1. Создайте бота в [@BotFather](https://t.me/BotFather), получите `BOT_TOKEN`.
2. Добавьте бота в группу.
3. В BotFather для этого бота выполните `**/setprivacy` → Disable**. Иначе при включённой приватности бот часто **не получает** сервисные сообщения о новых участниках, и обработчик не сработает.
4. Задайте гифку через `WELCOME_GIF_FILE_ID` или `WELCOME_GIF_URL`.

### Как получить `WELCOME_GIF_FILE_ID`

1. В `.env` выставьте `ECHO_FILE_ID_MODE=1` (и при публичном боте — `ECHO_ALLOWED_USER_IDS` со своим user id).
2. Перезапустите бота, в **личку** боту отправьте нужную гифку / видео / фото.
3. Скопируйте из ответа строку `animation.file_id` (или подходящий `document` / `video`, если так пришло сообщение) в `WELCOME_GIF_FILE_ID`.
4. Выключите эхо (`ECHO_FILE_ID_MODE=0`), если он больше не нужен.

Альтернатива: взять `file_id` из логов своего кода или из ответа Bot API после отправки файла.

## Команды (только личный чат)

- `**/start`** — краткое описание и сводка настроек.
- `**/settings**` — та же сводка.

## Как устроен опрос сервера

Используется **long polling**: запросы `getUpdates` висят на стороне Telegram до появления апдейтов или до таймаута, а не «стучат» с фиксированным коротким интервалом вхолостую. Подробнее — в [документации Bot API](https://core.telegram.org/bots/api#getupdates).

## Развёртывание на виртуальной машине в Yandex Cloud

Ниже — типовой сценарий: одна ВМ с **Ubuntu** в [Yandex Compute Cloud](https://cloud.yandex.ru/docs/compute/), бот в **long polling** (входящий трафик от Telegram **не нужен**, достаточно **исходящего HTTPS** на `api.telegram.org`).

### 1. Облако и сеть

1. Войдите в [консоль Yandex Cloud](https://console.cloud.yandex.ru/) и выберите **каталог** (folder), где будет ВМ.
2. Убедитесь, что есть **подсеть** в нужной зоне доступности (при создании ВМ её можно создать мастером).
3. **Группа безопасности** (или правила на уровне сети) для ВМ:
  - **Исходящий** трафик: разрешить **HTTPS (443)** в интернет (для Bot API).
  - **Входящий** (по желанию): **SSH (22)** только с ваших IP — для администрирования. Публичный IP ВМ не обязателен, если подключаетесь через [Bastion](https://cloud.yandex.ru/docs/tutorials/security/bastion/) или другой способ, но для простейшего варианта чаще выдают публичный IPv4 и открывают 22 ограниченно.

Подробнее о создании ВМ: [документация Compute Cloud](https://cloud.yandex.ru/docs/compute/operations/vm-create/create-linux-vm).

### 2. Создание ВМ

1. **Compute Cloud** → **Виртуальные машины** → **Создать ВМ**.
2. **Образ**: например **Ubuntu 22.04 LTS** (или новее, с Python 3.10+).
3. **Платформа и vCPU/RAM**: для одного бота достаточно минимальной конфигурации (например 2 vCPU / 2 ГБ или меньше по тарифу).
4. **Диск**: 10–20 ГБ SSD обычно с запасом.
5. **Сеть**: выберите подсеть, назначьте публичный адрес, если планируете SSH с интернета.
6. **Доступ**: добавьте **SSH-ключ** (публичная часть `~/.ssh/id_rsa.pub` или аналог). Имя пользователя для входа зависит от образа (для официального Ubuntu в Yandex Cloud часто `**ubuntu`** — уточните подсказку в мастере создания ВМ).
7. Создайте ВМ и дождитесь статуса **Running**.

### 3. Установка бота на ВМ

Подключитесь по SSH (подставьте пользователя, IP и путь к ключу):

```bash
ssh -i ~/.ssh/your_key ubuntu@<PUBLIC_IP>
```

**Быстрее:** на ВМ достаточно выполнить одну команду из раздела [«Быстрый старт»](#быстрый-старт-одна-команда) (при необходимости добавьте `TG_JOIN_GIF_APT_INSTALL=1`; для форка замените `lyakich` в URL и в аргументе).

Ручной перенос кода (если не используете `install.sh`):

```bash
sudo apt update && sudo apt install -y python3-venv python3-pip git curl
sudo mkdir -p /opt/telegram-join-gif-bot
sudo chown "$USER":"$USER" /opt/telegram-join-gif-bot
cd /opt/telegram-join-gif-bot
git clone https://github.com/lyakich/telegram-join-gif-bot.git .
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
nano .env
chmod 600 .env
```

Проверочный запуск:

```bash
.venv/bin/python bot.py
```

Остановите процесс (**Ctrl+C**) после проверки.

### 4. Сервис systemd (автозапуск и перезапуск)

Чтобы бот поднимался после перезагрузки ВМ и перезапускался при сбое:

```bash
sudo nano /etc/systemd/system/telegram-join-gif-bot.service
```

Пример юнита (пути и пользователя приведите к своим):

```ini
[Unit]
Description=Telegram join GIF bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/telegram-join-gif-bot
ExecStart=/opt/telegram-join-gif-bot/.venv/bin/python /opt/telegram-join-gif-bot/bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

Активация:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now telegram-join-gif-bot.service
sudo systemctl status telegram-join-gif-bot.service
```

Логи:

```bash
journalctl -u telegram-join-gif-bot.service -f
```

### 5. Обновление кода на ВМ

```bash
cd /opt/telegram-join-gif-bot
git pull
sudo systemctl restart telegram-join-gif-bot.service
```

### 6. Замечания по безопасности

- Не коммитьте `.env` в git (он в [.gitignore](.gitignore)); на ВМ держите права `**chmod 600 .env**`.
- Токен бота = секрет: ограничьте доступ к ВМ и к резервным копиям диска.
- Режим `**ECHO_FILE_ID_MODE**` в проде лучше держать выключенным или ограничивать `**ECHO_ALLOWED_USER_IDS**`, чтобы посторонние не дергали бота в личке.

## Публикация и релиз на GitHub

1. Создайте **новый** репозиторий `telegram-join-gif-bot` в своём аккаунте или организации ([инструкция GitHub](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)). Удобно **без** автоматического README, чтобы не мешал первому `push`.
2. **Первый push** из каталога с кодом (для этого репозитория — `lyakich`; для форка замените на свой логин):

```bash
git init             # только если в каталоге ещё нет .git
git branch -M main   # если ветка ещё не main
git add .
git status           # убедитесь, что .env и .venv не попали в коммит
git commit -m "Initial commit: Telegram join GIF bot"
git remote add origin https://github.com/lyakich/telegram-join-gif-bot.git
git push -u origin main
```

Если `origin` уже добавлен: `git remote set-url origin https://github.com/lyakich/telegram-join-gif-bot.git`.

Если репозиторий на GitHub **уже создан** с файлами (README и т.д.), перед первым push может понадобиться:  
`git pull origin main --rebase` или слияние несвязанных историй — см. [документацию](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts).

**SSH** (если настроен ключ в GitHub):

```bash
git remote add origin git@github.com:lyakich/telegram-join-gif-bot.git
git push -u origin main
```

Если `git push` **«висит»** без ошибки, чаще всего ждёт ввода логина/пароля в невидимом режиме: используйте [Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) вместо пароля для HTTPS, перейдите на **SSH**, либо выполните `gh auth login` ([GitHub CLI](https://cli.github.com/)).

1. **Тег** версии (пример `v1.0.0`) и отправка на GitHub:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

1. В веб-интерфейсе GitHub: **Releases** → **Create a new release** → выберите тег `v1.0.0`, опишите изменения, опубликуйте.
  Либо: `gh release create v1.0.0 --title "v1.0.0" --notes-file CHANGELOG.md`.

### Уже есть локальный `git init`

Не создавайте репозиторий заново: достаточно `git remote add origin …` (или `git remote set-url origin …`), затем `git push -u origin main` и при наличии тегов — `git push origin --tags`.

Скрипт установки по умолчанию читается с ветки `**main`**:  
`https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh`  
После релиза в описании можно дать ту же команду с URL на **конкретный тег** (файл совпадает с исходниками на теге).

### Структура репозитория


| Файл / каталог                         | Назначение                                    |
| -------------------------------------- | --------------------------------------------- |
| `[bot.py](bot.py)`                     | Логика бота                                   |
| `[install.sh](install.sh)`             | Интерактивная установка и опционально systemd |
| `[.env.example](.env.example)`         | Шаблон переменных окружения                   |
| `[requirements.txt](requirements.txt)` | Зависимости Python                            |
| `[CHANGELOG.md](CHANGELOG.md)`         | Заметки к релизам                             |


## Лицензия

Проект без явной лицензии: используйте и дорабатывайте по своему усмотрению.