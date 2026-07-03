from nv_failsafe_recovery.utilities import version_meets_minimum


def test_string_comparison_false_positive_for_future_major_versions():
    assert "10.0" < "5.1"


def test_accepts_python_10_plus_with_numeric_version_comparison():
    assert version_meets_minimum("10.0", "3.11") is True
    assert version_meets_minimum("3.12", "3.11") is True


def test_rejects_versions_below_minimum():
    assert version_meets_minimum("3.10", "3.11") is False
    assert version_meets_minimum("2.7", "3.11") is False


def test_accepts_exact_minimum_version():
    assert version_meets_minimum("3.11", "3.11") is True
