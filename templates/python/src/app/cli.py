# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Command-line interface implementation adhering to POSIX standards and stream discipline."""

import argparse
import json
import os
import signal
import sys
from typing import List, Optional
from app import __version__, __license__, __repository__
from app.config import (
    load_preset,
    save_preset,
    reset_all_configuration,
    get_presets_dir,
    ToolPreset,
)


def setup_signal_handlers() -> None:
    """Gracefully handle SIGINT and SIGTERM without dumping unhandled tracebacks."""
    def _sig_handler(signum, frame):
        # Flush message to stderr and terminate cleanly with standard code 130
        sys.stderr.write("\n[mytool] Process interrupted by user. Exiting.\n")
        sys.stderr.flush()
        sys.exit(130)

    signal.signal(signal.SIGINT, _sig_handler)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, _sig_handler)


def should_colorize() -> bool:
    """Determine whether terminal ANSI colors should be emitted.

    Checks for the NO_COLOR standard environment variable before verifying
    whether stdout is connected to an interactive TTY.

    Returns:
        True if colors are supported and allowed, False otherwise.
    """
    if "NO_COLOR" in os.environ:
        return False
    return sys.stdout.isatty()


def main(argv: Optional[List[str]] = None) -> int:
    """Execute the primary command-line interface entry point.

    Args:
        argv: Optional list of CLI argument strings. If None, sys.argv[1:] is parsed.

    Returns:
        Integer exit code: 0 for success, 1 for operational error, 2 for CLI syntax error.
    """
    setup_signal_handlers()

    parser = argparse.ArgumentParser(
        prog="mytool",
        description="mytool: A standard-compliant open-source utility.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Standard global flags
    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"%(prog)s {__version__} ({__license__})\nSource: {__repository__}",
        help="Show program version and license information.",
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Suppress all informational messages (errors and data output only).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose diagnostic output on stderr.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output structured results in machine-readable JSON format to stdout.",
    )
    parser.add_argument(
        "--reset-config",
        action="store_true",
        help="Purge all user-saved presets and restore factory defaults.",
    )

    subparsers = parser.add_subparsers(dest="subcommand", help="Available subcommands")

    # 'serve' subcommand
    serve_parser = subparsers.add_parser("serve", help="Launch the local web interface on localhost.")
    serve_parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="Port number to bind (default: 8080).",
    )
    serve_parser.add_argument(
        "--host",
        type=str,
        default="127.0.0.1",
        help="Host interface to bind. Defaults strictly to 127.0.0.1 (localhost).",
    )
    serve_parser.add_argument(
        "--no-browser",
        action="store_true",
        help="Suppress automatic opening of default web browser on launch.",
    )

    # 'preset' subcommand
    preset_parser = subparsers.add_parser("preset", help="Inspect and manage local YAML presets.")
    preset_sub = preset_parser.add_subparsers(dest="preset_action")
    preset_sub.add_parser("list", help="List all locally available presets.")
    
    show_preset = preset_sub.add_parser("show", help="Display the active preset configuration.")
    show_preset.add_argument("name", nargs="?", default="default", help="Preset name (default: 'default').")

    # 'run' subcommand with stdin piping support (-)
    run_parser = subparsers.add_parser("run", help="Execute utility processing on input data.")
    run_parser.add_argument(
        "input",
        nargs="?",
        default="-",
        help="Input file path, or '-' to read directly from standard input (stdin).",
    )

    args = parser.parse_args(argv)

    # Handle global reset
    if args.reset_config:
        reset_all_configuration()
        if not args.quiet:
            sys.stderr.write("[mytool] Local configuration reset to factory defaults.\n")
        return 0

    if not args.subcommand:
        parser.print_help(sys.stderr)
        return 2

    # Handler: serve (Lazy import to maintain sub-200ms startup latency for CLI commands)
    if args.subcommand == "serve":
        from app.server import run_local_server
        run_local_server(port=args.port, host=args.host, no_browser=args.no_browser)
        return 0

    # Handler: preset
    if args.subcommand == "preset":
        if args.preset_action == "list":
            presets_dir = get_presets_dir()
            preset_files = [p.stem for p in presets_dir.glob("*.yaml")]
            if args.json:
                sys.stdout.write(json.dumps({"presets": preset_files}, indent=2) + "\n")
            else:
                for p in preset_files:
                    sys.stdout.write(f"- {p}\n")
            return 0

        if args.preset_action == "show":
            preset = load_preset(args.name)
            if args.json:
                sys.stdout.write(json.dumps(preset.model_dump(), indent=2) + "\n")
            else:
                import yaml
                sys.stdout.write(yaml.dump(preset.model_dump(), sort_keys=False) + "\n")
            return 0

    # Handler: run (Demonstrates stdin support and stream separation)
    if args.subcommand == "run":
        if args.input == "-":
            data = sys.stdin.read()
        else:
            with open(args.input, "r", encoding="utf-8") as f:
                data = f.read()

        preset = load_preset("default")
        result = {
            "status": "success",
            "bytes_processed": len(data.encode("utf-8")),
            "preset_applied": preset.name,
        }

        if args.json:
            sys.stdout.write(json.dumps(result, indent=2) + "\n")
        else:
            sys.stdout.write(f"Processed {result['bytes_processed']} bytes successfully.\n")

        if args.verbose:
            sys.stderr.write(f"[mytool] Applied preset '{preset.name}' with max_items={preset.max_items}\n")

        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
