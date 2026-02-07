#!/usr/bin/env python3
"""
Test runner script for Florent test suite.

Usage:
    python tests/run_tests.py              # Run all tests
    python tests/run_tests.py unit         # Run only unit tests
    python tests/run_tests.py integration  # Run only integration tests
    python tests/run_tests.py fast         # Run only fast tests (exclude slow)
    python tests/run_tests.py coverage     # Run with coverage report
"""

import sys
import os
import unittest
import argparse


def discover_tests(pattern='test_*.py', start_dir='tests'):
    """Discover all test files matching the pattern."""
    loader = unittest.TestLoader()
    suite = loader.discover(start_dir, pattern=pattern)
    return suite


def run_unit_tests():
    """Run only unit tests."""
    print("Running unit tests...\n")
    # Unit tests are individual test files except test_integration.py
    unit_test_files = [
        'test_base.py',
        'test_entities.py',
        'test_graph.py',
        'test_traversal.py',
        'test_orchestrator.py',
        'test_signatures.py',
        'test_tensor_ops.py',
        'test_ai_client.py',
        'test_geo.py',
        'test_settings.py'
    ]

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    for test_file in unit_test_files:
        module_name = f"tests.{test_file[:-3]}"
        try:
            module = __import__(module_name, fromlist=[''])
            suite.addTests(loader.loadTestsFromModule(module))
        except ImportError as e:
            print(f"Warning: Could not import {module_name}: {e}")

    return suite


def run_integration_tests():
    """Run only integration tests."""
    print("Running integration tests...\n")
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromName('tests.test_integration')
    return suite


def run_all_tests():
    """Run all tests."""
    print("Running all tests...\n")
    return discover_tests()


def run_with_coverage(suite):
    """Run tests with coverage report."""
    try:
        import coverage
    except ImportError:
        print("Error: coverage package not installed.")
        print("Install with: pip install coverage")
        sys.exit(1)

    cov = coverage.Coverage(source=['src'])
    cov.start()

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    cov.stop()
    cov.save()

    print("\n" + "="*70)
    print("Coverage Report:")
    print("="*70)
    cov.report()

    # Generate HTML report
    html_dir = 'htmlcov'
    cov.html_report(directory=html_dir)
    print(f"\nDetailed HTML coverage report generated in: {html_dir}/index.html")

    return result


def main():
    """Main test runner function."""
    parser = argparse.ArgumentParser(description='Run Florent test suite')
    parser.add_argument(
        'mode',
        nargs='?',
        default='all',
        choices=['all', 'unit', 'integration', 'fast', 'coverage'],
        help='Test mode to run (default: all)'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Verbose output'
    )
    parser.add_argument(
        '-f', '--failfast',
        action='store_true',
        help='Stop on first failure'
    )
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Minimal output'
    )

    args = parser.parse_args()

    # Set verbosity level
    if args.quiet:
        verbosity = 0
    elif args.verbose:
        verbosity = 2
    else:
        verbosity = 1

    # Select test suite based on mode
    if args.mode == 'unit':
        suite = run_unit_tests()
    elif args.mode == 'integration':
        suite = run_integration_tests()
    elif args.mode == 'fast':
        print("Running fast tests (excluding slow tests)...\n")
        suite = run_unit_tests()  # Integration tests may be slow
    elif args.mode == 'coverage':
        suite = run_all_tests()
        result = run_with_coverage(suite)
        return 0 if result.wasSuccessful() else 1
    else:  # 'all'
        suite = run_all_tests()

    # Run tests
    runner = unittest.TextTestRunner(
        verbosity=verbosity,
        failfast=args.failfast
    )
    result = runner.run(suite)

    # Print summary
    print("\n" + "="*70)
    print("Test Summary:")
    print("="*70)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")

    if result.wasSuccessful():
        print("\n✓ All tests passed!")
        return 0
    else:
        print("\n✗ Some tests failed.")
        return 1


if __name__ == '__main__':
    # Add parent directory to path for imports
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

    exit_code = main()
    sys.exit(exit_code)
