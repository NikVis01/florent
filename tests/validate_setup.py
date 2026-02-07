#!/usr/bin/env python3
"""
Validate test setup and environment.

This script checks that all test dependencies and imports are working correctly.
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def check_imports():
    """Check that all required modules can be imported."""
    print("Checking imports...")
    errors = []

    # Standard library
    try:
        import unittest
        print("✓ unittest")
    except ImportError as e:
        errors.append(f"✗ unittest: {e}")

    try:
        from unittest.mock import patch, MagicMock
        print("✓ unittest.mock")
    except ImportError as e:
        errors.append(f"✗ unittest.mock: {e}")

    # Third-party
    try:
        import pydantic
        print(f"✓ pydantic (version {pydantic.__version__})")
    except ImportError as e:
        errors.append(f"✗ pydantic: {e}")

    # Optional
    try:
        import pytest
        print(f"✓ pytest (version {pytest.__version__})")
    except ImportError:
        print("⚠ pytest (optional, not installed)")

    try:
        import coverage
        print(f"✓ coverage (version {coverage.__version__})")
    except ImportError:
        print("⚠ coverage (optional, not installed)")

    return errors


def check_src_modules():
    """Check that source modules can be imported."""
    print("\nChecking source modules...")
    errors = []

    modules_to_check = [
        'src.models.base',
        'src.models.entities',
        'src.models.graph',
        'src.services.agent.core.traversal',
        'src.services.country.geo',
        'src.settings',
    ]

    for module in modules_to_check:
        try:
            __import__(module)
            print(f"✓ {module}")
        except ImportError as e:
            errors.append(f"✗ {module}: {e}")
            print(f"✗ {module}: {e}")

    return errors


def check_test_files():
    """Check that all test files exist and are readable."""
    print("\nChecking test files...")
    test_dir = os.path.dirname(__file__)

    expected_files = [
        'test_base.py',
        'test_entities.py',
        'test_graph.py',
        'test_traversal.py',
        'test_orchestrator.py',
        'test_signatures.py',
        'test_tensor_ops.py',
        'test_ai_client.py',
        'test_geo.py',
        'test_settings.py',
        'test_integration.py',
        'conftest.py',
        'pytest.ini',
        'run_tests.py',
    ]

    errors = []
    for filename in expected_files:
        filepath = os.path.join(test_dir, filename)
        if os.path.exists(filepath):
            print(f"✓ {filename}")
        else:
            errors.append(f"✗ {filename} (not found)")
            print(f"✗ {filename} (not found)")

    return errors


def check_test_discovery():
    """Check that tests can be discovered."""
    print("\nChecking test discovery...")
    import unittest

    loader = unittest.TestLoader()
    test_dir = os.path.dirname(__file__)

    try:
        suite = loader.discover(test_dir, pattern='test_*.py')
        test_count = suite.countTestCases()
        print(f"✓ Discovered {test_count} tests")
        return []
    except Exception as e:
        error = f"✗ Test discovery failed: {e}"
        print(error)
        return [error]


def run_sample_test():
    """Run a simple sample test to verify test execution."""
    print("\nRunning sample test...")
    import unittest

    class SampleTest(unittest.TestCase):
        def test_sample(self):
            """Sample test to verify testing infrastructure."""
            self.assertTrue(True)

    suite = unittest.TestLoader().loadTestsFromTestCase(SampleTest)
    runner = unittest.TextTestRunner(verbosity=0)
    result = runner.run(suite)

    if result.wasSuccessful():
        print("✓ Sample test passed")
        return []
    else:
        error = "✗ Sample test failed"
        print(error)
        return [error]


def main():
    """Main validation function."""
    print("="*70)
    print("Florent Test Setup Validation")
    print("="*70)

    all_errors = []

    # Run all checks
    all_errors.extend(check_imports())
    all_errors.extend(check_src_modules())
    all_errors.extend(check_test_files())
    all_errors.extend(check_test_discovery())
    all_errors.extend(run_sample_test())

    # Summary
    print("\n" + "="*70)
    print("Validation Summary")
    print("="*70)

    if not all_errors:
        print("✓ All checks passed! Test environment is ready.")
        print("\nYou can now run tests with:")
        print("  python tests/run_tests.py")
        print("  python -m pytest tests/")
        print("  python -m unittest discover tests/")
        return 0
    else:
        print(f"✗ {len(all_errors)} error(s) found:")
        for error in all_errors:
            print(f"  {error}")
        print("\nPlease resolve these issues before running tests.")
        return 1


if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)
