# Agency
This repo holds configuration details for coding agents. It is primarily intended for us with OpenCode, but it can easily be adapted for other harnesses.

## Coding Loop
To run an autonomous coding loop, carry out the following steps:

1. Give your request to the planning agent and answer any follow up questions
```
opencode run --agent="planner" --auto "Write a plan to implement a flappy bird game that can be played on the browser"
```

2. Invoke the build-test-review loop to carry out the plan:
```
bash loops/build_test_review_loop.sh
```