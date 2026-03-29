#!/usr/bin/env python3

import pathlib
import subprocess
import sys


def main():
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    helper = repo_root / "codex_agents" / "scripts" / "source_control_report.py"

    if not helper.exists():
        print(
            "missing helper script: %s" % helper,
            file=sys.stderr,
        )
        return 2

    args = [sys.executable, str(helper)]
    if len(sys.argv) == 1:
        args.append(str(repo_root))
    else:
        args.extend(sys.argv[1:])

    return subprocess.call(args)


if __name__ == "__main__":
    raise SystemExit(main())
