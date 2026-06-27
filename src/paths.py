# src/paths.py
import os
import platform
from pathlib import Path

from src.formatting import header
from src.logger import get_logger

logger = get_logger()

BASE_DIR = Path(__file__).resolve().parents[1]


def get_platform() -> str:
    return platform.machine()


def get_input_dir() -> Path:
    env_path = os.getenv("TRAINING_DATA_DIR")
    if env_path and Path(env_path).exists():
        return Path(env_path)
    local_path = BASE_DIR / "input" / "data" / "training"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def get_model_dir() -> Path:
    env_path = os.getenv("MODEL_DIR")
    if env_path and Path(env_path).exists():
        return Path(env_path)
    local_path = BASE_DIR / "output" / "model"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def get_output_dir() -> Path:
    env_path = os.getenv("OUTPUT_DIR")
    if env_path and Path(env_path).exists():
        return Path(env_path)
    local_path = BASE_DIR / "output"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def print_paths():
    logger.info(header("PATHS"))
    logger.info(f"PLATFORM   = {get_platform()}")
    logger.info(f"INPUT_DIR  = {get_input_dir().resolve()}")
    logger.info(f"MODEL_DIR  = {get_model_dir().resolve()}")
    logger.info(f"OUTPUT_DIR = {get_output_dir().resolve()}")
    logger.info(50 * "=" + "\n")


if __name__ == "__main__":
    print_paths()
