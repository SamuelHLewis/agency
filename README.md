# Agency
This repo holds configuration details for coding agents. It is primarily intended for us with OpenCode, but it can easily be adapted for other harnesses.

## Coding Loop
To run an autonomous coding loop, carry out the following steps:

1. Give your request to the planning agent and answer any follow up questions
```bash
opencode run --agent="planner" "Write a plan to implement a flappy bird game that can be played on the browser"
```

2. Invoke the build-test-review loop to carry out the plan:
```bash
bash loops/build_test_review_loop.sh
```

## Sandboxed Coding Loop
### Why Sandbox?
Coding loops are designed to act autonomously, completing a task and reporting back to a human rather than asking a human's permission at every step. While this ia enourmously powerful and very productive, it introduces the risk of unexpected commands being issued and critical files being accessed and modified. It is therefore advisable to run the coding loop in a container, which imposes OS-level restrictions on the files that the agents can access.

### Prerequisites

* MacOS 12+
* homebrew
* an account with a coding assistant provider (if using a proprietary assistant)

### Caveats

* These instructions are intended as a general guide, not a rigorous specification. Details may differ depending on your OS or hardware.
* This sandbox setup allows access to the internet, so you still need to supervise your assistant.
* The functions below are working examples only, they are not recommendations of best security practice. You are responsible for deciding what implementation gives you an appropriate balance of security and functionality.

### Initial Setup

The following steps only need to be carried out the first time you set up your sandbox.

#### Podman Installation

We use Podman because it doesn't require root privileges. To install it on MacOS, type into terminal:

```bash
brew install podman
```

Then create the lightweight Linux VM that will host your containers:

```bash
podman machine init
```

Finally, create an image for the container that contains the coding agent and its dependencies:

```bash
podman build --no-cache -t localhost/opencode-base ~/coding_sandbox/
```

#### Loop Custom Command

Add this to your shell config file (`.bashrc` or `.zshrc`):
```bash
opencode_bash_sandboxed() {
  # Require at least the target directory and the script to run
  if [ "$#" -lt 2 ]; then
    echo "Usage: opencode_bash_sandboxed <target_dir> <script_path_relative_to_target> [args...]"
    return 1
  fi

  local target_dir="$1"
  shift

  # 1. Ensure the sandbox layout exists
  mkdir -p "$HOME/.ai-sandbox-home/.local/bin"
  mkdir -p "$HOME/.ai-sandbox-home/.opencode"
  chmod 700 "$HOME/.ai-sandbox-home/.opencode"

  # 2. Mirror the host OpenCode config into the sandbox before starting
  local OPENCODE_CONFIG_SRC="${OPENCODE_CONFIG_SRC:-$HOME/.config/opencode/opencode.jsonc}"
  local OPENCODE_SANDBOX_CONFIG="${OPENCODE_SANDBOX_CONFIG:-$HOME/.ai-sandbox-home/.opencode/opencode.jsonc}"

  if [ ! -f "$OPENCODE_CONFIG_SRC" ]; then
    printf 'Host opencode config not present at %s, skipping copy.\n' "$OPENCODE_CONFIG_SRC" >&2
  else
    mkdir -p "$(dirname "$OPENCODE_SANDBOX_CONFIG")"
    if [ -f "$OPENCODE_SANDBOX_CONFIG" ] && cmp -s "$OPENCODE_CONFIG_SRC" "$OPENCODE_SANDBOX_CONFIG"; then
      chmod 600 "$OPENCODE_SANDBOX_CONFIG"
      printf 'Sandbox opencode config already up to date (%s).\n' "$OPENCODE_SANDBOX_CONFIG" >&2
    else
      cp "$OPENCODE_CONFIG_SRC" "$OPENCODE_SANDBOX_CONFIG"
      chmod 600 "$OPENCODE_SANDBOX_CONFIG"
      printf 'Copied host opencode config into sandbox (%s).\n' "$OPENCODE_SANDBOX_CONFIG" >&2
    fi
  fi

  echo "Starting bash sandbox for directory: $target_dir"

  # 3. Run the container with a bash entrypoint
  #    "$@" now represents the script name and any arguments you pass
  podman run --rm -it \
    --entrypoint /bin/bash \
    -v "$HOME/.ai-sandbox-home:/root:Z" \
    -v "$(realpath "$target_dir"):/workspace:Z" \
    -w "/workspace" \
    localhost/opencode-base "$@"
}
```

### How to Run

Having completed the Initial Setup procedure outlined above, the following steps need to be run each time you start up your computer.

#### Podman

To start the VM, run:

```bash
podman machine start
```

And check that it has launched successfully by running:

```bash
podman info
```

#### Loop Launch

Once the podman VM is running, launch the loop with:

```bash
opencode_bash_sandboxed /path/to/your/project ./loops/build_test_review_loop.sh
```

## OpenCode Configuration

If you are using OpenCode, there are two files that you need to modify to ensure that OpenCode can run: `auth.json` and `opencode.jsonc`.

### auth.json

This file holds your API keys and metadata for your model deployments. On MacOS it can be found at:

`~/.local/share/opencode/auth.json`

Each cloud platform has a separate entry, with common variable names across the entries.

For example, if you want to access models deployed on Azure Foundry and AWS Bedrock, your `auth.json` will look like this:
```json
{
  "azure": {
    "type": "api",
    "key": "replace-with-your-Azure-Foundry-api-key",
    "metadata": {
      "resourceName": "replace-with-your-Azure-resource-name"
    }
  },
  "amazon-bedrock": {
    "type": "api",
    "key": "replace-with-your-AWS-Bedrock-key"
  }
}
```

### opencode.jsonc

This file holds metadata about your cloud platforms and specifications for agents. On MacOS it can be found at:

`~/.config/opencode/opencode.jsonc`

This file allows you to specify different models for each agent. For example, if you want your build agent to use gpt-5.3-codex deployed on Azure Foundry, and your reviewer agent to use Claude Sonnet 5 deployed on AWS Bedrock, your `opencode.jsonc` will look like this:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
      "amazon-bedrock": {
        "options": {
          "region": "replace-with-your-AWS-region"
        }
      },
      "azure": {
        "options": {
          "resourceName": "replace-with-your-Azure-resource-name"
        }
      }
    },
  "agent": {
    "builder": {
      "mode": "primary",
      "model": "azure/gpt-5.3-codex",
      "prompt": "You are the build engineer. Your primary task is to write source code to implement features.",
      "permission": {
        "bash": {
          "git push": "deny",
          "git commit": "deny"
        }
      }
    },
    "reviewer": {
      "mode": "primary",
      "model": "amazon-bedrock/anthropic.claude-sonnet-5",
      "prompt": "You are the review agent. Your primary task is to review code.",
      "permission": {
        "edit": "deny"
      }
    }
  }
}
```
