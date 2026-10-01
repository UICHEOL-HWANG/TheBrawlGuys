from pathlib import Path

import pytest

from brawl_analysis.io import Dataset, load_dataset

# 8 synthetic matches (gen_dataset --matches=8 --seed=1), events cut to ringout/score/knockdown
# and the timeline thinned to one sample every 3 s to keep the fixture small.
FIXTURE = Path(__file__).parent / "fixtures" / "tiny"


@pytest.fixture(scope="session")
def tiny() -> Dataset:
    return load_dataset(FIXTURE)
