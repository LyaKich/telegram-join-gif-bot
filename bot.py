#!/usr/bin/env python3
"""
Telegram-бот: при системном сообщении о вступлении в группу отправляет GIF.

Переменные окружения (см. также /settings в личке с ботом):

  BOT_TOKEN              — токен от @BotFather (обязательно)
  WELCOME_GIF_FILE_ID    — file_id гифки (предпочтительно)
  WELCOME_GIF_URL        — HTTPS URL на .gif / mp4 для sendAnimation

  ECHO_FILE_ID_MODE      — 1/true/yes/on: в личке отвечать file_id на медиа
  ECHO_ALLOWED_USER_IDS  — необязательно: список user id через запятую; если
                           задан — эхо только для них. Иначе — любой личный чат.

В группе: @BotFather → /setprivacy → Disable, иначе join-сообщения могут не приходить.

Опционально: файл .env в каталоге проекта (подхватывается через python-dotenv).
"""

from __future__ import annotations

import html
import logging
import os
import re
import sys

from telegram import Update
from telegram.constants import ChatType
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None  # type: ignore[misc, assignment]

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)


def _env_truthy(name: str) -> bool:
    v = os.environ.get(name, "").strip().lower()
    return v in ("1", "true", "yes", "on")


def _echo_file_id_mode() -> bool:
    return _env_truthy("ECHO_FILE_ID_MODE")


def _echo_allowed_user_ids() -> frozenset[int] | None:
    raw = os.environ.get("ECHO_ALLOWED_USER_IDS", "").strip()
    if not raw:
        return None
    out: set[int] = set()
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.add(int(part))
        except ValueError:
            logger.warning("ECHO_ALLOWED_USER_IDS: пропуск нечисла %r", part)
    return frozenset(out) if out else None


def _echo_user_allowed(user_id: int) -> bool:
    allowed = _echo_allowed_user_ids()
    if allowed is None:
        return True
    return user_id in allowed


def _animation_source() -> str | None:
    file_id = os.environ.get("WELCOME_GIF_FILE_ID", "").strip()
    if file_id:
        return file_id
    url = os.environ.get("WELCOME_GIF_URL", "").strip()
    if url:
        return url
    return None


def _welcome_configured() -> bool:
    return _animation_source() is not None


def _lines_media_file_ids(update: Update) -> list[str]:
    msg = update.message
    if not msg:
        return []
    lines: list[str] = []

    if msg.animation:
        a = msg.animation
        lines.append(
            f"animation.file_id = <code>{html.escape(a.file_id)}</code>"
        )
        if a.file_unique_id:
            lines.append(
                "animation.file_unique_id = "
                f"<code>{html.escape(a.file_unique_id)}</code>"
            )
    if msg.document:
        d = msg.document
        mime = html.escape(d.mime_type or "?")
        lines.append(
            f"document.file_id = <code>{html.escape(d.file_id)}</code> (mime: {mime})"
        )
    if msg.video:
        v = msg.video
        lines.append(f"video.file_id = <code>{html.escape(v.file_id)}</code>")
    if msg.video_note:
        vn = msg.video_note
        lines.append(
            f"video_note.file_id = <code>{html.escape(vn.file_id)}</code>"
        )
    if msg.photo:
        p = msg.photo[-1]
        lines.append(
            f"photo (largest).file_id = <code>{html.escape(p.file_id)}</code>"
        )

    return lines


def _settings_text() -> str:
    echo_on = _echo_file_id_mode()
    allowed = _echo_allowed_user_ids()
    if allowed is None:
        allow_txt = "любой пользователь в личке"
    else:
        allow_txt = "только id: " + ", ".join(str(i) for i in sorted(allowed))

    welcome = _welcome_configured()
    w_state = "<b>задана</b>" if welcome else "<b>нет</b>"
    w_hint = (
        ""
        if welcome
        else " (<code>WELCOME_GIF_FILE_ID</code> или <code>WELCOME_GIF_URL</code>)"
    )
    echo_state = "<b>вкл</b>" if echo_on else "<b>выкл</b>"
    allow_extra = (
        " (<code>ECHO_ALLOWED_USER_IDS</code> пуст — без ограничения)"
        if allowed is None
        else ""
    )
    lines = [
        "<b>Настройки бота</b> (из окружения / <code>.env</code>)",
        "",
        f"• Приветственная анимация: {w_state}{w_hint}",
        f"• Режим эхо file_id: {echo_state} (<code>ECHO_FILE_ID_MODE</code>)",
        f"• Кому доступно эхо: {html.escape(allow_txt)}{allow_extra}",
        "",
        "Подсказка: отправьте в <b>личку</b> боту гифку / видео / фото — при включённом эхо "
        "получите <code>file_id</code> для <code>WELCOME_GIF_FILE_ID</code>.",
    ]
    return "\n".join(lines)


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat or update.effective_chat.type != ChatType.PRIVATE:
        return
    await update.message.reply_text(
        "Бот шлёт GIF ответом на сообщение о <b>новом участнике</b> в группе.\n\n"
        + _settings_text(),
        parse_mode="HTML",
    )


async def cmd_settings(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat or update.effective_chat.type != ChatType.PRIVATE:
        return
    await update.message.reply_text(_settings_text(), parse_mode="HTML")


async def on_echo_file_id(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not _echo_file_id_mode():
        return
    if not update.effective_chat or update.effective_chat.type != ChatType.PRIVATE:
        return
    user = update.effective_user
    if not user or not _echo_user_allowed(user.id):
        return
    if not update.message:
        return

    lines = _lines_media_file_ids(update)
    if not lines:
        return

    body = (
        "Скопируйте значение в <code>WELCOME_GIF_FILE_ID</code>:\n\n"
        + "\n".join(lines)
    )
    try:
        await update.message.reply_text(body, parse_mode="HTML")
    except Exception:
        logger.exception("echo file_id reply failed")
        plain = re.sub(r"<[^>]*>", "", body)
        await update.message.reply_text(plain)


async def on_new_chat_members(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    if not update.message or not update.message.new_chat_members:
        return
    chat = update.effective_chat
    if not chat:
        return
    animation = _animation_source()
    if not animation:
        logger.warning(
            "Новый участник в chat_id=%s, но WELCOME_GIF не задан — пропуск",
            chat.id,
        )
        return
    try:
        await context.bot.send_animation(
            chat_id=chat.id,
            animation=animation,
            reply_to_message_id=update.message.message_id,
        )
    except Exception:
        logger.exception("Не удалось отправить GIF в chat_id=%s", chat.id)


def _build_private_media_filter() -> filters.BaseFilter:
    media = (
        filters.ANIMATION
        | filters.VIDEO
        | filters.VIDEO_NOTE
        | filters.PHOTO
        | filters.Document.MimeType("image/gif")
        | filters.Document.MimeType("video/mp4")
    )
    return filters.ChatType.PRIVATE & ~filters.COMMAND & media


def main() -> None:
    if load_dotenv:
        load_dotenv()

    token = os.environ.get("BOT_TOKEN", "").strip()
    if not token:
        print("Укажите BOT_TOKEN в окружении или .env.", file=sys.stderr)
        sys.exit(1)

    has_welcome = _welcome_configured()
    echo_on = _echo_file_id_mode()
    if not has_welcome and not echo_on:
        print(
            "Задайте WELCOME_GIF_FILE_ID или WELCOME_GIF_URL, либо включите "
            "ECHO_FILE_ID_MODE=1 для настройки без гифки.",
            file=sys.stderr,
        )
        sys.exit(1)
    if not has_welcome and echo_on:
        logger.warning(
            "Приветственная гифка не задана: join-события будут пропускаться, "
            "пока не появится WELCOME_GIF_FILE_ID / WELCOME_GIF_URL"
        )

    app = Application.builder().token(token).build()

    private = filters.ChatType.PRIVATE
    app.add_handler(CommandHandler("start", cmd_start, filters=private))
    app.add_handler(CommandHandler("settings", cmd_settings, filters=private))

    if echo_on:
        app.add_handler(
            MessageHandler(_build_private_media_filter(), on_echo_file_id)
        )

    app.add_handler(
        MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, on_new_chat_members)
    )

    logger.info("Бот запущен (long polling); echo_file_id=%s", echo_on)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
