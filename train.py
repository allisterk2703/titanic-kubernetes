#!/usr/bin/env python3
from src.config import TARGET_COLUMN
from src.evaluate import evaluate
from src.load import load_data
from src.logger import get_logger
from src.paths import print_paths
from src.preprocess import preprocess
from src.train import train_model

logger = get_logger()


def main():
    print_paths()

    df = load_data()
    df = preprocess(df)
    train_model(df, target_col=TARGET_COLUMN)
    evaluate()


if __name__ == "__main__":
    main()
