"""Extra locales for app UI strings that previously copied English."""
from app_ui_locales_a import LOCALES_A
from app_ui_locales_b import LOCALES_B
from app_ui_locales_c import LOCALES_C

LOCALES: dict[str, tuple[str, str, str, str, str, str]] = {
    **LOCALES_A,
    **LOCALES_B,
    **LOCALES_C,
}
