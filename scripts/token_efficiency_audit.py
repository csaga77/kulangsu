#!/usr/bin/env python3

import pathlib
import subprocess
import sys


def main():
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    helper = repo_root / "codex_agents" / "scripts" / "token_efficiency_audit.py"
    default_config = repo_root / "scripts" / "token_efficiency_workflows.json"

    if not helper.exists():
        print("missing helper script: %s" % helper, file=sys.stderr)
        return 2
    if not default_config.exists():
        print("missing workflow config: %s" % default_config, file=sys.stderr)
        return 2

    args = [sys.executable, str(helper)]
    if len(sys.argv) == 1:
        args.append(str(default_config))
    elif sys.argv[1].startswith("-"):
        args.append(str(default_config))
        args.extend(sys.argv[1:])
    else:
        args.extend(sys.argv[1:])

    return subprocess.call(args)


if __name__ == "__main__":
    raise SystemExit(main())
